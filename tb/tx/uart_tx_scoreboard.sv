class uart_tx_scoreboard;
    function void check_reset_state(
        input logic rst_n,
        input logic tx,
        input logic tx_ready,
        input logic baud_tick
    );
        if (
            (rst_n     === 1'b0) &&
            (tx        === 1'b1) &&
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
                tx,
                tx_ready,
                baud_tick
            );
        end
    endfunction

    function void check_idle_state(
        input logic tx,
        input logic tx_ready
    );
        if ((tx === 1'b1) && (tx_ready === 1'b1)) begin
            $display(
                "[%0t] [PASS] UART remained idle after reset",
                $time
            );
        end else begin
            $error(
                "[%0t] [FAIL] UART not idle after reset: tx=%b ready=%b",
                $time,
                tx,
                tx_ready
            );
        end
    endfunction

    function void check_byte(
        input logic [7:0] expected,
        input logic [7:0] actual
    );
        if (actual === expected) begin
            $display(
                "[%0t] [PASS] expected=%02h actual=%02h",
                $time,
                expected,
                actual
            );
        end
        else begin

            $error(
                "[%0t] [FAIL] expected=%02h actual=%02h",
                $time,
                expected,
                actual
            );
        end
    endfunction
endclass
