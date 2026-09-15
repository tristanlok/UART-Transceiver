`include "uart_config.svh"
`include "uart_tb_log.svh"

// AXI-Lite protocol/register-integration verification layer. The serial pins
// remain idle except when a register access itself starts UART TX; end-to-end
// serial behavior belongs to uart_axi_system_tb.
module uart_axi_lite_tb;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned CLOCK_HZ  = 100_000_000;
    localparam int unsigned BAUD_RATE = 115_200;
    localparam realtime REF_TICK_HALF_PERIOD =
        1.0e9 / (2.0 * BAUD_RATE * `OVERSAMPLE);

    logic clk;

    uart_tb_ctrl_if ctrl_vif(clk);
    axi_lite_if     axi_vif();
    uart_serial_if  serial_vif();
    uart_irq_if     irq_vif();

    uart_axi_lite #(
        .CLOCK_HZ       (CLOCK_HZ),
        .BAUD_RATE      (BAUD_RATE),
        .AXI_ADDR_WIDTH (axi_lite_tb_pkg::AXI_LITE_ADDR_WIDTH),
        .AXI_DATA_WIDTH (axi_lite_tb_pkg::AXI_LITE_DATA_WIDTH),
        .AXI_STRB_WIDTH (axi_lite_tb_pkg::AXI_LITE_STRB_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (ctrl_vif.rst_n),

        .s_axi_awaddr   (axi_vif.s_axi_awaddr),
        .s_axi_awprot   (axi_vif.s_axi_awprot),
        .s_axi_awvalid  (axi_vif.s_axi_awvalid),
        .s_axi_awready  (axi_vif.s_axi_awready),

        .s_axi_wdata    (axi_vif.s_axi_wdata),
        .s_axi_wstrb    (axi_vif.s_axi_wstrb),
        .s_axi_wvalid   (axi_vif.s_axi_wvalid),
        .s_axi_wready   (axi_vif.s_axi_wready),

        .s_axi_bresp    (axi_vif.s_axi_bresp),
        .s_axi_bvalid   (axi_vif.s_axi_bvalid),
        .s_axi_bready   (axi_vif.s_axi_bready),

        .s_axi_araddr   (axi_vif.s_axi_araddr),
        .s_axi_arprot   (axi_vif.s_axi_arprot),
        .s_axi_arvalid  (axi_vif.s_axi_arvalid),
        .s_axi_arready  (axi_vif.s_axi_arready),

        .s_axi_rdata    (axi_vif.s_axi_rdata),
        .s_axi_rresp    (axi_vif.s_axi_rresp),
        .s_axi_rvalid   (axi_vif.s_axi_rvalid),
        .s_axi_rready   (axi_vif.s_axi_rready),

        .rx_in          (serial_vif.rx_in),
        .tx_out         (serial_vif.tx_out),
        .irq            (irq_vif.irq)
`ifdef UART_SIM
        ,.baud_tick_sim (ctrl_vif.baud_tick)
`endif
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // The external UART peer uses timing independent of the DUT baud
    // generator, so a DUT timing error is not repeated by the testbench.
    initial begin : generate_reference_baud_tick
        ctrl_vif.ref_baud_tick = 1'b0;

        forever begin
            #(REF_TICK_HALF_PERIOD);
            ctrl_vif.ref_baud_tick = ~ctrl_vif.ref_baud_tick;
        end
    end

    // Prevent a broken handshake or monitor from leaving an unattended
    // regression running forever.
    initial begin : simulation_watchdog
        #20ms;
        `UART_FATAL((1, "[AXI TB] simulation watchdog expired"))
    end

    initial begin : waveform_capture
        string wave_file;

        if (!$value$plusargs("WAVE_FILE=%s", wave_file))
            wave_file = "build/waves/uart_axi_lite_tb.vcd";

        $dumpfile(wave_file);
        $dumpvars(0, uart_axi_lite_tb);
        `UART_DISPLAY(("[AXI TB] Recording waveforms to %s", wave_file))
    end

    initial begin : test_sequence
        string              testname;
        uart_axi_env        env;
        uart_axi_lite_tests tests;

        $timeformat(-9, 3, " ns", 12);

        if (!$value$plusargs("TEST=%s", testname))
            testname = "axi_reset_basic_map";

        env = new(
            ctrl_vif,
            axi_vif,
            serial_vif,
            irq_vif
        );
        tests = new(env);

        `UART_DISPLAY(("[AXI TB] Running test: %s", testname))
        tests.setup_test(testname);

        // Match the project's TX/RX/UART/register benches: one tests object
        // contains named test tasks and this top selects one by plusarg.
        case (testname)
            "axi_reset_basic_map":
                tests.axi_reset_basic_map();
            "axi_write_channel_order":
                tests.axi_write_channel_order();
            "axi_response_backpressure":
                tests.axi_response_backpressure();
            "axi_negative_and_strobes":
                tests.axi_negative_and_strobes();
            "axi_concurrent_read_write":
                tests.axi_concurrent_read_write();
            default:
                `UART_FATAL((1, "[AXI TB] Unknown test: %s", testname))
        endcase

        tests.finish_test(testname);
        `UART_DISPLAY(("[AXI TB] AXI-Lite test finished"))
        $finish;
    end

endmodule
