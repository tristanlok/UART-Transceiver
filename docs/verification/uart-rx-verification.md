# UART receiver verification plan

Sources: [`tb/rx/`](../../tb/rx/) and
[`tb/common/`](../../tb/common/).

## Objective

Verify synchronization-visible behavior, false-start rejection, 16x
three-sample majority decisions, data reconstruction, stop-bit rejection, and
reset recovery of `uart_rx`.

## Bench structure

```text
uart_rx_tb
├── baud_generator
├── uart_rx DUT
├── uart_tb_ctrl_if
├── uart_rx_if
├── uart_reset_driver
├── uart_rx_driver
├── uart_rx_monitor
├── uart_rx_scoreboard
└── uart_rx_tests
```

The DUT consumes its RTL-generated timing enable. The driver constructs serial
bit timing from an independent reference tick.

## Requirements checked

- idle/reset outputs;
- start detection and false-start rejection;
- busy assertion throughout active reception;
- LSB-first byte reconstruction;
- all truth-table cases of the three-input majority voter;
- valid only after a good stop bit;
- one-cycle valid/error indications;
- preservation of last good data after a bad frame;
- recovery without reset after a framing error;
- reset recovery from every RX state.

## Tests

### `rx_sim_sanity`

Maps to `rx_read_data_sanity()`. It applies the eight patterns `00`, all ones,
`55`, `AA`, `01`, `80`, `A5`, and `5A`. Each reconstructed byte must match and
must complete without framing error.

### `rx_false_start`

Drives a low pulse shorter than the start-bit validation point. The receiver
must notice activity, briefly become busy, reject the majority-high start, and
return idle. This test directly checks the busy-state entry and exit; adding an
explicit `rx_valid`/`framing_error` observation window would strengthen its
completion-output checking.

### `rx_data_majority_vote`

For each data-bit position, the test injects every three-sample pattern from
`000` through `111`. An independent Boolean reference function calculates the
expected majority. With eight data bits this runs 64 frames and proves every
majority truth-table row at every payload position.

### `rx_framing_error`

First receives valid `A5` to establish `data_out`. It then sends `3C` with a
low stop bit and requires `framing_error = 1`, `rx_valid = 0`, and unchanged
data. On the next clock both pulses must be low. A valid `5A` frame must then
succeed without another reset.

### `rx_reset_every_state`

Forces `RX_IDLE`, `RX_START`, `RX_DATA`, and `RX_STOP`, resets in each, checks
the reset state, and receives recovery byte `11` after every case.

## Checker ownership

- The driver owns bit shape and injected center-sample patterns.
- The monitor captures completion pulses and bounded busy transitions.
- The scoreboard checks data, valid/error, busy, reset, and data preservation.
- The test owns the expected majority reference and scenario sequencing.

## Pass criteria

Every good frame must produce exactly the expected byte with no error. False or
malformed frames must not produce valid data. All state/reset recovery checks
must complete without scoreboard failures.
