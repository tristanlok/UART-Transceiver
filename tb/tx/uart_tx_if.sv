`include "uart_config.svh"

interface uart_tx_if;

    logic                       tx_start;
    logic [`DATA_BITS-1:0]      tx_data;
    logic                       tx_out;
    logic                       tx_ready;

    // The TX driver owns only the request and parallel data inputs. It reads
    // ready to perform a legal request handshake. Shared timing comes from
    // uart_tb_ctrl_if rather than being duplicated here.
    modport driver (
        input  tx_ready,
        output tx_start,
        output tx_data
    );

    // TX monitors and tests are passive observers.
    modport monitor (
        input tx_start,
        input tx_data,
        input tx_out,
        input tx_ready
    );

    // This documents the directions seen by uart_tx if the RTL is later
    // converted to accept an interface port.
    modport dut (
        input  tx_start,
        input  tx_data,
        output tx_out,
        output tx_ready
    );

endinterface
