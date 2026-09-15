# Integrated UART core architecture

Source: [`rtl/uart.sv`](../../rtl/uart.sv).

## Responsibility

`uart` combines timing, transmit, and receive into one full-duplex serial core.
It deliberately contains no register map and no AXI logic. This boundary lets
the serial design be verified independently before software control is added.

## Hierarchy

```text
uart
├── baud_generator
├── uart_tx
└── uart_rx
```

The generated 16x `baud_tick` is shared. Reset and configuration are shared,
but TX and RX state and datapaths are independent.

## Parameters

| Parameter | Default | Purpose |
| --- | ---: | --- |
| `CLOCK_HZ` | 100,000,000 | System clock frequency |
| `BAUD_RATE` | 115,200 | Serial bits per second |

Payload width and oversampling ratio come from `uart_config.svh`.

## TX boundary

The top forwards `tx_data`, `tx_start`, `tx_ready`, and `tx_out` directly
between the external parallel client and `uart_tx`. No top-level queue or
additional handshake state exists here.

## RX boundary

The top forwards `rx_in`, `rx_data`, `rx_valid`, `rx_busy`, and
`framing_error` between the physical line and `uart_rx`. Receive buffering for
software belongs to the later register block.

## Full-duplex behavior

The only intentional coupling is timing configuration. TX activity does not
gate RX and RX activity does not gate TX. Consequently:

- TX-only operation must leave RX idle when `rx_in` stays high;
- RX-only operation must leave `tx_out` idle high;
- simultaneous frames must complete independently;
- an error on RX must not corrupt TX;
- TX request stress must not corrupt RX.

## Simulation visibility

When compiled with `UART_SIM`, `baud_tick_sim` exposes the otherwise internal
16x timing enable. Testbenches use this for state alignment and diagnostic
checks. It is omitted from the normal module interface when `UART_SIM` is not
defined.
