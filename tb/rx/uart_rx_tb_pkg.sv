`include "rtl/uart_config.svh"

package uart_rx_tb_pkg;

    // Common RX transaction shape for future monitor/scoreboard reuse.
    typedef struct packed {
        logic [`DATA_BITS-1:0] data;
        logic                  framing_error;
    } uart_rx_transaction_t;

endpackage
