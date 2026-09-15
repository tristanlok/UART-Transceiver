`include "uart_config.svh"
`include "uart_tb_log.svh"

// Passive integration-level observations that do not belong to either the
// AXI bus agent or the external serial agent.
class uart_axi_monitor;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_serial_if.monitor  serial_vif;
    virtual uart_irq_if.monitor     irq_vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_serial_if.monitor  serial_vif_arg,
        virtual uart_irq_if.monitor     irq_vif_arg
    );
        this.ctrl_vif   = ctrl_vif_arg;
        this.serial_vif = serial_vif_arg;
        this.irq_vif    = irq_vif_arg;
    endfunction

    // Wait for the interrupt pin to reach the requested state. The monitor
    // reports whether it observed the state; the test layer decides whether a
    // timeout is fatal for that scenario.
    task automatic wait_for_irq_state(
        input  logic        expected,
        input  int unsigned timeout_cycles,
        output logic        observed
    );
        observed = 1'b0;

        for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
            if (irq_vif.irq === expected) begin
                observed = 1'b1;
                `UART_DISPLAY((
                    "[AXI UART MONITOR] Observed irq=%0b",
                    expected
                ))
                return;
            end

            @(posedge ctrl_vif.clk);
            #1step;
        end
    endtask

    // Observe physical full-duplex activity without generating stimulus.
    // Both lines being low at once proves that an incoming frame overlapped a
    // DUT transmission rather than merely running before or after it.
    task automatic observe_serial_overlap(
        input  int unsigned timeout_cycles,
        output logic        overlap_observed
    );
        overlap_observed = 1'b0;

        for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
            @(posedge ctrl_vif.clk);
            #1step;

            if ((serial_vif.tx_out === 1'b0) &&
                (serial_vif.rx_in  === 1'b0)) begin
                overlap_observed = 1'b1;
                `UART_DISPLAY((
                    "[AXI UART MONITOR] Observed overlapping TX/RX serial activity"
                ))
                return;
            end
        end
    endtask

endclass
