// The interrupt pin is neither an AXI channel nor a UART serial wire. Giving
// it a small interface keeps ownership explicit and avoids hierarchy peeks in
// reusable tests.
interface uart_irq_if;
    logic irq;

    modport monitor (
        input irq
    );

    modport dut (
        output irq
    );

endinterface
