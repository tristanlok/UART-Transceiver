`include "uart_config.svh"

interface uart_reg_if;

    logic                         write_en;
    logic [31:0]                  write_addr;
    logic [31:0]                  write_data;
    logic [3:0]                   write_strb;
    logic                         write_error;

    logic                         read_en;
    logic [31:0]                  read_addr;
    logic [31:0]                  read_data;
    logic                         read_error;

    logic [`DATA_BITS-1:0]        uart_tx_data;
    logic                         uart_tx_start;
    logic                         uart_tx_ready;

    logic [`DATA_BITS-1:0]        uart_rx_data;
    logic                         uart_rx_valid;
    logic                         uart_framing_error;

    logic                         irq;

    modport driver (
        output write_en,
        output write_addr,
        output write_data,
        output write_strb,
        input  write_error,

        output read_en,
        output read_addr,
        input  read_data,
        input  read_error,

        input  uart_tx_data,
        input  uart_tx_start,
        output uart_tx_ready,

        output uart_rx_data,
        output uart_rx_valid,
        output uart_framing_error,

        input  irq
    );

    modport monitor (
        input write_en,
        input write_addr,
        input write_data,
        input write_strb,
        input write_error,

        input read_en,
        input read_addr,
        input read_data,
        input read_error,

        input uart_tx_data,
        input uart_tx_start,
        input uart_tx_ready,

        input uart_rx_data,
        input uart_rx_valid,
        input uart_framing_error,

        input irq
    );

    modport dut (
        input  write_en,
        input  write_addr,
        input  write_data,
        input  write_strb,
        output write_error,

        input  read_en,
        input  read_addr,
        output read_data,
        output read_error,

        output uart_tx_data,
        output uart_tx_start,
        input  uart_tx_ready,

        input  uart_rx_data,
        input  uart_rx_valid,
        input  uart_framing_error,

        output irq
    );

endinterface
