`include "uart_config.svh"
`include "uart_tb_log.svh"

// Integration-level scoreboard. AXI transaction results remain in the AXI
// scoreboard and decoded UART frames remain in the serial scoreboard; this
// object owns cross-interface/reset/IRQ signal checks.
class uart_axi_scoreboard;
    int unsigned pass_count;
    int unsigned fail_count;

    function new();
        pass_count = 0;
        fail_count = 0;
    endfunction

    function void check_signal(
        input string test_context,
        input logic  expected,
        input logic  actual
    );
        if (actual === expected) begin
            pass_count++;
            `UART_DISPLAY((
                "[AXI UART SCOREBOARD] [PASS] %s expected=%0b actual=%0b",
                test_context,
                expected,
                actual
            ))
        end else begin
            fail_count++;
            `UART_ERROR((
                "[AXI UART SCOREBOARD] [FAIL] %s expected=%0b actual=%0b",
                test_context,
                expected,
                actual
            ))
        end
    endfunction

    function void report();
        if (fail_count == 0) begin
            `UART_DISPLAY((
                "[AXI UART SCOREBOARD] [PASS] summary: checks=%0d failures=0",
                pass_count
            ))
        end else begin
            `UART_ERROR((
                "[AXI UART SCOREBOARD] [FAIL] summary: passes=%0d failures=%0d",
                pass_count,
                fail_count
            ))
        end
    endfunction

endclass
