# UART receiver architecture

Source: [`rtl/uart_rx.sv`](../../rtl/uart_rx.sv).

## Responsibility

`uart_rx` converts an asynchronous serial 8N1 frame into a parallel byte. It
synchronizes the input, validates the start bit, takes three center samples per
bit, performs majority voting, checks the stop bit, and emits one-cycle result
pulses.

## Interface

| Signal | Direction | Description |
| --- | --- | --- |
| `clk` | Input | System clock |
| `rst_n` | Input | Synchronous active-low reset |
| `baud_tick` | Input | 16x one-cycle timing enable |
| `rx_in` | Input | Asynchronous UART input |
| `data_out` | Output | Last successfully received byte |
| `rx_valid` | Output | One-clock valid-frame pulse |
| `rx_busy` | Output | High outside IDLE |
| `framing_error` | Output | One-clock bad-stop-bit pulse |

## Clock-domain crossing

The external input first passes through:

```text
rx_in → rx_meta → rx_sync → FSM and sampler
```

`rx_meta` may experience metastability. The second stage substantially reduces
the probability that metastability reaches the receiver logic. Both registers
carry the `ASYNC_REG` implementation attribute and reset high to match the
idle line.

## State machine

```text
RX_IDLE → RX_START → RX_DATA → RX_STOP → RX_IDLE
                ↘ false start ↗
```

| State | Purpose |
| --- | --- |
| `RX_IDLE` | Wait for synchronized low level |
| `RX_START` | Verify that the possible start bit remains mostly low |
| `RX_DATA` | Collect `DATA_BITS` majority-voted data bits |
| `RX_STOP` | Require a majority-high stop bit |

`rx_busy` is defined as `curr_state != RX_IDLE`, so it is high throughout
START, DATA, and STOP.

## Three-sample majority vote

For the default 16x configuration, the sample registers capture at internal
counter values 6, 7, and 8. Since counting starts at zero, these correspond to
the seventh, eighth, and ninth timing events around the bit center.

```text
sample 1 ─┐
sample 2 ─┼─ majority vote → decoded bit
sample 3 ─┘
```

The Boolean implementation is:

```text
(data_1 and data_2) or
(data_1 and data_3) or
(data_2 and data_3)
```

Any two matching samples determine the result. A single disturbed center
sample therefore does not change the decoded bit.

## Start-bit validation

Seeing `rx_sync = 0` in IDLE begins a possible frame. RX then samples the start
bit. A majority-low result confirms it and advances to data. A majority-high
result identifies a short low pulse or false start and returns directly to
IDLE without producing valid or error output.

## Data assembly

UART data arrives LSB first. At the end of each bit period, the majority result
is inserted at the MSB side of `data_shift_reg`:

```systemverilog
{majority_vote, data_shift_reg[DATA_BITS-1:1]}
```

Repeated rightward movement reconstructs the original byte after all bits
arrive. The data output is not updated yet; the stop bit must first validate
the complete frame.

## Stop-bit decision

At the end of STOP:

- majority high copies the shift register to `data_out` and pulses `rx_valid`;
- majority low pulses `framing_error`, leaves `rx_valid` low, and preserves
  the preceding valid `data_out`.

Both result pulses default low on every non-reset clock and are raised only on
their respective completion event. They therefore last one system-clock
cycle, not an entire UART bit.

## Reset and recovery

Reset returns the FSM and counters to zero/IDLE, clears sample storage and the
data shift register, clears both result pulses and `data_out`, and sets the
synchronizer to idle high. A valid frame after reset starts from a completely
new receive operation.

## Configuration assumptions

The practical supported configuration is eight data bits with 16x
oversampling. Very small oversampling ratios do not provide the three sample
positions used by the expressions `OVERSAMPLE/2-2` through `OVERSAMPLE/2`.
