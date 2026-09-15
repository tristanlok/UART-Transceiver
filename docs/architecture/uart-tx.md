# UART transmitter architecture

Source: [`rtl/uart_tx.sv`](../../rtl/uart_tx.sv).

## Responsibility

`uart_tx` accepts one parallel byte and serializes it as an 8N1 frame. It owns
the active byte, bit counters, FSM, and serial output. Buffering before this
block belongs to `uart_reg_block`, not the transmitter itself.

## Interface

| Signal | Direction | Description |
| --- | --- | --- |
| `clk` | Input | System clock |
| `rst_n` | Input | Synchronous active-low reset |
| `baud_tick` | Input | 16x one-cycle timing enable |
| `data_in` | Input | Parallel byte to capture |
| `tx_start` | Input | Request to accept `data_in` |
| `tx_ready` | Output | High while the FSM is idle |
| `tx_out` | Output | UART serial output |

Acceptance occurs at a rising clock edge where both `tx_start` and `tx_ready`
are high. `data_shift_reg` captures `data_in` on that edge, isolating the frame
from later changes on the live input.

## State machine

```text
TX_IDLE → TX_ALIGN → TX_START → TX_DATA → TX_STOP → TX_IDLE
```

| State | Serial value | Exit condition |
| --- | --- | --- |
| `TX_IDLE` | 1 | A request is accepted |
| `TX_ALIGN` | 1 | First following `baud_tick` |
| `TX_START` | 0 | 16 timing ticks |
| `TX_DATA` | Current LSB | Eight groups of 16 ticks |
| `TX_STOP` | 1 | 16 timing ticks |

`TX_ALIGN` makes the start-bit boundary coincide with a timing tick. Without
it, the time from request acceptance to the first timing event would be folded
into the start bit and could shorten that bit.

## Counters

`bclk_curr_count` counts timing enables inside one serial bit. It returns to
zero after `OVERSAMPLE` events. `data_curr_count` counts completed data bits.
Both next values are combinational; their current values are registers updated
in the sequential block.

## Data shifting

During `TX_DATA`, the output is:

```systemverilog
tx_out = data_shift_reg[0];
```

At the end of each data-bit period the shift register moves right. That sends
bit zero first, as required by UART, and exposes the next bit at index zero.

## Output decoding

The output decoder only drives low in `TX_START` or according to the shift
register in `TX_DATA`. Every other state drives high. This naturally produces
the idle and stop levels and gives a safe high output for unexpected state
recovery.

`tx_ready` is combinationally true only in `TX_IDLE`. It is not a completion
pulse; it is an availability level.

## Held requests and busy requests

- A request presented while busy is not accepted.
- If `tx_start` remains high until the transmitter returns to idle, a new
  acceptance can occur in that idle cycle.
- The register block avoids accidental repetition by removing its start
  request when the stored THR byte is accepted.

## Reset and recovery

Reset returns the state to `TX_IDLE` and clears counters and captured data.
Because the outputs are decoded from state, reset also yields `tx_out = 1` and
`tx_ready = 1`. A reset during any frame aborts that frame; transmission does
not resume from the interrupted state after reset is released.
