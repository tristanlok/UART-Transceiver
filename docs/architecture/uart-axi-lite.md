# AXI-Lite UART architecture

Source: [`rtl/uart_axi_lite.sv`](../../rtl/uart_axi_lite.sv).

## Responsibility

`uart_axi_lite` is the complete peripheral boundary. It translates AXI-Lite
channel traffic into the register block's simple request interface and joins
that block to the full-duplex UART core.

## Hierarchy

```text
uart_axi_lite
├── AXI write-channel collection and B response
├── AXI read-address acceptance and R response
├── uart_reg_block
└── uart
    ├── baud_generator
    ├── uart_tx
    └── uart_rx
```

## Why the AXI layer and register layer are separate

AXI-Lite answers protocol questions:

- When did AW, W, or AR handshake?
- What must remain stored during backpressure?
- When may the next request be accepted?
- Which response code goes on B or R?

The register block answers functional questions:

- What does an address mean?
- Is the register writable?
- What happens when a buffer is full?
- Which read has a side effect?
- Which interrupt is highest priority?

Keeping these concerns separate avoids embedding UART policy throughout five
AXI channels.

## Write-channel architecture

AXI-Lite does not require AW and W to arrive together. The wrapper therefore
stores them independently:

| Storage | Captured on |
| --- | --- |
| `awaddr_reg`, `aw_pending` | `AWVALID && AWREADY` |
| `wdata_reg`, `wstrb_reg`, `w_pending` | `WVALID && WREADY` |

When both pending flags are high and no B response is outstanding,
`reg_write_en` becomes a one-cycle register request. On that edge:

- the register block applies any legal side effect;
- the wrapper samples `reg_write_error`;
- pending flags clear;
- `BVALID` is set with OKAY or SLVERR.

The response remains registered until `BVALID && BREADY`.

## Read-channel architecture

ARREADY is available only when no R response is outstanding. An
`ARVALID && ARREADY` handshake directly creates `reg_read_en`. The wrapper
captures the combinational register data and error into `RDATA` and `RRESP`
and raises `RVALID`.

This ordering gives read-to-clear and pop registers correct semantics:

```text
1. observe old register value;
2. capture it into the AXI response;
3. apply the register side effect at the same edge;
4. retain the captured response until RREADY.
```

## Backpressure

Registered B and R payloads isolate responses from later UART/register
changes. While the master stalls a response:

- no second request of that direction is accepted;
- the response data/code remains the captured transaction result;
- the opposite direction can continue independently.

## UART integration

The register block's THR output drives the UART transmit handshake. The UART
receiver's valid byte and framing-error pulse feed the register block. RX busy
is currently observed only as an intentionally unused internal status, while
the external peripheral exposes `rx_in`, `tx_out`, and `irq`.

## Ignored fields

`AWPROT` and `ARPROT` are accepted but do not affect the register policy. The
RTL consumes them through an intentional unused-input reduction so strict lint
does not confuse a defined no-op policy with accidental omission.

## Reset

The single reset clears:

- partial AW and W collection;
- pending B and R responses;
- captured response payloads;
- register and buffer state;
- UART timing and serial state;
- interrupt state.

READY outputs are gated low while reset is active. After release, an empty
wrapper is immediately available for new AW, W, and AR transfers.
