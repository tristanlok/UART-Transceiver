interface uart_tx_if (input logic clk);

    logic       rst_n;
    logic       baud_tick;

    logic       tx_start;
    logic [7:0] tx_data;
    
    logic       tx;
    logic       tx_ready;

endinterface
