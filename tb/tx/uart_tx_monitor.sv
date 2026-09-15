`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_tx_monitor;

    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_tx_if.monitor      vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_tx_if.monitor      vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif      = vif_arg;
    endfunction

    task automatic watch_for_activity(ref logic unexpected_activity_seen);
        unexpected_activity_seen = 1'b0;

        forever begin
            @(posedge ctrl_vif.clk);
            #1step;

            // Only evaluate normal behavior after reset has been released.
            if (ctrl_vif.rst_n === 1'b1) begin
                if ((vif.tx_ready   !== 1'b1) ||
                    (vif.tx_out     !== 1'b1)
                ) begin
                    unexpected_activity_seen = 1'b1;
                end
            end
        end
    endtask

    task automatic wait_ref_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(negedge ctrl_vif.ref_baud_tick);
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
        `UART_DISPLAY(("[TX MONITOR] received start bit: %0b", start_bit))
    endtask

    task automatic receive_byte(
        output logic [`DATA_BITS-1:0] data
    );
        for (int bit_index = 0; bit_index < `DATA_BITS; bit_index++) begin
            receive_serial_bit(data[bit_index]);
            `UART_DISPLAY((
                "[TX MONITOR] received data bit %0d: %0b",
                bit_index,
                data[bit_index]
            ))
        end
    endtask

    task automatic receive_stop_bit(output logic stop_bit);
        receive_serial_bit(stop_bit);
        `UART_DISPLAY(("[TX MONITOR] received stop bit: %0b", stop_bit))
    endtask

    // Compatibility wrappers for the integrated test's older three-call
    // monitor flow. New tests should use receive_frame() and let the
    // scoreboard perform these checks.
    task automatic check_start_bit();
        logic start_bit;

        receive_start_bit(start_bit);
        if (start_bit !== 1'b0)
            `UART_ERROR(("[TX MONITOR] Invalid TX start bit: %b", start_bit))
    endtask

    task automatic check_stop_bit();
        logic stop_bit;

        receive_stop_bit(stop_bit);
        if (stop_bit !== 1'b1)
            `UART_ERROR(("[TX MONITOR] Invalid TX stop bit: %b", stop_bit))
    endtask

    // Return one complete observed frame, mirroring the RX monitor's
    // transaction-level receive_frame() task.
    task automatic receive_frame(
        output logic [`DATA_BITS-1:0] data,
        output logic                  start_bit,
        output logic                  stop_bit
    );
        wait (ctrl_vif.rst_n === 1'b1);

        receive_start_bit(start_bit);
        receive_byte(data);
        receive_stop_bit(stop_bit);

        `UART_DISPLAY((
            "[TX MONITOR] received frame: start=%0b data=0x%0h stop=%0b",
            start_bit,
            data,
            stop_bit
        ))
    endtask

    // Measure the start, data, and stop symbol widths in DUT oversampling
    // ticks. The caller must transmit 0x55 so every boundary from START
    // through STOP produces a visible tx_out transition. tx_ready marks the
    // end of STOP because the stop and idle levels are both high.
    task automatic measure_frame_bit_durations(
        output int unsigned bit_ticks [0:`DATA_BITS+1]
    );
        logic        previous_tx_out;
        int unsigned completed_symbols;
        int unsigned current_ticks;

        foreach (bit_ticks[index])
            bit_ticks[index] = 0;

        wait (ctrl_vif.rst_n === 1'b1);
        @(negedge vif.tx_out);

        previous_tx_out  = 1'b0;
        completed_symbols = 0;
        current_ticks     = 0;

        // The alternating data pattern creates one edge after START and one
        // after each data bit, producing DATA_BITS+1 measurable boundaries.
        while (completed_symbols < (`DATA_BITS + 1)) begin
            @(posedge ctrl_vif.clk);
            #1step;

            if (ctrl_vif.baud_tick === 1'b1)
                current_ticks++;

            if (vif.tx_out !== previous_tx_out) begin
                bit_ticks[completed_symbols] = current_ticks;
                previous_tx_out              = vif.tx_out;
                completed_symbols++;
                current_ticks = 0;
            end
        end

        // STOP has no trailing line transition because UART idle is also
        // high, so count until the transmitter advertises IDLE with ready.
        while (vif.tx_ready !== 1'b1) begin
            @(posedge ctrl_vif.clk);
            #1step;

            if (ctrl_vif.baud_tick === 1'b1)
                current_ticks++;
        end

        bit_ticks[`DATA_BITS+1] = current_ticks;
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
            @(posedge ctrl_vif.clk);
            #1step;

            if (vif.tx_ready === expected_ready) begin
                observed = 1'b1;
                return;
            end

            if (ctrl_vif.baud_tick === 1'b1)
                baud_ticks_seen++;
        end
    endtask
endclass
