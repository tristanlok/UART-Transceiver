class uart_tx_driver;
    virtual uart_tx_if vif;

    function new(virtual uart_tx_if vif_arg);
        this.vif = vif_arg;
    endfunction

    task automatic reset_dut();
        vif.rst_n    <= 1'b0;
        vif.tx_start <= 1'b0;
        vif.tx_data  <= '0;

        repeat (5)
            @(posedge vif.clk);

        vif.rst_n <= 1'b1;

        repeat (2)
            @(posedge vif.clk);
    endtask

    task automatic send_byte(input logic [7:0] data);
        wait (vif.tx_ready);

        @(posedge vif.clk);

        vif.tx_data  <= data;
        vif.tx_start <= 1'b1;

        @(posedge vif.clk);

        vif.tx_start <= 1'b0;
    endtask
endclass
