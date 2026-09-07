`include "rtl/uart_config.svh"

interface uart_rx_if (
    input logic clk,
    input logic rst_n,
    input logic baud_tick,
    input logic ref_baud_tick
);

    logic                       rx_in;

    logic [`DATA_BITS-1:0]      rx_data;
    logic                       rx_valid;
    logic                       rx_busy;
    logic                       framing_error;

endinterface
