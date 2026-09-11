`include "rtl/uart_config.svh"

class uart_rx_tests;
    virtual uart_rx_if  vif;
    uart_reset_driver  reset_driver;
    uart_rx_driver     driver;
    uart_rx_monitor    monitor;
    uart_rx_scoreboard scoreboard;

    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } uart_rx_possible_states_t;

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
    task automatic reset_and_check(
        input int unsigned reset_cycles = 3
    );
        `UART_DISPLAY((
            "[RX TEST] Asserting and verifying reset"
        ))

        driver.drive_idle();
        reset_driver.assert_reset();
        repeat (reset_cycles)
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
        input logic [`DATA_BITS-1:0] recovery_data
    );
        logic [`DATA_BITS-1:0] actual_data;
        logic                  framing_error;

        `UART_DISPLAY((
            "[RX TEST] Checking recovery after reset with data=0x%0h",
            recovery_data
        ))

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

        `UART_DISPLAY((
            "[RX TEST] Starting UART receive sanity test with %0d patterns",
            $size(patterns)
        ))

        `UART_DISPLAY(("[RX TEST] Asserting reset on DUT"))
        driver.drive_idle();
        reset_driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(vif.rst_n, vif.rx_data, vif.rx_valid, vif.rx_busy, vif.framing_error);
        reset_driver.deassert_reset();
        `UART_DISPLAY(("[RX TEST] Reset deasserted on DUT"))

        foreach (patterns[i]) begin
            logic [`DATA_BITS-1:0] actual;
            logic                  framing_error;

            `UART_DISPLAY((
                "[RX TEST] Pattern %0d/%0d: data=0x%02h",
                i + 1,
                $size(patterns),
                patterns[i]
            ))

            fork
                driver.send_frame(patterns[i]);
                monitor.receive_frame(actual, framing_error);
            join

            scoreboard.check_data(patterns[i], actual);
            scoreboard.check_framing_error(1'b0, framing_error);

            `UART_DISPLAY((
                "[RX TEST] Pattern %0d/%0d complete",
                i + 1,
                $size(patterns)
            ))
        end

        `UART_DISPLAY((
            "[RX TEST] [PASS] UART receive sanity test completed all %0d patterns",
            $size(patterns)
        ))
    endtask

    task automatic rx_false_start();
        bit busy_asserted;
        bit busy_deasserted;

        `UART_DISPLAY((
            "[RX TEST] Starting UART receive false-start test"
        ))

        `UART_DISPLAY(("[RX TEST] Asserting reset on DUT"))
        driver.drive_idle();
        reset_driver.assert_reset();
        repeat ($urandom_range(200, 5))
            @(posedge vif.clk);
        scoreboard.check_reset_state(vif.rst_n, vif.rx_data, vif.rx_valid, vif.rx_busy, vif.framing_error);
        reset_driver.deassert_reset();
        `UART_DISPLAY(("[RX TEST] Reset deasserted on DUT"))

        `UART_DISPLAY(("[RX TEST] Delaying before beginning test"))
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

        `UART_DISPLAY((
            "[RX TEST] [PASS] UART receive false-start test completed"
        ))
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

        `UART_DISPLAY((
            "[RX TEST] Starting RX data majority-vote test: %0d bits x %0d patterns",
            `DATA_BITS,
            $size(vote_patterns)
        ))

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

                `UART_DISPLAY((
                    "[RX TEST] Majority target_bit=%0d samples=%03b expected_bit=%0b",
                    target_bit,
                    vote_patterns[pattern_index],
                    expected_data[target_bit]
                ))

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

        `UART_DISPLAY((
            "[RX TEST] [PASS] RX data majority-vote test completed"
        ))
    endtask

    task automatic rx_framing_error();
        logic [`DATA_BITS-1:0] baseline_data;
        logic [`DATA_BITS-1:0] rejected_data;
        logic [`DATA_BITS-1:0] recovery_data;
        logic [`DATA_BITS-1:0] actual_data;
        logic                  actual_valid;
        logic                  actual_error;
        logic                  valid_after_pulse;
        logic                  error_after_pulse;

        baseline_data     = `DATA_BITS'(8'hA5);
        rejected_data     = `DATA_BITS'(8'h3C);
        recovery_data     = `DATA_BITS'(8'h5A);
        actual_data       = '0;
        actual_valid      = 1'b0;
        actual_error      = 1'b0;
        valid_after_pulse = 1'b0;
        error_after_pulse = 1'b0;

        `UART_DISPLAY((
            "[RX TEST] Starting RX framing-error test"
        ))

        reset_and_check();

        // Establish a known valid data_out value before injecting the bad
        // stop bit. A rejected frame must not overwrite this value.
        fork
            driver.send_frame(baseline_data);
            monitor.receive_frame_result(
                actual_data,
                actual_valid,
                actual_error
            );
        join

        scoreboard.check_valid_state(
            1'b1,
            actual_valid,
            "valid baseline frame"
        );
        scoreboard.check_framing_error(1'b0, actual_error);
        scoreboard.check_data(baseline_data, actual_data);

        // A low stop bit completes with framing_error=1, rx_valid=0, and the
        // last valid data_out value preserved.
        fork
            driver.send_frame(rejected_data, 1'b0);

            begin : observe_rejected_frame
                monitor.receive_frame_result(
                    actual_data,
                    actual_valid,
                    actual_error
                );

                @(posedge vif.clk);
                #1step;
                valid_after_pulse = vif.rx_valid;
                error_after_pulse = vif.framing_error;
            end
        join

        scoreboard.check_valid_state(
            1'b0,
            actual_valid,
            "framing-error completion"
        );
        scoreboard.check_framing_error(1'b1, actual_error);
        scoreboard.check_data_unchanged_after_error(
            baseline_data,
            actual_data
        );
        scoreboard.check_valid_state(
            1'b0,
            valid_after_pulse,
            "cycle after framing error"
        );
        scoreboard.check_framing_error(1'b0, error_after_pulse);

        // The receiver must accept a new good frame without requiring reset.
        fork
            driver.send_frame(recovery_data);
            monitor.receive_frame_result(
                actual_data,
                actual_valid,
                actual_error
            );
        join

        scoreboard.check_valid_state(
            1'b1,
            actual_valid,
            "post-error recovery frame"
        );
        scoreboard.check_framing_error(1'b0, actual_error);
        scoreboard.check_data(recovery_data, actual_data);
        scoreboard.check_busy_state(1'b0, vif.rx_busy, "post-error recovery");

        `UART_DISPLAY((
            "[RX TEST] [PASS] RX framing-error test completed"
        ))
    endtask

    task automatic force_state(
        input uart_rx_possible_states_t state
    );
        logic [`DATA_BITS-1:0] stimulus_data;

        stimulus_data = `DATA_BITS'(8'hA5);

        case (state)
            RX_IDLE: begin
                scoreboard.check_busy_state(1'b0, vif.rx_busy, "RX_IDLE before reset");
            end

            RX_START: begin
                logic busy_observed = 1'b0;
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
            end

            RX_DATA: begin
                driver.send_start_bit();
                fork : drive_data_state
                    driver.send_data_byte(stimulus_data);
                    driver.wait_ref_ticks(`OVERSAMPLE / 2);
                join_any
                disable drive_data_state;

                scoreboard.check_busy_state(1'b1, vif.rx_busy, "RX_DATA before reset");
            end

            RX_STOP: begin
                driver.send_start_bit();
                driver.send_data_byte(stimulus_data);
                fork : drive_stop_state
                    driver.send_stop_bit();
                    driver.wait_ref_ticks(`OVERSAMPLE / 2);
                join_any
                disable drive_stop_state;

                scoreboard.check_busy_state(1'b1, vif.rx_busy, "RX_STOP before reset");
            end

            default: begin
                `UART_FATAL((
                    1,
                    "[RX TEST] Cannot force invalid RX state value %0d",
                    state
                ))
            end
        endcase
    endtask

    task automatic rx_reset_every_state();
        uart_rx_possible_states_t uart_rx_possible_states = uart_rx_possible_states.first();

        `UART_DISPLAY((
            "[RX TEST] Starting reset-in-every-RX-state test"
        ))

        // Establish a known state before deliberately resetting in RX_IDLE.
        reset_and_check();

        do begin
            `UART_DISPLAY((
                "[RX TEST] Forcing UART RX into state %s",
                uart_rx_possible_states.name()
            ))
            force_state(uart_rx_possible_states);

            `UART_DISPLAY((
                "[RX TEST] Resetting UART RX from state %s",
                uart_rx_possible_states.name()
            ))
            reset_and_check();
            check_post_reset_recovery(`DATA_BITS'(8'h11));
            uart_rx_possible_states = uart_rx_possible_states.next();
        end while (uart_rx_possible_states != uart_rx_possible_states.first());
        
        `UART_DISPLAY((
            "[RX TEST] [PASS] Reset-in-every-RX-state test completed"
        ))
    endtask
endclass
