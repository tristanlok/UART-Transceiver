`include "uart_config.svh"

module uart_tx (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    baud_tick,
    input  logic [`DATA_BITS-1:0]   data_in,
    input  logic                    tx_start,

    output logic                    tx_ready,
    output logic                    tx_out
);

    localparam int unsigned DATA_COUNT_WIDTH =
        (`DATA_BITS <= 1) ? 1 : $clog2(`DATA_BITS);
    localparam int unsigned BCLK_COUNT_WIDTH =
        (`OVERSAMPLE <= 1) ? 1 : $clog2(`OVERSAMPLE);

    typedef enum logic [2:0] {
        TX_IDLE,
        TX_ALIGN,
        TX_START,
        TX_DATA,
        TX_STOP
    } uart_tx_state_t;

    uart_tx_state_t                 curr_state, next_state;
    logic [DATA_COUNT_WIDTH-1:0]    data_curr_count, data_next_count;
    logic [BCLK_COUNT_WIDTH-1:0]    bclk_curr_count, bclk_next_count;
    logic [`DATA_BITS-1:0]          data_shift_reg;

    assign tx_ready = (curr_state == TX_IDLE);

    always_comb begin
        // Hold the current values unless the FSM advances them.
        next_state = curr_state;
        data_next_count = data_curr_count;
        bclk_next_count = bclk_curr_count;

        unique case (curr_state)
            TX_IDLE: begin
                if (tx_start) begin
                    next_state = TX_ALIGN;
                    data_next_count = '0;
                    bclk_next_count = '0;
                end
            end

            TX_ALIGN: begin
                if (baud_tick) begin
                    next_state = TX_START;
                    data_next_count = '0;
                    bclk_next_count = '0;
                end
            end

            TX_START: begin
                if (baud_tick) begin
                    if (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1)) begin
                        next_state = TX_DATA;
                        data_next_count = '0;
                        bclk_next_count = '0;
                    end else begin
                        bclk_next_count = bclk_curr_count + 1'b1;
                    end
                end
            end

            TX_DATA: begin
                if (baud_tick) begin
                    if (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1)) begin
                        bclk_next_count = '0;

                        if (data_curr_count == DATA_COUNT_WIDTH'(`DATA_BITS - 1)) begin
                            next_state = TX_STOP;
                            data_next_count = '0;
                        end else begin
                            data_next_count = data_curr_count + 1'b1;
                        end
                    end else begin
                        bclk_next_count = bclk_curr_count + 1'b1;
                    end
                end
            end

            TX_STOP: begin
                if (baud_tick) begin
                    if (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1)) begin
                        next_state = TX_IDLE;
                        data_next_count = '0;
                        bclk_next_count = '0;
                    end else begin
                        bclk_next_count = bclk_curr_count + 1'b1;
                    end
                end
            end

            default: begin
                next_state = TX_IDLE;
                data_next_count = '0;
                bclk_next_count = '0;
            end
        endcase
    end

    always_comb begin
        // UART idles high and is not ready while transmitting.
        unique case (curr_state)
            TX_START: begin
                tx_out = '0;
            end

            TX_DATA: begin
                tx_out = data_shift_reg[0];
            end

            default: begin
                tx_out   = '1;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state     <= TX_IDLE;
            data_curr_count <= '0;
            bclk_curr_count <= '0;
            data_shift_reg <= '0;
        end else begin
            curr_state <= next_state;
            data_curr_count <= data_next_count;
            bclk_curr_count <= bclk_next_count;

            unique0 if (tx_ready && tx_start) begin
                data_shift_reg <= data_in;
            end else if ((curr_state == TX_DATA) && baud_tick &&
                         (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1))) begin
                data_shift_reg <= data_shift_reg >> 1'b1;
            end
        end
    end

endmodule
