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

    task automatic wait_clock_cycles(
        ref logic clk,
        input int unsigned cycles
    );
        repeat (cycles)
            @(posedge clk);
    endtask

    task automatic assert_request(input logic [`DATA_BITS-1:0] data);
        vif.tx_data  <= data;
        vif.tx_start <= 1'b1;
    endtask

    task automatic wait_for_acceptance();
        wait (!vif.tx_ready);
    endtask

    task automatic set_data(input logic [`DATA_BITS-1:0] data);
        vif.tx_data <= data;
    endtask

    task automatic release_request();
        vif.tx_start <= 1'b0;
        @(posedge vif.clk);
    endtask

    task automatic send_byte_and_wait(
        input logic [`DATA_BITS-1:0] data,
        input int unsigned delay_cycles
    );
        $display("[%0t] Driver waiting to send byte 0x%02h", $time, data);
        wait_until_ready();

        $display(
            "[%0t] Driver delaying transmission by %0d clock cycles",
            $time,
            delay_cycles
        );

        wait_clock_cycles(vif.clk, delay_cycles);
        assert_request(data);
        wait_for_acceptance();
        release_request();
    endtask
endclass
