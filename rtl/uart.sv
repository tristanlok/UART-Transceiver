module uart #(
    parameter int unsigned CLOCK_HZ  = 100_000_000,
    parameter int unsigned BAUD_RATE = 115_200
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] data_in,
    input  logic       tx_start,

    output logic       tx_ready,
    output logic       tx_out
);

    logic baud_tick;

    baud_generator #(
        .CLOCK_HZ  (CLOCK_HZ),
        .BAUD_RATE (BAUD_RATE)
    ) baud_generator_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick)
    );

    uart_tx uart_tx_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .data_in   (data_in),
        .tx_start  (tx_start),
        .tx_ready  (tx_ready),
        .tx_out    (tx_out)
    );

endmodule
