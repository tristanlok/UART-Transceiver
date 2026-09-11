`include "rtl/uart_config.svh"

module uart_rx (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    baud_tick,
    input  logic                    rx_in,

    output logic [`DATA_BITS-1:0]   data_out,
    output logic                    rx_valid,
    output logic                    rx_busy,
    output logic                    framing_error
);

    localparam int unsigned DATA_COUNT_WIDTH =
        (`DATA_BITS <= 1) ? 1 : $clog2(`DATA_BITS);
    localparam int unsigned BCLK_COUNT_WIDTH =
        (`OVERSAMPLE <= 1) ? 1 : $clog2(`OVERSAMPLE);

    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } uart_rx_state_t;

    logic                               majority_vote;
    uart_rx_state_t                     curr_state, next_state;
    logic [DATA_COUNT_WIDTH-1:0]        data_curr_count, data_next_count;
    logic [BCLK_COUNT_WIDTH-1:0]        bclk_curr_count, bclk_next_count;
    logic                               data_1, data_2, data_3;
    logic [`DATA_BITS - 1:0]            data_shift_reg;   
    (* ASYNC_REG = "TRUE" *) logic rx_meta, rx_sync;

    assign rx_busy = (curr_state != RX_IDLE);
    assign majority_vote =
        (data_1 & data_2) |
        (data_1 & data_3) |
        (data_2 & data_3);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rx_meta <= '1;
            rx_sync <= '1;
        end else begin
            rx_meta <= rx_in;
            rx_sync <= rx_meta;
        end
    end

    always_comb begin
        next_state = curr_state;
        data_next_count = data_curr_count;
        bclk_next_count = bclk_curr_count;

        unique case (curr_state)
            RX_IDLE: begin
                if (rx_sync == 1'b0) begin
                    next_state = RX_START;
                    data_next_count = '0;
                    bclk_next_count = '0;
                end
            end

            RX_START: begin
                if (baud_tick) begin
                    if (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1)) begin
                        data_next_count = '0;
                        bclk_next_count = '0;
                        
                        if (majority_vote) begin
                            next_state = RX_IDLE;
                        end else begin
                            next_state = RX_DATA;
                        end
                    end else begin
                        bclk_next_count = bclk_curr_count + 1'b1;
                    end
                end
            end

            RX_DATA: begin
                if (baud_tick) begin
                    if (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1)) begin
                        bclk_next_count = '0;

                        if (data_curr_count == DATA_COUNT_WIDTH'(`DATA_BITS - 1)) begin
                            data_next_count = '0;
                            next_state = RX_STOP;
                        end else begin
                            data_next_count = data_curr_count + 1'b1;
                        end
                    end else begin
                        bclk_next_count = bclk_curr_count + 1'b1;
                    end
                end
            end

            RX_STOP: begin
                if (baud_tick) begin
                    if (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1)) begin
                        next_state = RX_IDLE;
                        data_next_count = '0;
                        bclk_next_count = '0;
                    end else begin
                        bclk_next_count = bclk_curr_count + 1'b1;
                    end
                end
            end

            default: begin
                next_state = RX_IDLE;
                data_next_count = '0;
                bclk_next_count = '0;
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= RX_IDLE;
            data_curr_count <= '0;
            bclk_curr_count <= '0;
            data_shift_reg <= '0;
            data_1 <= '0;
            data_2 <= '0;
            data_3 <= '0;
            framing_error <= '0;
            rx_valid <= '0;
            data_out <= '0;
        end else begin
            curr_state <= next_state;
            data_curr_count <= data_next_count;
            bclk_curr_count <= bclk_next_count;
            rx_valid <= '0;
            framing_error <= '0;

            if (baud_tick) begin 
                // Begins with -2 as the count starts at 0 - (`OVERSAMPLE - 1)
                unique0 case (bclk_curr_count)
                    BCLK_COUNT_WIDTH'(`OVERSAMPLE / 2 - 2): begin
                        data_1 <= rx_sync;
                    end
                    BCLK_COUNT_WIDTH'(`OVERSAMPLE / 2 - 1): begin
                        data_2 <= rx_sync;
                    end
                    BCLK_COUNT_WIDTH'(`OVERSAMPLE / 2): begin
                        data_3 <= rx_sync;
                    end
                endcase

                unique0 if ((curr_state == RX_DATA) &&
                            (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1))) begin
                    data_shift_reg <= {
                        majority_vote,
                        data_shift_reg[`DATA_BITS-1:1]
                    };
                end else if ((curr_state == RX_STOP) &&
                             (bclk_curr_count == BCLK_COUNT_WIDTH'(`OVERSAMPLE - 1))) begin
                    if (!majority_vote) begin
                        framing_error <= '1;
                    end else begin
                        data_out <= data_shift_reg;
                        rx_valid <= '1;
                    end
                end
            end
        end
    end
endmodule
