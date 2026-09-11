`include "rtl/uart_config.svh"

class uart_reset_driver;
    virtual uart_tb_ctrl_if vif;

    function new(virtual uart_tb_ctrl_if vif_arg);
        this.vif = vif_arg;
    endfunction

    // Reset assertion may occur at any point in a test. Because the UART uses
    // synchronous reset, the RTL observes this value on the next rising edge.
    task automatic assert_reset();
        vif.rst_n = 1'b0;

        `UART_DISPLAY(("[RESET DRIVER] asserted reset"))
    endtask

    // Release reset away from the DUT's active rising edge to avoid a race
    // between testbench stimulus and sequential RTL.
    task automatic deassert_reset();
        @(negedge vif.clk);
        vif.rst_n = 1'b1;

        `UART_DISPLAY(("[RESET DRIVER] released reset"))
    endtask

    task automatic apply_reset(input int unsigned cycles = 3);
        assert_reset();

        repeat (cycles)
            @(posedge vif.clk);

        deassert_reset();
    endtask
endclass
