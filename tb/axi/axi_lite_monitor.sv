`include "uart_config.svh"
`include "uart_tb_log.svh"

import axi_lite_tb_pkg::AXI_LITE_DATA_WIDTH;
import axi_lite_tb_pkg::AXI_LITE_DEFAULT_TIMEOUT_CYCLES;
import axi_lite_tb_pkg::AXI_LITE_READ;
import axi_lite_tb_pkg::AXI_LITE_WRITE;
import axi_lite_tb_pkg::AXI_LITE_AW_BEFORE_W;
import axi_lite_tb_pkg::AXI_LITE_W_BEFORE_AW;
import axi_lite_tb_pkg::AXI_LITE_AW_W_SAME_CYCLE;
import axi_lite_tb_pkg::axi_lite_transaction_t;
import axi_lite_tb_pkg::axi_lite_default_transaction;

class axi_lite_monitor;

    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual axi_lite_if.monitor     vif;
    int unsigned                    timeout_cycles;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual axi_lite_if.monitor     vif_arg,
        input int unsigned timeout_cycles_arg =
            AXI_LITE_DEFAULT_TIMEOUT_CYCLES
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif = vif_arg;
        this.timeout_cycles = timeout_cycles_arg;
    endfunction

    // Reconstruct one complete write without assuming which independent
    // request channel arrives first.
    task automatic observe_write(
        output axi_lite_transaction_t transaction
    );
        bit aw_seen;
        bit w_seen;
        bit response_seen;
        bit aw_handshake;
        bit w_handshake;
        bit b_handshake;
        int unsigned cycle_index;
        int unsigned aw_cycle;
        int unsigned w_cycle;
        int unsigned cycles_waited;
        logic [1:0] held_response;

        transaction = axi_lite_default_transaction();
        transaction.access = AXI_LITE_WRITE;
        transaction.check_read_data = 1'b0;
        aw_seen = 1'b0;
        w_seen = 1'b0;
        response_seen = 1'b0;
        cycle_index = 0;
        cycles_waited = 0;
        held_response = '0;

        while (!(aw_seen && w_seen)) begin
            @(posedge ctrl_vif.clk);

            aw_handshake = (vif.s_axi_awvalid === 1'b1) &&
                           (vif.s_axi_awready === 1'b1);
            w_handshake = (vif.s_axi_wvalid === 1'b1) &&
                          (vif.s_axi_wready === 1'b1);

            if (aw_handshake && !aw_seen) begin
                transaction.address = vif.s_axi_awaddr;
                transaction.protection = vif.s_axi_awprot;
                aw_cycle = cycle_index;
                aw_seen = 1'b1;
            end

            if (w_handshake && !w_seen) begin
                transaction.write_data = vif.s_axi_wdata;
                transaction.write_strobe = vif.s_axi_wstrb;
                w_cycle = cycle_index;
                w_seen = 1'b1;
            end

            #1step;

            if (ctrl_vif.rst_n !== 1'b1) begin
                `UART_FATAL((
                    1,
                    "[AXI MONITOR] reset interrupted observed write"
                ))
            end

            cycle_index++;
            if (cycle_index >= timeout_cycles) begin
                `UART_FATAL((
                    1,
                    "[AXI MONITOR] timed out collecting AW and W handshakes"
                ))
            end
        end

        if (aw_cycle < w_cycle)
            transaction.write_order = AXI_LITE_AW_BEFORE_W;
        else if (w_cycle < aw_cycle)
            transaction.write_order = AXI_LITE_W_BEFORE_AW;
        else
            transaction.write_order = AXI_LITE_AW_W_SAME_CYCLE;

        // Observe the response through its handshake. If the master applies
        // backpressure, verify the slave holds BRESP and BVALID stable.
        while (!transaction.completed) begin
            @(posedge ctrl_vif.clk);

            b_handshake = (vif.s_axi_bvalid === 1'b1) &&
                          (vif.s_axi_bready === 1'b1);

            if (vif.s_axi_bvalid === 1'b1) begin
                if (!response_seen) begin
                    held_response = vif.s_axi_bresp;
                    response_seen = 1'b1;
                end else if (vif.s_axi_bresp !== held_response) begin
                    `UART_ERROR((
                        "[AXI MONITOR] BRESP changed while BVALID was asserted"
                    ))
                end
            end

            if (b_handshake) begin
                transaction.actual_response = vif.s_axi_bresp;
                transaction.completed = 1'b1;
            end

            #1step;
            cycles_waited++;
            if (cycles_waited >= timeout_cycles) begin
                `UART_FATAL((
                    1,
                    "[AXI MONITOR] timed out waiting for B handshake"
                ))
            end
        end

        `UART_DISPLAY((
            "[AXI MONITOR] write address=0x%08h data=0x%08h strb=0x%0h order=%0d response=%02b",
            transaction.address,
            transaction.write_data,
            transaction.write_strobe,
            transaction.write_order,
            transaction.actual_response
        ))
    endtask

    task automatic observe_read(
        output axi_lite_transaction_t transaction
    );
        bit address_seen;
        bit response_seen;
        bit ar_handshake;
        bit r_handshake;
        int unsigned cycles_waited;
        logic [AXI_LITE_DATA_WIDTH-1:0] held_data;
        logic [1:0]                     held_response;

        transaction = axi_lite_default_transaction();
        transaction.access = AXI_LITE_READ;
        address_seen = 1'b0;
        response_seen = 1'b0;
        cycles_waited = 0;
        held_data = '0;
        held_response = '0;

        while (!address_seen) begin
            @(posedge ctrl_vif.clk);
            ar_handshake = (vif.s_axi_arvalid === 1'b1) &&
                           (vif.s_axi_arready === 1'b1);

            if (ar_handshake) begin
                transaction.address = vif.s_axi_araddr;
                transaction.protection = vif.s_axi_arprot;
                address_seen = 1'b1;
            end

            #1step;

            if (ctrl_vif.rst_n !== 1'b1) begin
                `UART_FATAL((
                    1,
                    "[AXI MONITOR] reset interrupted observed read"
                ))
            end

            cycles_waited++;
            if (cycles_waited >= timeout_cycles) begin
                `UART_FATAL((
                    1,
                    "[AXI MONITOR] timed out waiting for AR handshake"
                ))
            end
        end

        cycles_waited = 0;
        while (!transaction.completed) begin
            @(posedge ctrl_vif.clk);

            r_handshake = (vif.s_axi_rvalid === 1'b1) &&
                          (vif.s_axi_rready === 1'b1);

            if (vif.s_axi_rvalid === 1'b1) begin
                if (!response_seen) begin
                    held_data = vif.s_axi_rdata;
                    held_response = vif.s_axi_rresp;
                    response_seen = 1'b1;
                end else if ((vif.s_axi_rdata !== held_data) ||
                             (vif.s_axi_rresp !== held_response)) begin
                    `UART_ERROR((
                        "[AXI MONITOR] RDATA/RRESP changed while RVALID was asserted"
                    ))
                end
            end

            if (r_handshake) begin
                transaction.actual_read_data = vif.s_axi_rdata;
                transaction.actual_response = vif.s_axi_rresp;
                transaction.completed = 1'b1;
            end

            #1step;
            cycles_waited++;
            if (cycles_waited >= timeout_cycles) begin
                `UART_FATAL((
                    1,
                    "[AXI MONITOR] timed out waiting for R handshake"
                ))
            end
        end

        `UART_DISPLAY((
            "[AXI MONITOR] read address=0x%08h data=0x%08h response=%02b",
            transaction.address,
            transaction.actual_read_data,
            transaction.actual_response
        ))
    endtask

endclass
