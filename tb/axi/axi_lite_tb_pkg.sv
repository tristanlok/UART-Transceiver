`include "uart_config.svh"

package axi_lite_tb_pkg;

    // These defaults match uart_axi_lite. Keeping the widths in one package
    // gives every AXI verification component the same transaction shape.
    localparam int unsigned AXI_LITE_ADDR_WIDTH = 32;
    localparam int unsigned AXI_LITE_DATA_WIDTH = 32;
    localparam int unsigned AXI_LITE_STRB_WIDTH =
        AXI_LITE_DATA_WIDTH / 8;
    localparam int unsigned AXI_LITE_PROT_WIDTH = 3;

    localparam int unsigned AXI_LITE_DEFAULT_TIMEOUT_CYCLES = 1_000;

    localparam logic [1:0] AXI_LITE_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_LITE_RESP_SLVERR = 2'b10;

    typedef enum logic {
        AXI_LITE_READ,
        AXI_LITE_WRITE
    } axi_lite_access_e;

    // AXI-Lite permits AW and W to handshake independently. Tests select one
    // of these orderings to make sure the slave does not assume simultaneity.
    typedef enum logic [1:0] {
        AXI_LITE_AW_BEFORE_W,
        AXI_LITE_W_BEFORE_AW,
        AXI_LITE_AW_W_SAME_CYCLE
    } axi_lite_write_order_e;

    typedef struct {
        axi_lite_access_e      access;
        axi_lite_write_order_e write_order;

        logic [AXI_LITE_ADDR_WIDTH-1:0] address;
        logic [AXI_LITE_DATA_WIDTH-1:0] write_data;
        logic [AXI_LITE_STRB_WIDTH-1:0] write_strobe;
        logic [AXI_LITE_PROT_WIDTH-1:0] protection;

        // channel_gap_cycles inserts full idle clock cycles between the first
        // accepted write channel and presentation of the second channel.
        int unsigned channel_gap_cycles;
        // response_stall_cycles holds BREADY/RREADY low after VALID is seen.
        int unsigned response_stall_cycles;

        logic [AXI_LITE_DATA_WIDTH-1:0] expected_read_data;
        logic [1:0]                     expected_response;
        bit                             check_read_data;

        logic [AXI_LITE_DATA_WIDTH-1:0] actual_read_data;
        logic [1:0]                     actual_response;
        bit                             completed;
    } axi_lite_transaction_t;

    function automatic axi_lite_transaction_t axi_lite_default_transaction();
        axi_lite_transaction_t transaction;

        transaction.access = AXI_LITE_READ;
        transaction.write_order = AXI_LITE_AW_W_SAME_CYCLE;
        transaction.address = '0;
        transaction.write_data = '0;
        transaction.write_strobe = '1;
        transaction.protection = '0;
        transaction.channel_gap_cycles = 0;
        transaction.response_stall_cycles = 0;
        transaction.expected_read_data = '0;
        transaction.expected_response = AXI_LITE_RESP_OKAY;
        transaction.check_read_data = 1'b1;
        transaction.actual_read_data = '0;
        transaction.actual_response = '0;
        transaction.completed = 1'b0;

        return transaction;
    endfunction

endpackage
