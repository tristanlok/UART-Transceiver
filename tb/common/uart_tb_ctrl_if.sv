// Shared testbench control and timing signals for every UART verification
// component. rst_n has one writer (uart_reset_driver), while baud_tick is
// driven by the RTL and ref_baud_tick is driven by the testbench reference.
interface uart_tb_ctrl_if (input logic clk);

    logic rst_n;
    logic baud_tick;
    logic ref_baud_tick;

    // The reset driver is the only verification component allowed to change
    // the shared reset. It observes clk to time reset transitions.
    modport reset_driver (
        input  clk,
        output rst_n
    );

    // The testbench reference-tick process owns ref_baud_tick.
    modport reference_tick_driver (
        input  clk,
        output ref_baud_tick
    );

    // The RTL baud generator (or integrated UART simulation output) owns the
    // DUT baud tick and observes the shared reset.
    modport baud_source (
        input  clk,
        input  rst_n,
        output baud_tick
    );

    // Passive components may observe all shared timing and control signals.
    modport monitor (
        input clk,
        input rst_n,
        input baud_tick,
        input ref_baud_tick
    );

endinterface
