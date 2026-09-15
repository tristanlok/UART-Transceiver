# UART-Transceiver

## Functional Requirements

The design shall implement a fixed-configuration, full-duplex UART transceiver
with independent transmit and receive paths.

### UART Configuration

| Parameter | Requirement |
| --- | --- |
| System clock | 100 MHz |
| Baud rate | 115200 baud, fixed |
| Data bits | 8 |
| Parity | None |
| Stop bits | 1 |
| Frame format | 8N1: 1 start bit, 8 data bits, and 1 stop bit |
| Bit order | Least-significant bit first |
| Idle level | Logic high |

At 115200 baud, one UART bit lasts approximately `8.6806 us`, or `868.0556`
cycles of the 100 MHz system clock. The baud-timing implementation shall
account for the non-integer number of clock cycles per bit.

### Transmitter (`uart_tx`)

- The transmitter shall operate synchronously in the 100 MHz `clk` domain.
- The serial `tx` output shall idle at logic high when no frame is being sent.
- Each accepted byte shall be transmitted as one 8N1 frame: a logic-low start
  bit, eight data bits least-significant bit first, and one logic-high stop bit.
- Every transmitted bit shall be held for one nominal baud period.
- The transmitter shall be able to operate at the same time as the receiver.

The transmit clock path is:

```text
100 MHz clk -> uart_tx -> tx pin
```

### Receiver (`uart_rx`)

- The external `rx` input shall be treated as asynchronous to the 100 MHz
  system clock.
- The `rx` input shall pass through a synchronizer containing at least two
  flip-flops before it is used by the receiver logic. Edge detection shall be
  performed on the synchronized signal.
- While idle, the receiver shall wait for a high-to-low transition indicating
  a possible start bit.
- After detecting the transition, the receiver shall wait approximately half
  of one baud period and sample the center of the start bit. A high sample
  shall reject the transition as a false start.
- After validating the start bit, the receiver shall sample each data bit at
  its nominal midpoint, one baud period apart.
- The receiver shall assemble eight sampled data bits, least-significant bit
  first, into one received byte.
- The stop bit shall be sampled at its nominal midpoint. If it is low, the
  receiver shall report a framing error for that frame.
- The receiver shall be able to operate at the same time as the transmitter.

The receive clock-domain path is:

```text
external UART -> rx pin -> 2+ flip-flop synchronizer -> uart_rx logic (100 MHz clk domain)
```

### Full-Duplex Operation

The transmit and receive paths shall have independent control and state. An
active transmission shall not prevent reception, and an active reception shall
not prevent transmission.

## Repository layout

```text
rtl/          Synthesizable UART, register, and AXI-Lite design
tb/           Layered simulation testbenches and reusable verification code
docs/         Architecture, specification, and per-layer verification plans
```

Use the [system architecture](docs/architecture/system-overview.md) as the
starting point, then continue through the [specifications](docs/specifications/)
and [verification plans](docs/verification/). These cover every RTL block,
every verification layer, and all commands.

## Simulation and lint

Run all six simulation suites with:

```sh
make tx-sim-all
make rx-sim-all
make uart-sim-all
make reg-sim-all
make axi-sim-all
make axi-uart-sim-all
```

See [running and debugging tests](docs/verification/running-tests.md) for
single-test commands, lint targets, logs, waveforms, and extension steps.

The verification environment is simulation based. Formal-verification and
assertion-specific infrastructure are intentionally not part of this project.
