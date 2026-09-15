# System architecture

Source directories: [`rtl/`](../../rtl/) and [`tb/`](../../tb/).

## Learning progression

The repository is organized around the same sequence used to build the
project:

```text
Timing generation
    ↓
Standalone transmitter
    ↓
16x-oversampled receiver
    ↓
Full-duplex UART core
    ↓
Software-visible register block
    ↓
AXI-Lite UART peripheral
```

Each step has its own simulation layer. This is useful both educationally and
practically: a failure can first be isolated to a small block and then checked
again at the integration boundary.

## RTL hierarchy

```text
uart_axi_lite
├── uart_reg_block
└── uart
    ├── baud_generator
    ├── uart_tx
    └── uart_rx
```

`uart_reg_pkg` supplies the register addresses and bit indices used by the
register block and verification code. `uart_config.svh` supplies the UART data
width and oversampling ratio.

## Source ownership

| Directory | Owns |
| --- | --- |
| `rtl/` | Synthesizable design modules, package, and design configuration |
| `tb/common/` | Shared reset/control infrastructure and DV logging |
| `tb/tx/`, `tb/rx/` | Standalone UART block verification |
| `tb/uart/` | Integrated, non-AXI UART verification |
| `tb/reg/` | Direct register-block verification |
| `tb/axi/` | Reusable AXI-Lite master components |
| `tb/serial/` | Reusable external UART peer components |
| `tb/uart_axi/` | Self-contained AXI-oriented tops, shared environment, and tests |
| `docs/` | Architecture, requirements, and verification plans |

## Data paths

### Software-to-serial transmit

```text
AXI AW/W
  → uart_axi_lite channel storage
  → uart_reg_block THR
  → uart_tx parallel handshake
  → tx_out serial frame
```

The THR is a one-byte staging element. It decouples an AXI write from the
instant at which the transmitter becomes ready.

### Serial-to-software receive

```text
rx_in
  → two-flip-flop synchronizer
  → uart_rx majority sampling
  → uart_reg_block RBR
  → AXI read response
```

The RBR is also one byte. Because UART RX cannot be backpressured, a new byte
arriving while RBR is full is discarded and recorded as overrun.

### Interrupt path

```text
buffer/error state
  → interrupt enable mask
  → priority encoder / IIR
  → irq
```

IRQ is not a separately stored event. It is derived from enabled underlying
conditions, which makes its clearing behavior explicit.

## Clocking and timing

Every design block is synchronous to `clk`. The external UART input is
asynchronous and is synchronized before use. A fractional accumulator creates
a shared 16x timing enable. TX and RX independently count those enables, so
they can operate concurrently while remaining configured to the same baud
rate.

The verification serial peer deliberately uses its own reference timing. It
does not use the DUT's internal tick to decide whether the DUT timing is
correct.

## Reset model

`rst_n` is active low. Sequential state resets on a rising `clk` edge while
`rst_n` is low. The same reset reaches AXI channel storage, registers, timing,
TX, and RX. Testbench reset ownership is centralized in
`uart_reset_driver`, preventing multiple protocol drivers from competing to
drive the same signal.

## Configuration boundary

`rtl/uart_config.svh` contains only hardware configuration:

```systemverilog
`define DATA_BITS 8
`define OVERSAMPLE 16
```

`tb/common/uart_tb_log.svh` contains simulation-only logging. Keeping those
headers separate prevents verification facilities from becoming part of the
design configuration boundary.
