// Composition container for the reusable AXI-Lite verification components.
// The agent models one AXI-Lite master and keeps protocol mechanics out of
// higher-level UART tests.
class axi_lite_agent;
    virtual uart_tb_ctrl_if ctrl_vif;
    virtual axi_lite_if     vif;

    axi_lite_driver     driver;
    axi_lite_monitor    monitor;
    axi_lite_scoreboard scoreboard;

    function new(
        virtual uart_tb_ctrl_if ctrl_vif_arg,
        virtual axi_lite_if     vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif      = vif_arg;

        this.driver     = new(ctrl_vif_arg, vif_arg);
        this.monitor    = new(ctrl_vif_arg, vif_arg);
        this.scoreboard = new();
    endfunction

    task automatic initialize();
        driver.initialize_inputs();
    endtask

endclass
