`include "rtl/uart_config.svh"

class uart_rx_scoreboard;

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
            $display(
                "[%0t] [PASS] RX reset state: data=0x%0h valid=0 busy=0 error=0",
                $time,
                data_out
            );
        end else begin
            $error(
                "[%0t] [FAIL] RX reset state: rst_n=%b data=0x%0h valid=%b busy=%b error=%b",
                $time,
                rst_n,
                data_out,
                rx_valid,
                rx_busy,
                framing_error
            );
        end
    endfunction

    function void check_framing_error(
        input logic expected,
        input logic actual
    );
        if (actual === expected) begin
            $display(
                "[%0t] [PASS] Framing error: expected=%0b actual=%0b",
                $time,
                expected,
                actual
            );
        end else begin
            $error(
                "[%0t] [FAIL] Framing error: expected=%0b actual=%0b",
                $time,
                expected,
                actual
            );
        end
    endfunction

    function void check_busy_state(
        input logic  expected,
        input logic  actual,
        input string state_context
    );
        if (actual === expected) begin
            $display(
                "[%0t] [PASS] RX busy state in %s: expected=%0b actual=%0b",
                $time,
                state_context,
                expected,
                actual
            );
        end else begin
            $error(
                "[%0t] [FAIL] RX busy state in %s: expected=%0b actual=%0b",
                $time,
                state_context,
                expected,
                actual
            );
        end
    endfunction

    function void check_data(
        input logic [`DATA_BITS-1:0] expected,
        input logic [`DATA_BITS-1:0] actual
    );
        if (actual === expected) begin
            $display(
                "[%0t] [PASS] RX data: expected=0x%0h actual=0x%0h",
                $time,
                expected,
                actual
            );
        end else begin
            $error(
                "[%0t] [FAIL] RX data: expected=0x%0h actual=0x%0h",
                $time,
                expected,
                actual
            );
        end
    endfunction

    function void check_false_start_busy(
        input logic busy_asserted,
        input logic busy_deasserted
    );
        if (busy_asserted && busy_deasserted) begin
            $display(
                "[%0t] [PASS] DUT successfully entered START state before reverting back to IDLE after false start",
                $time
            );
        end else begin
            $error(
                "[%0t] [FAIL] DUT failed to correctly model false start. busy_asserted=%0b busy_deasserted=%0b",
                $time,
                busy_asserted,
                busy_deasserted
            );
        end
    endfunction


    function void check_data_unchanged_after_error(
        input logic [`DATA_BITS-1:0] previous_data,
        input logic [`DATA_BITS-1:0] actual_data
    );
        if (actual_data === previous_data) begin
            $display(
                "[%0t] [PASS] RX data held after framing error: data=0x%0h",
                $time,
                actual_data
            );
        end else begin
            $error(
                "[%0t] [FAIL] RX data changed after framing error: previous=0x%0h actual=0x%0h",
                $time,
                previous_data,
                actual_data
            );
        end
    endfunction

endclass
