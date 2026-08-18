typedef enum logic [2:0] { 
    IDLE,
    ALIGN,
    START,
    DATA,
    STOP
} uart_tx_state_t;

module uart_tx (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        baud_tick,
    input  logic [7:0]  data_in,
    input  logic        tx_start,

    output logic        tx_ready,
    output logic        tx_out
);

    uart_tx_state_t curr_state, next_state;
    logic [2:0]     curr_count, next_count;
    logic [7:0]     data_shift_reg;

    always_comb begin
        // Hold the current values unless the FSM advances them.
        next_state = curr_state;
        next_count = curr_count;

        unique case (curr_state)
            IDLE: begin
                if (tx_start) begin
                    next_state = ALIGN;
                    next_count = 3'd0;
                end
            end

            ALIGN: begin
                if (baud_tick) begin
                    next_state = START;
                    next_count = 3'd0;
                end
            end

            START: begin
                if (baud_tick) begin
                    next_state = DATA;
                end
            end

            DATA: begin
                if (baud_tick) begin
                    if (curr_count == 3'd7) begin
                        next_state = STOP;
                    end else begin
                        next_count = curr_count + 1'b1;
                    end
                end
            end

            STOP: begin
                if (baud_tick) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
                next_count = 3'd0;
            end
        endcase
    end

    always_comb begin
        // UART idles high and is not ready while transmitting.
        tx_out   = 1'b1;
        tx_ready = 1'b0;

        unique case (curr_state)
            IDLE: begin
                tx_ready = 1'b1;
            end

            ALIGN: begin
                tx_out = 1'b1;
            end

            START: begin
                tx_out = 1'b0;
            end

            DATA: begin
                tx_out = data_shift_reg[0];
            end

            STOP: begin
                tx_out = 1'b1;
                tx_ready = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state     <= IDLE;
            curr_count     <= 3'd0;
            data_shift_reg <= 8'd0;
        end else begin
            curr_state <= next_state;
            curr_count <= next_count;

            if ((curr_state == IDLE) && tx_start) begin
                data_shift_reg <= data_in;
            end else if ((curr_state == DATA) && baud_tick) begin
                data_shift_reg <= {1'b0, data_shift_reg[7:1]};
            end
        end
    end

endmodule
