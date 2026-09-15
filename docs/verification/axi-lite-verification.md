# AXI-Lite and register integration verification plan

Sources: [`tb/axi/`](../../tb/axi/) and
[`tb/uart_axi/`](../../tb/uart_axi/).

## Objective

Verify that `uart_axi_lite` transports legal and illegal register operations
through AXI-Lite correctly. This layer focuses on channel ordering,
backpressure, concurrent directions, response codes, and register snapshots.
Complete serial data paths are covered by the next verification layer.

## Reusable components

The tests use `axi_lite_agent`, which owns:

- `axi_lite_driver` for AW, W, B, AR, and R mechanics;
- `axi_lite_monitor` for passive transaction reconstruction;
- `axi_lite_scoreboard` for completion, response, data, and observed ordering.

`uart_axi_lite_tb` directly instantiates the DUT, interfaces, system clock, and
independent serial reference timing. `uart_axi_env` receives those local
interfaces and supplies reset, AXI and serial agents, and integration-level
checking. The serial input remains idle except where a test checks that a THR
no-op does not begin transmission.

The corresponding system top also contains its own physical instantiations.
The class-based environment and agents remain reusable between the two tops.

## Tests

### `axi_reset_basic_map`

- Checks READY/VALID and IRQ while reset is active.
- Checks AWREADY, WREADY, and ARREADY after reset.
- Reads reset values of RBR, IER, IIR, and LSR.
- Writes all IER word bits and verifies only implemented low bits read back.

### `axi_write_channel_order`

Executes AW-before-W, W-before-AW, and same-cycle AW/W writes with intentional
gaps. The passive monitor reconstructs the observed order, the scoreboard
checks the response and order, and an IER read confirms the side effect.

### `axi_response_backpressure`

Stalls BREADY for six cycles and RREADY for ten cycles. During the stalled IER
read, another write changes the live register. The pending read response must
retain its older snapshot; a later read must see the new value.

### `axi_negative_and_strobes`

- Requires SLVERR for writes to IIR/LSR.
- Requires SLVERR and zero data for unmapped/misaligned reads.
- Requires SLVERR for unmapped/misaligned writes.
- Confirms an empty RBR read is legal and returns zero.
- Confirms upper-byte-only IER and unstrobed THR writes are OKAY no-ops.
- Confirms the THR no-op leaves the serial output idle and THR empty.

### `axi_concurrent_read_write`

Starts an IER read and write concurrently. The read must capture the old value
while the write completes independently and becomes visible afterward. It then
leaves an AW-only partial request pending, proves unrelated reads still work
and no B response appears early, supplies W later, and checks completion.

## Requirement mapping

| AXI behavior | Test |
| --- | --- |
| Reset gating and basic map | `axi_reset_basic_map` |
| Independent AW/W arrival | `axi_write_channel_order` |
| B and R backpressure | `axi_response_backpressure` |
| Stable read snapshot | `axi_response_backpressure` |
| Error response policy | `axi_negative_and_strobes` |
| Strobe/no-op policy | `axi_negative_and_strobes` |
| Concurrent read/write | `axi_concurrent_read_write` |
| Partial write collection | `axi_concurrent_read_write` |

## Pass criteria

Every driven transaction must complete within driver timeouts with the expected
OKAY/SLVERR code and data. Monitored ordering and snapshot behavior must match
the requested scenario, and invalid/no-op operations must have no unintended
UART or register side effect.
