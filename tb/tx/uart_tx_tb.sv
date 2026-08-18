module uart_tx_tb;
    import uart_tx_tb_pkg::*;

    logic clk;
    uart_tx_if uart_tx_vif(clk);

    uart #(
        .CLOCK_HZ  (100_000_000),
        .BAUD_RATE (115_200)
    ) dut (
        .clk      (clk),
        .rst_n    (uart_tx_vif.rst_n),
        .data_in  (uart_tx_vif.tx_data),
        .tx_start (uart_tx_vif.tx_start),
        .tx_ready (uart_tx_vif.tx_ready),
        .tx_out   (uart_tx_vif.tx)
`ifdef UART_SIM
        , .baud_tick_sim (uart_tx_vif.baud_tick)
`endif
    );

    initial clk = 1'b0;

    always #5 clk = ~clk;

    initial begin
        string wave_file;

        if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
            wave_file = "build/waves/uart_tx_tb.vcd";
        end

        $dumpfile(wave_file);
        $dumpvars(0, uart_tx_tb);
        $display("[0 ns] Recording waveforms to %s", wave_file);
    end

    initial begin : test_sequence
        string testname;
        uart_tx_driver driver;
        uart_tx_monitor monitor;
        uart_tx_scoreboard scoreboard;
        uart_tx_tests tests;

        $timeformat(-9, 3, " ns", 12);
        $display("[%0t] Starting UART transmitter test", $time);

        if (!$value$plusargs("TEST=%s", testname))
            testname = "basic";

        driver = new(uart_tx_vif);
        monitor = new(uart_tx_vif);
        scoreboard = new();
        tests = new(uart_tx_vif, driver, monitor, scoreboard);

        $display("[%0t] Resetting DUT", $time);
        driver.reset_dut();
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
