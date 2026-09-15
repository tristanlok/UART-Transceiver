`include "uart_config.svh"

module uart #(
    parameter int unsigned CLOCK_HZ  = 100_000_000,
    parameter int unsigned BAUD_RATE = 115_200
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // Transmitter interface
    input  logic [`DATA_BITS-1:0]   tx_data,
    input  logic                    tx_start,
    output logic                    tx_ready,
    output logic                    tx_out,

    // Receiver interface
    input  logic                    rx_in,
    output logic [`DATA_BITS-1:0]   rx_data,
    output logic                    rx_valid,
    output logic                    rx_busy,
    output logic                    framing_error
`ifdef UART_SIM
    , output logic                  baud_tick_sim
`endif
);

    logic baud_tick;

`ifdef UART_SIM
    assign baud_tick_sim = baud_tick;
`endif

    baud_generator #(
        .CLOCK_HZ  (CLOCK_HZ),
        .BAUD_RATE (BAUD_RATE)
    ) baud_generator_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_tick  (baud_tick)
    );

    uart_tx uart_tx_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_tick  (baud_tick),
        .data_in    (tx_data),
        .tx_start   (tx_start),
        .tx_ready   (tx_ready),
        .tx_out     (tx_out)
    );

    uart_rx uart_rx_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        .baud_tick      (baud_tick),
        .rx_in          (rx_in),
        .data_out       (rx_data),
        .rx_valid       (rx_valid),
        .rx_busy        (rx_busy),
        .framing_error  (framing_error)
    );

endmodule
