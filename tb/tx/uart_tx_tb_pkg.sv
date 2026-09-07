`include "rtl/uart_config.svh"

package uart_tx_tb_pkg;

    // Common TX transaction shape for future monitor/scoreboard reuse.
    typedef struct packed {
        logic [`DATA_BITS-1:0] data;
    } uart_tx_transaction_t;

endpackage
