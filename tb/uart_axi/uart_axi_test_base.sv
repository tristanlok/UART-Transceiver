`include "uart_config.svh"
`include "uart_tb_log.svh"

// Common setup, reporting, and register-access helpers shared by the two test
// suite classes. Each suite inherits these mechanics and supplies named test
// tasks, matching the organization used by the TX/RX/UART/register benches.
import axi_lite_tb_pkg::axi_lite_transaction_t;
import axi_lite_tb_pkg::axi_lite_write_order_e;
import axi_lite_tb_pkg::axi_lite_default_transaction;
import axi_lite_tb_pkg::AXI_LITE_READ;
import axi_lite_tb_pkg::AXI_LITE_WRITE;
import axi_lite_tb_pkg::AXI_LITE_AW_W_SAME_CYCLE;

class uart_axi_test_base;

    uart_axi_env env;

    function new(uart_axi_env env_arg);
        this.env = env_arg;
    endfunction

    // Called once by the testbench before dispatching a named test task.
    task automatic setup_test(input string selected_test);
        `UART_DISPLAY(("[AXI UART BASE TEST] Starting %s", selected_test))
        env.initialize_inputs();
        env.apply_reset();
    endtask

    // Called once after the selected task. Keeping all three summaries here
    // ensures every test uses identical pass/fail handling.
    task automatic finish_test(input string selected_test);
        env.axi_agent.scoreboard.report();
        env.serial_agent.scoreboard.report();
        env.scoreboard.report();

        if ((env.axi_agent.scoreboard.fail_count != 0) ||
            (env.serial_agent.scoreboard.fail_count != 0) ||
            (env.scoreboard.fail_count != 0)) begin
            `UART_FATAL((
                1,
                "[AXI UART BASE TEST] %s failed: AXI errors=%0d serial errors=%0d integration errors=%0d",
                selected_test,
                env.axi_agent.scoreboard.fail_count,
                env.serial_agent.scoreboard.fail_count,
                env.scoreboard.fail_count
            ))
        end

        `UART_DISPLAY((
            "[AXI UART BASE TEST] [PASS] Completed %s",
            selected_test
        ))
    endtask

    task automatic wait_clock_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(posedge env.ctrl_vif.clk);
            #1step;
        end
    endtask

    task automatic check_bit(
        input string test_context,
        input logic  expected,
        input logic  actual
    );
        env.scoreboard.check_signal(test_context, expected, actual);
    endtask

    task automatic wait_for_irq(
        input logic        expected,
        input int unsigned timeout_cycles = 2_000
    );
        logic observed;

        env.monitor.wait_for_irq_state(expected, timeout_cycles, observed);

        if (observed)
            return;

        `UART_FATAL((
            1,
            "[AXI UART BASE TEST] timed out waiting for irq=%0b",
            expected
        ))
    endtask

    task automatic axi_write(
        input  logic [31:0]           address,
        input  logic [31:0]           data,
        input  logic [3:0]            strobe,
        output logic [1:0]            response,
        input  axi_lite_write_order_e order = AXI_LITE_AW_W_SAME_CYCLE,
        input  int unsigned           channel_gap_cycles = 0,
        input  int unsigned           response_stall_cycles = 0
    );
        axi_lite_transaction_t transaction;

        transaction = axi_lite_default_transaction();
        transaction.access = AXI_LITE_WRITE;
        transaction.address = address;
        transaction.write_data = data;
        transaction.write_strobe = strobe;
        transaction.write_order = order;
        transaction.channel_gap_cycles = channel_gap_cycles;
        transaction.response_stall_cycles = response_stall_cycles;
        transaction.check_read_data = 1'b0;

        env.axi_agent.driver.write_transaction(transaction);
        response = transaction.actual_response;
    endtask

    task automatic axi_read(
        input  logic [31:0] address,
        output logic [31:0] data,
        output logic [1:0]  response,
        input  int unsigned response_stall_cycles = 0
    );
        axi_lite_transaction_t transaction;

        transaction = axi_lite_default_transaction();
        transaction.access = AXI_LITE_READ;
        transaction.address = address;
        transaction.response_stall_cycles = response_stall_cycles;

        env.axi_agent.driver.read_transaction(transaction);
        data = transaction.actual_read_data;
        response = transaction.actual_response;
    endtask

    task automatic expect_write(
        input logic [31:0]           address,
        input logic [31:0]           data,
        input logic [3:0]            strobe,
        input logic [1:0]            expected_response,
        input string                 test_context,
        input axi_lite_write_order_e order = AXI_LITE_AW_W_SAME_CYCLE,
        input int unsigned           channel_gap_cycles = 0,
        input int unsigned           response_stall_cycles = 0
    );
        axi_lite_transaction_t transaction;

        transaction = axi_lite_default_transaction();
        transaction.access = AXI_LITE_WRITE;
        transaction.address = address;
        transaction.write_data = data;
        transaction.write_strobe = strobe;
        transaction.write_order = order;
        transaction.channel_gap_cycles = channel_gap_cycles;
        transaction.response_stall_cycles = response_stall_cycles;
        transaction.expected_response = expected_response;
        transaction.check_read_data = 1'b0;

        env.axi_agent.driver.write_transaction(transaction);
        env.axi_agent.scoreboard.check_transaction(test_context, transaction);
    endtask

    task automatic expect_read(
        input logic [31:0] address,
        input logic [31:0] expected_data,
        input logic [1:0]  expected_response,
        input string       test_context,
        input int unsigned response_stall_cycles = 0
    );
        axi_lite_transaction_t transaction;

        transaction = axi_lite_default_transaction();
        transaction.access = AXI_LITE_READ;
        transaction.address = address;
        transaction.expected_read_data = expected_data;
        transaction.expected_response = expected_response;
        transaction.response_stall_cycles = response_stall_cycles;
        transaction.check_read_data = 1'b1;

        env.axi_agent.driver.read_transaction(transaction);
        env.axi_agent.scoreboard.check_transaction(test_context, transaction);
    endtask

endclass
