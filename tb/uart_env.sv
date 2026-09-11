// Reusable container for all verification components surrounding the
// integrated UART. The environment builds and owns the equipment; individual
// tests decide which scenarios that equipment performs.
class uart_env;
    virtual uart_tb_ctrl_if ctrl_vif;
    virtual uart_tx_if      tx_vif;
    virtual uart_rx_if      rx_vif;

    uart_reset_driver   reset_driver;
    uart_monitor        uart_dup_monitor;
    uart_scoreboard     uart_dup_scoreboard;

    uart_tx_driver      tx_driver;
    uart_tx_monitor     tx_monitor;
    uart_tx_scoreboard  tx_scoreboard;

    uart_rx_driver      rx_driver;
    uart_rx_monitor     rx_monitor;
    uart_rx_scoreboard  rx_scoreboard;

    function new(
        virtual uart_tb_ctrl_if ctrl_vif_arg,
        virtual uart_tx_if      tx_vif_arg,
        virtual uart_rx_if      rx_vif_arg
    );
        this.ctrl_vif = ctrl_vif_arg;
        this.tx_vif   = tx_vif_arg;
        this.rx_vif   = rx_vif_arg;

        this.reset_driver        = new(ctrl_vif_arg);
        this.uart_dup_monitor    = new(ctrl_vif_arg, tx_vif_arg, rx_vif_arg);
        this.uart_dup_scoreboard = new();

        this.tx_driver     = new(tx_vif_arg);
        this.tx_monitor    = new(tx_vif_arg);
        this.tx_scoreboard = new();

        this.rx_driver     = new(rx_vif_arg);
        this.rx_monitor    = new(rx_vif_arg);
        this.rx_scoreboard = new();
    endfunction

    // Establish legal inactive values before a test asserts reset or begins
    // stimulus. Each protocol driver remains responsible for only its inputs.
    task automatic initialize_inputs();
        tx_driver.drive_idle();
        rx_driver.drive_idle();
    endtask
endclass
