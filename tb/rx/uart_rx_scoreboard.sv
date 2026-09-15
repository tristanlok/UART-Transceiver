`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_rx_scoreboard;

    function void check_for_unexpected_activity(
        input logic rx_activity_seen
    );
        if (rx_activity_seen === 0) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] No unexpected activity seen on UART RX"
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] Unexpected activity seen on UART RX"
            ))
        end
    endfunction

    function void check_reset_state(
        input logic                    rst_n,
        input logic [`DATA_BITS-1:0]  data_out,
        input logic                    rx_valid,
        input logic                    rx_busy,
        input logic                    framing_error
    );
        if (
            (rst_n         === 1'b0) &&
            (data_out      === '0)   &&
            (rx_valid      === 1'b0) &&
            (rx_busy       === 1'b0) &&
            (framing_error === 1'b0)
        ) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] RX reset state: data=0x%0h valid=0 busy=0 error=0",
                data_out
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] RX reset state: rst_n=%b data=0x%0h valid=%b busy=%b error=%b",
                rst_n,
                data_out,
                rx_valid,
                rx_busy,
                framing_error
            ))
        end
    endfunction

    function void check_framing_error(
        input logic expected,
        input logic actual
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] Framing error: expected=%0b actual=%0b",
                expected,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] Framing error: expected=%0b actual=%0b",
                expected,
                actual
            ))
        end
    endfunction

    function void check_valid_state(
        input logic  expected,
        input logic  actual,
        input string state_context
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] RX valid state in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] RX valid state in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end
    endfunction

    function void check_busy_state(
        input logic  expected,
        input logic  actual,
        input string state_context
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] RX busy state in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] RX busy state in %s: expected=%0b actual=%0b",
                state_context,
                expected,
                actual
            ))
        end
    endfunction

    function void check_data(
        input logic [`DATA_BITS-1:0] expected,
        input logic [`DATA_BITS-1:0] actual
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] RX data: expected=0x%0h actual=0x%0h",
                expected,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] RX data: expected=0x%0h actual=0x%0h",
                expected,
                actual
            ))
        end
    endfunction

    function void check_false_start_busy(
        input logic busy_asserted,
        input logic busy_deasserted
    );
        if (busy_asserted && busy_deasserted) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] DUT successfully entered START state before reverting back to IDLE after false start"
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] DUT failed to correctly model false start. busy_asserted=%0b busy_deasserted=%0b",
                busy_asserted,
                busy_deasserted
            ))
        end
    endfunction


    function void check_data_unchanged_after_error(
        input logic [`DATA_BITS-1:0] previous_data,
        input logic [`DATA_BITS-1:0] actual_data
    );
        if (actual_data === previous_data) begin
            `UART_DISPLAY((
                "[RX SCOREBOARD] [PASS] RX data held after framing error: data=0x%0h",
                actual_data
            ))
        end else begin
            `UART_ERROR((
                "[RX SCOREBOARD] [FAIL] RX data changed after framing error: previous=0x%0h actual=0x%0h",
                previous_data,
                actual_data
            ))
        end
    endfunction

endclass
