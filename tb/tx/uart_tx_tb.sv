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
    end

    initial begin
        uart_tx_driver driver;

        driver = new(uart_tx_vif);

        driver.reset_dut();

        driver.send_byte(8'hA5);

        // Observe the complete busy interval before ending the test.
        wait (!uart_tx_vif.tx_ready);
        wait (uart_tx_vif.tx_ready);

        repeat (10)
            @(posedge clk);

        $finish;
    end
endmodule
