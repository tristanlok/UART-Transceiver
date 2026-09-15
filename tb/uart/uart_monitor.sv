`include "uart_config.svh"
`include "uart_tb_log.svh"

class uart_monitor;

    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_tx_if.monitor      tx_vif;
    virtual uart_rx_if.monitor      rx_vif;

    function new(
        virtual uart_tb_ctrl_if.monitor ctrl_vif_arg,
        virtual uart_tx_if.monitor      tx_vif_arg,
        virtual uart_rx_if.monitor      rx_vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.tx_vif   = tx_vif_arg;
        this.rx_vif   = rx_vif_arg;
    endfunction

    task automatic wait_for_duplex_overlap(
        input   int     timeout,
        output  logic   overlap_observed
    );
        int baud_tick_seen = 0;

        `UART_DISPLAY((
            "[UART MONITOR] Observing for Duplex Overlap"
        ))

        while (baud_tick_seen < timeout) begin
            @(posedge ctrl_vif.clk);
            #1step;

            if (tx_vif.tx_ready === 1'b0 &&
                rx_vif.rx_busy  === 1'b1
            ) begin
                overlap_observed = 1'b1;
                `UART_DISPLAY((
                    "[UART MONITOR] Observed Duplex Overlap"
                ))
                return;
            end

            if (ctrl_vif.baud_tick === 1'b1) begin
                baud_tick_seen++;
            end
        end
    endtask
                

endclass
