// Testbench-only logging helpers. Pass a system-task argument list as one
// parenthesized macro argument, for example:
//   `UART_DISPLAY(("value=%0h", value))
// Do not append a semicolon: each macro expands to a complete begin/end block.
//
// %m prints the active hierarchy. In class-based code, simulators generally
// include the active method or task in that scope.
`define UART_LOG_CONTEXT \
    $write("[%0t] [%s:%0d] [%m] ", $time, `__FILE__, `__LINE__);

`define UART_DISPLAY(ARGS) \
    begin \
        `UART_LOG_CONTEXT \
        $display ARGS; \
    end

`define UART_ERROR(ARGS) \
    begin \
        `UART_LOG_CONTEXT \
        $error ARGS; \
    end

`define UART_FATAL(ARGS) \
    begin \
        `UART_LOG_CONTEXT \
        $fatal ARGS; \
    end
