`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_rx_driver;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_rx_if.driver       vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_rx_if.driver       vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif      = vif_arg;
    endfunction

    // UART serial input idles high. Reset itself is owned separately by
    // uart_reset_driver because it affects the complete UART.
    task automatic drive_idle();
        vif.rx_in = 1'b1;

        `UART_DISPLAY((
            "[RX DRIVER] returned rx_in to idle-high"
        ))
    endtask

    task automatic wait_ref_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(negedge ctrl_vif.ref_baud_tick);
            #1step;
        end
    endtask

    task automatic align_to_ref_tick();
        @(negedge ctrl_vif.ref_baud_tick);
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
        `UART_DISPLAY(("[RX DRIVER] sending start bit: 0"))
        drive_serial_bit(1'b0);
    endtask

    task automatic send_data_byte(input logic [`DATA_BITS-1:0] data);
        `UART_DISPLAY((
            "[RX DRIVER] sending data 0x%0h LSB-first",
            data
        ))

        for (int bit_index = 0; bit_index < `DATA_BITS; bit_index++) begin
            `UART_DISPLAY((
                "[RX DRIVER] sending data bit %0d: %0b",
                bit_index,
                data[bit_index]
            ))
            drive_serial_bit(data[bit_index]);
        end
    endtask

    task automatic send_stop_bit(input logic stop_bit = 1'b1);
        `UART_DISPLAY((
            "[RX DRIVER] sending stop bit: %0b",
            stop_bit
        ))
        drive_serial_bit(stop_bit);

        // UART idles high, including after an intentionally bad stop bit.
        vif.rx_in = 1'b1;
        `UART_DISPLAY(("[RX DRIVER] returned rx_in to idle-high"))
    endtask

    task automatic send_frame(
        input logic [`DATA_BITS-1:0] data,
        input logic                  stop_bit = 1'b1
    );
        `UART_DISPLAY((
            "[RX DRIVER] starting RX frame: data=0x%0h stop_bit=%0b",
            data,
            stop_bit
        ))

        send_start_bit();
        send_data_byte(data);
        send_stop_bit(stop_bit);

        `UART_DISPLAY((
            "[RX DRIVER] completed RX frame: data=0x%0h",
            data
        ))
    endtask

    // Send a legal UART frame, but replace the three center samples of one
    // selected data bit with vote_samples. All other bits remain unchanged.
    task automatic send_frame_with_data_vote(
        input logic [`DATA_BITS-1:0] data,
        input int unsigned           target_bit,
        input logic [2:0]            vote_samples
    );
        if (target_bit >= `DATA_BITS) begin
            `UART_FATAL((
                1,
                "[RX DRIVER] target bit %0d is outside DATA_BITS=%0d",
                target_bit,
                `DATA_BITS
            ))
        end

        `UART_DISPLAY((
            "[RX DRIVER] injecting vote samples %03b into data bit %0d",
            vote_samples,
            target_bit
        ))

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
        `UART_DISPLAY((
            "[RX DRIVER] holding rx_in idle-high for %0d reference ticks",
            tick_count
        ))

        vif.rx_in = 1'b1;
        wait_ref_ticks(tick_count);

        `UART_DISPLAY(("[RX DRIVER] completed idle interval"))
    endtask

    task automatic drive_low_pulse(input int unsigned tick_count);
        align_to_ref_tick();

        `UART_DISPLAY((
            "[RX DRIVER] injecting low pulse for %0d reference ticks",
            tick_count
        ))

        vif.rx_in = 1'b0;
        wait_ref_ticks(tick_count);
        vif.rx_in = 1'b1;

        `UART_DISPLAY((
            "[RX DRIVER] completed low pulse; rx_in returned to idle-high"
        ))
    endtask
endclass
