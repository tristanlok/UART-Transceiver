# Running, debugging, and extending verification

Command definitions: [`Makefile`](../../Makefile).

## Prerequisites

The Makefile expects:

- Verilator for linting and simulation;
- a C++ compiler used by Verilator;
- GTKWave for interactive VCD viewing.

Commands are intended to run from the repository root.

## Run one test

```bash
make tx-sim TEST=tx_exact_bit_duration
make rx-sim TEST=rx_data_majority_vote
make reg-sim TEST=reg_buffer_corner_cases
make uart-sim TEST=uart_duplex_sanity
make axi-sim TEST=axi_write_channel_order
make axi-uart-sim TEST=axi_uart_full_duplex
```

Without `TEST=...`, each target uses its suite's default sanity test.

## Run complete suites

```bash
make tx-sim-all
make rx-sim-all
make reg-sim-all
make uart-sim-all
make axi-sim-all
make axi-uart-sim-all
```

An `*-sim-all` target builds once and runs the suite's named tests concurrently.
Every test receives its own log and waveform.

## Lint each design/bench layer

```bash
make lint SIM_TOP=uart_tx_tb
make lint SIM_TOP=uart_rx_tb
make lint SIM_TOP=uart_reg_block_tb
make lint SIM_TOP=uart_tb
make lint SIM_TOP=uart_axi_lite_tb
make lint SIM_TOP=uart_axi_system_tb
```

The first lint invocation checks the selected synthesizable RTL top with strict
warnings. The second also compiles the matching timed testbench and classes.

## Artifacts

```text
build/<SIM_TOP>/V<SIM_TOP>
build/logs/<SIM_TOP>_<TEST>.log
build/waves/<SIM_TOP>_<TEST>.vcd
```

For example:

```text
build/logs/uart_axi_system_tb_axi_uart_full_duplex.log
build/waves/uart_axi_system_tb_axi_uart_full_duplex.vcd
```

## Open a waveform

Use the same top and test that generated the VCD:

```bash
make wave SIM_TOP=uart_tb TEST=uart_duplex_sanity
```

Or open the file directly:

```bash
gtkwave build/waves/uart_tb_uart_duplex_sanity.vcd
```

If a regression was run, make sure you select the per-test filename rather
than a default waveform from a different test.

## Clean generated artifacts

```bash
make clean
```

This removes the complete `build/` directory, including binaries, logs, and
waves. Preserve anything you want to keep before cleaning.

## Debugging order

When a test fails:

1. Read the first `$error` or `$fatal`, not only the final summary.
2. Use its simulation time, filename, line, scope, and owner prefix.
3. Open the matching waveform and move to that time.
4. Identify the failing boundary: driver-to-DUT, internal DUT, or DUT-to-monitor.
5. Re-run the single test before running the complete regression.
6. After fixing it, run the owning leaf suite and every integration suite above
   it.

For example, after changing RX:

```bash
make rx-sim-all
make uart-sim-all
make axi-uart-sim-all
```

After changing register behavior:

```bash
make reg-sim-all
make axi-sim-all
make axi-uart-sim-all
```

## Add a new test

1. Add one task to the owning test-library class.
2. Add its string to the `case` statement in the matching testbench top.
3. Add the same string to the matching `*_TESTS` Makefile variable.
4. Put scenario choices in the test, pin mechanics in the driver, observation
   in the monitor, and comparisons in the scoreboard.
5. Run the new test alone, lint its top, then run the complete owning suite.

Missing any one of the first three registration points can create a test that
exists in source but is never selected by regressions.

## Timeouts and reproducibility

The two AXI-oriented tops contain a 20 ms global watchdog. Lower-level benches
mainly rely on bounded helper waits; if a newly added monitor waits forever,
give the scenario a timeout so a DUT failure produces a useful result instead
of a hung simulation.

Random data currently comes from `$urandom`. When debugging an intermittent
failure, record the simulator seed from your invocation or temporarily replace
the randomized value with the failing value so the case can be replayed.
