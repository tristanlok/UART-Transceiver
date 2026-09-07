`include "rtl/uart_config.svh"

class uart_tx_driver;
    virtual uart_tx_if vif;

    function new(virtual uart_tx_if vif_arg);
        this.vif = vif_arg;
    endfunction

    // Put only the TX protocol inputs into their inactive values. Reset is
    // owned separately by uart_reset_driver because it affects the whole DUT.
    task automatic drive_idle();
        vif.tx_start = 1'b0;
        vif.tx_data  = '0;

        $display(
            "[%0t] TX driver placed inputs in their idle state",
            $time
        );
    endtask

    task automatic wait_until_ready();
        wait (vif.tx_ready);
    endtask

    task automatic wait_clock_cycles(input int unsigned cycles);
        repeat (cycles)
            @(posedge vif.clk);
    endtask

    // Count the oversampling ticks actually consumed by the DUT. This is used
    // when a test deliberately targets a particular transmitter FSM window.
    task automatic wait_baud_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(posedge vif.baud_tick);
            #1step;
        end
    endtask

    task automatic assert_request(input logic [`DATA_BITS-1:0] data);
        // Drive away from the DUT's active edge so the request is stable when
        // uart_tx samples it on the following rising edge.
        @(negedge vif.clk);
        vif.tx_data  = data;
        vif.tx_start = 1'b1;

        $display(
            "[%0t] TX driver asserted request with data=0x%0h",
            $time,
            data
        );
    endtask

    task automatic wait_for_acceptance();
        wait (!vif.tx_ready);
    endtask

    task automatic set_data(input logic [`DATA_BITS-1:0] data);
        @(negedge vif.clk);
        vif.tx_data = data;
    endtask

    task automatic release_request();
        @(negedge vif.clk);
        vif.tx_start = 1'b0;

        $display("[%0t] TX driver released request", $time);
    endtask

    // Complete one request/acceptance handshake. The UART continues shifting
    // the accepted frame after this task returns; the monitor observes that
    // serial activity independently.
    task automatic send_byte(
        input logic [`DATA_BITS-1:0] data,
        input int unsigned           delay_cycles = 0
    );
        $display("[%0t] Driver waiting to send byte 0x%02h", $time, data);
        wait_until_ready();

        $display(
            "[%0t] Driver delaying transmission by %0d clock cycles",
            $time,
            delay_cycles
        );

        wait_clock_cycles(delay_cycles);
        assert_request(data);
        wait_for_acceptance();
        release_request();
    endtask

    // Compatibility wrapper for the integrated test while it migrates to the
    // shorter send_byte() name. New TX tests should call send_byte().
    task automatic send_byte_and_wait(
        input logic [`DATA_BITS-1:0] data,
        input int unsigned           delay_cycles = 0
    );
        send_byte(data, delay_cycles);
    endtask
endclass
