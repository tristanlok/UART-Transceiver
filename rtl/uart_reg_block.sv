`include "uart_config.svh"

module uart_reg_block #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned STRB_WIDTH = DATA_WIDTH / 8
) (
    input  logic                         clk,
    input  logic                         rst_n,

    // A request is presented for one clock after uart_axi_lite has collected
    // and accepted the required AXI channel information.
    input  logic                         write_en,
    input  logic [ADDR_WIDTH-1:0]        write_addr,
    input  logic [DATA_WIDTH-1:0]        write_data,
    input  logic [STRB_WIDTH-1:0]        write_strb,
    output logic                         write_error,

    input  logic                         read_en,
    input  logic [ADDR_WIDTH-1:0]        read_addr,
    output logic [DATA_WIDTH-1:0]        read_data,
    output logic                         read_error,

    // Parallel handoff to uart_tx. uart_tx captures uart_tx_data when both
    // uart_tx_start and uart_tx_ready are asserted on a rising clock edge.
    output logic [`DATA_BITS-1:0]        uart_tx_data,
    output logic                         uart_tx_start,
    input  logic                         uart_tx_ready,

    // Completed receive-byte and error pulses from uart_rx.
    input  logic [`DATA_BITS-1:0]        uart_rx_data,
    input  logic                         uart_rx_valid,
    input  logic                         uart_framing_error,

    output logic                         irq
);

    import uart_reg_pkg::*;

    // Locally sized aliases prevent the register decoder from depending on a
    // particular AXI address width.
    localparam logic [ADDR_WIDTH-1:0] RBR_THR_ADDR = UART_RBR_THR_ADDR;
    localparam logic [ADDR_WIDTH-1:0] IER_ADDR     = UART_IER_ADDR;
    localparam logic [ADDR_WIDTH-1:0] IIR_ADDR     = UART_IIR_ADDR;
    localparam logic [ADDR_WIDTH-1:0] LSR_ADDR     = UART_LSR_ADDR;

    localparam logic [1:0] IIR_ID_THR_EMPTY    = 2'd1;
    localparam logic [1:0] IIR_ID_RX_AVAILABLE = 2'd2;
    localparam logic [1:0] IIR_ID_LINE_STATUS  = 2'd3;

    // Only implemented bits require storage. Reserved portions of the
    // software-visible 32-bit registers are supplied as zero by read_data.
    logic [`DATA_BITS-1:0] rx_buffer_data;
    logic [`DATA_BITS-1:0] tx_holding_data;
    logic [3:0]            interrupt_enable_reg;
    logic [2:0]            interrupt_identification;
    logic [3:0]            line_status;

    logic                  rbr_pop;
    logic                  rbr_push;
    logic                  rbr_full;
    logic                  thr_pop;
    logic                  thr_push;
    logic                  thr_full;

    logic                  lsr_read;
    logic                  overrun_event;
    logic                  overrun_sticky;
    logic                  framing_error_sticky;

    logic                  line_status_pending;
    logic                  rx_data_pending;
    logic                  thr_empty_pending;

    // This UART currently implements only the low byte of each 32-bit AXI
    // word. Explicitly consume the reserved write payload so strict lint can
    // distinguish an intentional no-op policy from accidentally dropped bits.
    // The leading zero makes this a constant that synthesis removes.
    logic                  unused_write_payload;
    assign unused_write_payload = &{
        1'b0,
        write_data,
        write_strb
    };

    // ---------------------------------------------------------------------
    // Register-access decode
    // ---------------------------------------------------------------------

    // Reading address 0x0 consumes the pre-edge RBR contents. An empty read
    // remains an event but returns zero, allowing a simultaneous RX byte to be
    // stored for the following read.
    assign rbr_pop = read_en && (read_addr == RBR_THR_ADDR);
    assign rbr_push = uart_rx_valid;

    // A byte-zero strobe makes thr_push represent a requested THR write. The
    // sequential event table decides whether that request can be accepted.
    assign thr_push =
        write_en &&
        (write_addr == RBR_THR_ADDR) &&
        write_strb[0];

    // Assert start for as long as a byte is waiting. The current uart_tx
    // captures it only when ready is also asserted.
    assign uart_tx_data = tx_holding_data;
    assign uart_tx_start = thr_full;
    assign thr_pop = uart_tx_start && uart_tx_ready;

    assign lsr_read = read_en && (read_addr == LSR_ADDR);

    // A newly completed byte cannot backpressure the serial receiver. Preserve
    // the unread old byte, discard the new byte, and remember the loss.
    assign overrun_event = rbr_push && rbr_full && !rbr_pop;

    // Comb block to determine write_error
    always_comb begin
        write_error = 1'b0;

        if (write_en) begin
            unique0 case (write_addr)
                // Writing to full TX Holding Register
                RBR_THR_ADDR: begin
                    if (write_strb[0] && thr_full && !thr_pop)
                        write_error = 1'b1;
                end

                IER_ADDR: begin
                    // IER is writable. Unstrobed bytes are legal no-ops.
                end

                // Writing to Read-only registers
                IIR_ADDR,
                LSR_ADDR: begin
                    // IIR and LSR are read-only.
                    write_error = 1'b1;
                end

                default: begin
                    // Unmapped and misaligned addresses are illegal.
                    write_error = 1'b1;
                end
            endcase
        end
    end

    // Comb block to assign read data output
    always_comb begin
        read_data = '0;
        read_error = 1'b0;

        if (read_en) begin
            unique case (read_addr)
                RBR_THR_ADDR: begin
                    if (rbr_full)
                        read_data[`DATA_BITS-1:0] = rx_buffer_data;
                end

                IER_ADDR: begin
                    read_data[3:0] = interrupt_enable_reg;
                end

                IIR_ADDR: begin
                    read_data[2:0] = interrupt_identification;
                end

                LSR_ADDR: begin
                    read_data[3:0] = line_status;
                end

                default: begin
                    read_error = 1'b1;
                end
            endcase
        end
    end

    // ---------------------------------------------------------------------
    // Receiver Buffer Register
    // ---------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rx_buffer_data <= '0;
            rbr_full <= 1'b0;
        end else begin
            unique0 case ({rbr_pop, rbr_push})
                2'b01: begin
                    if (!rbr_full) begin
                        rx_buffer_data <= uart_rx_data;
                        rbr_full <= 1'b1;
                    end
                end

                2'b10: begin
                    rbr_full <= 1'b0;
                end

                2'b11: begin
                    rx_buffer_data <= uart_rx_data;
                    rbr_full <= 1'b1;
                end
            endcase
        end
    end

    // ---------------------------------------------------------------------
    // Transmitter Holding Register
    // ---------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            tx_holding_data <= '0;
            thr_full <= 1'b0;
        end else begin
            unique0 case ({thr_pop, thr_push})
                2'b01: begin
                    if (!thr_full) begin
                        tx_holding_data <= write_data[`DATA_BITS-1:0];
                        thr_full <= 1'b1;
                    end
                end

                2'b10: begin
                    thr_full <= 1'b0;
                end

                2'b11: begin
                    tx_holding_data <= write_data[`DATA_BITS-1:0];
                    thr_full <= 1'b1;
                end
            endcase
        end
    end

    // ---------------------------------------------------------------------
    // Interrupt Enable Register and sticky receiver errors
    // ---------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Software explicitly enables the desired interrupt sources.
            interrupt_enable_reg <= '0;
        end else if (
            write_en &&
            (write_addr == IER_ADDR) &&
            write_strb[0]
        ) begin
            interrupt_enable_reg <= write_data[3:0];
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            overrun_sticky <= 1'b0;
            framing_error_sticky <= 1'b0;
        end else begin
            // Hardware set has priority over a simultaneous LSR-read clear.
            if (overrun_event)
                overrun_sticky <= 1'b1;
            else if (lsr_read)
                overrun_sticky <= 1'b0;

            if (uart_framing_error)
                framing_error_sticky <= 1'b1;
            else if (lsr_read)
                framing_error_sticky <= 1'b0;
        end
    end

    // ---------------------------------------------------------------------
    // Live status and interrupt arbitration
    // ---------------------------------------------------------------------

    always_comb begin
        line_status = '0;
        line_status[UART_LSR_OVERRUN_BIT] = overrun_sticky;
        line_status[UART_LSR_FRAMING_BIT] = framing_error_sticky;
        line_status[UART_LSR_THR_EMPTY_BIT] = !thr_full;
        line_status[UART_LSR_RX_READY_BIT] = rbr_full;
    end

    assign line_status_pending =
        (interrupt_enable_reg[UART_IER_OVERRUN_BIT] && overrun_sticky) ||
        (interrupt_enable_reg[UART_IER_FRAMING_BIT] &&
         framing_error_sticky);

    assign rx_data_pending =
        interrupt_enable_reg[UART_IER_RX_BIT] && rbr_full;

    assign thr_empty_pending =
        interrupt_enable_reg[UART_IER_TX_BIT] && !thr_full;

    // IIR is a live priority encoding rather than separately stored state.
    // Bit 0 uses the plan's active-high "Interrupt Pending" interpretation.
    always_comb begin
        interrupt_identification = '0;

        if (line_status_pending) begin
            interrupt_identification[2:1] = IIR_ID_LINE_STATUS;
            interrupt_identification[0] = 1'b1;
        end else if (rx_data_pending) begin
            interrupt_identification[2:1] = IIR_ID_RX_AVAILABLE;
            interrupt_identification[0] = 1'b1;
        end else if (thr_empty_pending) begin
            interrupt_identification[2:1] = IIR_ID_THR_EMPTY;
            interrupt_identification[0] = 1'b1;
        end
    end

    assign irq = interrupt_identification[0];

endmodule
