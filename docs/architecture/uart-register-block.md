# UART register-block architecture

Sources: [`rtl/uart_reg_block.sv`](../../rtl/uart_reg_block.sv) and
[`rtl/uart_reg_pkg.sv`](../../rtl/uart_reg_pkg.sv).

## Responsibility

`uart_reg_block` owns software-visible UART state and converts simple one-cycle
read/write requests into register behavior. It does not implement AXI channel
handshakes. Separating it from `uart_axi_lite` makes buffer collisions,
interrupts, and register semantics directly testable.

## Boundaries

```text
bus wrapper
  ↕ write_en/address/data/strobe
  ↕ read_en/address/data/error
uart_reg_block
  ↕ uart_tx_data/start/ready
  ↕ uart_rx_data/valid/framing_error
  → irq
```

## Physical storage versus software width

Software accesses 32-bit words, but the hardware stores only implemented
fields:

| Function | Stored width |
| --- | ---: |
| RBR data | `DATA_BITS` |
| THR data | `DATA_BITS` |
| IER | 4 bits |
| Sticky error state | 2 bits |
| IIR | Combinational, 3 bits |
| LSR | Combinational, 4 bits |

Reserved read bits are filled with zero. This is more efficient than building
unnecessary 32-bit registers.

## Decode layer

The combinational decode determines:

- whether a write is legal;
- whether a read is legal;
- the pre-edge read data;
- RBR pop and THR write-request events;
- LSR read-to-clear events.

Exact address comparison enforces alignment: offsets such as `0x1` and `0x2`
do not alias an aligned register.

## Transmit holding path

```text
AXI/register write → tx_holding_data + thr_full
                         ↓
              uart_tx_data / uart_tx_start
                         ↓
             uart_tx_ready handshake → pop
```

While `thr_full` is high, `uart_tx_start` stays high and the stored data remains
stable. `thr_pop` occurs when the transmitter is ready to accept that request.

The sequential update considers push and pop together:

| Pop | Write request | Result |
| ---: | ---: | --- |
| 0 | 0 | Hold current state |
| 0 | 1 | Store only if not already full |
| 1 | 0 | Clear full |
| 1 | 1 | Transfer old data, store replacement, remain full |

A full/no-pop write reports an error and does not overwrite the waiting byte.
The simultaneous case avoids an unnecessary empty cycle.

The LSR THR-empty bit describes this holding register. It can become true as
soon as UART TX accepts the byte even though that byte is still being shifted
on the wire.

## Receive buffering path

```text
uart_rx_valid/data → rx_buffer_data + rbr_full → software read
                              ↓
                       overrun detection
```

The receiver cannot wait for software. The update policy is therefore:

| Initial/event combination | Result |
| --- | --- |
| Empty plus new byte | Store new byte and become full |
| Full plus read | Return old byte and become empty |
| Full plus new byte without read | Preserve old byte, discard new, set overrun |
| Full plus read and new byte | Return old byte, store new byte, remain full |
| Empty plus read and new byte | Read returns zero; new byte is stored for next read |

The bus wrapper snapshots `read_data` when accepting the read, so the
register block may apply the pop without changing a response that is stalled
later.

## Sticky error state

`uart_framing_error` and `overrun_event` are pulses, but software may not read
LSR in that cycle. The register block stretches them into sticky bits.

Update priority is:

```text
reset → new hardware event → LSR read clear → hold
```

Hardware-set priority prevents a new error from disappearing when software
reads LSR on the same edge.

## Live status

LSR is assembled combinationally:

```text
bit 3 = overrun_sticky
bit 2 = framing_error_sticky
bit 1 = not thr_full
bit 0 = rbr_full
```

Only error bits are sticky. Buffer status always reflects the current storage
state.

## Interrupt arbitration

Each condition is first masked by its IER bit. A priority encoder selects:

```text
line status > RX data ready > THR empty
```

The IIR value and `irq` are derived rather than stored. Reading IIR only
observes the current winning source. Software clears or masks the underlying
condition instead.

## Reset

Reset empties RBR and THR, clears their data, disables every interrupt, clears
sticky errors, and deasserts IRQ. Since THR is empty, the post-reset LSR value
is `0x2`.
