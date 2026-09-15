# UART core functional specification

Applicable RTL: [`baud_generator.sv`](../../rtl/baud_generator.sv),
[`uart_tx.sv`](../../rtl/uart_tx.sv), [`uart_rx.sv`](../../rtl/uart_rx.sv), and
[`uart.sv`](../../rtl/uart.sv).

## Purpose

The UART core provides independent transmit and receive paths using a fixed
8N1 serial format. `uart.sv` integrates the timing generator, transmitter, and
receiver but does not contain the software-visible register or AXI-Lite logic.

## Configuration

| Item | Implemented value |
| --- | --- |
| Default system clock | 100 MHz |
| Default baud rate | 115200 baud |
| Data bits | `` `DATA_BITS `` = 8 |
| Oversampling ratio | `` `OVERSAMPLE `` = 16 |
| Parity | None |
| Stop bits | One |
| Bit order | Least-significant bit first |
| Idle line level | Logic 1 |
| Frame | One start, eight data, one stop |

`CLOCK_HZ` and `BAUD_RATE` are parameters of `uart` and `baud_generator`.
Data width and oversampling ratio are project-wide macros in
`rtl/uart_config.svh`.

## Timing requirements

The timing generator produces an average enable rate of:

```text
BAUD_RATE × OVERSAMPLE
```

With the default settings, the enable rate is 1.8432 MHz. The TX and RX logic
count 16 enables for each serial bit, producing 115200 serial bits per second
on average. Fractional accumulation is required because 100 MHz is not an
integer multiple of 1.8432 MHz.

The signal named `baud_tick` is therefore a one-system-clock-wide 16x timing
enable, not a one-pulse-per-serial-bit enable.

## Transmit interface contract

| Signal | Direction | Meaning |
| --- | --- | --- |
| `tx_data` | Input | Byte offered to the transmitter |
| `tx_start` | Input | Request to capture and transmit `tx_data` |
| `tx_ready` | Output | High while the transmitter is in `TX_IDLE` |
| `tx_out` | Output | Serial output, idle high |

A byte is accepted when `tx_start` and `tx_ready` are both high at a rising
edge of `clk`. The transmitter captures the byte on that edge. Changes to
`tx_data` after acceptance must not affect the active frame.

`tx_ready` is a level indicating the idle/accepting state. It remains low for
the alignment, start, data, and stop states and returns high after the complete
stop-bit interval.

## Receive interface contract

| Signal | Direction | Meaning |
| --- | --- | --- |
| `rx_in` | Input | Asynchronous external serial input |
| `rx_data` | Output | Most recently accepted byte |
| `rx_valid` | Output | One-system-clock completion pulse for a valid frame |
| `rx_busy` | Output | High in START, DATA, and STOP |
| `framing_error` | Output | One-system-clock pulse when the stop bit is invalid |

The external input passes through a two-flip-flop synchronizer. The receiver
uses the majority of three samples around the nominal center of every bit.

A valid stop bit causes `rx_data` to update and `rx_valid` to pulse. A low stop
bit causes `framing_error` to pulse, leaves `rx_valid` low, and preserves the
previous valid `rx_data` value.

## Full-duplex requirement

TX and RX contain independent state machines and storage. Either direction
may be active without blocking the other, and both directions may operate at
the same time.

## Reset behavior

`rst_n` is active low and synchronously sampled by each sequential block. While
reset is observed low:

- the timing accumulator and tick return to zero;
- TX returns to idle, drives `tx_out` high, and reports ready;
- RX returns to idle and clears valid/error pulses and received data;
- the RX synchronizer returns to the idle-high value.
