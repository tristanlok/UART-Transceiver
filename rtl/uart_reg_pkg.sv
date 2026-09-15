package uart_reg_pkg;

    localparam logic [31:0] UART_RBR_THR_ADDR = 32'h0000_0000;
    localparam logic [31:0] UART_IER_ADDR     = 32'h0000_0004;
    localparam logic [31:0] UART_IIR_ADDR     = 32'h0000_0008;
    localparam logic [31:0] UART_LSR_ADDR     = 32'h0000_000C;

    localparam int unsigned UART_IER_RX_BIT       = 0;
    localparam int unsigned UART_IER_TX_BIT       = 1;
    localparam int unsigned UART_IER_FRAMING_BIT  = 2;
    localparam int unsigned UART_IER_OVERRUN_BIT  = 3;

    localparam int unsigned UART_LSR_RX_READY_BIT  = 0;
    localparam int unsigned UART_LSR_THR_EMPTY_BIT = 1;
    localparam int unsigned UART_LSR_FRAMING_BIT   = 2;
    localparam int unsigned UART_LSR_OVERRUN_BIT   = 3;

endpackage
