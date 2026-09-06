`include "rtl/uart_config.svh"

class uart_rx_monitor;

    virtual uart_rx_if vif;

    function new(virtual uart_rx_if vif_arg);
        this.vif = vif_arg;
    endfunction

    task automatic receive_frame(
        output logic [`DATA_BITS-1:0] data,
        output logic                  framing_error
    );
        // Ignore output activity until reset has been released.
        wait (vif.rst_n === 1'b1);

        forever begin
            @(posedge vif.clk);
            #1step;

            if (vif.rx_valid === 1'b1) begin
                data          = vif.data_out;
                framing_error = vif.framing_error;

                $display(
                    "[%0t] Monitor received RX frame: data=0x%0h framing_error=%0b",
                    $time,
                    data,
                    framing_error
                );

                return;
            end
        end
    endtask

    task automatic wait_for_busy_state(
        input  logic        expected_busy,
        input  int unsigned timeout_baud_ticks,
        output bit          observed
    );
        int unsigned baud_ticks_seen;

        observed        = 1'b0;
        baud_ticks_seen = 0;

        while (baud_ticks_seen < timeout_baud_ticks) begin
            @(posedge vif.clk);
            #1step;

            if (vif.rx_busy === expected_busy) begin
                observed = 1'b1;
                return;
            end

            if (vif.baud_tick === 1'b1)
                baud_ticks_seen++;
        end
    endtask
endclass
