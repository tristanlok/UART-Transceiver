`include "uart_config.svh"
`include "uart_tb_log.svh"

import axi_lite_tb_pkg::axi_lite_transaction_t;
import axi_lite_tb_pkg::axi_lite_write_order_e;
import axi_lite_tb_pkg::axi_lite_default_transaction;
import axi_lite_tb_pkg::AXI_LITE_READ;
import axi_lite_tb_pkg::AXI_LITE_WRITE;
import axi_lite_tb_pkg::AXI_LITE_RESP_OKAY;
import axi_lite_tb_pkg::AXI_LITE_RESP_SLVERR;
import axi_lite_tb_pkg::AXI_LITE_AW_BEFORE_W;
import axi_lite_tb_pkg::AXI_LITE_W_BEFORE_AW;
import axi_lite_tb_pkg::AXI_LITE_AW_W_SAME_CYCLE;
import uart_reg_pkg::UART_RBR_THR_ADDR;
import uart_reg_pkg::UART_IER_ADDR;
import uart_reg_pkg::UART_IIR_ADDR;
import uart_reg_pkg::UART_LSR_ADDR;

// AXI-Lite protocol/register test library. Like uart_tx_tests, uart_rx_tests,
// uart_reg_tests, and uart_tests, this class contains one named task per test.
// The shared base supplies setup, reporting, and transaction helpers.
class uart_axi_lite_tests extends uart_axi_test_base;

    function new(uart_axi_env env_arg);
        super.new(env_arg);
    endfunction

    task automatic observed_ier_write(
        input logic [3:0]            value,
        input axi_lite_write_order_e order,
        input int unsigned           gap,
        input string                 test_context
    );
        axi_lite_transaction_t driven;
        axi_lite_transaction_t observed;

        driven = axi_lite_default_transaction();
        driven.access = AXI_LITE_WRITE;
        driven.address = UART_IER_ADDR;
        driven.write_data = {28'b0, value};
        driven.write_strobe = 4'hF;
        driven.write_order = order;
        driven.channel_gap_cycles = gap;
        driven.expected_response = AXI_LITE_RESP_OKAY;
        driven.check_read_data = 1'b0;

        fork
            env.axi_agent.monitor.observe_write(observed);
            env.axi_agent.driver.write_transaction(driven);
        join

        env.axi_agent.scoreboard.check_transaction(test_context, driven);
        env.axi_agent.scoreboard.check_response(
            {test_context, " passive response"},
            AXI_LITE_RESP_OKAY,
            observed.actual_response
        );
        env.axi_agent.scoreboard.check_write_order(
            {test_context, " observed order"},
            order,
            observed.write_order
        );
        expect_read(UART_IER_ADDR, {28'b0, value}, AXI_LITE_RESP_OKAY,
                    {test_context, " readback"});
    endtask

    task automatic axi_reset_basic_map();
        `UART_DISPLAY(("[AXI PROTOCOL TEST] Checking reset and basic map"))

        env.reset_driver.assert_reset();
        wait_clock_cycles(2);

        check_bit("AWREADY suppressed during reset", 1'b0,
                  env.axi_vif.s_axi_awready);
        check_bit("WREADY suppressed during reset", 1'b0,
                  env.axi_vif.s_axi_wready);
        check_bit("BVALID cleared during reset", 1'b0,
                  env.axi_vif.s_axi_bvalid);
        check_bit("ARREADY suppressed during reset", 1'b0,
                  env.axi_vif.s_axi_arready);
        check_bit("RVALID cleared during reset", 1'b0,
                  env.axi_vif.s_axi_rvalid);
        check_bit("IRQ cleared during reset", 1'b0, env.irq_vif.irq);

        env.reset_driver.deassert_reset();
        wait_clock_cycles(1);

        check_bit("AWREADY asserted after reset", 1'b1,
                  env.axi_vif.s_axi_awready);
        check_bit("WREADY asserted after reset", 1'b1,
                  env.axi_vif.s_axi_wready);
        check_bit("ARREADY asserted after reset", 1'b1,
                  env.axi_vif.s_axi_arready);

        expect_read(UART_RBR_THR_ADDR, 32'h0, AXI_LITE_RESP_OKAY,
                    "empty RBR reset value");
        expect_read(UART_IER_ADDR, 32'h0, AXI_LITE_RESP_OKAY,
                    "IER reset value");
        expect_read(UART_IIR_ADDR, 32'h0, AXI_LITE_RESP_OKAY,
                    "IIR reset value");
        expect_read(UART_LSR_ADDR, 32'h2, AXI_LITE_RESP_OKAY,
                    "LSR reset value");

        expect_write(UART_IER_ADDR, 32'hFFFF_FFFA, 4'hF,
                     AXI_LITE_RESP_OKAY, "write IER implemented bits");
        expect_read(UART_IER_ADDR, 32'h0000_000A, AXI_LITE_RESP_OKAY,
                    "IER reserved bits read zero");
    endtask

    task automatic axi_write_channel_order();
        `UART_DISPLAY((
            "[AXI PROTOCOL TEST] Exercising independent AW/W ordering"
        ))

        observed_ier_write(4'h1, AXI_LITE_AW_BEFORE_W, 3,
                           "AW before W");
        observed_ier_write(4'h6, AXI_LITE_W_BEFORE_AW, 2,
                           "W before AW");
        observed_ier_write(4'hA, AXI_LITE_AW_W_SAME_CYCLE, 0,
                           "AW and W together");
    endtask

    task automatic axi_response_backpressure();
        axi_lite_transaction_t stalled_read;

        `UART_DISPLAY(("[AXI PROTOCOL TEST] Exercising B/R backpressure"))

        expect_write(UART_IER_ADDR, 32'h5, 4'hF, AXI_LITE_RESP_OKAY,
                     "stalled B response", AXI_LITE_AW_W_SAME_CYCLE,
                     0, 6);

        // RDATA must be a snapshot. Change the live register while its older
        // response is stalled and verify that the response remains 0x5.
        stalled_read = axi_lite_default_transaction();
        stalled_read.access = AXI_LITE_READ;
        stalled_read.address = UART_IER_ADDR;
        stalled_read.expected_read_data = 32'h5;
        stalled_read.expected_response = AXI_LITE_RESP_OKAY;
        stalled_read.response_stall_cycles = 10;

        fork
            env.axi_agent.driver.read_transaction(stalled_read);
            begin
                wait (env.axi_vif.s_axi_rvalid === 1'b1);
                expect_write(UART_IER_ADDR, 32'hA, 4'hF,
                             AXI_LITE_RESP_OKAY,
                             "write while R response is stalled");
            end
        join

        env.axi_agent.scoreboard.check_transaction(
            "stalled R response retains captured IER", stalled_read
        );
        expect_read(UART_IER_ADDR, 32'hA, AXI_LITE_RESP_OKAY,
                    "new IER visible after stalled response");
    endtask

    task automatic axi_negative_and_strobes();
        `UART_DISPLAY(("[AXI PROTOCOL TEST] Checking errors and WSTRB policy"))

        expect_write(UART_IIR_ADDR, 32'hFFFF_FFFF, 4'hF,
                     AXI_LITE_RESP_SLVERR, "write read-only IIR");
        expect_write(UART_LSR_ADDR, 32'hFFFF_FFFF, 4'hF,
                     AXI_LITE_RESP_SLVERR, "write read-only LSR");
        expect_write(32'h10, 32'h1234_5678, 4'hF,
                     AXI_LITE_RESP_SLVERR, "write unmapped address");
        expect_write(32'h01, 32'h1234_5678, 4'hF,
                     AXI_LITE_RESP_SLVERR, "write misaligned address");

        expect_read(32'h10, 32'h0, AXI_LITE_RESP_SLVERR,
                    "read unmapped address");
        expect_read(32'h02, 32'h0, AXI_LITE_RESP_SLVERR,
                    "read misaligned address");
        expect_read(UART_RBR_THR_ADDR, 32'h0, AXI_LITE_RESP_OKAY,
                    "empty RBR is legal zero");

        expect_write(UART_IER_ADDR, 32'hF, 4'b0010,
                     AXI_LITE_RESP_OKAY, "upper-byte IER strobe is no-op");
        expect_read(UART_IER_ADDR, 32'h0, AXI_LITE_RESP_OKAY,
                    "IER unchanged by upper-byte strobe");

        expect_write(UART_RBR_THR_ADDR, 32'hA5, 4'b0000,
                     AXI_LITE_RESP_OKAY, "un-strobed THR write is no-op");
        wait_clock_cycles(2);
        check_bit("TX remains idle after un-strobed THR write", 1'b1,
                  env.serial_vif.tx_out);
        expect_read(UART_LSR_ADDR, 32'h2, AXI_LITE_RESP_OKAY,
                    "THR remains empty after no-op write");
    endtask

    task automatic axi_concurrent_read_write();
        axi_lite_transaction_t read_transaction;
        axi_lite_transaction_t write_transaction;
        logic [1:0] response;

        `UART_DISPLAY((
            "[AXI PROTOCOL TEST] Exercising independent read/write paths"
        ))

        expect_write(UART_IER_ADDR, 32'h3, 4'hF, AXI_LITE_RESP_OKAY,
                     "initial IER value");

        read_transaction = axi_lite_default_transaction();
        read_transaction.access = AXI_LITE_READ;
        read_transaction.address = UART_IER_ADDR;
        read_transaction.expected_read_data = 32'h3;
        read_transaction.expected_response = AXI_LITE_RESP_OKAY;

        write_transaction = axi_lite_default_transaction();
        write_transaction.access = AXI_LITE_WRITE;
        write_transaction.address = UART_IER_ADDR;
        write_transaction.write_data = 32'hC;
        write_transaction.write_strobe = 4'hF;
        write_transaction.expected_response = AXI_LITE_RESP_OKAY;
        write_transaction.check_read_data = 1'b0;

        fork
            env.axi_agent.driver.read_transaction(read_transaction);
            env.axi_agent.driver.write_transaction(write_transaction);
        join

        env.axi_agent.scoreboard.check_transaction(
            "concurrent read captures old IER", read_transaction
        );
        env.axi_agent.scoreboard.check_transaction(
            "concurrent write completes independently", write_transaction
        );
        expect_read(UART_IER_ADDR, 32'hC, AXI_LITE_RESP_OKAY,
                    "concurrent write becomes visible");

        // An AW-only partial request must not block unrelated reads or create
        // a response before its W half arrives.
        env.axi_agent.driver.drive_write_address(UART_IER_ADDR, 3'b000);
        wait_clock_cycles(2);
        check_bit("no B response for AW-only request", 1'b0,
                  env.axi_vif.s_axi_bvalid);
        expect_read(UART_IER_ADDR, 32'hC, AXI_LITE_RESP_OKAY,
                    "read completes while AW is pending");

        env.axi_agent.driver.drive_write_data(32'h6, 4'hF);
        env.axi_agent.driver.collect_write_response(0, response);
        env.axi_agent.scoreboard.check_response(
            "late W completes partial write", AXI_LITE_RESP_OKAY, response
        );
        expect_read(UART_IER_ADDR, 32'h6, AXI_LITE_RESP_OKAY,
                    "partial write final value");
    endtask

endclass
