`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_reg_driver;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_reg_if.driver      vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_reg_if.driver      vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif = vif_arg;
    endfunction

    task automatic initialize_inputs();
        vif.write_en = 1'b0;
        vif.write_addr = '0;
        vif.write_data = '0;
        vif.write_strb = '0;
        vif.read_en = 1'b0;
        vif.read_addr = '0;
        vif.uart_tx_ready = 1'b0;
        vif.uart_rx_data = '0;
        vif.uart_rx_valid = 1'b0;
        vif.uart_framing_error = 1'b0;

        `UART_DISPLAY(("[REG DRIVER] initialized register-block inputs"))
    endtask

    task automatic wait_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(posedge ctrl_vif.clk);
            #1step;
        end
    endtask

    // Present a one-cycle register write. The returned error is the
    // combinational decision that uart_axi_lite will capture into BRESP.
    task automatic write_register(
        input  logic [31:0] address,
        input  logic [31:0] data,
        input  logic [3:0]  strobe,
        output logic        error
    );
        @(negedge ctrl_vif.clk);
        vif.write_addr = address;
        vif.write_data = data;
        vif.write_strb = strobe;
        vif.write_en = 1'b1;
        #1step;
        error = vif.write_error;

        @(posedge ctrl_vif.clk);
        #1step;
        @(negedge ctrl_vif.clk);
        vif.write_en = 1'b0;
        vif.write_addr = '0;
        vif.write_data = '0;
        vif.write_strb = '0;

        `UART_DISPLAY((
            "[REG DRIVER] write address=0x%08h data=0x%08h strb=0x%0h error=%0b",
            address,
            data,
            strobe,
            error
        ))
    endtask

    // Sample read_data before the active edge. This models uart_axi_lite
    // snapshotting the old register value while the same edge applies read
    // side effects such as an RBR pop or sticky-error clear.
    task automatic read_register(
        input  logic [31:0] address,
        output logic [31:0] data,
        output logic        error
    );
        @(negedge ctrl_vif.clk);
        vif.read_addr = address;
        vif.read_en = 1'b1;
        #1step;
        data = vif.read_data;
        error = vif.read_error;

        @(posedge ctrl_vif.clk);
        #1step;
        @(negedge ctrl_vif.clk);
        vif.read_en = 1'b0;
        vif.read_addr = '0;

        `UART_DISPLAY((
            "[REG DRIVER] read address=0x%08h data=0x%08h error=%0b",
            address,
            data,
            error
        ))
    endtask

    task automatic push_rx_byte(input logic [`DATA_BITS-1:0] data);
        @(negedge ctrl_vif.clk);
        vif.uart_rx_data = data;
        vif.uart_rx_valid = 1'b1;

        @(posedge ctrl_vif.clk);
        #1step;
        @(negedge ctrl_vif.clk);
        vif.uart_rx_valid = 1'b0;

        `UART_DISPLAY(("[REG DRIVER] pushed RX byte 0x%0h", data))
    endtask

    task automatic pulse_framing_error();
        @(negedge ctrl_vif.clk);
        vif.uart_framing_error = 1'b1;

        @(posedge ctrl_vif.clk);
        #1step;
        @(negedge ctrl_vif.clk);
        vif.uart_framing_error = 1'b0;

        `UART_DISPLAY(("[REG DRIVER] pulsed UART framing error"))
    endtask

    task automatic consume_thr(
        output logic [`DATA_BITS-1:0] accepted_data
    );
        int unsigned timeout_cycles;

        timeout_cycles = 0;
        while ((vif.uart_tx_start !== 1'b1) && (timeout_cycles < 20)) begin
            @(posedge ctrl_vif.clk);
            #1step;
            timeout_cycles++;
        end

        if (vif.uart_tx_start !== 1'b1) begin
            `UART_FATAL((1, "[REG DRIVER] timed out waiting for THR data"))
        end

        @(negedge ctrl_vif.clk);
        accepted_data = vif.uart_tx_data;
        vif.uart_tx_ready = 1'b1;

        @(posedge ctrl_vif.clk);
        #1step;
        @(negedge ctrl_vif.clk);
        vif.uart_tx_ready = 1'b0;

        `UART_DISPLAY((
            "[REG DRIVER] UART accepted THR byte 0x%0h",
            accepted_data
        ))
    endtask

    task automatic read_with_rx_push(
        input  logic [31:0]           address,
        input  logic [`DATA_BITS-1:0] new_rx_data,
        output logic [31:0]           old_read_data,
        output logic                  read_error
    );
        @(negedge ctrl_vif.clk);
        vif.read_addr = address;
        vif.read_en = 1'b1;
        vif.uart_rx_data = new_rx_data;
        vif.uart_rx_valid = 1'b1;
        #1step;
        old_read_data = vif.read_data;
        read_error = vif.read_error;

        @(posedge ctrl_vif.clk);
        #1step;
        @(negedge ctrl_vif.clk);
        vif.read_en = 1'b0;
        vif.read_addr = '0;
        vif.uart_rx_valid = 1'b0;

        `UART_DISPLAY((
            "[REG DRIVER] simultaneous RBR read old=0x%08h and RX push new=0x%0h",
            old_read_data,
            new_rx_data
        ))
    endtask

    task automatic write_with_tx_accept(
        input  logic [31:0]           address,
        input  logic [31:0]           new_write_data,
        input  logic [3:0]            strobe,
        output logic [`DATA_BITS-1:0] old_tx_data,
        output logic                  write_error
    );
        if (vif.uart_tx_start !== 1'b1) begin
            `UART_FATAL((
                1,
                "[REG DRIVER] simultaneous THR operation requires existing data"
            ))
        end

        @(negedge ctrl_vif.clk);
        old_tx_data = vif.uart_tx_data;
        vif.uart_tx_ready = 1'b1;
        vif.write_addr = address;
        vif.write_data = new_write_data;
        vif.write_strb = strobe;
        vif.write_en = 1'b1;
        #1step;
        write_error = vif.write_error;

        @(posedge ctrl_vif.clk);
        #1step;
        @(negedge ctrl_vif.clk);
        vif.uart_tx_ready = 1'b0;
        vif.write_en = 1'b0;
        vif.write_addr = '0;
        vif.write_data = '0;
        vif.write_strb = '0;

        `UART_DISPLAY((
            "[REG DRIVER] simultaneous THR pop old=0x%0h and write new=0x%08h",
            old_tx_data,
            new_write_data
        ))
    endtask

endclass
