# Complete AXI-UART system verification plan

Sources: [`tb/uart_axi/`](../../tb/uart_axi/),
[`tb/axi/`](../../tb/axi/), and [`tb/serial/`](../../tb/serial/).

## Objective

Verify complete paths crossing multiple design boundaries:

```text
software write → AXI → THR → UART TX → tx_out
rx_in → UART RX → RBR/interrupt → AXI read → software data
```

This is not a replacement for leaf verification. It checks that already-tested
pieces are wired together correctly and that simultaneous bus, serial, buffer,
error, IRQ, and reset behavior remains coherent.

## Environment

```text
uart_axi_system_tb
├── uart_axi_lite DUT
├── AXI interface
├── serial interface
├── IRQ interface
├── system clock and independent serial reference timing
├── uart_axi_env
│   ├── reset driver
│   ├── AXI agent
│   ├── serial agent
│   ├── integration monitor
│   └── integration scoreboard
└── uart_axi_tests
```

The AXI/register and full-system tops each instantiate their own physical DUT,
interfaces, clocks, and reference timing. They reuse the same environment and
protocol agents, while keeping all physical wiring visible in the owning
testbench file.

## Tests

### `axi_uart_tx_path`

Runs five randomized software-to-pin transfers. It rotates AW-before-W,
W-before-AW, and same-cycle write ordering. Each THR write must return OKAY,
and the serial monitor must decode the same byte with valid start and stop
bits.

### `axi_uart_rx_path`

Enables RX-data interrupt and sends five randomized serial frames. For each it
waits for IRQ, checks the IIR RX indication, reads the expected RBR byte,
requires IRQ to clear after the pop, and finally confirms LSR reports an empty
receive buffer.

### `axi_uart_full_duplex`

Creates three different TX and RX values and runs both directions concurrently.
It checks every emitted TX frame and every received RBR byte, confirms actual
physical overlap of TX and RX activity, and requires empty buffers afterward.

### `axi_uart_buffers_errors_irq`

The TX phase starts one byte, queues a second in THR, and attempts a third. The
third must return SLVERR; the first two must emerge in order. The test then
enables interrupts, injects a bad stop bit, checks framing status and line-
status priority, and confirms the bad byte never reaches RBR. Finally it sends
two valid bytes without an intervening read and checks overrun, first-byte
preservation, and interrupt-source sequencing.

### `axi_uart_reset_recovery`

Starts TX and RX activity, creates stalled B and R responses, and resets. It
requires both response-valid signals, IRQ, and serial TX state to reset with no
stale response after release. A second reset discards an AW-only partial write.
New RX and TX operations must then both succeed.

## End-to-end requirement mapping

| Requirement | Test |
| --- | --- |
| AXI write reaches serial TX | `axi_uart_tx_path` |
| Serial RX reaches AXI read | `axi_uart_rx_path` |
| Interrupt assertion/service | `axi_uart_rx_path`, `axi_uart_buffers_errors_irq` |
| Concurrent full duplex | `axi_uart_full_duplex` |
| THR buffering/full rejection | `axi_uart_buffers_errors_irq` |
| Framing/overrun propagation | `axi_uart_buffers_errors_irq` |
| Reset cancels partial work | `axi_uart_reset_recovery` |
| Post-reset functionality | `axi_uart_reset_recovery` |

## Pass criteria

Data must remain identical across every complete software-to-pin or
pin-to-software path. Response codes, ordering, buffer preservation, status,
IRQ, overlap, reset cancellation, and recovery must all match their documented
policies. The top-level watchdog must not expire.
