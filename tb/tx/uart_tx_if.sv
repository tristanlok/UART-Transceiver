`include "rtl/uart_config.svh"

interface uart_tx_if (input logic clk);

    logic       rst_n;
    logic       baud_tick;
    logic       ref_baud_tick;

    logic       tx_start;
    logic [`DATA_BITS-1:0] tx_data;
    
    logic       tx;
    logic       tx_ready;

endinterface
