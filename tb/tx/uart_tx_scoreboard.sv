`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_tx_scoreboard;

    function void check_for_unexpected_activity(
        input logic tx_activity_seen
    );
        if (tx_activity_seen === 0) begin
            `UART_DISPLAY((
                "[TX SCOREBOARD] [PASS] No unexpected activity seen on UART TX"
            ))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] Unexpected activity seen on UART TX"
            ))
        end
    endfunction

    function void check_reset_state(
        input logic rst_n,
        input logic tx_out,
        input logic tx_ready,
        input logic baud_tick
    );
        if (
            (rst_n     === 1'b0) &&
            (tx_out    === 1'b1) &&
            (tx_ready  === 1'b1) &&
            (baud_tick === 1'b0)
        ) begin
            `UART_DISPLAY((
                "[TX SCOREBOARD] [PASS] Reset state: tx=1 ready=1 baud_tick=0"
            ))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] Reset state: rst_n=%b tx=%b ready=%b baud_tick=%b",
                rst_n,
                tx_out,
                tx_ready,
                baud_tick
            ))
        end
    endfunction

    function void check_idle_state(
        input logic tx_out,
        input logic tx_ready
    );
        if ((tx_out === 1'b1) && (tx_ready === 1'b1)) begin
            `UART_DISPLAY((
                "[TX SCOREBOARD] [PASS] UART remained idle after reset"
            ))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] UART not idle after reset: tx=%b ready=%b",
                tx_out,
                tx_ready
            ))
        end
    endfunction

    function void check_data(
        input logic [`DATA_BITS-1:0] expected,
        input logic [`DATA_BITS-1:0] actual
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[TX SCOREBOARD] [PASS] expected=%02h actual=%02h",
                expected,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] TX data: expected=%02h actual=%02h",
                expected,
                actual
            ))
        end
    endfunction

    function void check_start_bit(input logic actual);
        if (actual === 1'b0) begin
            `UART_DISPLAY(("[TX SCOREBOARD] [PASS] TX start bit is low"))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] TX start bit: expected=0 actual=%b",
                actual
            ))
        end
    endfunction

    function void check_stop_bit(input logic actual);
        if (actual === 1'b1) begin
            `UART_DISPLAY(("[TX SCOREBOARD] [PASS] TX stop bit is high"))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] TX stop bit: expected=1 actual=%b",
                actual
            ))
        end
    endfunction

    function void check_frame(
        input logic [`DATA_BITS-1:0] expected_data,
        input logic [`DATA_BITS-1:0] actual_data,
        input logic                  actual_start_bit,
        input logic                  actual_stop_bit
    );
        check_start_bit(actual_start_bit);
        check_data(expected_data, actual_data);
        check_stop_bit(actual_stop_bit);
    endfunction

    function void check_ready_state(
        input logic  expected,
        input logic  actual,
        input string state_context
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[TX SCOREBOARD] [PASS] TX ready state in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] TX ready state in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end
    endfunction

    function void check_output_state(
        input logic  expected,
        input logic  actual,
        input string state_context
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[TX SCOREBOARD] [PASS] TX output in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] TX output in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end
    endfunction

    function void check_no_extra_frame(input logic extra_frame_seen);
        if (!extra_frame_seen) begin
            `UART_DISPLAY(("[TX SCOREBOARD] [PASS] No unexpected TX frame observed"))
        end else begin
            `UART_ERROR(("[TX SCOREBOARD] [FAIL] Unexpected additional TX frame observed"))
        end
    endfunction

    function void check_bit_duration(
        input string       symbol_name,
        input int unsigned expected_ticks,
        input int unsigned actual_ticks
    );
        if (actual_ticks == expected_ticks) begin
            `UART_DISPLAY((
                "[TX SCOREBOARD] [PASS] TX %s duration: expected=%0d ticks actual=%0d ticks",
                symbol_name,
                expected_ticks,
                actual_ticks
            ))
        end else begin
            `UART_ERROR((
                "[TX SCOREBOARD] [FAIL] TX %s duration: expected=%0d ticks actual=%0d ticks",
                symbol_name,
                expected_ticks,
                actual_ticks
            ))
        end
    endfunction
endclass
