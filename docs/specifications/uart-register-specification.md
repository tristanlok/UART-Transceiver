# UART register specification

Applicable RTL: [`uart_reg_pkg.sv`](../../rtl/uart_reg_pkg.sv) and
[`uart_reg_block.sv`](../../rtl/uart_reg_block.sv).

## Overview

The peripheral exposes four 32-bit word addresses. Only the implemented low
bits contain information; every reserved read bit returns zero. Address `0x0`
has direction-dependent behavior: reads access the receive buffer and writes
access the transmit holding register.

| Address | Read operation | Write operation | Reset read value |
| ---: | --- | --- | ---: |
| `0x0000_0000` | RBR: Receiver Buffer Register | THR: Transmitter Holding Register | `0x0000_0000` |
| `0x0000_0004` | IER: Interrupt Enable Register | IER | `0x0000_0000` |
| `0x0000_0008` | IIR: Interrupt Identification Register | Error | `0x0000_0000` |
| `0x0000_000C` | LSR: Line Status Register | Error | `0x0000_0002` |

## Receiver Buffer Register: RBR

| Bits | Meaning |
| --- | --- |
| `[7:0]` | Oldest unread received byte |
| `[31:8]` | Reserved, read as zero |

- A valid UART receive completion stores a byte when RBR is empty.
- Reading RBR consumes the pre-edge buffered byte.
- Reading an empty RBR returns zero with an OKAY response.
- If a second byte arrives while RBR is full and no read occurs, the old byte
  is preserved, the new byte is discarded, and sticky overrun is set.
- If a read and new received byte occur on the same edge, the read returns the
  old byte and the new byte becomes the next buffered byte.

## Transmitter Holding Register: THR

| Bits | Meaning |
| --- | --- |
| `[7:0]` | Byte waiting for `uart_tx` |
| `[31:8]` | Ignored |

- A write with `WSTRB[0] = 1` stores the low byte when THR can accept it.
- A write with `WSTRB[0] = 0` is an OKAY no-op.
- THR continuously presents its stored byte and a start request to UART TX
  while full.
- UART TX consumes THR when `uart_tx_start && uart_tx_ready` is true.
- A write to a full THR returns SLVERR if the old byte is not consumed on the
  same edge, and the waiting byte is preserved.
- A simultaneous consume and write transfers the old byte and retains the new
  byte, supporting back-to-back traffic.

## Interrupt Enable Register: IER

| Bit | Name | Effect when set |
| ---: | --- | --- |
| 0 | RX enable | Allow RBR-full to request an interrupt |
| 1 | TX enable | Allow THR-empty to request an interrupt |
| 2 | Framing enable | Allow sticky framing error to request an interrupt |
| 3 | Overrun enable | Allow sticky overrun to request an interrupt |
| `[31:4]` | Reserved | Read as zero |

IER resets to zero, so all interrupt sources are initially masked. Only a
write with `WSTRB[0] = 1` changes IER. Other byte strobes are legal no-ops.

Disabling a source masks its contribution to `irq`; it does not clear the
underlying buffer or sticky status condition.

## Interrupt Identification Register: IIR

| Bits | Meaning |
| --- | --- |
| 0 | Active-high interrupt pending |
| `[2:1]` | Identifier of highest-priority enabled source |
| `[31:3]` | Reserved, read as zero |

| Read value `[2:0]` | Source | Priority |
| ---: | --- | ---: |
| `3'b111` (`0x7`) | Receiver line status | Highest |
| `3'b101` (`0x5`) | Receiver data available | Middle |
| `3'b011` (`0x3`) | Transmitter holding register empty | Lowest |
| `3'b000` (`0x0`) | No enabled source pending | None |

IIR is live combinational status. Reading it does not clear a source. Service
the underlying condition instead:

- read LSR to clear sticky line errors;
- read RBR to clear receive-data-ready;
- write THR to clear THR-empty while the holding register is full.

When a higher-priority source is cleared, the next enabled source becomes
visible immediately.

## Line Status Register: LSR

| Bit | Name | Kind |
| ---: | --- | --- |
| 0 | RX data ready | Live: RBR full |
| 1 | THR empty | Live: THR not full |
| 2 | Framing error | Sticky |
| 3 | Overrun | Sticky |
| `[31:4]` | Reserved | Read as zero |

LSR resets to `0x2` because both buffers are empty and THR-empty is true.
Reading LSR clears only the sticky framing and overrun bits. It does not clear
RX-ready or THR-empty because those are live buffer states. A new hardware
error wins over a simultaneous LSR-read clear.

## Address and response policy

- Accesses must use the exact aligned addresses listed above.
- Misaligned and unmapped reads return zero with SLVERR.
- Misaligned and unmapped writes return SLVERR and have no side effects.
- Writes to IIR or LSR return SLVERR and have no side effects.
- Reading an empty RBR is explicitly legal and returns zero with OKAY.
- AXI protection attributes do not affect the current access policy.

## Simultaneous read and write

Read and write paths may complete on the same clock edge. A simultaneous read
and write of IER returns the old value for the read, while the new value becomes
visible after the edge. At address `0x0`, read and write remain independent
because the read targets RBR and the write targets THR.
