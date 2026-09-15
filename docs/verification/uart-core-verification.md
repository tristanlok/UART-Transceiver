# Integrated UART verification plan

Sources: [`tb/uart/`](../../tb/uart/), [`tb/tx/`](../../tb/tx/), and
[`tb/rx/`](../../tb/rx/).

## Objective

Verify the `uart` integration after TX and RX have passed independently. The
focus is wiring, independence, simultaneous operation, shared reset/timing, and
cross-direction error isolation rather than reimplementing every leaf test.

## Reuse architecture

`uart_env` constructs the existing TX and RX drivers, monitors, and
scoreboards around one shared control/reset interface. `uart_tests` constructs
`uart_tx_tests` and `uart_rx_tests` using those same objects, allowing proven
leaf sanity tasks to run against the integrated DUT.

```text
uart_tb
├── uart DUT
├── uart_env
│   ├── reset driver
│   ├── TX components
│   ├── RX components
│   └── duplex monitor/scoreboard
└── uart_tests
```

## Tests

### `uart_tx_sanity`

Reuses the full standalone TX sanity task against `uart.sv`. At the same time,
an RX activity watcher confirms that idle `rx_in` does not create receive
activity.

### `uart_rx_sanity`

Reuses the full standalone RX sanity task against `uart.sv`. A TX activity
watcher confirms that receive-only traffic leaves `tx_out` idle.

### `uart_duplex_sanity`

Runs ten randomized simultaneous TX/RX exchanges. The two data values are
forced different so accidental direction coupling cannot satisfy both checks.
It independently checks both frames, confirms physical activity overlap, and
uses bounded waits to prove TX returns ready and RX returns idle.

### `uart_error_isolation`

Part one transmits a valid TX frame while RX receives a bad stop bit. TX must
remain correct, RX must reject the malformed byte, and both directions must
overlap. Part two receives a valid frame while TX holds a request and changes
its live data after acceptance. RX must remain correct, TX must send captured
data, and no extra TX frame may occur.

### `uart_reset_every_state`

Crosses all five TX states with all four RX states, producing 20 combinations.
For each pair the test forces both states, resets the shared DUT, verifies reset
outputs, and proves TX and RX can each complete recovery traffic.

## Integration-specific pass criteria

- Leaf behavior remains correct through top-level wiring.
- Inactive directions remain inactive in one-way tests.
- Both active directions overlap and preserve their own data.
- A fault/stress condition on one direction cannot corrupt the other.
- Shared reset recovers every reachable TX/RX state combination.
