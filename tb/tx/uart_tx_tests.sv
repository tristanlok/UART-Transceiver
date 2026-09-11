`include "rtl/uart_config.svh"

class uart_tx_tests;
    virtual uart_tx_if  vif;
    uart_reset_driver   reset_driver;
    uart_tx_driver      driver;
    uart_tx_monitor     monitor;
    uart_tx_scoreboard  scoreboard;

    typedef enum logic [2:0] {
        TX_IDLE,
        TX_ALIGN,
        TX_START,
        TX_DATA,
        TX_STOP
    } uart_tx_possible_states_t;

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
        input int unsigned reset_cycles = 3
    );
        `UART_DISPLAY((
            "[TX TEST] Asserting and verifying reset"
        ))

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
            begin : delayed_stimulus
                // Delay belongs to the test scenario, not the protocol
                // driver. First wait until the requested delay can begin from
                // a legal ready state, preserving the original behavior.
                driver.wait_until_ready();
                driver.wait_clock_cycles(delay_cycles);
                driver.send_byte(data);
            end

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
        input logic [`DATA_BITS-1:0] recovery_data
    );
        `UART_DISPLAY((
            "[TX TEST] Checking recovery after reset with data=0x%0h",
            recovery_data
        ))

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

        `UART_DISPLAY((
            "[TX TEST] Starting UART transmit sanity test with %0d patterns",
            $size(patterns)
        ))

        reset_and_check($urandom_range(200, 5));

        foreach (patterns[i]) begin
            `UART_DISPLAY((
                "[TX TEST] Pattern %0d/%0d: data=0x%02h",
                i + 1,
                $size(patterns),
                patterns[i]
            ))

            send_and_check(patterns[i], $urandom_range(200, 0));

            `UART_DISPLAY((
                "[TX TEST] Pattern %0d/%0d complete",
                i + 1,
                $size(patterns)
            ))
        end

        `UART_DISPLAY((
            "[TX TEST] [PASS] UART transmit sanity test completed all %0d patterns",
            $size(patterns)
        ))
    endtask

    task automatic tx_send_data_and_assert_reset();
        logic [`DATA_BITS-1:0] random_data;
        int unsigned           reset_after_ticks;

        random_data = `DATA_BITS'($urandom);
        reset_after_ticks = $urandom_range(
            (`OVERSAMPLE * `DATA_BITS),
            1
        );

        `UART_DISPLAY((
            "[TX TEST] Starting reset-during-transmission test: data=0x%02h reset_after_ticks=%0d",
            random_data,
            reset_after_ticks
        ))

        reset_and_check($urandom_range(200, 5));

        driver.wait_until_ready();
        driver.wait_clock_cycles($urandom_range(200, 0));
        driver.send_byte(random_data);

        // The serial falling edge marks entry into TX_START. Counting DUT baud
        // ticks from here targets either TX_START or TX_DATA deterministically.
        @(negedge vif.tx_out);
        driver.wait_baud_ticks(reset_after_ticks);
        scoreboard.check_ready_state(
            1'b0,
            vif.tx_ready,
            "active frame before reset"
        );

        reset_and_check($urandom_range(50, 5));

        // Reset must abort the interrupted frame rather than resume it.
        check_no_unexpected_frame(2 * `OVERSAMPLE);
        check_post_reset_recovery(`DATA_BITS'(8'hA5));

        `UART_DISPLAY((
            "[TX TEST] [PASS] Reset-during-transmission test completed"
        ))
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

        `UART_DISPLAY((
            "[TX TEST] Starting held-request test: accepted=0x%02h changed=0x%02h",
            original_data,
            changed_data
        ))

        reset_and_check($urandom_range(200, 5));

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

        `UART_DISPLAY((
            "[TX TEST] [PASS] Held-request data-stability test completed"
        ))
    endtask

    task automatic tx_exact_bit_duration();
        logic [`DATA_BITS-1:0] stimulus_data;
        logic [`DATA_BITS-1:0] actual_data;
        logic                  actual_start_bit;
        logic                  actual_stop_bit;
        int unsigned           bit_ticks [0:`DATA_BITS+1];
        int unsigned           total_ticks;
        string                 symbol_name;

        // LSB-first 0x55 alternates every data bit. Together with start=0 and
        // stop=1, this creates an observable edge at every symbol boundary.
        stimulus_data    = `DATA_BITS'(8'h55);
        actual_data      = '0;
        actual_start_bit = 1'b1;
        actual_stop_bit  = 1'b0;
        total_ticks      = 0;

        `UART_DISPLAY((
            "[TX TEST] Starting exact TX bit-duration test"
        ))

        reset_and_check();

        fork
            driver.send_byte(stimulus_data);

            monitor.receive_frame(
                actual_data,
                actual_start_bit,
                actual_stop_bit
            );

            monitor.measure_frame_bit_durations(bit_ticks);
        join

        scoreboard.check_frame(
            stimulus_data,
            actual_data,
            actual_start_bit,
            actual_stop_bit
        );

        foreach (bit_ticks[index]) begin
            if (index == 0) begin
                symbol_name = "start bit";
            end else if (index <= `DATA_BITS) begin
                symbol_name = $sformatf("data bit %0d", index - 1);
            end else begin
                symbol_name = "stop bit";
            end

            scoreboard.check_bit_duration(
                symbol_name,
                `OVERSAMPLE,
                bit_ticks[index]
            );
            total_ticks += bit_ticks[index];
        end

        scoreboard.check_bit_duration(
            "complete 8-N-1 frame",
            (`DATA_BITS + 2) * `OVERSAMPLE,
            total_ticks
        );
        scoreboard.check_ready_state(
            1'b1,
            vif.tx_ready,
            "after exact-duration frame"
        );

        `UART_DISPLAY((
            "[TX TEST] [PASS] Exact TX bit-duration test completed"
        ))
    endtask

    task automatic force_state(
        input uart_tx_possible_states_t state
    );
        logic [`DATA_BITS-1:0] stimulus_data;

        stimulus_data = `DATA_BITS'(8'hA5);

        case (state)
            TX_IDLE: begin
                scoreboard.check_ready_state(1'b1, vif.tx_ready, "TX_IDLE before reset");
                scoreboard.check_output_state(1'b1, vif.tx_out, "TX_IDLE before reset");
            end

            TX_ALIGN: begin
                // Acceptance immediately enters TX_ALIGN. During this state
                // tx_ready is low, but tx_out remains high until a baud tick.
                driver.assert_request(stimulus_data);
                driver.wait_for_acceptance();
                driver.release_request();
                scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_ALIGN before reset");
                scoreboard.check_output_state(1'b1, vif.tx_out, "TX_ALIGN before reset");
            end

            TX_START: begin
                // The falling serial edge identifies entry into TX_START.
                driver.send_byte(stimulus_data);
                @(negedge vif.tx_out);
                driver.wait_baud_ticks(`OVERSAMPLE / 4);
                scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_START before reset");
                scoreboard.check_output_state(1'b0, vif.tx_out, "TX_START before reset");
            end

            TX_DATA: begin
                // Wait through START and halfway into the first data bit.
                driver.send_byte(stimulus_data);
                @(negedge vif.tx_out);
                driver.wait_baud_ticks(`OVERSAMPLE + (`OVERSAMPLE / 2));
                scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_DATA before reset");
            end

            TX_STOP: begin
                // All-zero data holds tx_out low through START and DATA. Its
                // next rising edge therefore identifies entry into TX_STOP.
                driver.send_byte('0);
                @(negedge vif.tx_out);
                @(posedge vif.tx_out);
                driver.wait_baud_ticks(`OVERSAMPLE / 4);
                scoreboard.check_ready_state(1'b0, vif.tx_ready, "TX_STOP before reset");
                scoreboard.check_output_state(1'b1, vif.tx_out, "TX_STOP before reset");
            end
            
            default: begin
                `UART_FATAL((
                    1,
                    "[UART TEST] Invalid state value: %0d",
                    state
                ))
            end
        endcase
    endtask

    task automatic tx_reset_every_state();
        uart_tx_possible_states_t uart_tx_possible_states =
            uart_tx_possible_states.first();

        `UART_DISPLAY((
            "[TX TEST] Starting reset-in-every-TX-state test"
        ))

        // Establish a known state before deliberately resetting in TX_IDLE.
        reset_and_check();

        do begin
            `UART_DISPLAY((
                "[TX TEST] Forcing UART TX into state %s",
                uart_tx_possible_states.name()
            ))
            force_state(uart_tx_possible_states);

            `UART_DISPLAY((
                "[TX TEST] Resetting UART TX from state %s",
                uart_tx_possible_states.name()
            ))
            reset_and_check();
            check_post_reset_recovery(`DATA_BITS'(8'h11));
            uart_tx_possible_states = uart_tx_possible_states.next();
        end while (uart_tx_possible_states != uart_tx_possible_states.first());

        `UART_DISPLAY((
            "[TX TEST] [PASS] Reset-in-every-TX-state test completed"
        ))
    endtask
endclass
