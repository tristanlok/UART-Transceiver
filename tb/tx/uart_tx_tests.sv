`include "rtl/uart_config.svh"

class uart_tx_tests;
    virtual uart_tx_if  vif;
    uart_tx_driver     driver;
    uart_tx_monitor    monitor;
    uart_tx_scoreboard scoreboard;

    function new(
        virtual uart_tx_if vif_arg,
        uart_tx_driver driver_arg,
        uart_tx_monitor monitor_arg,
        uart_tx_scoreboard scoreboard_arg
    );
        this.vif        = vif_arg;
        this.driver     = driver_arg;
        this.monitor    = monitor_arg;
        this.scoreboard = scoreboard_arg;
    endfunction

    task automatic tx_send_data_sanity();
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
        driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(
            vif.rst_n,
            vif.tx,
            vif.tx_ready,
            vif.baud_tick
        );
        driver.deassert_reset();
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
                driver.send_byte_and_wait(patterns[i], $urandom_range(200, 0));

                begin
                    $display(
                        "[%0t] Monitor waiting for pattern %0d (0x%02h)",
                        $time,
                        i + 1,
                        patterns[i]
                    );
                    monitor.check_start_bit();
                    monitor.receive_byte(actual);
                    monitor.check_stop_bit();
                    scoreboard.check_byte(patterns[i], actual);
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

    task automatic tx_send_data_and_assert_reset();
        logic [`DATA_BITS-1:0] random_data = `DATA_BITS'($urandom);
        int unsigned reset_after_bits = $urandom_range(`DATA_BITS - 1, 1);
        bit unexpected_start = 1'b0;
        
        $display(
            "[%0t] [TEST] Starting reset-during-transmission test: data=0x%02h, reset after=%0d baud periods",
            $time,
            random_data,
            reset_after_bits
        );

        $display("[%0t] Asserting Reset on DUT", $time);
        driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(
            vif.rst_n,
            vif.tx,
            vif.tx_ready,
            vif.baud_tick
        );
        driver.deassert_reset();
        $display("[%0t] Reset Deasserted on DUT", $time);

        fork
            begin : send_transaction
                driver.send_byte_and_wait(random_data, $urandom_range(200, 0));
            end

            begin : apply_mid_frame_reset
                $display("[%0t] Waiting for the UART start bit", $time);
                @(negedge vif.tx);

                $display(
                    "[%0t] Frame started; waiting %0d baud periods before reset",
                    $time,
                    reset_after_bits
                );
                driver.wait_clock_cycles(vif.baud_tick, reset_after_bits);

                $display("[%0t] Asserting reset during transmission", $time);
                driver.assert_reset();
                repeat ($urandom_range(50, 5))
                    @(posedge vif.clk);
                driver.deassert_reset();
                $display("[%0t] Reset released", $time);
            end

            begin : check_asserted_reset
                $display("[%0t] Waiting to observe reset assertion", $time);
                @(negedge vif.rst_n);

                $display(
                    "[%0t] Reset observed; checking the DUT for three clock cycles",
                    $time
                );

                // Reset is synchronous, so check after active clock edges.
                repeat (3) begin
                    @(posedge vif.clk);
                    #1step;
                    scoreboard.check_reset_state(
                        vif.rst_n,
                        vif.tx,
                        vif.tx_ready,
                        vif.baud_tick
                    );
                end
            end
        join

        $display(
            "[%0t] Watching for two baud periods to ensure the frame does not resume",
            $time
        );

        fork : post_reset_check
            begin
                @(negedge vif.tx);
                unexpected_start = 1'b1;
                $display(
                    "[%0t] Detected an unexpected start bit after reset",
                    $time
                );
            end

            begin
                repeat (2)
                    @(posedge vif.baud_tick);
            end
        join_any
        disable post_reset_check;

        if (unexpected_start) begin
            $error("[%0t] [FAIL] Interrupted frame resumed after reset", $time);
        end else begin
            scoreboard.check_idle_state(vif.tx, vif.tx_ready);
            $display(
                "[%0t] [PASS] Reset-during-transmission test completed",
                $time
            );
        end
    endtask

    task automatic tx_hold_request_data_stability();
        logic [`DATA_BITS-1:0] original_data = `DATA_BITS'(8'hA5);
        logic [`DATA_BITS-1:0] changed_data  = `DATA_BITS'(8'h3C);
        logic [`DATA_BITS-1:0] actual;
        bit         extra_frame_seen = 1'b0;

        $display(
            "[%0t] [TEST] Starting held-request test: accepted data must remain 0x%02h after tx_data changes to 0x%02h",
            $time,
            original_data,
            changed_data
        );

        $display("[%0t] Asserting Reset on DUT", $time);
        driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(
            vif.rst_n,
            vif.tx,
            vif.tx_ready,
            vif.baud_tick
        );
        driver.deassert_reset();
        $display("[%0t] Reset Deasserted on DUT", $time);

        fork
            begin : stimulus
                $display("[%0t] Waiting for DUT to become ready", $time);
                driver.wait_until_ready();

                $display(
                    "[%0t] DUT is ready",
                    $time
                );
                driver.wait_clock_cycles(vif.clk, $urandom_range(200, 0));

                $display(
                    "[%0t] Asserting tx_start with tx_data=0x%02h",
                    $time,
                    original_data
                );
                driver.assert_request(original_data);
                driver.wait_for_acceptance();

                $display(
                    "[%0t] Request accepted with data=0x%02h",
                    $time,
                    original_data
                );

                driver.set_data(changed_data);

                $display(
                    "[%0t] Changed tx_data to 0x%02h after acceptance",
                    $time,
                    changed_data
                );

                // Keep the request asserted until the frame is complete.
                $display(
                    "[%0t] Holding tx_start active while the accepted frame transmits",
                    $time
                );
                driver.wait_until_ready();

                $display(
                    "[%0t] Frame complete; releasing tx_start",
                    $time
                );
                driver.release_request();
            end

            begin : check_uart_frame
                $display(
                    "[%0t] Monitor waiting for one UART frame carrying 0x%02h",
                    $time,
                    original_data
                );
                monitor.check_start_bit();
                monitor.receive_byte(actual);
                monitor.check_stop_bit();
                scoreboard.check_byte(original_data, actual);
            end
        join

        // Watch long enough to catch an unintended second frame.
        $display(
            "[%0t] First frame complete; checking that no second frame starts",
            $time
        );
        fork : no_extra_frame_check
            begin
                @(negedge vif.tx);
                extra_frame_seen = 1'b1;
                $display("[%0t] Detected an unexpected second start bit", $time);
            end

            begin
                repeat (2)
                    @(negedge vif.baud_tick);
            end
        join_any
        disable no_extra_frame_check;

        if (extra_frame_seen) begin
            $error("[%0t] Unexpected additional UART frame", $time);
        end else begin
            $display("[%0t] [PASS] Exactly one UART frame observed", $time);
            $display("[%0t] [PASS] Held-request test completed", $time);
        end
    endtask
endclass
