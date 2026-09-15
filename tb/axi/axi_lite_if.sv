`include "uart_config.svh"

interface axi_lite_if #(
    parameter int unsigned ADDR_WIDTH =
        axi_lite_tb_pkg::AXI_LITE_ADDR_WIDTH,
    parameter int unsigned DATA_WIDTH =
        axi_lite_tb_pkg::AXI_LITE_DATA_WIDTH,
    parameter int unsigned STRB_WIDTH = DATA_WIDTH / 8
);

    logic [ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [2:0]            s_axi_awprot;
    logic                  s_axi_awvalid;
    logic                  s_axi_awready;

    logic [DATA_WIDTH-1:0] s_axi_wdata;
    logic [STRB_WIDTH-1:0] s_axi_wstrb;
    logic                  s_axi_wvalid;
    logic                  s_axi_wready;

    logic [1:0]            s_axi_bresp;
    logic                  s_axi_bvalid;
    logic                  s_axi_bready;

    logic [ADDR_WIDTH-1:0] s_axi_araddr;
    logic [2:0]            s_axi_arprot;
    logic                  s_axi_arvalid;
    logic                  s_axi_arready;

    logic [DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]            s_axi_rresp;
    logic                  s_axi_rvalid;
    logic                  s_axi_rready;

    // Clock and reset deliberately live in uart_tb_ctrl_if. This modport owns
    // every signal driven by an AXI-Lite master and observes slave outputs.
    modport driver (
        output s_axi_awaddr,
        output s_axi_awprot,
        output s_axi_awvalid,
        input  s_axi_awready,

        output s_axi_wdata,
        output s_axi_wstrb,
        output s_axi_wvalid,
        input  s_axi_wready,

        input  s_axi_bresp,
        input  s_axi_bvalid,
        output s_axi_bready,

        output s_axi_araddr,
        output s_axi_arprot,
        output s_axi_arvalid,
        input  s_axi_arready,

        input  s_axi_rdata,
        input  s_axi_rresp,
        input  s_axi_rvalid,
        output s_axi_rready
    );

    // Passive monitors receive every bus signal and cannot accidentally drive
    // either side of the interface.
    modport monitor (
        input s_axi_awaddr,
        input s_axi_awprot,
        input s_axi_awvalid,
        input s_axi_awready,

        input s_axi_wdata,
        input s_axi_wstrb,
        input s_axi_wvalid,
        input s_axi_wready,

        input s_axi_bresp,
        input s_axi_bvalid,
        input s_axi_bready,

        input s_axi_araddr,
        input s_axi_arprot,
        input s_axi_arvalid,
        input s_axi_arready,

        input s_axi_rdata,
        input s_axi_rresp,
        input s_axi_rvalid,
        input s_axi_rready
    );

    // Directions as seen by rtl/uart_axi_lite.sv.
    modport dut (
        input  s_axi_awaddr,
        input  s_axi_awprot,
        input  s_axi_awvalid,
        output s_axi_awready,

        input  s_axi_wdata,
        input  s_axi_wstrb,
        input  s_axi_wvalid,
        output s_axi_wready,

        output s_axi_bresp,
        output s_axi_bvalid,
        input  s_axi_bready,

        input  s_axi_araddr,
        input  s_axi_arprot,
        input  s_axi_arvalid,
        output s_axi_arready,

        output s_axi_rdata,
        output s_axi_rresp,
        output s_axi_rvalid,
        input  s_axi_rready
    );

endinterface
