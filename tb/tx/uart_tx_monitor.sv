`include "rtl/uart_config.svh"

class uart_tx_monitor;

    virtual uart_tx_if vif;

    function new(virtual uart_tx_if vif_arg);
        this.vif = vif_arg;
    endfunction

    task automatic wait_ref_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(negedge vif.ref_baud_tick);
            #1step;
        end
    endtask

    // Sample one complete UART bit at its center using the independent
    // testbench timing reference rather than the DUT-generated baud tick.
    task automatic receive_serial_bit(output logic bit_value);
        for (int tick_index = 0;
             tick_index < `OVERSAMPLE;
             tick_index++) begin
            if (tick_index == (`OVERSAMPLE / 2))
                bit_value = vif.tx_out;

            wait_ref_ticks(1);
        end
    endtask

    task automatic receive_start_bit(output logic start_bit);
        // The falling edge marks the beginning of the UART start bit.
        @(negedge vif.tx_out);

        receive_serial_bit(start_bit);
        $display("[%0t] TX monitor received start bit: %0b", $time, start_bit);
    endtask

    task automatic receive_byte(
        output logic [`DATA_BITS-1:0] data
    );
        for (int bit_index = 0; bit_index < `DATA_BITS; bit_index++) begin
            receive_serial_bit(data[bit_index]);
            $display(
                "[%0t] TX monitor received data bit %0d: %0b",
                $time,
                bit_index,
                data[bit_index]
            );
        end
    endtask

    task automatic receive_stop_bit(output logic stop_bit);
        receive_serial_bit(stop_bit);
        $display("[%0t] TX monitor received stop bit: %0b", $time, stop_bit);
    endtask

    // Compatibility wrappers for the integrated test's older three-call
    // monitor flow. New tests should use receive_frame() and let the
    // scoreboard perform these checks.
    task automatic check_start_bit();
        logic start_bit;

        receive_start_bit(start_bit);
        if (start_bit !== 1'b0)
            $error("[%0t] Invalid TX start bit: %b", $time, start_bit);
    endtask

    task automatic check_stop_bit();
        logic stop_bit;

        receive_stop_bit(stop_bit);
        if (stop_bit !== 1'b1)
            $error("[%0t] Invalid TX stop bit: %b", $time, stop_bit);
    endtask

    // Return one complete observed frame, mirroring the RX monitor's
    // transaction-level receive_frame() task.
    task automatic receive_frame(
        output logic [`DATA_BITS-1:0] data,
        output logic                  start_bit,
        output logic                  stop_bit
    );
        wait (vif.rst_n === 1'b1);

        receive_start_bit(start_bit);
        receive_byte(data);
        receive_stop_bit(stop_bit);

        $display(
            "[%0t] TX monitor received frame: start=%0b data=0x%0h stop=%0b",
            $time,
            start_bit,
            data,
            stop_bit
        );
    endtask

    task automatic wait_for_ready_state(
        input  logic        expected_ready,
        input  int unsigned timeout_baud_ticks,
        output bit          observed
    );
        int unsigned baud_ticks_seen;

        observed        = 1'b0;
        baud_ticks_seen = 0;

        while (baud_ticks_seen < timeout_baud_ticks) begin
            @(posedge vif.clk);
            #1step;

            if (vif.tx_ready === expected_ready) begin
                observed = 1'b1;
                return;
            end

            if (vif.baud_tick === 1'b1)
                baud_ticks_seen++;
        end
    endtask
endclass
