`include "uart_config.svh"
`include "uart_tb_log.svh"

import axi_lite_tb_pkg::AXI_LITE_ADDR_WIDTH;
import axi_lite_tb_pkg::AXI_LITE_DATA_WIDTH;
import axi_lite_tb_pkg::AXI_LITE_STRB_WIDTH;
import axi_lite_tb_pkg::AXI_LITE_PROT_WIDTH;
import axi_lite_tb_pkg::AXI_LITE_DEFAULT_TIMEOUT_CYCLES;
import axi_lite_tb_pkg::AXI_LITE_READ;
import axi_lite_tb_pkg::AXI_LITE_WRITE;
import axi_lite_tb_pkg::AXI_LITE_AW_BEFORE_W;
import axi_lite_tb_pkg::AXI_LITE_W_BEFORE_AW;
import axi_lite_tb_pkg::AXI_LITE_AW_W_SAME_CYCLE;
import axi_lite_tb_pkg::axi_lite_transaction_t;

class axi_lite_driver;

    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual axi_lite_if.driver      vif;
    int unsigned                    timeout_cycles;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual axi_lite_if.driver      vif_arg,
        input int unsigned timeout_cycles_arg =
            AXI_LITE_DEFAULT_TIMEOUT_CYCLES
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif = vif_arg;
        this.timeout_cycles = timeout_cycles_arg;
    endfunction

    task automatic initialize_inputs();
        vif.s_axi_awaddr  = '0;
        vif.s_axi_awprot  = '0;
        vif.s_axi_awvalid = 1'b0;

        vif.s_axi_wdata   = '0;
        vif.s_axi_wstrb   = '0;
        vif.s_axi_wvalid  = 1'b0;

        vif.s_axi_bready  = 1'b0;

        vif.s_axi_araddr  = '0;
        vif.s_axi_arprot  = '0;
        vif.s_axi_arvalid = 1'b0;

        vif.s_axi_rready  = 1'b0;

        `UART_DISPLAY(("[AXI DRIVER] initialized AXI-Lite master inputs"))
    endtask

    task automatic wait_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(posedge ctrl_vif.clk);
            #1step;
        end
    endtask

    // VALID is held until the rising edge on which READY is sampled. It is
    // removed one simulator step later, avoiding a race with the DUT.
    task automatic drive_write_address(
        input logic [AXI_LITE_ADDR_WIDTH-1:0] address,
        input logic [AXI_LITE_PROT_WIDTH-1:0] protection
    );
        bit accepted;
        int unsigned cycles_waited;

        accepted = 1'b0;
        cycles_waited = 0;

        @(negedge ctrl_vif.clk);
        vif.s_axi_awaddr = address;
        vif.s_axi_awprot = protection;
        vif.s_axi_awvalid = 1'b1;

        while (!accepted) begin
            @(posedge ctrl_vif.clk);
            accepted = (vif.s_axi_awready === 1'b1);
            #1step;

            if (ctrl_vif.rst_n !== 1'b1) begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] reset interrupted AW transaction"
                ))
            end

            if (!accepted) begin
                cycles_waited++;
                if (cycles_waited >= timeout_cycles) begin
                    `UART_FATAL((
                        1,
                        "[AXI DRIVER] timed out waiting for AWREADY"
                    ))
                end
            end
        end

        vif.s_axi_awvalid = 1'b0;
        vif.s_axi_awaddr = '0;
        vif.s_axi_awprot = '0;

        `UART_DISPLAY((
            "[AXI DRIVER] AW handshake address=0x%08h prot=0x%0h",
            address,
            protection
        ))
    endtask

    task automatic drive_write_data(
        input logic [AXI_LITE_DATA_WIDTH-1:0] data,
        input logic [AXI_LITE_STRB_WIDTH-1:0] strobe
    );
        bit accepted;
        int unsigned cycles_waited;

        accepted = 1'b0;
        cycles_waited = 0;

        @(negedge ctrl_vif.clk);
        vif.s_axi_wdata = data;
        vif.s_axi_wstrb = strobe;
        vif.s_axi_wvalid = 1'b1;

        while (!accepted) begin
            @(posedge ctrl_vif.clk);
            accepted = (vif.s_axi_wready === 1'b1);
            #1step;

            if (ctrl_vif.rst_n !== 1'b1) begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] reset interrupted W transaction"
                ))
            end

            if (!accepted) begin
                cycles_waited++;
                if (cycles_waited >= timeout_cycles) begin
                    `UART_FATAL((
                        1,
                        "[AXI DRIVER] timed out waiting for WREADY"
                    ))
                end
            end
        end

        vif.s_axi_wvalid = 1'b0;
        vif.s_axi_wdata = '0;
        vif.s_axi_wstrb = '0;

        `UART_DISPLAY((
            "[AXI DRIVER] W handshake data=0x%08h strb=0x%0h",
            data,
            strobe
        ))
    endtask

    task automatic drive_read_address(
        input logic [AXI_LITE_ADDR_WIDTH-1:0] address,
        input logic [AXI_LITE_PROT_WIDTH-1:0] protection
    );
        bit accepted;
        int unsigned cycles_waited;

        accepted = 1'b0;
        cycles_waited = 0;

        @(negedge ctrl_vif.clk);
        vif.s_axi_araddr = address;
        vif.s_axi_arprot = protection;
        vif.s_axi_arvalid = 1'b1;

        while (!accepted) begin
            @(posedge ctrl_vif.clk);
            accepted = (vif.s_axi_arready === 1'b1);
            #1step;

            if (ctrl_vif.rst_n !== 1'b1) begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] reset interrupted AR transaction"
                ))
            end

            if (!accepted) begin
                cycles_waited++;
                if (cycles_waited >= timeout_cycles) begin
                    `UART_FATAL((
                        1,
                        "[AXI DRIVER] timed out waiting for ARREADY"
                    ))
                end
            end
        end

        vif.s_axi_arvalid = 1'b0;
        vif.s_axi_araddr = '0;
        vif.s_axi_arprot = '0;

        `UART_DISPLAY((
            "[AXI DRIVER] AR handshake address=0x%08h prot=0x%0h",
            address,
            protection
        ))
    endtask

    task automatic collect_write_response(
        input  int unsigned response_stall_cycles,
        output logic [1:0] response
    );
        bit response_seen;
        int unsigned cycles_waited;

        response_seen = 1'b0;
        cycles_waited = 0;
        vif.s_axi_bready = 1'b0;

        while (!response_seen) begin
            @(posedge ctrl_vif.clk);
            #1step;
            response_seen = (vif.s_axi_bvalid === 1'b1);

            if (ctrl_vif.rst_n !== 1'b1) begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] reset interrupted B response"
                ))
            end

            if (!response_seen) begin
                cycles_waited++;
                if (cycles_waited >= timeout_cycles) begin
                    `UART_FATAL((
                        1,
                        "[AXI DRIVER] timed out waiting for BVALID"
                    ))
                end
            end
        end

        response = vif.s_axi_bresp;

        // Keep READY low to exercise response backpressure, checking that the
        // slave holds both VALID and BRESP stable throughout the stall.
        repeat (response_stall_cycles) begin
            @(posedge ctrl_vif.clk);
            #1step;

            if ((vif.s_axi_bvalid !== 1'b1) ||
                (vif.s_axi_bresp !== response)) begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] B response changed while BREADY was low"
                ))
            end
        end

        @(negedge ctrl_vif.clk);
        vif.s_axi_bready = 1'b1;

        @(posedge ctrl_vif.clk);
        if (vif.s_axi_bvalid !== 1'b1) begin
            `UART_FATAL((
                1,
                "[AXI DRIVER] BVALID dropped before the B handshake"
            ))
        end
        response = vif.s_axi_bresp;
        #1step;
        vif.s_axi_bready = 1'b0;

        `UART_DISPLAY((
            "[AXI DRIVER] B handshake response=%02b stall_cycles=%0d",
            response,
            response_stall_cycles
        ))
    endtask

    task automatic collect_read_response(
        input  int unsigned response_stall_cycles,
        output logic [AXI_LITE_DATA_WIDTH-1:0] data,
        output logic [1:0] response
    );
        bit response_seen;
        int unsigned cycles_waited;

        response_seen = 1'b0;
        cycles_waited = 0;
        vif.s_axi_rready = 1'b0;

        while (!response_seen) begin
            @(posedge ctrl_vif.clk);
            #1step;
            response_seen = (vif.s_axi_rvalid === 1'b1);

            if (ctrl_vif.rst_n !== 1'b1) begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] reset interrupted R response"
                ))
            end

            if (!response_seen) begin
                cycles_waited++;
                if (cycles_waited >= timeout_cycles) begin
                    `UART_FATAL((
                        1,
                        "[AXI DRIVER] timed out waiting for RVALID"
                    ))
                end
            end
        end

        data = vif.s_axi_rdata;
        response = vif.s_axi_rresp;

        // RDATA, RRESP, and RVALID must all remain stable under backpressure.
        repeat (response_stall_cycles) begin
            @(posedge ctrl_vif.clk);
            #1step;

            if ((vif.s_axi_rvalid !== 1'b1) ||
                (vif.s_axi_rdata !== data) ||
                (vif.s_axi_rresp !== response)) begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] R response changed while RREADY was low"
                ))
            end
        end

        @(negedge ctrl_vif.clk);
        vif.s_axi_rready = 1'b1;

        @(posedge ctrl_vif.clk);
        if (vif.s_axi_rvalid !== 1'b1) begin
            `UART_FATAL((
                1,
                "[AXI DRIVER] RVALID dropped before the R handshake"
            ))
        end
        data = vif.s_axi_rdata;
        response = vif.s_axi_rresp;
        #1step;
        vif.s_axi_rready = 1'b0;

        `UART_DISPLAY((
            "[AXI DRIVER] R handshake data=0x%08h response=%02b stall_cycles=%0d",
            data,
            response,
            response_stall_cycles
        ))
    endtask

    task automatic write_transaction(
        ref axi_lite_transaction_t transaction
    );
        if (transaction.access != AXI_LITE_WRITE) begin
            `UART_FATAL((
                1,
                "[AXI DRIVER] write_transaction received a read transaction"
            ))
        end

        `UART_DISPLAY((
            "[AXI DRIVER] starting write address=0x%08h data=0x%08h order=%0d",
            transaction.address,
            transaction.write_data,
            transaction.write_order
        ))

        unique case (transaction.write_order)
            AXI_LITE_AW_BEFORE_W: begin
                drive_write_address(
                    transaction.address,
                    transaction.protection
                );
                wait_cycles(transaction.channel_gap_cycles);
                drive_write_data(
                    transaction.write_data,
                    transaction.write_strobe
                );
            end

            AXI_LITE_W_BEFORE_AW: begin
                drive_write_data(
                    transaction.write_data,
                    transaction.write_strobe
                );
                wait_cycles(transaction.channel_gap_cycles);
                drive_write_address(
                    transaction.address,
                    transaction.protection
                );
            end

            AXI_LITE_AW_W_SAME_CYCLE: begin
                fork
                    drive_write_address(
                        transaction.address,
                        transaction.protection
                    );
                    drive_write_data(
                        transaction.write_data,
                        transaction.write_strobe
                    );
                join
            end

            default: begin
                `UART_FATAL((
                    1,
                    "[AXI DRIVER] unsupported write-channel ordering"
                ))
            end
        endcase

        collect_write_response(
            transaction.response_stall_cycles,
            transaction.actual_response
        );
        transaction.completed = 1'b1;
    endtask

    task automatic read_transaction(
        ref axi_lite_transaction_t transaction
    );
        if (transaction.access != AXI_LITE_READ) begin
            `UART_FATAL((
                1,
                "[AXI DRIVER] read_transaction received a write transaction"
            ))
        end

        `UART_DISPLAY((
            "[AXI DRIVER] starting read address=0x%08h",
            transaction.address
        ))

        drive_read_address(transaction.address, transaction.protection);
        collect_read_response(
            transaction.response_stall_cycles,
            transaction.actual_read_data,
            transaction.actual_response
        );
        transaction.completed = 1'b1;
    endtask

endclass
