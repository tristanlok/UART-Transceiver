# UART register-block verification plan

Source: [`tb/reg/`](../../tb/reg/).

## Objective

Verify register decode, one-entry TX/RX storage, simultaneous buffer events,
sticky status, and interrupt arbitration without AXI channel timing obscuring
the functional behavior.

## Bench structure

```text
uart_reg_block_tb
├── uart_reg_block DUT
├── uart_tb_ctrl_if
├── uart_reg_if
├── uart_reset_driver
├── uart_reg_driver
├── uart_reg_monitor
├── uart_reg_scoreboard
└── uart_reg_tests
```

The register driver produces direct one-cycle `read_en` and `write_en` events.
It also models UART-side byte arrival, framing-error pulses, and TX acceptance.

## Tests

### `reg_sanity`

- Writes and reads IER.
- Writes THR and checks the presented TX request/data.
- Models TX acceptance and checks THR-empty status.
- Pushes an RX byte, checks IRQ and RX-ready status, reads RBR, and confirms
  the RX interrupt clears.

### `reg_random_access`

Runs ten randomized directed iterations. It randomizes the four implemented
IER bits, RX data, and TX data. Every iteration checks IER readback, RBR
storage/read, THR request presentation, and TX consumption.

### `reg_negative_access`

- Rejects writes to read-only IIR and LSR.
- Rejects unmapped and misaligned reads/writes.
- Confirms invalid reads return zero with an error.
- Confirms empty RBR returns zero without an error.
- Confirms inactive `WSTRB[0]` causes legal no-op writes.
- Attempts to overwrite a full THR, requires an error, and checks preservation
  of the old byte.

### `reg_buffer_corner_cases`

- Pushes two RX bytes without a read and checks that overrun preserves the
  oldest byte.
- Reads LSR and checks sticky-overrun clearing.
- Performs simultaneous RBR pop/push, requiring the old byte in the current
  read and the new byte in the next read.
- Performs simultaneous THR pop/push, requiring the old byte to be accepted by
  TX and the replacement byte to remain pending.

### `reg_interrupt_priority`

- Creates underlying sources while IER masks them.
- Enables all sources and checks line status (`IIR = 7`) wins.
- Reads LSR and checks RX data (`IIR = 5`) becomes visible.
- Reads RBR and checks THR empty (`IIR = 3`) becomes visible.
- Writes THR and checks IRQ clears when no source remains.
- Disables and re-enables TX interrupt to prove masking does not destroy the
  underlying THR-empty condition.

## Requirement mapping

| Requirement | Primary tests |
| --- | --- |
| Reset values | All through shared reset helper |
| Basic read/write decode | `reg_sanity`, `reg_random_access` |
| Access errors and strobes | `reg_negative_access` |
| Full THR protection | `reg_negative_access` |
| RX overrun policy | `reg_buffer_corner_cases` |
| Simultaneous push/pop | `reg_buffer_corner_cases` |
| Sticky clear behavior | `reg_buffer_corner_cases`, `reg_interrupt_priority` |
| Interrupt masking/priority | `reg_interrupt_priority` |

## Pass criteria

Every direct access must return the specified data/error, buffer handshakes
must preserve the specified old/new values, and IRQ/IIR/LSR must track the
underlying conditions and service operations exactly.
