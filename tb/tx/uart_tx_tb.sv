`include "rtl/uart_config.svh"

module uart_tx_tb;
    timeunit 1ns;
    timeprecision 1ps;

    import uart_tx_tb_pkg::*;

    localparam int unsigned CLOCK_HZ  = 100_000_000;
    localparam int unsigned BAUD_RATE = 115_200;
    localparam realtime REF_TICK_HALF_PERIOD =
        1.0e9 / (2.0 * BAUD_RATE * `OVERSAMPLE);

    logic clk;
    uart_tb_ctrl_if uart_tb_ctrl_vif(clk);
    uart_tx_if uart_tx_vif(
        clk,
        uart_tb_ctrl_vif.rst_n,
        uart_tb_ctrl_vif.baud_tick,
        uart_tb_ctrl_vif.ref_baud_tick
    );

    baud_generator #(
        .CLOCK_HZ  (CLOCK_HZ),
        .BAUD_RATE (BAUD_RATE)
    ) baud_generator_inst (
        .clk            (clk),
        .rst_n          (uart_tb_ctrl_vif.rst_n),
        .baud_tick      (uart_tb_ctrl_vif.baud_tick)
    );

    uart_tx uart_tx_inst (
        .clk        (clk),
        .rst_n      (uart_tx_vif.rst_n),
        .baud_tick  (uart_tx_vif.baud_tick),
        .data_in    (uart_tx_vif.tx_data),
        .tx_start   (uart_tx_vif.tx_start),
        .tx_ready   (uart_tx_vif.tx_ready),
        .tx_out     (uart_tx_vif.tx_out)
    );

    initial clk = 1'b0;

    always #5 clk = ~clk;

    // This independent oversampling reference is used only by the testbench
    // monitor. Its rate is configured by `OVERSAMPLE, while the DUT continues
    // to use the RTL-generated baud_tick above.
    initial begin : generate_reference_baud_tick
        uart_tb_ctrl_vif.ref_baud_tick = 1'b0;

        forever begin
            #(REF_TICK_HALF_PERIOD);
            uart_tb_ctrl_vif.ref_baud_tick =
                ~uart_tb_ctrl_vif.ref_baud_tick;
        end
    end

    initial begin
        string wave_file;

        if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
            wave_file = "build/waves/uart_tx_tb.vcd";
        end

        $dumpfile(wave_file);
        $dumpvars(0, uart_tx_tb);
        $display("[0 ns] Recording waveforms to %s", wave_file);
    end

    // add assertions and cover properties

    initial begin : test_sequence
        string testname;
        uart_reset_driver reset_driver;
        uart_tx_driver driver;
        uart_tx_monitor monitor;
        uart_tx_scoreboard scoreboard;
        uart_tx_tests tests;

        $timeformat(-9, 3, " ns", 12);
        $display("[%0t] Starting UART transmitter test", $time);

        if (!$value$plusargs("TEST=%s", testname))
            testname = "basic";

        reset_driver = new(uart_tb_ctrl_vif);
        driver = new(uart_tx_vif);
        monitor = new(uart_tx_vif);
        scoreboard = new();
        tests = new(
            uart_tx_vif,
            reset_driver,
            driver,
            monitor,
            scoreboard
        );

        $display("[%0t] Running test: %s", $time, testname);

        case (testname)
            "tx_sim_sanity":
                tests.tx_send_data_sanity();
            "tx_send_data_and_assert_reset":
                tests.tx_send_data_and_assert_reset();
            "tx_hold_request_data_stability":
                tests.tx_hold_request_data_stability();
            default:
                $fatal(1, "Unknown test: %s", testname);
        endcase

        wait (uart_tx_vif.tx_ready);
        $display("[%0t] UART transmitter test finished", $time);
        $finish;
    end
endmodule
