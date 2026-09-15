# UART transmitter verification plan

Sources: [`tb/tx/`](../../tb/tx/) and
[`tb/common/`](../../tb/common/).

## Objective

Verify `uart_tx` independently from RX, registers, and AXI. The bench uses the
real RTL baud generator for the DUT and an independent reference tick for the
monitor.

## Bench structure

```text
uart_tx_tb
├── baud_generator
├── uart_tx DUT
├── uart_tb_ctrl_if
├── uart_tx_if
├── uart_reset_driver
├── uart_tx_driver
├── uart_tx_monitor
├── uart_tx_scoreboard
└── uart_tx_tests
```

## Requirements checked

- idle-high output and ready reset state;
- acceptance only when ready;
- low start bit, LSB-first payload, high stop bit;
- capture of input data at acceptance;
- exactly 16 reference ticks per symbol;
- no repeated frame from a held request;
- reset abort and recovery from every state.

## Tests

### `tx_sim_sanity`

Maps to `tx_send_data_sanity()`. After a randomized reset, it transmits eight
patterns: `00`, all ones, `55`, `AA`, `01`, `80`, `A5`, and `5A`. Random idle
delays vary request phase. For every frame it checks start, payload, stop, and
bounded return to ready.

### `tx_send_data_and_assert_reset`

Starts a randomized byte, waits a randomized number of timing ticks into START
or DATA, confirms TX is busy, and drives reset active. It verifies reset state,
checks that the interrupted frame does not resume, then sends `A5` to prove
fresh post-reset operation.

Here “assert reset” means drive `rst_n` low; it is ordinary stimulus naming.

### `tx_hold_request_data_stability`

Offers `A5`, waits for acceptance, changes the live data input to `3C`, and
holds the request through the active frame. The observed frame must contain the
captured `A5`, and no second start edge may follow.

### `tx_exact_bit_duration`

Uses `55` so adjacent symbols alternate and every boundary is observable. The
monitor measures start, all eight data bits, and stop. Each must last exactly
`OVERSAMPLE` reference ticks; the complete frame must last
`(DATA_BITS + 2) × OVERSAMPLE` ticks. Ready must return afterward.

### `tx_reset_every_state`

Forces TX into `TX_IDLE`, `TX_ALIGN`, `TX_START`, `TX_DATA`, and `TX_STOP`.
It checks the expected pre-reset state, resets, verifies idle output/ready, and
transmits recovery byte `11` after every state.

## Checker ownership

- The monitor reconstructs serial symbols and measures timing.
- The scoreboard compares frame format, payload, duration, ready, and reset.
- The test chooses patterns, delays, reset timing, and expected data.

## Pass criteria

Every scoreboard comparison must pass, all bounded ready waits must complete,
and no unintended falling edge may appear during no-extra-frame windows.
