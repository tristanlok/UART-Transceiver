# AXI-Lite peripheral interface specification

Applicable RTL: [`uart_axi_lite.sv`](../../rtl/uart_axi_lite.sv).

## Scope

`uart_axi_lite` is a 32-bit AXI-Lite slave wrapped around the UART register
block and serial core. It supports independent read and write operation with a
maximum of one outstanding read response and one outstanding write response.

## Interface configuration

| Item | Implemented value |
| --- | --- |
| Address width | Parameterized, default 32 bits |
| Data width | Parameterized, default 32 bits |
| Strobe width | `AXI_DATA_WIDTH / 8`, default 4 |
| Write responses | OKAY or SLVERR |
| Read responses | OKAY or SLVERR |
| Outstanding writes | One |
| Outstanding reads | One |
| AW/W arrival order | Either order or same cycle |
| Concurrent read/write | Supported |

## Transfer rule

Every AXI channel transfers only on a rising edge where both `VALID` and
`READY` are high. Holding `VALID` without `READY` does not complete a transfer.

## Write transaction

AXI-Lite write address and data are independent. The slave stores accepted AW
and W payloads separately. After both are present, it presents one write event
to the register block and captures the resulting response.

```text
AW handshake ─┐
              ├─ both collected → register write → B response
W handshake ──┘
```

The supported orderings are:

- AW before W;
- W before AW;
- AW and W on the same clock edge.

While `BVALID` is waiting for `BREADY`, another AW or W component is not
accepted. `BVALID` and `BRESP` retain the stored response until its handshake.

## Read transaction

The slave accepts AR when there is no pending read response. At the AR
handshake, it snapshots register `read_data` and `read_error` into the R
channel registers.

```text
AR handshake → register snapshot/side effect → R response
```

The snapshot is important for read side effects. For example, an RBR read can
consume the buffered byte immediately while the captured `RDATA` remains
available until the master accepts it. While `RVALID` is pending, another read
address is not accepted.

## Read/write independence

The read and write channel groups use separate state. They may progress on the
same edge, including while one response is backpressured. This is required for
full AXI-Lite read/write independence even though each direction permits only
one outstanding response.

## Reset behavior

When `rst_n` is low:

- AW and W pending flags are cleared;
- partially collected writes are discarded;
- `BVALID` and `RVALID` are cleared;
- response codes and read data return to their reset values;
- channel READY outputs are suppressed;
- the register block, UART core, and IRQ are reset through the same signal.

After reset is released and no response is pending, AWREADY, WREADY, and
ARREADY become available.

## Access errors

The wrapper maps the register block's `write_error` and `read_error` to
SLVERR. Legal accesses return OKAY. The exact register, alignment, strobe, and
buffer-full policies are defined in
[the register specification](uart-register-specification.md).

## Current boundaries

- `AWPROT` and `ARPROT` are accepted but do not alter behavior.
- No burst, ID, or outstanding-transaction queue exists; those belong to full
  AXI rather than this AXI-Lite peripheral.
- The interface deliberately favors simple, explicit behavior over maximum
  bus throughput.
