`include "rtl/uart_config.svh"

class uart_rx_driver;
    virtual uart_rx_if vif;

    function new(virtual uart_rx_if vif_arg);
        this.vif = vif_arg;
    endfunction

    task automatic assert_reset();
        vif.rst_n = 1'b0;
        vif.rx_in = 1'b1;

        $display(
            "[%0t] Driver asserted reset",
            $time
        );
    endtask

    task automatic deassert_reset();
        // Release reset away from the DUT's active clock edge.
        @(negedge vif.clk);
        vif.rst_n = 1'b1;

        $display(
            "[%0t] Driver released reset; rx_in returned to idle-high",
            $time
        );
    endtask

    task automatic wait_ref_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(negedge vif.ref_baud_tick);
            #1step;
        end
    endtask

    task automatic align_to_ref_tick();
        @(negedge vif.ref_baud_tick);
        #1step;
    endtask

    // Drive one UART symbol for exactly one bit period. The caller must begin
    // on a reference-tick boundary; send_frame() guarantees that alignment.
    task automatic drive_serial_bit(input logic bit_value);
        vif.rx_in = bit_value;
        wait_ref_ticks(`OVERSAMPLE);
    endtask

    // Drive one UART data bit while independently controlling the three
    // samples used by the receiver's majority voter. vote_samples[2] is the
    // first sample, vote_samples[1] the middle sample, and vote_samples[0]
    // the final sample.
    task automatic drive_serial_bit_with_vote(
        input logic       nominal_bit,
        input logic [2:0] vote_samples
    );
        for (int tick_index = 0;
             tick_index < `OVERSAMPLE;
             tick_index++) begin
            unique case (tick_index)
                (`OVERSAMPLE / 2 - 2):
                    vif.rx_in = vote_samples[2];
                (`OVERSAMPLE / 2 - 1):
                    vif.rx_in = vote_samples[1];
                (`OVERSAMPLE / 2):
                    vif.rx_in = vote_samples[0];
                default:
                    vif.rx_in = nominal_bit;
            endcase

            wait_ref_ticks(1);
        end
    endtask

    // A start bit begins a frame, so align it to the external transmitter's
    // independent timing reference before driving the line low.
    task automatic send_start_bit();
        align_to_ref_tick();
        $display("[%0t] Driver sending start bit: 0", $time);
        drive_serial_bit(1'b0);
    endtask

    task automatic send_data_byte(input logic [`DATA_BITS-1:0] data);
        $display(
            "[%0t] Driver sending data 0x%0h LSB-first",
            $time,
            data
        );

        for (int bit_index = 0; bit_index < `DATA_BITS; bit_index++) begin
            $display(
                "[%0t] Driver sending data bit %0d: %0b",
                $time,
                bit_index,
                data[bit_index]
            );
            drive_serial_bit(data[bit_index]);
        end
    endtask

    task automatic send_stop_bit(input logic stop_bit = 1'b1);
        $display(
            "[%0t] Driver sending stop bit: %0b",
            $time,
            stop_bit
        );
        drive_serial_bit(stop_bit);

        // UART idles high, including after an intentionally bad stop bit.
        vif.rx_in = 1'b1;
        $display("[%0t] Driver returned rx_in to idle-high", $time);
    endtask

    task automatic send_frame(
        input logic [`DATA_BITS-1:0] data,
        input logic                  stop_bit = 1'b1
    );
        $display(
            "[%0t] Driver starting RX frame: data=0x%0h stop_bit=%0b",
            $time,
            data,
            stop_bit
        );

        send_start_bit();
        send_data_byte(data);
        send_stop_bit(stop_bit);

        $display(
            "[%0t] Driver completed RX frame: data=0x%0h",
            $time,
            data
        );
    endtask

    // Send a legal UART frame, but replace the three center samples of one
    // selected data bit with vote_samples. All other bits remain unchanged.
    task automatic send_frame_with_data_vote(
        input logic [`DATA_BITS-1:0] data,
        input int unsigned           target_bit,
        input logic [2:0]            vote_samples
    );
        if (target_bit >= `DATA_BITS) begin
            $fatal(
                1,
                "Target bit %0d is outside DATA_BITS=%0d",
                target_bit,
                `DATA_BITS
            );
        end

        $display(
            "[%0t] Driver injecting vote samples %03b into data bit %0d",
            $time,
            vote_samples,
            target_bit
        );

        send_start_bit();

        for (int bit_index = 0; bit_index < `DATA_BITS; bit_index++) begin
            if (bit_index == target_bit) begin
                drive_serial_bit_with_vote(data[bit_index], vote_samples);
            end else begin
                drive_serial_bit(data[bit_index]);
            end
        end

        send_stop_bit();
    endtask

    task automatic drive_idle_ticks(input int unsigned tick_count);
        $display(
            "[%0t] Driver holding rx_in idle-high for %0d reference ticks",
            $time,
            tick_count
        );

        vif.rx_in = 1'b1;
        wait_ref_ticks(tick_count);

        $display("[%0t] Driver completed idle interval", $time);
    endtask

    task automatic drive_low_pulse(input int unsigned tick_count);
        align_to_ref_tick();

        $display(
            "[%0t] Driver injecting low pulse for %0d reference ticks",
            $time,
            tick_count
        );

        vif.rx_in = 1'b0;
        wait_ref_ticks(tick_count);
        vif.rx_in = 1'b1;

        $display(
            "[%0t] Driver completed low pulse; rx_in returned to idle-high",
            $time
        );
    endtask
endclass
