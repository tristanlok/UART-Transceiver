`include "rtl/uart_config.svh"

class uart_rx_tests;
    virtual uart_rx_if  vif;
    uart_rx_driver     driver;
    uart_rx_monitor    monitor;
    uart_rx_scoreboard scoreboard;

    function new(
        virtual uart_rx_if vif_arg,
        uart_rx_driver driver_arg,
        uart_rx_monitor monitor_arg,
        uart_rx_scoreboard scoreboard_arg
    );
        this.vif        = vif_arg;
        this.driver     = driver_arg;
        this.monitor    = monitor_arg;
        this.scoreboard = scoreboard_arg;
    endfunction

    task automatic rx_read_data_sanity();
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
        driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(vif.rst_n, vif.data_out, vif.rx_valid, vif.rx_busy, vif.framing_error);
        driver.deassert_reset();
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
                driver.send_frame(patterns[i]);

                begin
                    $display(
                        "[%0t] Monitor waiting for pattern %0d (0x%02h)",
                        $time,
                        i + 1,
                        patterns[i]
                    );
                    monitor.receive_frame(actual, framing_error);
                    scoreboard.check_data(patterns[i], actual);
                    scoreboard.check_framing_error(1'b0, framing_error);
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
            "[%0t] [PASS] UART recieve sanity test completed all %0d patterns",
            $time,
            $size(patterns)
        );
    endtask

endclass
