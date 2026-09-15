// Small ownership container used by higher-level environments. AXI-Lite tests
// can operate through their bus agent while this object independently models
// the UART peer connected to rx_in and tx_out.
class uart_serial_agent;
    virtual uart_tb_ctrl_if.monitor ctrl_vif;
    virtual uart_serial_if          vif;

    uart_serial_driver     driver;
    uart_serial_monitor    monitor;
    uart_serial_scoreboard scoreboard;

    function new(
        virtual uart_tb_ctrl_if ctrl_vif_arg,
        virtual uart_serial_if  vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.vif      = vif_arg;

        this.driver     = new(ctrl_vif_arg, vif_arg);
        this.monitor    = new(ctrl_vif_arg, vif_arg);
        this.scoreboard = new();
    endfunction

    task automatic initialize();
        driver.drive_idle();
    endtask

endclass
