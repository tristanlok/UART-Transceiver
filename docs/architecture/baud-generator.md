# Baud generator architecture

Source: [`rtl/baud_generator.sv`](../../rtl/baud_generator.sv).

## Responsibility

`baud_generator` converts the system clock into a one-cycle timing enable at
`BAUD_RATE × OVERSAMPLE`. Both UART directions consume the same enable.

Despite the signal name, `baud_tick` is the oversampling tick. TX and RX each
count 16 ticks to form one serial-bit period.

## Parameters and ports

| Name | Kind | Default | Purpose |
| --- | --- | ---: | --- |
| `CLOCK_HZ` | Parameter | 100,000,000 | Input clock frequency |
| `BAUD_RATE` | Parameter | 115,200 | Required serial bit rate |
| `` `OVERSAMPLE `` | Macro | 16 | Enables per serial bit |
| `clk` | Input | — | System clock |
| `rst_n` | Input | — | Synchronous active-low reset |
| `baud_tick` | Output | — | One-clock-wide 16x timing enable |

## Why an integer divider is insufficient

At the defaults:

```text
oversampling frequency = 115200 × 16 = 1,843,200 Hz
clocks per tick         = 100,000,000 / 1,843,200
                        ≈ 54.253472 clocks
```

An integer counter would have to choose 54 or 55 clocks every time and would
produce a biased rate. The fractional accumulator distributes the tick across
nearby integer intervals while preserving the required average frequency.

## Accumulator operation

Each clock computes:

```text
accumulator_sum = accumulator + (BAUD_RATE × OVERSAMPLE)
```

Then:

- if the sum is below `CLOCK_HZ`, retain the sum and leave `baud_tick` low;
- if it reaches or exceeds `CLOCK_HZ`, subtract `CLOCK_HZ`, retain the
  remainder, and pulse `baud_tick` high for that clock.

This is a phase-accumulator or numerically controlled oscillator pattern. The
retained remainder is what prevents long-term fractional error.

## Default timing

| Quantity | Approximate value |
| --- | ---: |
| Tick frequency | 1.8432 MHz |
| Tick period | 542.535 ns |
| Ticks per UART bit | 16 |
| UART bit period | 8.68056 us |
| System clocks per UART bit | 868.056 |

Individual tick gaps vary by approximately one system-clock period, but the
average phase remains correct.

## Sizing

`ACC_WIDTH` is based on `$clog2(CLOCK_HZ)`, with a minimum width of one bit.
`SUM_WIDTH` provides the extra carry bit required by the addition. Sized casts
make truncation points explicit and keep lint from treating intentional width
conversion as an accidental mismatch.

## Reset

On a rising edge where `rst_n` is low:

- `accumulator` becomes zero;
- `baud_tick` becomes zero;
- the internal oversample counter becomes zero.

The current `oversample_count` rolls over every `OVERSAMPLE` ticks but has no
functional fanout. TX and RX perform the meaningful divide-by-16 themselves.
It can be removed in a future RTL cleanup without changing the external
behavior; it is retained here because this documentation describes the live
implementation.

## Assumptions

The intended configuration has `CLOCK_HZ >= BAUD_RATE × OVERSAMPLE` and uses
an oversampling ratio large enough for RX's three center samples. Those
relationships are design assumptions rather than elaboration-time checks.
