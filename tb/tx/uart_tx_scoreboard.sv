class uart_tx_scoreboard;
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
