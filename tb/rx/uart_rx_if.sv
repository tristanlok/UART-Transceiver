`include "uart_config.svh"

interface uart_rx_if;

    logic                       rx_in;

    logic [`DATA_BITS-1:0]      rx_data;
    logic                       rx_valid;
    logic                       rx_busy;
    logic                       framing_error;

    // The RX driver owns only the external serial input. Its symbol timing is
    // provided separately by uart_tb_ctrl_if.
    modport driver (
        output rx_in
    );

    // RX monitors and tests are passive observers.
    modport monitor (
        input rx_in,
        input rx_data,
        input rx_valid,
        input rx_busy,
        input framing_error
    );

    // This documents the directions seen by uart_rx if the RTL is later
    // converted to accept an interface port.
    modport dut (
        input  rx_in,
        output rx_data,
        output rx_valid,
        output rx_busy,
        output framing_error
    );

endinterface
