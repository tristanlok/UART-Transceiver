// Integrated-test container. It reuses the existing TX and RX test libraries
// with the components already constructed by uart_env.
class uart_tests;
    uart_env      env;
    uart_tx_tests tx_tests;
    uart_rx_tests rx_tests;

    function new(uart_env env_arg);
        this.env = env_arg;

        this.tx_tests = new(
            env.tx_vif,
            env.reset_driver,
            env.tx_driver,
            env.tx_monitor,
            env.tx_scoreboard
        );

        this.rx_tests = new(
            env.rx_vif,
            env.reset_driver,
            env.rx_driver,
            env.rx_monitor,
            env.rx_scoreboard
        );
    endfunction
endclass
