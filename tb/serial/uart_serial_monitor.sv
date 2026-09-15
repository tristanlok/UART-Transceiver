`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_serial_monitor;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_serial_if.monitor  vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_serial_if.monitor  vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif      = vif_arg;
    endfunction

    task automatic wait_ref_ticks(input int unsigned tick_count);
        repeat (tick_count) begin
            @(negedge ctrl_vif.ref_baud_tick);
            #1step;
        end
    endtask

    // Observe one entire UART symbol and sample it near the center. Continuing
    // to the end of the symbol leaves the next call aligned for the next bit.
    task automatic receive_serial_bit(output logic bit_value);
        for (int tick_index = 0;
             tick_index < `OVERSAMPLE;
             tick_index++) begin
            if (tick_index == (`OVERSAMPLE / 2))
                bit_value = vif.tx_out;

            wait_ref_ticks(1);
        end
    endtask

    // Decode one frame emitted on uart_axi_lite.tx_out. The falling edge is the
    // start-bit boundary; all later symbols are sampled LSB-first using only
    // the independent testbench reference tick.
    task automatic receive_tx_frame(
        output uart_serial_tb_pkg::uart_serial_frame_t frame
    );
        frame = '0;
        wait (ctrl_vif.rst_n === 1'b1);

        // If an edge occurred during reset, discard it and wait for the first
        // legitimate post-reset start edge.
        forever begin
            @(negedge vif.tx_out);
            if (ctrl_vif.rst_n === 1'b1)
                break;
        end

        receive_serial_bit(frame.start_bit);

        for (int bit_index = 0; bit_index < `DATA_BITS; bit_index++) begin
            receive_serial_bit(frame.data[bit_index]);
        end

        receive_serial_bit(frame.stop_bit);

        `UART_DISPLAY((
            "[SERIAL MONITOR] decoded TX frame: start=%0b data=0x%0h stop=%0b",
            frame.start_bit,
            frame.data,
            frame.stop_bit
        ))
    endtask

    // Convenience wrapper for tests that do not need a transaction object.
    task automatic receive_frame(
        output logic [`DATA_BITS-1:0] data,
        output logic                  start_bit,
        output logic                  stop_bit
    );
        uart_serial_tb_pkg::uart_serial_frame_t frame;

        receive_tx_frame(frame);
        data      = frame.data;
        start_bit = frame.start_bit;
        stop_bit  = frame.stop_bit;
    endtask

endclass
