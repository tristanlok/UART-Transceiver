`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_serial_scoreboard;
    int unsigned pass_count;
    int unsigned fail_count;

    function new();
        pass_count = 0;
        fail_count = 0;
    endfunction

    function void check_frame(
        input uart_serial_tb_pkg::uart_serial_frame_t expected,
        input uart_serial_tb_pkg::uart_serial_frame_t actual
    );
        if (actual === expected) begin
            pass_count++;
            `UART_DISPLAY((
                "[SERIAL SCOREBOARD] [PASS] frame matched: start=%0b data=0x%0h stop=%0b",
                actual.start_bit,
                actual.data,
                actual.stop_bit
            ))
        end else begin
            fail_count++;
            `UART_ERROR((
                "[SERIAL SCOREBOARD] [FAIL] frame mismatch: expected={%0b,0x%0h,%0b} actual={%0b,0x%0h,%0b}",
                expected.start_bit,
                expected.data,
                expected.stop_bit,
                actual.start_bit,
                actual.data,
                actual.stop_bit
            ))
        end
    endfunction

    // The normal TX check used after software writes one byte through AXI.
    function void check_valid_tx_frame(
        input logic [`DATA_BITS-1:0] expected_data,
        input uart_serial_tb_pkg::uart_serial_frame_t actual
    );
        uart_serial_tb_pkg::uart_serial_frame_t expected;

        expected = uart_serial_tb_pkg::make_uart_serial_frame(
            expected_data,
            1'b1
        );
        check_frame(expected, actual);
    endfunction

    function void check_framing(
        input logic               expected_start_bit,
        input logic               expected_stop_bit,
        input uart_serial_tb_pkg::uart_serial_frame_t actual
    );
        if ((actual.start_bit === expected_start_bit) &&
            (actual.stop_bit  === expected_stop_bit)) begin
            pass_count++;
            `UART_DISPLAY((
                "[SERIAL SCOREBOARD] [PASS] framing matched: start=%0b stop=%0b",
                actual.start_bit,
                actual.stop_bit
            ))
        end else begin
            fail_count++;
            `UART_ERROR((
                "[SERIAL SCOREBOARD] [FAIL] framing mismatch: expected={%0b,%0b} actual={%0b,%0b}",
                expected_start_bit,
                expected_stop_bit,
                actual.start_bit,
                actual.stop_bit
            ))
        end
    endfunction

    function void check_data(
        input logic [`DATA_BITS-1:0] expected_data,
        input logic [`DATA_BITS-1:0] actual_data
    );
        if (actual_data === expected_data) begin
            pass_count++;
            `UART_DISPLAY((
                "[SERIAL SCOREBOARD] [PASS] data matched: expected=0x%0h actual=0x%0h",
                expected_data,
                actual_data
            ))
        end else begin
            fail_count++;
            `UART_ERROR((
                "[SERIAL SCOREBOARD] [FAIL] data mismatch: expected=0x%0h actual=0x%0h",
                expected_data,
                actual_data
            ))
        end
    endfunction

    function void report();
        if (fail_count == 0) begin
            `UART_DISPLAY((
                "[SERIAL SCOREBOARD] [PASS] summary: checks=%0d failures=0",
                pass_count
            ))
        end else begin
            `UART_ERROR((
                "[SERIAL SCOREBOARD] [FAIL] summary: passes=%0d failures=%0d",
                pass_count,
                fail_count
            ))
        end
    endfunction

endclass
