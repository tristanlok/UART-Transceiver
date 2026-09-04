`include "rtl/uart_config.svh"

package uart_tx_tb_pkg;

    typedef struct {
        logic [`DATA_BITS-1:0] data;
    } uart_tx_transaction_t;

endpackage
