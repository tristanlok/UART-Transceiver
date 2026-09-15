`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_reg_scoreboard;

    function void check_read(
        input string       test_context,
        input logic [31:0] expected_data,
        input logic [31:0] actual_data,
        input logic        expected_error,
        input logic        actual_error
    );
        if ((actual_data === expected_data) &&
            (actual_error === expected_error)) begin
            `UART_DISPLAY((
                "[REG SCOREBOARD] [PASS] %s: data=0x%08h error=%0b",
                test_context,
                actual_data,
                actual_error
            ))
        end else begin
            `UART_ERROR((
                "[REG SCOREBOARD] [FAIL] %s: expected data=0x%08h error=%0b, actual data=0x%08h error=%0b",
                test_context,
                expected_data,
                expected_error,
                actual_data,
                actual_error
            ))
        end
    endfunction

    function void check_write_error(
        input string test_context,
        input logic  expected_error,
        input logic  actual_error
    );
        if (actual_error === expected_error) begin
            `UART_DISPLAY((
                "[REG SCOREBOARD] [PASS] %s: write_error=%0b",
                test_context,
                actual_error
            ))
        end else begin
            `UART_ERROR((
                "[REG SCOREBOARD] [FAIL] %s: expected write_error=%0b actual=%0b",
                test_context,
                expected_error,
                actual_error
            ))
        end
    endfunction

    function void check_tx_request(
        input string                  test_context,
        input logic                   expected_start,
        input logic [`DATA_BITS-1:0]  expected_data,
        input logic                   actual_start,
        input logic [`DATA_BITS-1:0]  actual_data
    );
        if ((actual_start === expected_start) &&
            (actual_data === expected_data)) begin
            `UART_DISPLAY((
                "[REG SCOREBOARD] [PASS] %s: start=%0b data=0x%0h",
                test_context,
                actual_start,
                actual_data
            ))
        end else begin
            `UART_ERROR((
                "[REG SCOREBOARD] [FAIL] %s: expected start=%0b data=0x%0h, actual start=%0b data=0x%0h",
                test_context,
                expected_start,
                expected_data,
                actual_start,
                actual_data
            ))
        end
    endfunction

    function void check_irq(
        input string test_context,
        input logic  expected,
        input logic  actual
    );
        if (actual === expected) begin
            `UART_DISPLAY((
                "[REG SCOREBOARD] [PASS] %s: irq=%0b",
                test_context,
                actual
            ))
        end else begin
            `UART_ERROR((
                "[REG SCOREBOARD] [FAIL] %s: expected irq=%0b actual=%0b",
                test_context,
                expected,
                actual
            ))
        end
    endfunction

endclass
