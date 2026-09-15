`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_scoreboard;

    function void check_for_duplex_overlap(
        input logic overlap_observed
    );
        if (overlap_observed) begin
            `UART_DISPLAY((
                "[UART SCOREBOARD] [PASS] TX and RX activity overlapped"
            ))
        end else begin
            `UART_ERROR((
                "[UART SCOREBOARD] [FAIL] No simultaneous TX/RX activity observed"
            ))
        end
    endfunction
endclass
