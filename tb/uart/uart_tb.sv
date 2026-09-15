`include "uart_config.svh"
`include "uart_tb_log.svh"

module uart_tb;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned CLOCK_HZ  = 100_000_000;
    localparam int unsigned BAUD_RATE = 115_200;
    localparam realtime REF_TICK_HALF_PERIOD =
        1.0e9 / (2.0 * BAUD_RATE * `OVERSAMPLE);

    logic clk;
    uart_tb_ctrl_if uart_tb_ctrl_vif(clk);
    uart_rx_if uart_rx_vif();
    uart_tx_if uart_tx_vif();

    uart #(
        .CLOCK_HZ  (CLOCK_HZ),
        .BAUD_RATE (BAUD_RATE)
    ) uart_inst (
        .clk            (clk),
        .rst_n          (uart_tb_ctrl_vif.rst_n),

        .tx_data        (uart_tx_vif.tx_data),
        .tx_start       (uart_tx_vif.tx_start),
        .tx_ready       (uart_tx_vif.tx_ready),
        .tx_out         (uart_tx_vif.tx_out),

        .rx_in          (uart_rx_vif.rx_in),
        .rx_data        (uart_rx_vif.rx_data),
        .rx_valid       (uart_rx_vif.rx_valid),
        .rx_busy        (uart_rx_vif.rx_busy),
        .framing_error  (uart_rx_vif.framing_error)
`ifdef UART_SIM
        ,.baud_tick_sim (uart_tb_ctrl_vif.baud_tick)
`endif
    );

    initial clk = 1'b0;

    always #5 clk = ~clk;

    // Independent testbench timing reference configured by `OVERSAMPLE.
    // The DUT continues to use the RTL-generated baud_tick above.
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
            wave_file = "build/waves/uart_tb.vcd";
        end

        $dumpfile(wave_file);
        $dumpvars(0, uart_tb);
        `UART_DISPLAY(("[UART TB] Recording waveforms to %s", wave_file))
    end

    initial begin : test_sequence
        string testname;
        uart_env env;
        uart_tests tests;

        $timeformat(-9, 3, " ns", 12);
        `UART_DISPLAY(("[UART TB] Starting UART transceiver test"))

        if (!$value$plusargs("TEST=%s", testname))
            testname = "uart_tx_sanity";

        // The top creates one environment. Future integrated tests can reuse
        // the same object instead of rebuilding every component themselves.
        env = new(uart_tb_ctrl_vif, uart_tx_vif, uart_rx_vif);
        env.initialize_inputs();

        tests = new(env);

        `UART_DISPLAY(("[UART TB] Running test: %s", testname))

        case (testname)
            "uart_tx_sanity":
                tests.uart_tx_sanity();
            "uart_rx_sanity":
                tests.uart_rx_sanity();
            "uart_duplex_sanity":
                tests.uart_duplex_sanity();
            "uart_reset_every_state":
                tests.uart_reset_every_state();
            "uart_error_isolation":
                tests.uart_error_isolation();
            default:
                `UART_FATAL((1, "[UART TB] Unknown test: %s", testname))
        endcase

        //wait (!uart_rx_vif.rx_busy);
        `UART_DISPLAY(("[UART TB] UART transceiver test finished"))
        $finish;
    end
endmodule
