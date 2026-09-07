`include "rtl/uart_config.svh"

interface uart_tx_if (
    input logic clk,
    input logic rst_n,
    input logic baud_tick,
    input logic ref_baud_tick
);

    logic       tx_start;
    logic [`DATA_BITS-1:0] tx_data;
    
    logic       tx_out;
    logic       tx_ready;

endinterface
