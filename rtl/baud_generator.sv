`include "rtl/uart_config.svh"

module baud_generator #(
    parameter int unsigned CLOCK_HZ  = 100_000_000,
    parameter int unsigned BAUD_RATE = 115_200
) (
    input  logic clk,
    input  logic rst_n,
    output logic baud_tick
);

    // Generate the finer RX sampling rate first. Every OVERSAMPLE-th sampling
    // event becomes one TX baud event, so both outputs remain phase-related.
    localparam int unsigned OVERSAMPLE_RATE =
        BAUD_RATE * `OVERSAMPLE;

    // The accumulator preserves the fractional part of
    // CLOCK_HZ / OVERSAMPLE_RATE. This produces the requested average rate
    // even when that ratio is not an integer.
    localparam int unsigned ACC_WIDTH =
        (CLOCK_HZ <= 1) ? 1 : $clog2(CLOCK_HZ);
    localparam int unsigned SUM_WIDTH = ACC_WIDTH + 1;
    localparam int unsigned OVERSAMPLE_COUNT_WIDTH =
        (`OVERSAMPLE <= 1) ? 1 : $clog2(`OVERSAMPLE);

    localparam logic [ACC_WIDTH:0] CLOCK_VALUE = SUM_WIDTH'(CLOCK_HZ);
    localparam logic [ACC_WIDTH:0] OVERSAMPLE_VALUE =
        SUM_WIDTH'(OVERSAMPLE_RATE);

    logic [ACC_WIDTH-1:0]              accumulator;
    logic [ACC_WIDTH:0]                accumulator_sum;
    logic [OVERSAMPLE_COUNT_WIDTH-1:0] oversample_count;

    always_comb begin
        accumulator_sum = {1'b0, accumulator} + OVERSAMPLE_VALUE;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            accumulator      <= '0;
            oversample_count <= '0;
            baud_tick        <= '0;
        end else if (accumulator_sum >= CLOCK_VALUE) begin
            accumulator      <= ACC_WIDTH'(accumulator_sum - CLOCK_VALUE);
            baud_tick        <= '1;

            // Dividing the fine timing grid by OVERSAMPLE recreates the
            // original one-pulse-per-UART-bit TX timing enable.
            if (oversample_count == OVERSAMPLE_COUNT_WIDTH'(`OVERSAMPLE - 1)) begin
                oversample_count <= '0;
            end else begin
                oversample_count <= oversample_count + 1'b1;
            end
        end else begin
            accumulator      <= ACC_WIDTH'(accumulator_sum);
            baud_tick        <= '0;
        end
    end

endmodule
