`include "uart_config.svh"
`include "uart_tb_log.svh"

import uart_reg_pkg::UART_RBR_THR_ADDR;
import uart_reg_pkg::UART_IER_ADDR;
import uart_reg_pkg::UART_IIR_ADDR;
import uart_reg_pkg::UART_LSR_ADDR;

class uart_reg_tests;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_reg_if.monitor     vif;
    uart_reset_driver               reset_driver;
    uart_reg_driver                 driver;
    uart_reg_monitor                monitor;
    uart_reg_scoreboard             scoreboard;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_reg_if.monitor     vif_arg,
        uart_reset_driver               reset_driver_arg,
        uart_reg_driver                 driver_arg,
        uart_reg_monitor                monitor_arg,
        uart_reg_scoreboard             scoreboard_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif = vif_arg;
        this.reset_driver = reset_driver_arg;
        this.driver = driver_arg;
        this.monitor = monitor_arg;
        this.scoreboard = scoreboard_arg;
    endfunction

    task automatic expect_read(
        input logic [31:0] address,
        input logic [31:0] expected_data,
        input logic        expected_error,
        input string       test_context
    );
        logic [31:0] actual_data;
        logic        actual_error;

        driver.read_register(address, actual_data, actual_error);
        scoreboard.check_read(
            test_context,
            expected_data,
            actual_data,
            expected_error,
            actual_error
        );
    endtask

    task automatic expect_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0]  strobe,
        input logic        expected_error,
        input string       test_context
    );
        logic actual_error;

        driver.write_register(address, data, strobe, actual_error);
        scoreboard.check_write_error(
            test_context,
            expected_error,
            actual_error
        );
    endtask

    task automatic check_tx(
        input logic                  expected_start,
        input logic [`DATA_BITS-1:0] expected_data,
        input string                 test_context
    );
        logic                  actual_start;
        logic [`DATA_BITS-1:0] actual_data;

        monitor.sample_tx_request(actual_start, actual_data);
        scoreboard.check_tx_request(
            test_context,
            expected_start,
            expected_data,
            actual_start,
            actual_data
        );
    endtask

    task automatic check_irq(
        input logic  expected,
        input string test_context
    );
        scoreboard.check_irq(
            test_context,
            expected,
            monitor.sample_irq()
        );
    endtask

    task automatic reset_and_check();
        driver.initialize_inputs();
        reset_driver.apply_reset();

        check_tx(1'b0, '0, "reset TX state");
        check_irq(1'b0, "reset interrupt state");
        expect_read(UART_IER_ADDR, 32'h0000_0000, 1'b0, "IER reset value");
        expect_read(UART_IIR_ADDR, 32'h0000_0000, 1'b0, "IIR reset value");
        expect_read(UART_LSR_ADDR, 32'h0000_0002, 1'b0, "LSR reset value");
    endtask

    task automatic reg_sanity();
        logic [`DATA_BITS-1:0] accepted_data;

        `UART_DISPLAY(("[REG TEST] Starting register-block sanity test"))
        reset_and_check();

        expect_write(
            UART_IER_ADDR,
            32'h0000_0005,
            4'hF,
            1'b0,
            "write IER"
        );
        expect_read(UART_IER_ADDR, 32'h0000_0005, 1'b0, "read back IER");

        expect_write(
            UART_RBR_THR_ADDR,
            32'h0000_00A5,
            4'hF,
            1'b0,
            "write THR"
        );
        check_tx(1'b1, `DATA_BITS'(8'hA5), "THR presents data to UART TX");
        expect_read(UART_LSR_ADDR, 32'h0000_0000, 1'b0, "LSR while THR full");

        driver.consume_thr(accepted_data);
        scoreboard.check_tx_request(
            "UART consumed THR data",
            1'b1,
            `DATA_BITS'(8'hA5),
            1'b1,
            accepted_data
        );
        check_tx(1'b0, `DATA_BITS'(8'hA5), "THR empty after UART acceptance");
        expect_read(UART_LSR_ADDR, 32'h0000_0002, 1'b0, "LSR after THR pop");

        driver.push_rx_byte(`DATA_BITS'(8'h3C));
        check_irq(1'b1, "RX data interrupt enabled");
        expect_read(UART_LSR_ADDR, 32'h0000_0003, 1'b0, "LSR with RX data");
        expect_read(UART_RBR_THR_ADDR, 32'h0000_003C, 1'b0, "read received byte");
        check_irq(1'b0, "RX interrupt cleared by RBR read");
        expect_read(UART_LSR_ADDR, 32'h0000_0002, 1'b0, "LSR after RBR pop");

        `UART_DISPLAY(("[REG TEST] [PASS] Register-block sanity test completed"))
    endtask

    task automatic reg_random_access();
        logic [3:0]            random_ier;
        logic [`DATA_BITS-1:0] random_rx_data;
        logic [`DATA_BITS-1:0] random_tx_data;
        logic [`DATA_BITS-1:0] accepted_data;

        `UART_DISPLAY(("[REG TEST] Starting randomized directed register test"))
        reset_and_check();

        for (int iteration = 0; iteration < 10; iteration++) begin
            random_ier = 4'($urandom);
            random_rx_data = `DATA_BITS'($urandom);
            random_tx_data = `DATA_BITS'($urandom);

            expect_write(
                UART_IER_ADDR,
                {28'b0, random_ier},
                4'hF,
                1'b0,
                $sformatf("random IER write %0d", iteration)
            );
            expect_read(
                UART_IER_ADDR,
                {28'b0, random_ier},
                1'b0,
                $sformatf("random IER readback %0d", iteration)
            );

            driver.push_rx_byte(random_rx_data);
            expect_read(
                UART_RBR_THR_ADDR,
                {{(32-`DATA_BITS){1'b0}}, random_rx_data},
                1'b0,
                $sformatf("random RBR data %0d", iteration)
            );

            expect_write(
                UART_RBR_THR_ADDR,
                {{(32-`DATA_BITS){1'b0}}, random_tx_data},
                4'hF,
                1'b0,
                $sformatf("random THR data %0d", iteration)
            );
            check_tx(
                1'b1,
                random_tx_data,
                $sformatf("random THR request %0d", iteration)
            );
            driver.consume_thr(accepted_data);
            scoreboard.check_tx_request(
                $sformatf("random THR acceptance %0d", iteration),
                1'b1,
                random_tx_data,
                1'b1,
                accepted_data
            );
        end

        `UART_DISPLAY(("[REG TEST] [PASS] Randomized directed register test completed"))
    endtask

    task automatic reg_negative_access();
        `UART_DISPLAY(("[REG TEST] Starting negative register-access test"))
        reset_and_check();

        expect_write(UART_IIR_ADDR, 32'hFFFF_FFFF, 4'hF, 1'b1, "write read-only IIR");
        expect_write(UART_LSR_ADDR, 32'hFFFF_FFFF, 4'hF, 1'b1, "write read-only LSR");
        expect_write(32'h0000_0010, 32'h1234_5678, 4'hF, 1'b1, "write unmapped address");
        expect_write(32'h0000_0001, 32'h1234_5678, 4'hF, 1'b1, "write misaligned address");

        expect_read(32'h0000_0010, 32'h0000_0000, 1'b1, "read unmapped address");
        expect_read(32'h0000_0002, 32'h0000_0000, 1'b1, "read misaligned address");
        expect_read(UART_RBR_THR_ADDR, 32'h0000_0000, 1'b0, "read empty RBR");

        expect_write(
            UART_RBR_THR_ADDR,
            32'h0000_00CC,
            4'h0,
            1'b0,
            "THR write with WSTRB[0] clear"
        );
        check_tx(1'b0, '0, "un-strobed THR write has no effect");

        expect_write(
            UART_IER_ADDR,
            32'h0000_000F,
            4'b0010,
            1'b0,
            "IER upper-byte-only write"
        );
        expect_read(UART_IER_ADDR, 32'h0000_0000, 1'b0, "IER unchanged by upper strobe");

        expect_write(UART_RBR_THR_ADDR, 32'h0000_0055, 4'hF, 1'b0, "initial THR write");
        expect_write(UART_RBR_THR_ADDR, 32'h0000_00AA, 4'hF, 1'b1, "write full THR");
        check_tx(1'b1, `DATA_BITS'(8'h55), "full THR preserves old byte");

        begin
            logic [`DATA_BITS-1:0] accepted_data;
            driver.consume_thr(accepted_data);
            scoreboard.check_tx_request(
                "consume preserved THR byte",
                1'b1,
                `DATA_BITS'(8'h55),
                1'b1,
                accepted_data
            );
        end

        `UART_DISPLAY(("[REG TEST] [PASS] Negative register-access test completed"))
    endtask

    task automatic reg_buffer_corner_cases();
        logic [31:0]          read_data;
        logic                 access_error;
        logic [`DATA_BITS-1:0] accepted_data;

        `UART_DISPLAY(("[REG TEST] Starting register buffer corner-case test"))
        reset_and_check();

        // Preserve the unread first byte and set overrun on the second.
        driver.push_rx_byte(`DATA_BITS'(8'h11));
        driver.push_rx_byte(`DATA_BITS'(8'h22));
        expect_read(UART_LSR_ADDR, 32'h0000_000B, 1'b0, "LSR reports overrun");
        expect_read(UART_LSR_ADDR, 32'h0000_0003, 1'b0, "LSR read clears only overrun");
        expect_read(UART_RBR_THR_ADDR, 32'h0000_0011, 1'b0, "overrun preserves old RBR byte");

        // A simultaneous pop/push returns the old byte and retains the new one.
        driver.push_rx_byte(`DATA_BITS'(8'h33));
        driver.read_with_rx_push(
            UART_RBR_THR_ADDR,
            `DATA_BITS'(8'h44),
            read_data,
            access_error
        );
        scoreboard.check_read(
            "simultaneous RBR pop/push returns old byte",
            32'h0000_0033,
            read_data,
            1'b0,
            access_error
        );
        expect_read(UART_RBR_THR_ADDR, 32'h0000_0044, 1'b0, "new simultaneous RX byte remains buffered");

        // A simultaneous THR pop/push transfers the old byte and retains new.
        expect_write(UART_RBR_THR_ADDR, 32'h0000_0055, 4'hF, 1'b0, "load old THR byte");
        driver.write_with_tx_accept(
            UART_RBR_THR_ADDR,
            32'h0000_0066,
            4'hF,
            accepted_data,
            access_error
        );
        scoreboard.check_write_error(
            "simultaneous THR pop/push accepted",
            1'b0,
            access_error
        );
        scoreboard.check_tx_request(
            "simultaneous THR pop transfers old byte",
            1'b1,
            `DATA_BITS'(8'h55),
            1'b1,
            accepted_data
        );
        check_tx(1'b1, `DATA_BITS'(8'h66), "new THR byte retained after simultaneous pop/push");
        driver.consume_thr(accepted_data);
        scoreboard.check_tx_request(
            "consume replacement THR byte",
            1'b1,
            `DATA_BITS'(8'h66),
            1'b1,
            accepted_data
        );

        `UART_DISPLAY(("[REG TEST] [PASS] Register buffer corner-case test completed"))
    endtask

    task automatic reg_interrupt_priority();
        `UART_DISPLAY(("[REG TEST] Starting interrupt masking and priority test"))
        reset_and_check();

        // Underlying sources may become active while IER masks every interrupt.
        driver.push_rx_byte(`DATA_BITS'(8'hA1));
        driver.pulse_framing_error();
        check_irq(1'b0, "IER masks pending RX and line-status sources");

        expect_write(UART_IER_ADDR, 32'h0000_000F, 4'hF, 1'b0, "enable all interrupts");
        check_irq(1'b1, "enabling IER exposes pending source");
        expect_read(UART_IIR_ADDR, 32'h0000_0007, 1'b0, "line status has highest priority");

        expect_read(UART_LSR_ADDR, 32'h0000_0007, 1'b0, "read LSR with framing and RX data");
        expect_read(UART_IIR_ADDR, 32'h0000_0005, 1'b0, "RX data exposed after line-status clear");

        expect_read(UART_RBR_THR_ADDR, 32'h0000_00A1, 1'b0, "service RX-data interrupt");
        expect_read(UART_IIR_ADDR, 32'h0000_0003, 1'b0, "THR empty exposed after RBR read");

        expect_write(UART_RBR_THR_ADDR, 32'h0000_005A, 4'hF, 1'b0, "service THR-empty interrupt");
        expect_read(UART_IIR_ADDR, 32'h0000_0000, 1'b0, "no pending source with THR full");
        check_irq(1'b0, "irq clears after all sources serviced");

        expect_write(UART_IER_ADDR, 32'h0000_0000, 4'hF, 1'b0, "disable all interrupts");
        begin
            logic [`DATA_BITS-1:0] accepted_data;
            driver.consume_thr(accepted_data);
        end
        check_irq(1'b0, "disabled TX interrupt remains masked when THR empties");
        expect_write(UART_IER_ADDR, 32'h0000_0002, 4'hF, 1'b0, "re-enable TX interrupt");
        expect_read(UART_IIR_ADDR, 32'h0000_0003, 1'b0, "underlying THR-empty source remains active");

        `UART_DISPLAY(("[REG TEST] [PASS] Interrupt masking and priority test completed"))
    endtask

endclass
