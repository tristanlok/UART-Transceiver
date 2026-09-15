`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_rx_monitor;

    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_rx_if.monitor      vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_rx_if.monitor      vif_arg
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
                if ((vif.rx_in          !== 1'b1) ||
                    (vif.rx_busy        !== 1'b0) ||
                    (vif.rx_valid       !== 1'b0) ||
                    (vif.framing_error  !== 1'b0)
                ) begin
                    unexpected_activity_seen = 1'b1;
                end
            end
        end
    endtask

    // Observe either successful reception or a framing-error completion.
    // Capturing rx_valid separately lets negative tests prove that bad data
    // was rejected rather than published as a valid byte.
    task automatic receive_frame_result(
        output logic [`DATA_BITS-1:0] data,
        output logic                  rx_valid,
        output logic                  framing_error
    );
        // Ignore output activity until reset has been released.
        wait (ctrl_vif.rst_n === 1'b1);

        forever begin
            @(posedge ctrl_vif.clk);
            #1step;

            if ((vif.rx_valid === 1'b1) ||
                (vif.framing_error === 1'b1)) begin
                data          = vif.rx_data;
                rx_valid      = vif.rx_valid;
                framing_error = vif.framing_error;

                `UART_DISPLAY((
                    "[RX MONITOR] received RX result: data=0x%0h valid=%0b framing_error=%0b",
                    data,
                    rx_valid,
                    framing_error
                ))

                return;
            end
        end
    endtask

    // Convenience task for existing positive tests. Negative tests use
    // receive_frame_result() so they can also inspect the valid indication.
    task automatic receive_frame(
        output logic [`DATA_BITS-1:0] data,
        output logic                  framing_error
    );
        logic rx_valid;

        receive_frame_result(data, rx_valid, framing_error);
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
            @(posedge ctrl_vif.clk);
            #1step;

            if (vif.rx_busy === expected_busy) begin
                observed = 1'b1;
                return;
            end

            if (ctrl_vif.baud_tick === 1'b1)
                baud_ticks_seen++;
        end
    endtask
endclass
