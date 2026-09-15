`include "uart_config.svh"
`include "uart_tb_log.svh"

module uart_reg_block_tb;
    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    uart_tb_ctrl_if uart_tb_ctrl_vif(clk);
    uart_reg_if uart_reg_vif();

    uart_reg_block #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .STRB_WIDTH (4)
    ) uart_reg_block_inst (
        .clk                (clk),
        .rst_n              (uart_tb_ctrl_vif.rst_n),

        .write_en           (uart_reg_vif.write_en),
        .write_addr         (uart_reg_vif.write_addr),
        .write_data         (uart_reg_vif.write_data),
        .write_strb         (uart_reg_vif.write_strb),
        .write_error        (uart_reg_vif.write_error),

        .read_en            (uart_reg_vif.read_en),
        .read_addr          (uart_reg_vif.read_addr),
        .read_data          (uart_reg_vif.read_data),
        .read_error         (uart_reg_vif.read_error),

        .uart_tx_data       (uart_reg_vif.uart_tx_data),
        .uart_tx_start      (uart_reg_vif.uart_tx_start),
        .uart_tx_ready      (uart_reg_vif.uart_tx_ready),

        .uart_rx_data       (uart_reg_vif.uart_rx_data),
        .uart_rx_valid      (uart_reg_vif.uart_rx_valid),
        .uart_framing_error (uart_reg_vif.uart_framing_error),

        .irq                (uart_reg_vif.irq)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        uart_tb_ctrl_vif.baud_tick = 1'b0;
        uart_tb_ctrl_vif.ref_baud_tick = 1'b0;
    end

    initial begin
        string wave_file;

        if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
            wave_file = "build/waves/uart_reg_block_tb.vcd";
        end

        $dumpfile(wave_file);
        $dumpvars(0, uart_reg_block_tb);
        `UART_DISPLAY(("[REG TB] Recording waveforms to %s", wave_file))
    end

    initial begin : test_sequence
        string testname;
        uart_reset_driver reset_driver;
        uart_reg_driver driver;
        uart_reg_monitor monitor;
        uart_reg_scoreboard scoreboard;
        uart_reg_tests tests;

        $timeformat(-9, 3, " ns", 12);
        `UART_DISPLAY(("[REG TB] Starting UART register-block test"))

        if (!$value$plusargs("TEST=%s", testname))
            testname = "reg_sanity";

        reset_driver = new(uart_tb_ctrl_vif);
        driver = new(uart_tb_ctrl_vif, uart_reg_vif);
        monitor = new(uart_tb_ctrl_vif, uart_reg_vif);
        scoreboard = new();
        tests = new(
            uart_tb_ctrl_vif,
            uart_reg_vif,
            reset_driver,
            driver,
            monitor,
            scoreboard
        );

        `UART_DISPLAY(("[REG TB] Running test: %s", testname))

        case (testname)
            "reg_sanity":
                tests.reg_sanity();
            "reg_random_access":
                tests.reg_random_access();
            "reg_negative_access":
                tests.reg_negative_access();
            "reg_buffer_corner_cases":
                tests.reg_buffer_corner_cases();
            "reg_interrupt_priority":
                tests.reg_interrupt_priority();
            default:
                `UART_FATAL((1, "[REG TB] Unknown test: %s", testname))
        endcase

        `UART_DISPLAY(("[REG TB] UART register-block test finished"))
        $finish;
    end

endmodule
