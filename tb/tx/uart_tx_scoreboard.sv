`include "rtl/uart_config.svh"

class uart_tx_scoreboard;

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
            $display(
                "[%0t] [PASS] Reset state: tx=1 ready=1 baud_tick=0",
                $time
            );
        end else begin
            $error(
                "[%0t] [FAIL] Reset state: rst_n=%b tx=%b ready=%b baud_tick=%b",
                $time,
                rst_n,
                tx_out,
                tx_ready,
                baud_tick
            );
        end
    endfunction

    function void check_idle_state(
        input logic tx_out,
        input logic tx_ready
    );
        if ((tx_out === 1'b1) && (tx_ready === 1'b1)) begin
            $display(
                "[%0t] [PASS] UART remained idle after reset",
                $time
            );
        end else begin
            $error(
                "[%0t] [FAIL] UART not idle after reset: tx=%b ready=%b",
                $time,
                tx_out,
                tx_ready
            );
        end
    endfunction

    function void check_data(
        input logic [`DATA_BITS-1:0] expected,
        input logic [`DATA_BITS-1:0] actual
    );
        if (actual === expected) begin
            $display(
                "[%0t] [PASS] expected=%02h actual=%02h",
                $time,
                expected,
                actual
            );
        end else begin
            $error(
                "[%0t] [FAIL] TX data: expected=%02h actual=%02h",
                $time,
                expected,
                actual
            );
        end
    endfunction

    function void check_start_bit(input logic actual);
        if (actual === 1'b0) begin
            $display("[%0t] [PASS] TX start bit is low", $time);
        end else begin
            $error(
                "[%0t] [FAIL] TX start bit: expected=0 actual=%b",
                $time,
                actual
            );
        end
    endfunction

    function void check_stop_bit(input logic actual);
        if (actual === 1'b1) begin
            $display("[%0t] [PASS] TX stop bit is high", $time);
        end else begin
            $error(
                "[%0t] [FAIL] TX stop bit: expected=1 actual=%b",
                $time,
                actual
            );
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
            $display(
                "[%0t] [PASS] TX ready state in %s: expected=%0b actual=%0b",
                $time,
                state_context,
                expected,
                actual
            );
        end else begin
            $error(
                "[%0t] [FAIL] TX ready state in %s: expected=%0b actual=%0b",
                $time,
                state_context,
                expected,
                actual
            );
        end
    endfunction

    function void check_output_state(
        input logic  expected,
        input logic  actual,
        input string state_context
    );
        if (actual === expected) begin
            $display(
                "[%0t] [PASS] TX output in %s: expected=%0b actual=%0b",
                $time,
                state_context,
                expected,
                actual
            );
        end else begin
            $error(
                "[%0t] [FAIL] TX output in %s: expected=%0b actual=%0b",
                $time,
                state_context,
                expected,
                actual
            );
        end
    endfunction

    function void check_no_extra_frame(input logic extra_frame_seen);
        if (!extra_frame_seen) begin
            $display("[%0t] [PASS] No unexpected TX frame observed", $time);
        end else begin
            $error("[%0t] [FAIL] Unexpected additional TX frame observed", $time);
        end
    endfunction
endclass
