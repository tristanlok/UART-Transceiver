`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_reg_monitor;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_reg_if.monitor     vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_reg_if.monitor     vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif = vif_arg;
    endfunction

    function automatic void sample_tx_request(
        output logic                  start,
        output logic [`DATA_BITS-1:0] data
    );
        start = vif.uart_tx_start;
        data = vif.uart_tx_data;

        `UART_DISPLAY((
            "[REG MONITOR] sampled TX request: start=%0b data=0x%0h",
            start,
            data
        ))
    endfunction

    function automatic logic sample_irq();
        `UART_DISPLAY(("[REG MONITOR] sampled irq=%0b", vif.irq))
        return vif.irq;
    endfunction

    task automatic wait_for_irq(
        input  logic        expected,
        input  int unsigned timeout_cycles,
        output logic        observed
    );
        observed = 1'b0;

        repeat (timeout_cycles) begin
            @(posedge ctrl_vif.clk);
            #1step;

            if (vif.irq === expected) begin
                observed = 1'b1;
                return;
            end
        end
    endtask

endclass
