`include "uart_config.svh"
`include "uart_tb_log.svh"

import axi_lite_tb_pkg::AXI_LITE_DATA_WIDTH;
import axi_lite_tb_pkg::AXI_LITE_READ;
import axi_lite_tb_pkg::axi_lite_write_order_e;
import axi_lite_tb_pkg::axi_lite_transaction_t;

class axi_lite_scoreboard;

    int unsigned pass_count;
    int unsigned fail_count;

    function new();
        pass_count = 0;
        fail_count = 0;
    endfunction

    function void check_response(
        input string      test_context,
        input logic [1:0] expected,
        input logic [1:0] actual
    );
        if (actual === expected) begin
            pass_count++;
            `UART_DISPLAY((
                "[AXI SCOREBOARD] [PASS] %s response=%02b",
                test_context,
                actual
            ))
        end else begin
            fail_count++;
            `UART_ERROR((
                "[AXI SCOREBOARD] [FAIL] %s expected response=%02b actual=%02b",
                test_context,
                expected,
                actual
            ))
        end
    endfunction

    function void check_read_data(
        input string                                test_context,
        input logic [AXI_LITE_DATA_WIDTH-1:0]       expected,
        input logic [AXI_LITE_DATA_WIDTH-1:0]       actual
    );
        if (actual === expected) begin
            pass_count++;
            `UART_DISPLAY((
                "[AXI SCOREBOARD] [PASS] %s read_data=0x%08h",
                test_context,
                actual
            ))
        end else begin
            fail_count++;
            `UART_ERROR((
                "[AXI SCOREBOARD] [FAIL] %s expected data=0x%08h actual=0x%08h",
                test_context,
                expected,
                actual
            ))
        end
    endfunction

    function void check_write_order(
        input string                 test_context,
        input axi_lite_write_order_e expected,
        input axi_lite_write_order_e actual
    );
        if (actual === expected) begin
            pass_count++;
            `UART_DISPLAY((
                "[AXI SCOREBOARD] [PASS] %s write_order=%0d",
                test_context,
                actual
            ))
        end else begin
            fail_count++;
            `UART_ERROR((
                "[AXI SCOREBOARD] [FAIL] %s expected order=%0d actual=%0d",
                test_context,
                expected,
                actual
            ))
        end
    endfunction

    // The reusable bus scoreboard checks only protocol-visible results. Tests
    // or a UART register reference model supply the expected data/response.
    function void check_transaction(
        input string                 test_context,
        input axi_lite_transaction_t transaction
    );
        if (!transaction.completed) begin
            fail_count++;
            `UART_ERROR((
                "[AXI SCOREBOARD] [FAIL] %s transaction did not complete",
                test_context
            ))
            return;
        end

        check_response(
            test_context,
            transaction.expected_response,
            transaction.actual_response
        );

        if ((transaction.access == AXI_LITE_READ) &&
            transaction.check_read_data) begin
            check_read_data(
                test_context,
                transaction.expected_read_data,
                transaction.actual_read_data
            );
        end
    endfunction

    function void report();
        if (fail_count == 0) begin
            `UART_DISPLAY((
                "[AXI SCOREBOARD] [PASS] summary: checks=%0d failures=0",
                pass_count
            ))
        end else begin
            `UART_ERROR((
                "[AXI SCOREBOARD] [FAIL] summary: passes=%0d failures=%0d",
                pass_count,
                fail_count
            ))
        end
    endfunction

endclass
