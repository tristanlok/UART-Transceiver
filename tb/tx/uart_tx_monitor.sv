class uart_tx_monitor;

    virtual uart_tx_if vif;

    function new(virtual uart_tx_if vif_arg);
        this.vif = vif_arg;
    endfunction

    task automatic receive_byte(
        output logic [7:0] data
    );
        // The falling edge marks the beginning of the UART start bit.
        @(negedge vif.tx);

        if (vif.tx !== 1'b0)
            $error("Invalid start bit");

        // baud_tick is a registered clock-enable pulse. Its falling edge
        // occurs when the transmitter consumes the pulse and advances to the
        // next UART bit. Wait one simulation step for outputs to settle.
        for (int i = 0; i < 8; i++) begin
            @(negedge vif.baud_tick);
            #1step;
            data[i] = vif.tx;
        end

        @(negedge vif.baud_tick);
        #1step;

        if (vif.tx !== 1'b1)
            $error("Invalid stop bit");
    endtask

endclass
