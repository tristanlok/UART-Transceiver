`include "rtl/uart_config.svh"

class uart_rx_tests;
    virtual uart_rx_if  vif;
    uart_reset_driver  reset_driver;
    uart_rx_driver     driver;
    uart_rx_monitor    monitor;
    uart_rx_scoreboard scoreboard;

    function new(
        virtual uart_rx_if vif_arg,
        uart_reset_driver reset_driver_arg,
        uart_rx_driver driver_arg,
        uart_rx_monitor monitor_arg,
        uart_rx_scoreboard scoreboard_arg
    );
        this.vif        = vif_arg;
        this.reset_driver = reset_driver_arg;
        this.driver     = driver_arg;
        this.monitor    = monitor_arg;
        this.scoreboard = scoreboard_arg;
    endfunction

    // Independent reference model for the DUT's three-input majority voter.
    function automatic logic reference_majority(input logic [2:0] samples);
        return (samples[0] & samples[1]) |
               (samples[0] & samples[2]) |
               (samples[1] & samples[2]);
    endfunction

    // The test selects the reset timing, uart_reset_driver owns rst_n, and the
    // RX driver only restores its protocol input to the UART idle level.
    task automatic reset_and_check(input string state_name);
        $display(
            "[%0t] [TEST] Asserting reset while receiver is in %s",
            $time,
            state_name
        );

        driver.drive_idle();
        reset_driver.assert_reset();
        repeat (3)
            @(posedge vif.clk);
        #1step;

        scoreboard.check_reset_state(
            vif.rst_n,
            vif.rx_data,
            vif.rx_valid,
            vif.rx_busy,
            vif.framing_error
        );

        reset_driver.deassert_reset();
        driver.drive_idle_ticks(2);
    endtask

    // A valid byte after each reset proves that the receiver returned to IDLE
    // and can start a completely new frame.
    task automatic check_post_reset_recovery(
        input logic [`DATA_BITS-1:0] recovery_data,
        input string                 state_name
    );
        logic [`DATA_BITS-1:0] actual_data;
        logic                  framing_error;

        $display(
            "[%0t] [TEST] Checking recovery after reset in %s with data=0x%0h",
            $time,
            state_name,
            recovery_data
        );

        fork
            driver.send_frame(recovery_data);
            monitor.receive_frame(actual_data, framing_error);
        join

        scoreboard.check_data(recovery_data, actual_data);
        scoreboard.check_framing_error(1'b0, framing_error);
        scoreboard.check_busy_state(1'b0, vif.rx_busy, "post-reset recovery");
    endtask

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
        driver.drive_idle();
        reset_driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(vif.rst_n, vif.rx_data, vif.rx_valid, vif.rx_busy, vif.framing_error);
        reset_driver.deassert_reset();
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
                end
            join

            scoreboard.check_data(patterns[i], actual);
            scoreboard.check_framing_error(1'b0, framing_error);

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

    task automatic rx_false_start();
        bit busy_asserted;
        bit busy_deasserted;

        $display(
            "[%0t] [TEST] Starting UART receive false-start test",
            $time
        );

        $display("[%0t] Asserting Reset on DUT", $time);
        driver.drive_idle();
        reset_driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(vif.rst_n, vif.rx_data, vif.rx_valid, vif.rx_busy, vif.framing_error);
        reset_driver.deassert_reset();
        $display("[%0t] Reset Deasserted on DUT", $time);

        $display("[%0t] Delaying before beginning test", $time);
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);

        fork
            driver.drive_low_pulse(
                $urandom_range(
                    (`OVERSAMPLE / 2 - 1),
                    (`OVERSAMPLE / 2 - 2)
            ));

            begin
                monitor.wait_for_busy_state(1'b1, 2, busy_asserted);

                if (busy_asserted) begin
                    monitor.wait_for_busy_state(1'b0, `OVERSAMPLE + 2, busy_deasserted);
                end
            end
        join

        scoreboard.check_false_start_busy(busy_asserted, busy_deasserted);

        $display(
            "[%0t] [PASS] UART recieve false start test completed",
            $time
        );
    endtask

    task automatic rx_data_majority_vote();
        logic [2:0] vote_patterns [0:7] = '{
            3'b000,
            3'b001,
            3'b010,
            3'b011,
            3'b100,
            3'b101,
            3'b110,
            3'b111
        };
        logic [`DATA_BITS-1:0] nominal_data;
        logic [`DATA_BITS-1:0] expected_data;
        logic [`DATA_BITS-1:0] actual_data;
        logic                  framing_error;

        $display(
            "[%0t] [TEST] Starting RX data majority-vote test: %0d bits x %0d patterns",
            $time,
            `DATA_BITS,
            $size(vote_patterns)
        );

        driver.drive_idle();
        reset_driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(
            vif.rst_n,
            vif.rx_data,
            vif.rx_valid,
            vif.rx_busy,
            vif.framing_error
        );
        reset_driver.deassert_reset();

        for (int target_bit = 0; target_bit < `DATA_BITS; target_bit++) begin
            foreach (vote_patterns[pattern_index]) begin
                // Keep the normal value of the selected bit low. Only the
                // three injected samples determine its expected result.
                nominal_data = `DATA_BITS'(8'hA5);
                nominal_data[target_bit] = 1'b0;

                expected_data = nominal_data;
                expected_data[target_bit] =
                    reference_majority(vote_patterns[pattern_index]);
                actual_data  = '0;
                framing_error = 1'b0;

                $display(
                    "[%0t] [TEST] Majority target_bit=%0d samples=%03b expected_bit=%0b",
                    $time,
                    target_bit,
                    vote_patterns[pattern_index],
                    expected_data[target_bit]
                );

                fork
                    driver.send_frame_with_data_vote(
                        nominal_data,
                        target_bit,
                        vote_patterns[pattern_index]
                    );

                    monitor.receive_frame(actual_data, framing_error);
                join

                scoreboard.check_data(expected_data, actual_data);
                scoreboard.check_framing_error(1'b0, framing_error);
            end
        end

        $display(
            "[%0t] [PASS] RX data majority-vote test completed",
            $time
        );
    endtask

    task automatic rx_reset_every_state();
        logic [`DATA_BITS-1:0] stimulus_data;
        bit                    busy_observed;

        stimulus_data = `DATA_BITS'(8'hA5);

        $display(
            "[%0t] [TEST] Starting reset-in-every-RX-state test",
            $time
        );

        // Establish a known state before deliberately resetting in RX_IDLE.
        reset_and_check("initialization");
        scoreboard.check_busy_state(1'b0, vif.rx_busy, "RX_IDLE before reset");
        reset_and_check("RX_IDLE");
        check_post_reset_recovery(`DATA_BITS'(8'h11), "RX_IDLE");

        // Hold a legal start bit low, wait until the DUT becomes busy, and
        // interrupt it well before the start-bit sampling window completes.
        busy_observed = 1'b0;
        fork : drive_start_state
            driver.send_start_bit();

            begin
                monitor.wait_for_busy_state(1'b1, 2, busy_observed);
                if (busy_observed)
                    driver.wait_ref_ticks(`OVERSAMPLE / 4);
            end
        join_any
        disable drive_start_state;

        scoreboard.check_busy_state(1'b1, vif.rx_busy, "RX_START before reset");
        reset_and_check("RX_START");
        check_post_reset_recovery(`DATA_BITS'(8'h22), "RX_START");

        // Complete the start bit, begin the first data bit, and reset halfway
        // through that bit while the receiver is in RX_DATA.
        driver.send_start_bit();
        fork : drive_data_state
            driver.send_data_byte(stimulus_data);
            driver.wait_ref_ticks(`OVERSAMPLE / 2);
        join_any
        disable drive_data_state;

        scoreboard.check_busy_state(1'b1, vif.rx_busy, "RX_DATA before reset");
        reset_and_check("RX_DATA");
        check_post_reset_recovery(`DATA_BITS'(8'h44), "RX_DATA");

        // Complete start and data, then reset halfway through the stop bit.
        driver.send_start_bit();
        driver.send_data_byte(stimulus_data);
        fork : drive_stop_state
            driver.send_stop_bit();
            driver.wait_ref_ticks(`OVERSAMPLE / 2);
        join_any
        disable drive_stop_state;

        scoreboard.check_busy_state(1'b1, vif.rx_busy, "RX_STOP before reset");
        reset_and_check("RX_STOP");
        check_post_reset_recovery(`DATA_BITS'(8'h88), "RX_STOP");

        $display(
            "[%0t] [PASS] Reset-in-every-RX-state test completed",
            $time
        );
    endtask
endclass
