// Shared environment for AXI protocol tests and complete peripheral tests.
// It composes independent agents instead of making unrelated drivers inherit
// from one another.
class uart_axi_env;
    virtual uart_tb_ctrl_if ctrl_vif;
    virtual axi_lite_if     axi_vif;
    virtual uart_serial_if  serial_vif;
    virtual uart_irq_if     irq_vif;

    uart_reset_driver reset_driver;
    axi_lite_agent    axi_agent;
    uart_serial_agent serial_agent;
    uart_axi_monitor  monitor;
    uart_axi_scoreboard scoreboard;

    function new(
        virtual uart_tb_ctrl_if ctrl_vif_arg,
        virtual axi_lite_if     axi_vif_arg,
        virtual uart_serial_if  serial_vif_arg,
        virtual uart_irq_if     irq_vif_arg
    );
        this.ctrl_vif   = ctrl_vif_arg;
        this.axi_vif    = axi_vif_arg;
        this.serial_vif = serial_vif_arg;
        this.irq_vif    = irq_vif_arg;

        this.reset_driver = new(ctrl_vif_arg);
        this.axi_agent    = new(ctrl_vif_arg, axi_vif_arg);
        this.serial_agent = new(ctrl_vif_arg, serial_vif_arg);
        this.monitor      = new(ctrl_vif_arg, serial_vif_arg, irq_vif_arg);
        this.scoreboard   = new();
    endfunction

    task automatic initialize_inputs();
        // Establish known values before the first active clock edge.
        reset_driver.assert_reset();
        axi_agent.initialize();
        serial_agent.initialize();
    endtask

    task automatic apply_reset(input int unsigned cycles = 3);
        reset_driver.apply_reset(cycles);
        @(posedge ctrl_vif.clk);
        #1step;
    endtask

endclass
