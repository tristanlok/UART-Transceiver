// Shared testbench control and timing signals for every UART verification
// component. rst_n has one writer (uart_reset_driver), while baud_tick is
// driven by the RTL and ref_baud_tick is driven by the testbench reference.
interface uart_tb_ctrl_if (input logic clk);

    logic rst_n;
    logic baud_tick;
    logic ref_baud_tick;

endinterface
