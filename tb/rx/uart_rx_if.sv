`include "rtl/uart_config.svh"

interface uart_rx_if (input logic clk);

    logic                       rst_n;
    logic                       baud_tick;
    logic                       ref_baud_tick;
    logic                       rx_in;

    logic [`DATA_BITS-1:0]      data_out;
    logic                       rx_valid;
    logic                       rx_busy;
    logic                       framing_error;

endinterface
