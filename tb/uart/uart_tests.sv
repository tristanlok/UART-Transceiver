`include "uart_config.svh"
`include "uart_tb_log.svh"

// Integrated-test container. It reuses the existing TX and RX test libraries
// with the components already constructed by uart_env.
class uart_tests;
    uart_env      env;
    uart_tx_tests tx_tests;
    uart_rx_tests rx_tests;

    function new(uart_env env_arg);
        this.env = env_arg;

        this.tx_tests = new(
            env.ctrl_vif,
            env.tx_vif,
            env.reset_driver,
            env.tx_driver,
            env.tx_monitor,
            env.tx_scoreboard
        );

        this.rx_tests = new(
            env.ctrl_vif,
            env.rx_vif,
            env.reset_driver,
            env.rx_driver,
            env.rx_monitor,
            env.rx_scoreboard
        );
    endfunction

    task automatic uart_tx_sanity();
        logic rx_activity_seen;

        fork: tx_sanity_with_rx_guard
            tx_tests.tx_send_data_sanity();
            env.rx_monitor.watch_for_activity(rx_activity_seen);
        join_any
        disable tx_sanity_with_rx_guard;

        env.rx_scoreboard.check_for_unexpected_activity(rx_activity_seen);
    endtask

    task automatic uart_rx_sanity();
        logic tx_activity_seen;

        fork: rx_sanity_with_tx_guard
            rx_tests.rx_read_data_sanity();
            env.tx_monitor.watch_for_activity(tx_activity_seen);
        join_any
        disable rx_sanity_with_tx_guard;

        env.tx_scoreboard.check_for_unexpected_activity(tx_activity_seen);
    endtask

    // Exercise error isolation in both directions. RX has an explicit framing
    // error condition; TX has no error input, so its negative condition is a
    // held request whose data changes after the original byte is accepted.
    task automatic uart_error_isolation();
        logic [`DATA_BITS-1:0] baseline_rx_data;
        logic [`DATA_BITS-1:0] rejected_rx_data;
        logic [`DATA_BITS-1:0] nominal_tx_data;
        logic [`DATA_BITS-1:0] held_tx_data;
        logic [`DATA_BITS-1:0] changed_tx_data;
        logic [`DATA_BITS-1:0] nominal_rx_data;
        logic [`DATA_BITS-1:0] tx_actual_data;
        logic [`DATA_BITS-1:0] rx_actual_data;
        logic                  tx_actual_start_bit;
        logic                  tx_actual_stop_bit;
        logic                  rx_actual_valid;
        logic                  rx_actual_error;
        logic                  rx_valid_after_pulse;
        logic                  rx_error_after_pulse;
        logic                  overlap_observed;

        baseline_rx_data     = `DATA_BITS'(8'hA5);
        rejected_rx_data     = `DATA_BITS'(8'h3C);
        nominal_tx_data      = `DATA_BITS'(8'hC3);
        held_tx_data         = `DATA_BITS'(8'h96);
        changed_tx_data      = `DATA_BITS'(8'h69);
        nominal_rx_data      = `DATA_BITS'(8'h5A);
        tx_actual_data       = '0;
        rx_actual_data       = '0;
        tx_actual_start_bit  = 1'b1;
        tx_actual_stop_bit   = 1'b0;
        rx_actual_valid      = 1'b0;
        rx_actual_error      = 1'b0;
        rx_valid_after_pulse = 1'b0;
        rx_error_after_pulse = 1'b0;
        overlap_observed     = 1'b0;

        `UART_DISPLAY((
            "[UART TEST] Starting two-part UART error-isolation test"
        ))

        reset_and_check();

        // Establish a known RX data value. The malformed frame in part 1
        // must not overwrite this last successfully received byte.
        fork
            env.rx_driver.send_frame(baseline_rx_data);
            env.rx_monitor.receive_frame_result(
                rx_actual_data,
                rx_actual_valid,
                rx_actual_error
            );
        join

        env.rx_scoreboard.check_valid_state(
            1'b1,
            rx_actual_valid,
            "error-isolation baseline"
        );
        env.rx_scoreboard.check_framing_error(1'b0, rx_actual_error);
        env.rx_scoreboard.check_data(baseline_rx_data, rx_actual_data);

        // Part 1: TX runs normally while RX receives a malformed stop bit.
        // The TX frame must complete correctly and the RX frame must be
        // rejected without replacing the previous valid data.
        `UART_DISPLAY((
            "[UART TEST] Part 1: RX framing error while TX runs nominally"
        ))

        overlap_observed = 1'b0;
        fork
            env.uart_dup_monitor.wait_for_duplex_overlap(
                (`DATA_BITS + 2) * `OVERSAMPLE,
                overlap_observed
            );

            tx_tests.send_and_check(nominal_tx_data);

            env.rx_driver.send_frame(rejected_rx_data, 1'b0);

            begin : observe_rx_error
                env.rx_monitor.receive_frame_result(
                    rx_actual_data,
                    rx_actual_valid,
                    rx_actual_error
                );

                @(posedge env.ctrl_vif.clk);
                #1step;
                rx_valid_after_pulse = env.rx_vif.rx_valid;
                rx_error_after_pulse = env.rx_vif.framing_error;
            end
        join

        env.rx_scoreboard.check_valid_state(
            1'b0,
            rx_actual_valid,
            "framing error during nominal TX"
        );
        env.rx_scoreboard.check_framing_error(1'b1, rx_actual_error);
        env.rx_scoreboard.check_data_unchanged_after_error(
            baseline_rx_data,
            rx_actual_data
        );
        env.rx_scoreboard.check_valid_state(
            1'b0,
            rx_valid_after_pulse,
            "cycle after isolated framing error"
        );
        env.rx_scoreboard.check_framing_error(
            1'b0,
            rx_error_after_pulse
        );
        env.uart_dup_scoreboard.check_for_duplex_overlap(overlap_observed);

        // Part 2: RX runs normally while TX is given a held request and its
        // live data input changes after acceptance. TX must serialize the
        // originally captured byte and must not create an additional frame.
        `UART_DISPLAY((
            "[UART TEST] Part 2: TX request stress while RX runs nominally"
        ))

        tx_actual_data      = '0;
        rx_actual_data      = '0;
        tx_actual_start_bit = 1'b1;
        tx_actual_stop_bit  = 1'b0;
        rx_actual_valid     = 1'b0;
        rx_actual_error     = 1'b0;
        overlap_observed    = 1'b0;

        fork
            env.uart_dup_monitor.wait_for_duplex_overlap(
                (`DATA_BITS + 2) * `OVERSAMPLE,
                overlap_observed
            );

            begin : drive_held_tx_request
                env.tx_driver.wait_until_ready();
                env.tx_driver.assert_request(held_tx_data);
                env.tx_driver.wait_for_acceptance();

                // Changing tx_data after acceptance must not alter the byte
                // already stored by the transmitter.
                env.tx_driver.set_data(changed_tx_data);
                env.tx_driver.wait_until_ready();
                env.tx_driver.release_request();
            end

            env.tx_monitor.receive_frame(
                tx_actual_data,
                tx_actual_start_bit,
                tx_actual_stop_bit
            );

            env.rx_driver.send_frame(nominal_rx_data);
            env.rx_monitor.receive_frame_result(
                rx_actual_data,
                rx_actual_valid,
                rx_actual_error
            );
        join

        env.tx_scoreboard.check_frame(
            held_tx_data,
            tx_actual_data,
            tx_actual_start_bit,
            tx_actual_stop_bit
        );
        env.rx_scoreboard.check_valid_state(
            1'b1,
            rx_actual_valid,
            "nominal RX during TX request stress"
        );
        env.rx_scoreboard.check_framing_error(1'b0, rx_actual_error);
        env.rx_scoreboard.check_data(nominal_rx_data, rx_actual_data);
        env.uart_dup_scoreboard.check_for_duplex_overlap(overlap_observed);

        // Holding tx_start during the active frame must not queue or launch a
        // second transmission after the request is released.
        tx_tests.check_no_unexpected_frame(2 * `OVERSAMPLE);

        `UART_DISPLAY((
            "[UART TEST] [PASS] Two-part UART error-isolation test completed"
        ))
    endtask

    task automatic reset_and_check(
        input int unsigned reset_cycles = 3
    );
        `UART_DISPLAY((
            "[UART TEST] Asserting reset on DUT"
        ))

        env.initialize_inputs();
        env.reset_driver.assert_reset();

        repeat (reset_cycles)
            @(posedge env.ctrl_vif.clk);
        #1step;

        fork
            env.tx_scoreboard.check_reset_state(
                env.ctrl_vif.rst_n,
                env.tx_vif.tx_out,
                env.tx_vif.tx_ready,
                env.ctrl_vif.baud_tick
            );

            env.rx_scoreboard.check_reset_state(
                env.ctrl_vif.rst_n,
                env.rx_vif.rx_data,
                env.rx_vif.rx_valid,
                env.rx_vif.rx_busy,
                env.rx_vif.framing_error
            );
        join

        env.reset_driver.deassert_reset();

        // Give the DUT two system-clock edges in its reset-released idle state.
        repeat (2)
            @(posedge env.ctrl_vif.clk);
    endtask

    task automatic uart_duplex_sanity();
        localparam int unsigned TRANSACTION_COUNT = 10;

        logic tx_actual_start_bit, tx_actual_stop_bit, rx_framing_error;
        logic tx_ready_observed, rx_idle_observed, overlap_observed;
        logic [`DATA_BITS-1:0] tx_actual_data, rx_actual_data;
        logic [`DATA_BITS-1:0] tx_expected_data, rx_expected_data;

        `UART_DISPLAY((
            "[UART TEST] Starting UART duplex sanity test with %0d randomized transactions",
            TRANSACTION_COUNT
        ))

        reset_and_check($urandom_range(200, 5));

        for (int unsigned transaction_index = 0;
                transaction_index < TRANSACTION_COUNT;
                transaction_index++) begin
            tx_expected_data = `DATA_BITS'($urandom());

            // Keep the directions different so unintended TX-to-RX coupling
            // cannot satisfy both scoreboards with the same value.
            do begin
                rx_expected_data = `DATA_BITS'($urandom());
            end while (rx_expected_data === tx_expected_data);

            tx_ready_observed = 1'b0;
            rx_idle_observed  = 1'b0;
            overlap_observed  = 1'b0;

            `UART_DISPLAY((
                "[UART TEST] Transaction %0d/%0d: TX data=0x%02h RX data=0x%02h",
                transaction_index + 1,
                TRANSACTION_COUNT,
                tx_expected_data,
                rx_expected_data
            ))

            fork
                env.uart_dup_monitor.wait_for_duplex_overlap(
                    (`DATA_BITS + 2) * `OVERSAMPLE,
                    overlap_observed
                );

                env.tx_driver.send_byte(tx_expected_data);
                env.tx_monitor.receive_frame(
                    tx_actual_data,
                    tx_actual_start_bit,
                    tx_actual_stop_bit
                );

                env.rx_driver.send_frame(rx_expected_data);
                env.rx_monitor.receive_frame(rx_actual_data, rx_framing_error);
            join

            fork
                env.tx_scoreboard.check_frame(
                    tx_expected_data,
                    tx_actual_data,
                    tx_actual_start_bit,
                    tx_actual_stop_bit
                );

                env.rx_scoreboard.check_data(
                    rx_expected_data,
                    rx_actual_data
                );
                env.rx_scoreboard.check_framing_error(
                    1'b0,
                    rx_framing_error
                );

                env.uart_dup_scoreboard.check_for_duplex_overlap(overlap_observed);
            join

            // Each serial monitor can complete just before the DUT consumes
            // its final internal tick. Use bounded waits so this test cannot
            // hang if TX fails to return ready or RX fails to return idle.
            fork
                env.tx_monitor.wait_for_ready_state(
                    1'b1,
                    `OVERSAMPLE + 2,
                    tx_ready_observed
                );

                env.rx_monitor.wait_for_busy_state(
                    1'b0,
                    `OVERSAMPLE + 2,
                    rx_idle_observed
                );
            join

            // The observation flags are already 1 on success and 0 on
            // timeout. These scoreboard calls are the only failure reports;
            // separate "if (!observed) $error" checks would be redundant.
            env.tx_scoreboard.check_ready_state(
                1'b1,
                tx_ready_observed,
                "bounded wait after completed frame"
            );
            env.rx_scoreboard.check_busy_state(
                1'b1,
                rx_idle_observed,
                "bounded wait for idle after completed frame"
            );

            `UART_DISPLAY((
                "[UART TEST] Transaction %0d/%0d complete",
                transaction_index + 1,
                TRANSACTION_COUNT
            ))
        end

        `UART_DISPLAY((
            "[UART TEST] [PASS] UART duplex sanity test completed all %0d randomized transactions",
            TRANSACTION_COUNT
        ))
    endtask

    task automatic uart_reset_every_state();
        uart_rx_tests::uart_rx_possible_states_t uart_rx_possible_states = uart_rx_possible_states.first();
        uart_tx_tests::uart_tx_possible_states_t uart_tx_possible_states = uart_tx_possible_states.first();

        `UART_DISPLAY((
            "[UART TEST] Starting reset-in-every-TX-RX-state test"
        ))

        // Establish a known state before deliberately resetting in RX_IDLE.
        reset_and_check();

        do begin
            do begin
                `UART_DISPLAY((
                    "[UART TEST] Forcing UART RX into state %s, UART TX into state %s",
                    uart_rx_possible_states.name(),
                    uart_tx_possible_states.name()
                ))
                fork
                    rx_tests.force_state(uart_rx_possible_states);
                    tx_tests.force_state(uart_tx_possible_states);
                join

                `UART_DISPLAY((
                    "[UART TEST] Resetting UART RX from state %s, UART TX from state %s",
                    uart_rx_possible_states.name(),
                    uart_tx_possible_states.name()
                ))
                reset_and_check();

                fork
                    rx_tests.check_post_reset_recovery(`DATA_BITS'(8'h11));
                    tx_tests.check_post_reset_recovery(`DATA_BITS'(8'h11));
                join

                uart_tx_possible_states = uart_tx_possible_states.next();
            end while (uart_tx_possible_states != uart_tx_possible_states.first());
            uart_rx_possible_states = uart_rx_possible_states.next();
        end while (uart_rx_possible_states != uart_rx_possible_states.first());

        `UART_DISPLAY((
            "[UART TEST] [PASS] Reset-in-every-TX-RX-state test completed"
        ))
    endtask
endclass
