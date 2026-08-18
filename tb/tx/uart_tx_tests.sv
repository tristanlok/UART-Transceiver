class uart_tx_tests;
    uart_tx_driver     driver;
    uart_tx_monitor    monitor;
    uart_tx_scoreboard scoreboard;

    function new(
        uart_tx_driver driver_arg,
        uart_tx_monitor monitor_arg,
        uart_tx_scoreboard scoreboard_arg
    );
        this.driver     = driver_arg;
        this.monitor    = monitor_arg;
        this.scoreboard = scoreboard_arg;
    endfunction

    task automatic test_basic();
        logic [7:0] actual;
        fork
            driver.send_byte(8'hA5);

            begin
                monitor.receive_byte(actual);
                scoreboard.check_byte(8'hA5, actual);
            end
        join
    endtask

    task automatic test_patterns();
        logic [7:0] patterns [0:7] = '{
            8'h00,
            8'hFF,
            8'h55,
            8'hAA,
            8'h01,
            8'h80,
            8'hA5,
            8'h5A
        };
        logic [7:0] actual;

        foreach (patterns[i]) begin
            fork
                driver.send_byte(patterns[i]);

                begin
                    monitor.receive_byte(actual);
                    scoreboard.check_byte(
                        patterns[i],
                        actual
                    );
                end
            join
        end
    endtask
endclass
