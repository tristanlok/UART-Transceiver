module baud_generator #(
    parameter int unsigned CLOCK_HZ  = 100_000_000,
    parameter int unsigned BAUD_RATE = 115_200
) (
    input  logic clk,
    input  logic rst_n,
    output logic baud_tick
);

    // The accumulator preserves the fractional part of CLOCK_HZ / BAUD_RATE.
    // This produces the requested average baud rate even when that ratio is
    // not an integer (for example, 100 MHz / 115200 baud).
    localparam int unsigned ACC_WIDTH =
        (CLOCK_HZ <= 1) ? 1 : $clog2(CLOCK_HZ);
    localparam int unsigned SUM_WIDTH = ACC_WIDTH + 1;

    localparam logic [ACC_WIDTH:0] CLOCK_VALUE = SUM_WIDTH'(CLOCK_HZ);
    localparam logic [ACC_WIDTH:0] BAUD_VALUE  = SUM_WIDTH'(BAUD_RATE);

    logic [ACC_WIDTH-1:0] accumulator;
    logic [ACC_WIDTH:0]   accumulator_sum;

    always_comb begin
        accumulator_sum = {1'b0, accumulator} + BAUD_VALUE;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            accumulator <= '0;
            baud_tick   <= 1'b0;
        end else if (accumulator_sum >= CLOCK_VALUE) begin
            accumulator <= ACC_WIDTH'(accumulator_sum - CLOCK_VALUE);
            baud_tick   <= 1'b1;
        end else begin
            accumulator <= ACC_WIDTH'(accumulator_sum);
            baud_tick   <= 1'b0;
        end
    end

endmodule
