`include "uart_config.svh"
`include "uart_tb_log.svh"

import axi_lite_tb_pkg::axi_lite_write_order_e;
import axi_lite_tb_pkg::AXI_LITE_RESP_OKAY;
import axi_lite_tb_pkg::AXI_LITE_RESP_SLVERR;
import axi_lite_tb_pkg::AXI_LITE_AW_BEFORE_W;
import axi_lite_tb_pkg::AXI_LITE_W_BEFORE_AW;
import axi_lite_tb_pkg::AXI_LITE_AW_W_SAME_CYCLE;
import uart_serial_tb_pkg::uart_serial_frame_t;
import uart_reg_pkg::UART_RBR_THR_ADDR;
import uart_reg_pkg::UART_IER_ADDR;
import uart_reg_pkg::UART_IIR_ADDR;
import uart_reg_pkg::UART_LSR_ADDR;

// End-to-end AXI-UART test library. One suite object owns all named test tasks,
// while the inherited base keeps common setup and checking helpers reusable.
class uart_axi_tests extends uart_axi_test_base;

    function new(uart_axi_env env_arg);
        super.new(env_arg);
    endfunction

    task automatic axi_uart_tx_path();
        logic [`DATA_BITS-1:0] random_data;
        uart_serial_frame_t    actual_frame;
        axi_lite_write_order_e order;

        `UART_DISPLAY((
            "[AXI UART SYSTEM TEST] Checking AXI-to-serial TX path"
        ))

        for (int unsigned iteration = 0; iteration < 5; iteration++) begin
            random_data = `DATA_BITS'($urandom());

            unique case (iteration % 3)
                0: order = AXI_LITE_AW_BEFORE_W;
                1: order = AXI_LITE_W_BEFORE_AW;
                default: order = AXI_LITE_AW_W_SAME_CYCLE;
            endcase

            fork
                env.serial_agent.monitor.receive_tx_frame(actual_frame);
                expect_write(
                    UART_RBR_THR_ADDR,
                    {{(32-`DATA_BITS){1'b0}}, random_data},
                    4'hF,
                    AXI_LITE_RESP_OKAY,
                    $sformatf("TX byte %0d accepted through THR", iteration),
                    order,
                    iteration % 2
                );
            join

            env.serial_agent.scoreboard.check_valid_tx_frame(
                random_data,
                actual_frame
            );
        end
    endtask

    task automatic axi_uart_rx_path();
        logic [`DATA_BITS-1:0] random_data;

        `UART_DISPLAY((
            "[AXI UART SYSTEM TEST] Checking serial-to-AXI RX path"
        ))

        // Enable only RX-data interrupts so irq is an unambiguous indication
        // that a completed frame reached the receive buffer.
        expect_write(UART_IER_ADDR, 32'h1, 4'hF, AXI_LITE_RESP_OKAY,
                     "enable RX-data interrupt");

        for (int unsigned iteration = 0; iteration < 5; iteration++) begin
            random_data = `DATA_BITS'($urandom());
            env.serial_agent.driver.send_valid_frame(random_data);

            wait_for_irq(1'b1);
            expect_read(UART_IIR_ADDR, 32'h5, AXI_LITE_RESP_OKAY,
                        $sformatf("RX interrupt identification %0d", iteration));
            expect_read(
                UART_RBR_THR_ADDR,
                {{(32-`DATA_BITS){1'b0}}, random_data},
                AXI_LITE_RESP_OKAY,
                $sformatf("RX byte %0d read through RBR", iteration)
            );

            wait_for_irq(1'b0);
            check_bit("RBR read clears RX interrupt", 1'b0,
                      env.irq_vif.irq);
        end

        expect_read(UART_LSR_ADDR, 32'h2, AXI_LITE_RESP_OKAY,
                    "RX buffer empty after all reads");
    endtask

    task automatic axi_uart_full_duplex();
        logic [`DATA_BITS-1:0] tx_values [0:2];
        logic [`DATA_BITS-1:0] rx_values [0:2];
        uart_serial_frame_t    tx_frame;
        logic                  overlap_seen;

        `UART_DISPLAY(("[AXI UART SYSTEM TEST] Checking concurrent TX and RX"))

        for (int unsigned index = 0; index < 3; index++) begin
            tx_values[index] = `DATA_BITS'($urandom());
            rx_values[index] = `DATA_BITS'($urandom());

            // Different values make accidental direction swapping obvious.
            if (rx_values[index] == tx_values[index])
                rx_values[index] ^= `DATA_BITS'(8'hFF);
        end

        expect_write(UART_IER_ADDR, 32'h1, 4'hF, AXI_LITE_RESP_OKAY,
                     "enable RX interrupt for duplex traffic");

        fork
            begin : tx_direction
                for (int unsigned index = 0; index < 3; index++) begin
                    fork
                        env.serial_agent.monitor.receive_tx_frame(tx_frame);
                        expect_write(
                            UART_RBR_THR_ADDR,
                            {{(32-`DATA_BITS){1'b0}}, tx_values[index]},
                            4'hF,
                            AXI_LITE_RESP_OKAY,
                            $sformatf("duplex TX write %0d", index)
                        );
                    join

                    env.serial_agent.scoreboard.check_valid_tx_frame(
                        tx_values[index],
                        tx_frame
                    );
                end
            end

            begin : rx_direction
                for (int unsigned index = 0; index < 3; index++) begin
                    env.serial_agent.driver.send_valid_frame(rx_values[index]);
                    wait_for_irq(1'b1);
                    expect_read(
                        UART_RBR_THR_ADDR,
                        {{(32-`DATA_BITS){1'b0}}, rx_values[index]},
                        AXI_LITE_RESP_OKAY,
                        $sformatf("duplex RX read %0d", index)
                    );
                    wait_for_irq(1'b0);
                end
            end

            env.monitor.observe_serial_overlap(100_000, overlap_seen);
        join

        check_bit("TX and RX serial activity overlapped", 1'b1,
                  overlap_seen);
        expect_read(UART_LSR_ADDR, 32'h2, AXI_LITE_RESP_OKAY,
                    "duplex traffic leaves buffers empty");
    endtask

    task automatic axi_uart_buffers_errors_irq();
        uart_serial_frame_t first_tx_frame;
        uart_serial_frame_t second_tx_frame;

        `UART_DISPLAY((
            "[AXI UART SYSTEM TEST] Checking buffers, errors, and IRQ priority"
        ))

        // The first byte moves from THR into the busy UART. The second remains
        // buffered; a third write must fail and must not replace it.
        fork
            begin
                env.serial_agent.monitor.receive_tx_frame(first_tx_frame);
                env.serial_agent.monitor.receive_tx_frame(second_tx_frame);
            end
            begin
                expect_write(UART_RBR_THR_ADDR, 32'h31, 4'hF,
                             AXI_LITE_RESP_OKAY, "first TX byte accepted");
                wait (env.serial_vif.tx_out === 1'b0);
                expect_write(UART_RBR_THR_ADDR, 32'h42, 4'hF,
                             AXI_LITE_RESP_OKAY, "second TX byte buffered");
                expect_write(UART_RBR_THR_ADDR, 32'hE7, 4'hF,
                             AXI_LITE_RESP_SLVERR,
                             "full THR rejects third TX byte");
            end
        join

        env.serial_agent.scoreboard.check_valid_tx_frame(
            `DATA_BITS'(8'h31), first_tx_frame
        );
        env.serial_agent.scoreboard.check_valid_tx_frame(
            `DATA_BITS'(8'h42), second_tx_frame
        );

        // Enable every source. Empty THR is initially the only pending source.
        expect_write(UART_IER_ADDR, 32'hF, 4'hF, AXI_LITE_RESP_OKAY,
                     "enable all interrupts");
        expect_read(UART_IIR_ADDR, 32'h3, AXI_LITE_RESP_OKAY,
                    "THR-empty interrupt identification");

        // A malformed stop bit sets sticky framing status, but does not place
        // bad data in RBR. Line status has the highest interrupt priority.
        env.serial_agent.driver.send_bad_stop_frame(`DATA_BITS'(8'hD4));
        wait_clock_cycles(20);
        expect_read(UART_IIR_ADDR, 32'h7, AXI_LITE_RESP_OKAY,
                    "framing error has line-status priority");
        expect_read(UART_LSR_ADDR, 32'h6, AXI_LITE_RESP_OKAY,
                    "LSR reports and clears framing error");
        expect_read(UART_IIR_ADDR, 32'h3, AXI_LITE_RESP_OKAY,
                    "priority returns to THR empty after LSR read");
        expect_read(UART_RBR_THR_ADDR, 32'h0, AXI_LITE_RESP_OKAY,
                    "bad frame did not enter RBR");

        // Two complete frames without a software read overflow the one-byte
        // RBR. The first byte must be preserved and overrun must be sticky.
        env.serial_agent.driver.send_valid_frame(`DATA_BITS'(8'h55));
        env.serial_agent.driver.send_valid_frame(`DATA_BITS'(8'hAA));
        wait_clock_cycles(20);
        expect_read(UART_IIR_ADDR, 32'h7, AXI_LITE_RESP_OKAY,
                    "overrun has line-status priority");
        expect_read(UART_LSR_ADDR, 32'hB, AXI_LITE_RESP_OKAY,
                    "LSR reports overrun and RX-ready");
        expect_read(UART_IIR_ADDR, 32'h5, AXI_LITE_RESP_OKAY,
                    "RX data becomes pending after overrun clear");
        expect_read(UART_RBR_THR_ADDR, 32'h55, AXI_LITE_RESP_OKAY,
                    "RBR preserves first byte on overrun");
        expect_read(UART_IIR_ADDR, 32'h3, AXI_LITE_RESP_OKAY,
                    "THR empty remains after RBR pop");
    endtask

    task automatic axi_uart_reset_recovery();
        uart_serial_frame_t recovered_tx_frame;

        `UART_DISPLAY((
            "[AXI UART SYSTEM TEST] Checking reset cancellation and recovery"
        ))

        // Start both serial directions. Leave B and R responses backpressured,
        // then reset to prove that neither response survives reset.
        fork : interrupted_rx_traffic
            env.serial_agent.driver.send_valid_frame(`DATA_BITS'(8'h96));
        join_none

        expect_write(UART_RBR_THR_ADDR, 32'h69, 4'hF,
                     AXI_LITE_RESP_OKAY, "start TX before reset");
        wait (env.serial_vif.tx_out === 1'b0);

        fork
            env.axi_agent.driver.drive_write_address(UART_IER_ADDR, 3'b000);
            env.axi_agent.driver.drive_write_data(32'hF, 4'hF);
        join
        wait (env.axi_vif.s_axi_bvalid === 1'b1);

        env.axi_agent.driver.drive_read_address(UART_LSR_ADDR, 3'b000);
        wait (env.axi_vif.s_axi_rvalid === 1'b1);

        env.reset_driver.assert_reset();
        repeat (3) @(posedge env.ctrl_vif.clk);
        disable interrupted_rx_traffic;
        env.serial_agent.driver.drive_idle();
        #1step;

        check_bit("BVALID cleared by reset", 1'b0,
                  env.axi_vif.s_axi_bvalid);
        check_bit("RVALID cleared by reset", 1'b0,
                  env.axi_vif.s_axi_rvalid);
        check_bit("IRQ cleared by reset", 1'b0, env.irq_vif.irq);
        check_bit("TX returns idle-high on reset", 1'b1,
                  env.serial_vif.tx_out);

        env.reset_driver.deassert_reset();
        wait_clock_cycles(2);
        check_bit("no stale B response after reset", 1'b0,
                  env.axi_vif.s_axi_bvalid);
        check_bit("no stale R response after reset", 1'b0,
                  env.axi_vif.s_axi_rvalid);

        // A separately reset AW-only request proves that partially collected
        // write-channel state is also discarded.
        env.axi_agent.driver.drive_write_address(UART_IER_ADDR, 3'b000);
        env.reset_driver.assert_reset();
        repeat (2) @(posedge env.ctrl_vif.clk);
        env.reset_driver.deassert_reset();
        wait_clock_cycles(3);
        check_bit("partial AW does not resurrect after reset", 1'b0,
                  env.axi_vif.s_axi_bvalid);
        expect_read(UART_IER_ADDR, 32'h0, AXI_LITE_RESP_OKAY,
                    "registers return to reset state");

        // Finally prove that reset did not merely silence the peripheral: new
        // traffic must work correctly in both directions.
        env.serial_agent.driver.send_valid_frame(`DATA_BITS'(8'hA6));
        wait_clock_cycles(20);
        expect_read(UART_RBR_THR_ADDR, 32'hA6, AXI_LITE_RESP_OKAY,
                    "RX recovers after reset");

        fork
            env.serial_agent.monitor.receive_tx_frame(recovered_tx_frame);
            expect_write(UART_RBR_THR_ADDR, 32'h5C, 4'hF,
                         AXI_LITE_RESP_OKAY, "TX recovers after reset");
        join
        env.serial_agent.scoreboard.check_valid_tx_frame(
            `DATA_BITS'(8'h5C), recovered_tx_frame
        );
    endtask

endclass
