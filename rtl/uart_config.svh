`define DATA_BITS 8
`define OVERSAMPLE 16

// Testbench logging helpers. Pass the normal system-task argument list as one
// parenthesized macro argument, for example:
//   `UART_DISPLAY(("value=%0h", value))
// Do not append a semicolon: each macro expands to a complete begin/end block.
//
// %m prints the current hierarchical scope. In class-based testbench code,
// simulators generally include the active class method/task in that scope.
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
