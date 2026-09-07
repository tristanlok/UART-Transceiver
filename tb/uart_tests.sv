class uart_tests;
    uart_env env;

    function new(uart_env env_arg);
        this.env = env_arg;
    endfunction

    task automatic uart_tx_sanity();
        logic [`DATA_BITS-1:0] patterns [0:7] = '{
            '0,
            '1,
            `DATA_BITS'(8'h55),
            `DATA_BITS'(8'hAA),
            `DATA_BITS'(8'h01),
            `DATA_BITS'(8'h80),
            `DATA_BITS'(8'hA5),
            `DATA_BITS'(8'h5A)
        };

        $display(
            "[%0t] [TEST] Starting UART transmit sanity test with %0d patterns",
            $time,
            $size(patterns)
        );

        $display("[%0t] Asserting Reset on DUT", $time);
        env.tx_driver.drive_idle();
        env.reset_driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge env.ctrl_vif.clk);
        env.tx_scoreboard.check_reset_state(
            env.ctrl_vif.rst_n,
            env.tx_vif.tx_out,
            env.tx_vif.tx_ready,
            env.ctrl_vif.baud_tick
        );
        env.reset_driver.deassert_reset();
        $display("[%0t] Reset Deasserted on DUT", $time);

        foreach (patterns[i]) begin
            logic [`DATA_BITS-1:0] actual;

            $display(
                "[%0t] [TEST] Pattern %0d/%0d: data=0x%02h",
                $time,
                i + 1,
                $size(patterns),
                patterns[i]
            );

            fork
                env.tx_driver.send_byte_and_wait(patterns[i], $urandom_range(200, 0));

                begin
                    $display(
                        "[%0t] Monitor waiting for pattern %0d (0x%02h)",
                        $time,
                        i + 1,
                        patterns[i]
                    );
                    env.tx_monitor.check_start_bit();
                    env.tx_monitor.receive_byte(actual);
                    env.tx_monitor.check_stop_bit();
                    env.tx_scoreboard.check_data(patterns[i], actual);
                end
            join

            $display(
                "[%0t] [TEST] Pattern %0d/%0d complete",
                $time,
                i + 1,
                $size(patterns)
            );
        end

        $display(
            "[%0t] [PASS] UART transmit sanity test completed all %0d patterns",
            $time,
            $size(patterns)
        );
    endtask

    task automatic uart_rx_sanity();
        logic [`DATA_BITS-1:0] patterns [0:7] = '{
            '0,
            '1,
            `DATA_BITS'(8'h55),
            `DATA_BITS'(8'hAA),
            `DATA_BITS'(8'h01),
            `DATA_BITS'(8'h80),
            `DATA_BITS'(8'hA5),
            `DATA_BITS'(8'h5A)
        };

        $display(
            "[%0t] [TEST] Starting UART recieve sanity test with %0d patterns",
            $time,
            $size(patterns)
        );

        $display("[%0t] Asserting Reset on DUT", $time);
        env.rx_driver.drive_idle();
        env.reset_driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge env.ctrl_vif.clk);
        env.rx_scoreboard.check_reset_state(
            env.ctrl_vif.rst_n,
            env.rx_vif.rx_data,
            env.rx_vif.rx_valid,
            env.rx_vif.rx_busy,
            env.rx_vif.framing_error);
        env.reset_driver.deassert_reset();
        $display("[%0t] Reset Deasserted on DUT", $time);

        foreach (patterns[i]) begin
            logic [`DATA_BITS-1:0] actual;
            logic                  framing_error;

            $display(
                "[%0t] [TEST] Pattern %0d/%0d: data=0x%02h",
                $time,
                i + 1,
                $size(patterns),
                patterns[i]
            );

            fork
                env.rx_driver.send_frame(patterns[i]);

                begin
                    $display(
                        "[%0t] Monitor waiting for pattern %0d (0x%02h)",
                        $time,
                        i + 1,
                        patterns[i]
                    );
                    env.rx_monitor.receive_frame(actual, framing_error);
                end
            join

            env.rx_scoreboard.check_data(patterns[i], actual);
            env.rx_scoreboard.check_framing_error(1'b0, framing_error);

            $display(
                "[%0t] [TEST] Pattern %0d/%0d complete",
                $time,
                i + 1,
                $size(patterns)
            );
        end

        $display(
            "[%0t] [PASS] UART recieve sanity test completed all %0d patterns",
            $time,
            $size(patterns)
        );
    endtask
endclass
