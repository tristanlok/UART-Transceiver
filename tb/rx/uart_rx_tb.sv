`include "uart_config.svh"
`include "uart_tb_log.svh"

module uart_rx_tb;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned CLOCK_HZ  = 100_000_000;
    localparam int unsigned BAUD_RATE = 115_200;
    localparam realtime REF_TICK_HALF_PERIOD =
        1.0e9 / (2.0 * BAUD_RATE * `OVERSAMPLE);

    logic clk;
    uart_tb_ctrl_if uart_tb_ctrl_vif(clk);
    uart_rx_if uart_rx_vif();

    baud_generator #(
        .CLOCK_HZ  (CLOCK_HZ),
        .BAUD_RATE (BAUD_RATE)
    ) baud_generator_inst (
        .clk            (clk),
        .rst_n          (uart_tb_ctrl_vif.rst_n),
        .baud_tick      (uart_tb_ctrl_vif.baud_tick)
    );

    uart_rx uart_rx_inst (
        .clk            (clk),
        .rst_n          (uart_tb_ctrl_vif.rst_n),
        .baud_tick      (uart_tb_ctrl_vif.baud_tick),
        .rx_in          (uart_rx_vif.rx_in),

        .data_out       (uart_rx_vif.rx_data),
        .rx_valid       (uart_rx_vif.rx_valid),
        .rx_busy        (uart_rx_vif.rx_busy),
        .framing_error  (uart_rx_vif.framing_error)
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
            wave_file = "build/waves/uart_rx_tb.vcd";
        end

        $dumpfile(wave_file);
        $dumpvars(0, uart_rx_tb);
        `UART_DISPLAY(("[RX TB] Recording waveforms to %s", wave_file))
    end

    initial begin : test_sequence
        string testname;
        uart_reset_driver reset_driver;
        uart_rx_driver driver;
        uart_rx_monitor monitor;
        uart_rx_scoreboard scoreboard;
        uart_rx_tests tests;

        $timeformat(-9, 3, " ns", 12);
        `UART_DISPLAY(("[RX TB] Starting UART receiver test"))

        if (!$value$plusargs("TEST=%s", testname))
            testname = "rx_sim_sanity";

        reset_driver = new(uart_tb_ctrl_vif);
        driver = new(uart_tb_ctrl_vif, uart_rx_vif);
        monitor = new(uart_tb_ctrl_vif, uart_rx_vif);
        scoreboard = new();
        tests = new(
            uart_tb_ctrl_vif,
            uart_rx_vif,
            reset_driver,
            driver,
            monitor,
            scoreboard
        );

        `UART_DISPLAY(("[RX TB] Running test: %s", testname))

        case (testname)
            "rx_sim_sanity":
                tests.rx_read_data_sanity();
            "rx_false_start":
                tests.rx_false_start();
            "rx_data_majority_vote":
                tests.rx_data_majority_vote();
            "rx_framing_error":
                tests.rx_framing_error();
            "rx_reset_every_state":
                tests.rx_reset_every_state();
            default:
                `UART_FATAL((1, "[RX TB] Unknown test: %s", testname))
        endcase

        wait (!uart_rx_vif.rx_busy);
        `UART_DISPLAY(("[RX TB] UART receiver test finished"))
        $finish;
    end
endmodule
