`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_serial_driver;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_serial_if.driver   vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_serial_if.driver   vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif      = vif_arg;
    endfunction

    // A UART line must be high whenever no frame is being transmitted. Call
    // this once during testbench initialization, before reset is released.
    task automatic drive_idle();
        vif.rx_in = 1'b1;
        `UART_DISPLAY(("[SERIAL DRIVER] rx_in is idle-high"))
    endtask

    task automatic wait_ref_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(negedge ctrl_vif.ref_baud_tick);
            #1step;
        end
    endtask

    // Align the beginning of a frame to the remote transmitter's independent
    // clock. The DUT-generated baud_tick is deliberately not used here.
    task automatic align_to_ref_tick();
        @(negedge ctrl_vif.ref_baud_tick);
        #1step;
    endtask

    task automatic drive_serial_bit(input logic bit_value);
        vif.rx_in = bit_value;
        wait_ref_ticks(`OVERSAMPLE);
    endtask

    // Drive a complete 1-start, DATA_BITS-data, 1-stop UART frame. Supplying a
    // low stop_bit intentionally creates a framing-error stimulus.
    task automatic send_frame(
        input logic [`DATA_BITS-1:0] data,
        input logic                  stop_bit = 1'b1
    );
        wait (ctrl_vif.rst_n === 1'b1);
        align_to_ref_tick();

        `UART_DISPLAY((
            "[SERIAL DRIVER] sending frame: start=0 data=0x%0h stop=%0b",
            data,
            stop_bit
        ))

        drive_serial_bit(1'b0);

        // UART transmits the least-significant payload bit first.
        for (int bit_index = 0; bit_index < `DATA_BITS; bit_index++) begin
            drive_serial_bit(data[bit_index]);
        end

        drive_serial_bit(stop_bit);

        // A deliberately bad stop bit lasts for one complete symbol only. The
        // line then returns high so a later frame can be detected normally.
        vif.rx_in = 1'b1;

        `UART_DISPLAY((
            "[SERIAL DRIVER] completed frame: data=0x%0h stop=%0b",
            data,
            stop_bit
        ))
    endtask

    task automatic send_valid_frame(
        input logic [`DATA_BITS-1:0] data
    );
        send_frame(data, 1'b1);
    endtask

    task automatic send_bad_stop_frame(
        input logic [`DATA_BITS-1:0] data
    );
        send_frame(data, 1'b0);
    endtask

    // Return the generated payload so the caller can use the same value as an
    // expected transaction in its AXI/register checks.
    task automatic send_random_valid_frame(
        output logic [`DATA_BITS-1:0] data
    );
        data = `DATA_BITS'($urandom());
        send_valid_frame(data);
    endtask

    task automatic send_random_bad_stop_frame(
        output logic [`DATA_BITS-1:0] data
    );
        data = `DATA_BITS'($urandom());
        send_bad_stop_frame(data);
    endtask

endclass
