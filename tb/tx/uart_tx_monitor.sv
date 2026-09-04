`include "rtl/uart_config.svh"

class uart_tx_monitor;

    virtual uart_tx_if vif;

    function new(virtual uart_tx_if vif_arg);
        this.vif = vif_arg;
    endfunction

    task automatic check_start_bit();
        // The falling edge marks the beginning of the UART start bit.
        @(negedge vif.tx);

        // Check the start bit
        for (int baud_tick = 0; baud_tick < `OVERSAMPLE; baud_tick++) begin
            $display("[%0t] Baud tick: %0d", $time, baud_tick);
            if (baud_tick == (`OVERSAMPLE/2)) begin
                if (vif.tx !== 1'b0)
                    $error("Invalid start bit");
            end
            @(negedge vif.ref_baud_tick);
            #1step;
        end
    endtask

    task automatic receive_byte(
        output logic [`DATA_BITS-1:0] data
    );
        for (int data_bit = 0; data_bit < `DATA_BITS; data_bit++) begin
            for (int baud_tick = 0; baud_tick < `OVERSAMPLE; baud_tick++) begin
                if (baud_tick == (`OVERSAMPLE/2)) begin
                    $display("[%0t] Recieve Data Bit: %0d", $time, vif.tx);
                    data[data_bit] = vif.tx;
                end
                @(negedge vif.ref_baud_tick);
                #1step;
            end
        end
    endtask

    task automatic check_stop_bit();
        // Check the stop bit
        for (int baud_tick = 0; baud_tick < `OVERSAMPLE; baud_tick++) begin
            if (baud_tick == (`OVERSAMPLE/2)) begin
                if (vif.tx !== 1'b1)
                    $error("Invalid stop bit");
            end
            @(negedge vif.ref_baud_tick);
            #1step;
        end
    endtask

    task automatic recieve_tx_ready(output logic tx_ready);
        tx_ready = vif.tx_ready;
    endtask
endclass
