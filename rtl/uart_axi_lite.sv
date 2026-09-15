`include "uart_config.svh"

module uart_axi_lite #(
    parameter int unsigned CLOCK_HZ       = 100_000_000,
    parameter int unsigned BAUD_RATE      = 115_200,
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8
) (
    input  logic                          clk,
    input  logic                          rst_n,

    // AXI-Lite write-address channel
    input  logic [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  logic [2:0]                    s_axi_awprot,
    input  logic                          s_axi_awvalid,
    output logic                          s_axi_awready,

    // AXI-Lite write-data channel
    input  logic [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  logic [AXI_STRB_WIDTH-1:0]     s_axi_wstrb,
    input  logic                          s_axi_wvalid,
    output logic                          s_axi_wready,

    // AXI-Lite write-response channel
    output logic [1:0]                    s_axi_bresp,
    output logic                          s_axi_bvalid,
    input  logic                          s_axi_bready,

    // AXI-Lite read-address channel
    input  logic [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  logic [2:0]                    s_axi_arprot,
    input  logic                          s_axi_arvalid,
    output logic                          s_axi_arready,

    // AXI-Lite read-data channel
    output logic [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output logic [1:0]                    s_axi_rresp,
    output logic                          s_axi_rvalid,
    input  logic                          s_axi_rready,

    // External UART pins and interrupt output
    input  logic                          rx_in,
    output logic                          tx_out,
    output logic                          irq
`ifdef UART_SIM
    , output logic                        baud_tick_sim
`endif
);

    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    // The write-address and write-data channels are independent in AXI-Lite.
    // Each payload is therefore buffered until its partner arrives.
    logic                              aw_pending;
    logic [AXI_ADDR_WIDTH-1:0]         awaddr_reg;
    logic                              w_pending;
    logic [AXI_DATA_WIDTH-1:0]         wdata_reg;
    logic [AXI_STRB_WIDTH-1:0]         wstrb_reg;

    // Simplified request/response connection to uart_reg_block.
    logic                              reg_write_en;
    logic [AXI_ADDR_WIDTH-1:0]         reg_write_addr;
    logic [AXI_DATA_WIDTH-1:0]         reg_write_data;
    logic [AXI_STRB_WIDTH-1:0]         reg_write_strb;
    logic                              reg_write_error;

    logic                              reg_read_en;
    logic [AXI_ADDR_WIDTH-1:0]         reg_read_addr;
    logic [AXI_DATA_WIDTH-1:0]         reg_read_data;
    logic                              reg_read_error;

    // Parallel UART-core connections. These remain internal to the AXI UART
    // wrapper; only rx_in and tx_out are visible at the peripheral boundary.
    logic [`DATA_BITS-1:0]             uart_tx_data;
    logic                              uart_tx_start;
    logic                              uart_tx_ready;
    logic [`DATA_BITS-1:0]             uart_rx_data;
    logic                              uart_rx_valid;
    logic                              uart_rx_busy;
    logic                              uart_framing_error;

    // AXI protection attributes and RX busy are accepted/observed but do not
    // affect the current register policy. This reduction records that intent
    // without adding functional hardware.
    logic                              unused_inputs;
    assign unused_inputs = &{
        1'b0,
        s_axi_awprot,
        s_axi_arprot,
        uart_rx_busy
    };

    // ---------------------------------------------------------------------
    // AXI-Lite write channels
    // ---------------------------------------------------------------------

    // This simple slave supports one outstanding write. It may receive AW and
    // W in either order, but accepts neither part of another write until the
    // current B response has been consumed.
    assign s_axi_awready = rst_n && !aw_pending && !s_axi_bvalid;
    assign s_axi_wready  = rst_n && !w_pending && !s_axi_bvalid;

    assign reg_write_en = aw_pending && w_pending && !s_axi_bvalid;
    assign reg_write_addr = awaddr_reg;
    assign reg_write_data = wdata_reg;
    assign reg_write_strb = wstrb_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            aw_pending <= 1'b0;
            awaddr_reg <= '0;
            w_pending <= 1'b0;
            wdata_reg <= '0;
            wstrb_reg <= '0;
            s_axi_bresp <= AXI_RESP_OKAY;
            s_axi_bvalid <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_reg <= s_axi_awaddr;
                aw_pending <= 1'b1;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                wdata_reg <= s_axi_wdata;
                wstrb_reg <= s_axi_wstrb;
                w_pending <= 1'b1;
            end

            // reg_write_en is a one-cycle accepted register-access event. The
            // register block updates on this edge while the AXI response takes
            // a snapshot of its combinational error result.
            if (reg_write_en) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
                s_axi_bresp <=
                    reg_write_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------------
    // AXI-Lite read channels
    // ---------------------------------------------------------------------

    // One read response may be outstanding. Backpressure on RREADY therefore
    // also prevents another address from being accepted and changing RDATA.
    assign s_axi_arready = rst_n && !s_axi_rvalid;
    assign reg_read_en = s_axi_arvalid && s_axi_arready;
    assign reg_read_addr = s_axi_araddr;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_axi_rdata <= '0;
            s_axi_rresp <= AXI_RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end else begin
            // Capture the pre-edge register value. read_data and read_error then
            // remain stable in the AXI response even if UART state changes.
            if (reg_read_en) begin
                s_axi_rdata <= reg_read_data;
                s_axi_rresp <=
                    reg_read_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------------
    // UART register block and core integration
    // ---------------------------------------------------------------------

    uart_reg_block #(
        .ADDR_WIDTH (AXI_ADDR_WIDTH),
        .DATA_WIDTH (AXI_DATA_WIDTH),
        .STRB_WIDTH (AXI_STRB_WIDTH)
    ) uart_reg_block_inst (
        .clk                (clk),
        .rst_n              (rst_n),

        .write_en           (reg_write_en),
        .write_addr         (reg_write_addr),
        .write_data         (reg_write_data),
        .write_strb         (reg_write_strb),
        .write_error        (reg_write_error),

        .read_en            (reg_read_en),
        .read_addr          (reg_read_addr),
        .read_data          (reg_read_data),
        .read_error         (reg_read_error),

        .uart_tx_data       (uart_tx_data),
        .uart_tx_start      (uart_tx_start),
        .uart_tx_ready      (uart_tx_ready),

        .uart_rx_data       (uart_rx_data),
        .uart_rx_valid      (uart_rx_valid),
        .uart_framing_error (uart_framing_error),

        .irq                (irq)
    );

    uart #(
        .CLOCK_HZ  (CLOCK_HZ),
        .BAUD_RATE (BAUD_RATE)
    ) uart_inst (
        .clk            (clk),
        .rst_n          (rst_n),

        .tx_data        (uart_tx_data),
        .tx_start       (uart_tx_start),
        .tx_ready       (uart_tx_ready),
        .tx_out         (tx_out),

        .rx_in          (rx_in),
        .rx_data        (uart_rx_data),
        .rx_valid       (uart_rx_valid),
        .rx_busy        (uart_rx_busy),
        .framing_error  (uart_framing_error)
`ifdef UART_SIM
        ,.baud_tick_sim (baud_tick_sim)
`endif
    );

endmodule
