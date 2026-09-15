`include "uart_config.svh"

// External serial pins of the AXI-Lite UART. Clock, reset, and both baud-tick
// references intentionally live in uart_tb_ctrl_if so every verification
// agent observes one shared source of timing.
interface uart_serial_if;

    logic rx_in;
    logic tx_out;

    // The serial driver models a remote UART transmitter and therefore owns
    // only the DUT's receive pin.
    modport driver (
        output rx_in
    );

    // The serial monitor is passive. rx_in is included so tests can inspect
    // injected traffic without giving the monitor permission to drive it.
    modport monitor (
        input rx_in,
        input tx_out
    );

    // Directions as seen at the uart_axi_lite peripheral boundary.
    modport dut (
        input  rx_in,
        output tx_out
    );

endinterface
