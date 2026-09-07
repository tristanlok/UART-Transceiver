`include "rtl/uart_config.svh"

class uart_tx_tests;
    virtual uart_tx_if  vif;
    uart_reset_driver   reset_driver;
    uart_tx_driver      driver;
    uart_tx_monitor     monitor;
    uart_tx_scoreboard  scoreboard;

    function new(
        virtual uart_tx_if vif_arg,
        uart_reset_driver reset_driver_arg,
        uart_tx_driver driver_arg,
        uart_tx_monitor monitor_arg,
        uart_tx_scoreboard scoreboard_arg
    );
        this.vif          = vif_arg;
        this.reset_driver = reset_driver_arg;
        this.driver       = driver_arg;
        this.monitor      = monitor_arg;
        this.scoreboard   = scoreboard_arg;
    endfunction

    // Reset ownership remains separate from the TX protocol driver. The test
    // chooses when reset occurs, while this helper centralizes reset checking.
    task automatic reset_and_check(
        input string       state_name,
        input int unsigned reset_cycles = 3
    );
        $display(
            "[%0t] [TEST] Asserting reset while transmitter is in %s",
            $time,
            state_name
        );

        driver.drive_idle();
        reset_driver.assert_reset();

        repeat (reset_cycles)
            @(posedge vif.clk);
        #1step;

        scoreboard.check_reset_state(
            vif.rst_n,
            vif.tx_out,
            vif.tx_ready,
            vif.baud_tick
        );

        reset_driver.deassert_reset();

        // Give the DUT two system-clock edges in its reset-released idle state.
        driver.wait_clock_cycles(2);
    endtask

    // Drive one request, reconstruct the complete serial frame, and perform
    // all start/data/stop checks in one reusable transaction-level helper.
    task automatic send_and_check(
        input logic [`DATA_BITS-1:0] data,
        input int unsigned           delay_cycles = 0
    );
        logic [`DATA_BITS-1:0] actual_data;
        logic                  actual_start_bit;
        logic                  actual_stop_bit;
        bit                    ready_observed;

        actual_data      = '0;
        actual_start_bit = 1'b1;
        actual_stop_bit  = 1'b0;
        ready_observed   = 1'b0;

        fork
            driver.send_byte(data, delay_cycles);
            monitor.receive_frame(
                actual_data,
                actual_start_bit,
                actual_stop_bit
            );
        join

        scoreboard.check_frame(
            data,
            actual_data,
            actual_start_bit,
            actual_stop_bit
        );

        // The monitor uses an independent reference clock, so it may finish
        // the stop-bit window just before the DUT consumes its final tick.
        monitor.wait_for_ready_state(
            1'b1,
            `OVERSAMPLE + 2,
            ready_observed
        );
        scoreboard.check_ready_state(
            1'b1,
            ready_observed,
            "bounded wait after completed frame"
        );
    endtask

    // A valid frame after reset proves that the transmitter returned to IDLE
    // and can accept a completely new request.
    task automatic check_post_reset_recovery(
        input logic [`DATA_BITS-1:0] recovery_data,
        input string                 state_name
    );
        $display(
            "[%0t] [TEST] Checking recovery after reset in %s with data=0x%0h",
            $time,
            state_name,
            recovery_data
        );

        send_and_check(recovery_data);
    endtask

    // Watch the idle serial line long enough to detect an unintended frame.
    task automatic check_no_unexpected_frame(
        input int unsigned reference_tick_count
    );
        bit extra_frame_seen;

        extra_frame_seen = 1'b0;

        fork : no_extra_frame_check
            begin
                @(negedge vif.tx_out);
                extra_frame_seen = 1'b1;
            end

            monitor.wait_ref_ticks(reference_tick_count);
        join_any
        disable no_extra_frame_check;

        scoreboard.check_no_extra_frame(extra_frame_seen);
    endtask

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

        reset_and_check(
            "initialization",
            $urandom_range(200, 5)
        );

        foreach (patterns[i]) begin
            $display(
                "[%0t] [TEST] Pattern %0d/%0d: data=0x%02h",
                $time,
                i + 1,
                $size(patterns),
                patterns[i]
            );

            send_and_check(patterns[i], $urandom_range(200, 0));

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
        logic [`DATA_BITS-1:0] random_data;
        int unsigned           reset_after_ticks;

        random_data = `DATA_BITS'($urandom);
        reset_after_ticks = $urandom_range(
            (`OVERSAMPLE * `DATA_BITS),
            1
        );

        $display(
            "[%0t] [TEST] Starting reset-during-transmission test: data=0x%02h reset_after_ticks=%0d",
            $time,
            random_data,
            reset_after_ticks
        );

        reset_and_check(
            "initialization",
            $urandom_range(200, 5)
        );

        driver.send_byte(random_data, $urandom_range(200, 0));

        // The serial falling edge marks entry into TX_START. Counting DUT baud
        // ticks from here targets either TX_START or TX_DATA deterministically.
        @(negedge vif.tx_out);
        driver.wait_baud_ticks(reset_after_ticks);
        scoreboard.check_ready_state(
            1'b0,
            vif.tx_ready,
            "active frame before reset"
        );

        reset_and_check(
            "active transmission",
            $urandom_range(50, 5)
        );

        // Reset must abort the interrupted frame rather than resume it.
        check_no_unexpected_frame(2 * `OVERSAMPLE);
        check_post_reset_recovery(`DATA_BITS'(8'hA5), "active transmission");

        $display(
            "[%0t] [PASS] Reset-during-transmission test completed",
            $time
        );
    endtask

    task automatic tx_hold_request_data_stability();
        logic [`DATA_BITS-1:0] original_data;
        logic [`DATA_BITS-1:0] changed_data;
        logic [`DATA_BITS-1:0] actual_data;
        logic                  actual_start_bit;
        logic                  actual_stop_bit;

        original_data    = `DATA_BITS'(8'hA5);
        changed_data     = `DATA_BITS'(8'h3C);
        actual_data      = '0;
        actual_start_bit = 1'b1;
        actual_stop_bit  = 1'b0;

        $display(
            "[%0t] [TEST] Starting held-request test: accepted=0x%02h changed=0x%02h",
            $time,
            original_data,
            changed_data
        );

        reset_and_check(
            "initialization",
            $urandom_range(200, 5)
        );

        fork
            begin : stimulus
                driver.wait_until_ready();
                driver.wait_clock_cycles($urandom_range(200, 0));
                driver.assert_request(original_data);
                driver.wait_for_acceptance();

                // Change the live input after acceptance. The serialized frame
                // must still contain the byte captured with the request.
                driver.set_data(changed_data);
                driver.wait_until_ready();
                driver.release_request();
            end

            monitor.receive_frame(
                actual_data,
                actual_start_bit,
                actual_stop_bit
            );
        join

        scoreboard.check_frame(
            original_data,
            actual_data,
            actual_start_bit,
            actual_stop_bit
        );

        // Holding tx_start through the active frame must not create a second
        // transaction after the driver releases it at the next safe edge.
        check_no_unexpected_frame(2 * `OVERSAMPLE);

        $display(
            "[%0t] [PASS] Held-request data-stability test completed",
            $time
        );
    endtask

    task automatic tx_reset_every_state();
        logic [`DATA_BITS-1:0] stimulus_data;

        stimulus_data = `DATA_BITS'(8'hA5);

        $display(
            "[%0t] [TEST] Starting reset-in-every-TX-state test",
            $time
        );

        // Establish a known state, then explicitly exercise reset in TX_IDLE.
        reset_and_check("initialization");
        scoreboard.check_ready_state(1'b1, vif.tx_ready, "TX_IDLE before reset");
        scoreboard.check_output_state(1'b1, vif.tx_out, "TX_IDLE before reset");
        reset_and_check("TX_IDLE");
        check_post_reset_recovery(`DATA_BITS'(8'h11), "TX_IDLE");

        // Acceptance immediately enters TX_ALIGN. During this state tx_ready is
        // low, but the serial line remains high until the next baud tick.
        driver.assert_request(stimulus_data);
        driver.wait_for_acceptance();
        driver.release_request();
        scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_ALIGN before reset");
        scoreboard.check_output_state(1'b1, vif.tx_out, "TX_ALIGN before reset");
        reset_and_check("TX_ALIGN");
        check_post_reset_recovery(`DATA_BITS'(8'h22), "TX_ALIGN");

        // A falling serial edge marks TX_START. Reset well before one complete
        // start-bit period has elapsed.
        driver.send_byte(stimulus_data);
        @(negedge vif.tx_out);
        driver.wait_baud_ticks(`OVERSAMPLE / 4);
        scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_START before reset");
        scoreboard.check_output_state(1'b0, vif.tx_out, "TX_START before reset");
        reset_and_check("TX_START");
        check_post_reset_recovery(`DATA_BITS'(8'h44), "TX_START");

        // Wait through the start bit and halfway into the first data bit.
        driver.send_byte(stimulus_data);
        @(negedge vif.tx_out);
        driver.wait_baud_ticks(`OVERSAMPLE + (`OVERSAMPLE / 2));
        scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_DATA before reset");
        reset_and_check("TX_DATA");
        check_post_reset_recovery(`DATA_BITS'(8'h88), "TX_DATA");

        // All-zero data keeps tx_out low from START through DATA, so its next
        // rising edge unambiguously identifies entry into TX_STOP.
        driver.send_byte('0);
        @(negedge vif.tx_out);
        @(posedge vif.tx_out);
        driver.wait_baud_ticks(`OVERSAMPLE / 4);
        scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_STOP before reset");
        scoreboard.check_output_state(1'b1, vif.tx_out, "TX_STOP before reset");
        reset_and_check("TX_STOP");
        check_post_reset_recovery(`DATA_BITS'(8'h5A), "TX_STOP");

        $display(
            "[%0t] [PASS] Reset-in-every-TX-state test completed",
            $time
        );
    endtask
endclass
