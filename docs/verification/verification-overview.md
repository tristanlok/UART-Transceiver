# Verification architecture and progression

Verification sources: [`tb/`](../../tb/). Build orchestration:
[`Makefile`](../../Makefile).

## Strategy

Verification follows the design hierarchy from smallest block to complete
peripheral. A block is tested directly before its behavior is reused at the
next integration layer.

| Layer | DUT | Testbench top | Test library |
| --- | --- | --- | --- |
| TX | `uart_tx` | `uart_tx_tb` | `uart_tx_tests` |
| RX | `uart_rx` | `uart_rx_tb` | `uart_rx_tests` |
| UART | `uart` | `uart_tb` | `uart_tests` |
| Registers | `uart_reg_block` | `uart_reg_block_tb` | `uart_reg_tests` |
| AXI/register | `uart_axi_lite` | `uart_axi_lite_tb` | `uart_axi_lite_tests` |
| Complete peripheral | `uart_axi_lite` | `uart_axi_system_tb` | `uart_axi_tests` |

This layering answers increasingly broad questions:

```text
Does one state machine work?
  → Do TX and RX coexist?
  → Are register events correct?
  → Does AXI transport those events correctly?
  → Does software-visible traffic reach the serial pins and return?
```

## Component roles

### Interface

A SystemVerilog interface groups signals belonging to one boundary. Modports
document which side may drive or observe them. Interfaces reduce constructor
arguments and prevent unrelated protocol signals from becoming one oversized
bundle.

### Driver

A driver performs protocol mechanics. It turns a request such as “send this
UART byte” or “perform this AXI write” into signal transitions and handshakes.
It should not choose the overall test scenario or decide whether the DUT result
is correct.

### Monitor

A monitor observes without driving. It reconstructs higher-level activity,
such as a serial frame or AXI transaction, from signal behavior. Monitors also
provide bounded state/event waits used by tests.

### Scoreboard

A scoreboard owns comparisons and failure reporting. Expected values are
provided by the test or a reference calculation; observed values come from a
monitor or completed driver transaction.

### Agent

An agent groups reusable components for one protocol endpoint:

```text
axi_lite_agent                 uart_serial_agent
├── driver                     ├── driver
├── monitor                    ├── monitor
└── scoreboard                 └── scoreboard
```

Agents do not contain scenarios. Tests call their components. The reusable
`tb/axi/` and `tb/serial/` directories therefore contain no test files; their
agents are consumed by the suites under `tb/uart_axi/`.

### Environment

An environment composes agents and shared services. `uart_axi_env`, for
example, owns reset, the AXI agent, the serial agent, and integration-level
monitor/scoreboard objects. The test can then express behavior through `env`
without reconstructing wiring.

### Test library and top

A test-library class contains one task per named scenario. The HDL testbench
top instantiates the DUT/interfaces, creates the class objects, reads
`+TEST=<name>`, and dispatches exactly one task.

## Stimulus and checking flow

```text
named test
  → driver call
  → interface pins
  → DUT
  → monitored result
  → scoreboard comparison
  → $error/$fatal on failure
```

For end-to-end TX, two protocols participate:

```text
AXI agent writes THR → DUT → serial agent observes tx_out
```

For end-to-end RX:

```text
serial agent drives rx_in → DUT → AXI agent reads RBR
```

## Timing independence

The DUT uses `baud_generator`. TX monitors and RX/serial drivers use a separate
real-time reference tick calculated from the configured baud rate. This avoids
a self-checking error where both stimulus and DUT repeat the same faulty timing
calculation.

## Reset ownership

`uart_reset_driver` is the only object that drives shared `rst_n`. Protocol
drivers restore their own pins to idle but do not own reset. Tests decide when
reset should happen and use the shared reset driver to perform it.

## Pass/fail model

Scoreboards use case equality so X/Z results do not accidentally compare equal
to binary expectations. Failures call `$error`; unrecoverable setup, timeout,
or final summary failures call `$fatal`. AXI suites aggregate counts from bus,
serial, and integration scoreboards at test completion.

## Current scope boundaries

- Simulation is directed and constrained-random at selected data/delay points.
- No functional covergroups or code-coverage collection target currently
  exists.
- The baud generator is checked indirectly through exact TX timing and all
  serial tests; it has no standalone testbench.
- AXI and serial agents are tested through their consumer environments rather
  than dedicated agent self-test tops.
- The RX suite checks sampling decisions but has no separate exact-duration
  test analogous to TX.
