`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_tx_driver;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_tx_if.driver       vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_tx_if.driver       vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif      = vif_arg;
    endfunction

    // Put only the TX protocol inputs into their inactive values. Reset is
    // owned separately by uart_reset_driver because it affects the whole DUT.
    task automatic drive_idle();
        vif.tx_start = 1'b0;
        vif.tx_data  = '0;

        `UART_DISPLAY((
            "[TX DRIVER] placed inputs in their idle state"
        ))
    endtask

    task automatic wait_until_ready();
        wait (vif.tx_ready);
    endtask

    task automatic wait_clock_cycles(input int unsigned cycles);
        repeat (cycles)
            @(posedge ctrl_vif.clk);
    endtask

    // Count the oversampling ticks actually consumed by the DUT. This is used
    // when a test deliberately targets a particular transmitter FSM window.
    task automatic wait_baud_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(posedge ctrl_vif.baud_tick);
            #1step;
        end
    endtask

    task automatic assert_request(input logic [`DATA_BITS-1:0] data);
        // Drive away from the DUT's active edge so the request is stable when
        // uart_tx samples it on the following rising edge.
        @(negedge ctrl_vif.clk);
        vif.tx_data  = data;
        vif.tx_start = 1'b1;

        `UART_DISPLAY((
            "[TX DRIVER] asserted request with data=0x%0h",
            data
        ))
    endtask

    task automatic wait_for_acceptance();
        wait (!vif.tx_ready);
    endtask

    task automatic set_data(input logic [`DATA_BITS-1:0] data);
        @(negedge ctrl_vif.clk);
        vif.tx_data = data;
    endtask

    task automatic release_request();
        @(negedge ctrl_vif.clk);
        vif.tx_start = 1'b0;

        `UART_DISPLAY(("[TX DRIVER] released request"))
    endtask

    // Complete one request/acceptance handshake. The UART continues shifting
    // the accepted frame after this task returns; the monitor observes that
    // serial activity independently.
    task automatic send_byte(input logic [`DATA_BITS-1:0] data);
        `UART_DISPLAY(("[TX DRIVER] waiting to send byte 0x%02h", data))
        wait_until_ready();
        assert_request(data);
        wait_for_acceptance();
        release_request();
    endtask
endclass
