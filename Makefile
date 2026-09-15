SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

SIM_TOP   ?= uart_tx_tb
TX_SIM    ?= 0
RX_SIM    ?= 0
RUN_ALL   ?= 0
TX_TESTS  ?= tx_sim_sanity \
             tx_send_data_and_assert_reset \
             tx_hold_request_data_stability \
             tx_exact_bit_duration \
             tx_reset_every_state
RX_TESTS  ?= rx_sim_sanity \
             rx_false_start \
             rx_data_majority_vote \
             rx_framing_error \
             rx_reset_every_state
REG_TESTS ?= reg_sanity \
             reg_random_access \
             reg_negative_access \
             reg_buffer_corner_cases \
             reg_interrupt_priority
AXI_TESTS ?= axi_reset_basic_map \
             axi_write_channel_order \
             axi_response_backpressure \
             axi_negative_and_strobes \
             axi_concurrent_read_write
AXI_UART_TESTS ?= axi_uart_tx_path \
                  axi_uart_rx_path \
                  axi_uart_full_duplex \
                  axi_uart_buffers_errors_irq \
                  axi_uart_reset_recovery
UART_TESTS ?= uart_tx_sanity \
              uart_rx_sanity \
              uart_duplex_sanity \
              uart_error_isolation \
              uart_reset_every_state
BUILD_DIR ?= build
LOG_DIR   ?= $(BUILD_DIR)/logs
WAVE_DIR  ?= $(BUILD_DIR)/waves
TIMESCALE ?= 1ns/1ps

UART_CORE_RTL_SRCS := rtl/baud_generator.sv \
			      rtl/uart_rx.sv \
			      rtl/uart_tx.sv \
			      rtl/uart.sv

UART_REG_RTL_SRCS := rtl/uart_reg_pkg.sv \
			     rtl/uart_reg_block.sv

RTL_SRCS := $(UART_CORE_RTL_SRCS)

TX_RTL_SRCS := rtl/baud_generator.sv \
		       rtl/uart_tx.sv

RX_RTL_SRCS := rtl/baud_generator.sv \
		       rtl/uart_rx.sv

REG_RTL_SRCS := $(UART_REG_RTL_SRCS)

AXI_RTL_SRCS := $(UART_REG_RTL_SRCS) \
			$(UART_CORE_RTL_SRCS) \
			rtl/uart_axi_lite.sv

# Keep the files in declaration order: package, interface, classes, then top.
TX_TB_SRCS := tb/common/uart_tb_ctrl_if.sv \
		      tb/tx/uart_tx_if.sv \
		      tb/common/uart_reset_driver.sv \
		      tb/tx/uart_tx_driver.sv \
		      tb/tx/uart_tx_monitor.sv \
		      tb/tx/uart_tx_scoreboard.sv \
		      tb/tx/uart_tx_tests.sv \
		      tb/tx/uart_tx_tb.sv

RX_TB_SRCS := tb/common/uart_tb_ctrl_if.sv \
		      tb/rx/uart_rx_if.sv \
		      tb/common/uart_reset_driver.sv \
		      tb/rx/uart_rx_driver.sv \
		      tb/rx/uart_rx_monitor.sv \
		      tb/rx/uart_rx_scoreboard.sv \
		      tb/rx/uart_rx_tests.sv \
		      tb/rx/uart_rx_tb.sv

REG_TB_SRCS := tb/common/uart_tb_ctrl_if.sv \
		       tb/reg/uart_reg_if.sv \
		       tb/common/uart_reset_driver.sv \
		       tb/reg/uart_reg_driver.sv \
		       tb/reg/uart_reg_monitor.sv \
		       tb/reg/uart_reg_scoreboard.sv \
		       tb/reg/uart_reg_tests.sv \
		       tb/reg/uart_reg_block_tb.sv

# Reusable AXI master and external-UART peer. Both AXI verification layers use
# exactly this component stack and differ only in their test-suite class.
AXI_UART_COMMON_TB_SRCS := tb/axi/axi_lite_tb_pkg.sv \
				   tb/serial/uart_serial_tb_pkg.sv \
				   tb/common/uart_tb_ctrl_if.sv \
				   tb/axi/axi_lite_if.sv \
				   tb/serial/uart_serial_if.sv \
				   tb/uart_axi/uart_irq_if.sv \
				   tb/common/uart_reset_driver.sv \
				   tb/axi/axi_lite_driver.sv \
				   tb/axi/axi_lite_monitor.sv \
				   tb/axi/axi_lite_scoreboard.sv \
				   tb/axi/axi_lite_agent.sv \
				   tb/serial/uart_serial_driver.sv \
				   tb/serial/uart_serial_monitor.sv \
				   tb/serial/uart_serial_scoreboard.sv \
				   tb/serial/uart_serial_agent.sv \
				   tb/uart_axi/uart_axi_monitor.sv \
				   tb/uart_axi/uart_axi_scoreboard.sv \
				   tb/uart_axi/uart_axi_env.sv \
				   tb/uart_axi/uart_axi_test_base.sv

AXI_PROTOCOL_TEST_SRCS := tb/uart_axi/uart_axi_lite_tests.sv

AXI_SYSTEM_TEST_SRCS := tb/uart_axi/uart_axi_tests.sv

AXI_TB_SRCS := $(AXI_UART_COMMON_TB_SRCS) \
		       $(AXI_PROTOCOL_TEST_SRCS) \
		       tb/uart_axi/uart_axi_lite_tb.sv

AXI_UART_TB_SRCS := $(AXI_UART_COMMON_TB_SRCS) \
			    $(AXI_SYSTEM_TEST_SRCS) \
			    tb/uart_axi/uart_axi_system_tb.sv

# The integrated bench reuses the verified TX/RX components and adds tests
# that exercise both sides of the uart top at the same time.
UART_TB_SRCS := tb/common/uart_tb_ctrl_if.sv \
			tb/tx/uart_tx_if.sv \
			tb/rx/uart_rx_if.sv \
			tb/common/uart_reset_driver.sv \
			tb/tx/uart_tx_driver.sv \
			tb/tx/uart_tx_monitor.sv \
			tb/tx/uart_tx_scoreboard.sv \
			tb/tx/uart_tx_tests.sv \
			tb/rx/uart_rx_driver.sv \
			tb/rx/uart_rx_monitor.sv \
			tb/rx/uart_rx_scoreboard.sv \
			tb/rx/uart_rx_tests.sv \
			tb/uart/uart_monitor.sv \
			tb/uart/uart_scoreboard.sv \
			tb/uart/uart_env.sv \
			tb/uart/uart_tests.sv \
			tb/uart/uart_tb.sv

ifeq ($(SIM_TOP),uart_tx_tb)
SIM_RTL_SRCS := $(TX_RTL_SRCS)
TB_SRCS      := $(TX_TB_SRCS)
DEFAULT_TEST := tx_sim_sanity
ACTIVE_TESTS := $(TX_TESTS)
LEGACY_ALL   := $(TX_SIM)
RTL_LINT_SRCS := $(TX_RTL_SRCS)
RTL_LINT_TOP  := uart_tx
else ifeq ($(SIM_TOP),uart_rx_tb)
SIM_RTL_SRCS := $(RX_RTL_SRCS)
TB_SRCS      := $(RX_TB_SRCS)
DEFAULT_TEST := rx_sim_sanity
ACTIVE_TESTS := $(RX_TESTS)
LEGACY_ALL   := $(RX_SIM)
RTL_LINT_SRCS := $(RX_RTL_SRCS)
RTL_LINT_TOP  := uart_rx
else ifeq ($(SIM_TOP),uart_reg_block_tb)
SIM_RTL_SRCS := $(REG_RTL_SRCS)
TB_SRCS      := $(REG_TB_SRCS)
DEFAULT_TEST := reg_sanity
ACTIVE_TESTS := $(REG_TESTS)
LEGACY_ALL   := 0
RTL_LINT_SRCS := $(REG_RTL_SRCS)
RTL_LINT_TOP  := uart_reg_block
else ifeq ($(SIM_TOP),uart_axi_lite_tb)
SIM_RTL_SRCS := $(AXI_RTL_SRCS)
TB_SRCS      := $(AXI_TB_SRCS)
DEFAULT_TEST := axi_reset_basic_map
ACTIVE_TESTS := $(AXI_TESTS)
LEGACY_ALL   := 0
RTL_LINT_SRCS := $(AXI_RTL_SRCS)
RTL_LINT_TOP  := uart_axi_lite
else ifeq ($(SIM_TOP),uart_axi_system_tb)
SIM_RTL_SRCS := $(AXI_RTL_SRCS)
TB_SRCS      := $(AXI_UART_TB_SRCS)
DEFAULT_TEST := axi_uart_tx_path
ACTIVE_TESTS := $(AXI_UART_TESTS)
LEGACY_ALL   := 0
RTL_LINT_SRCS := $(AXI_RTL_SRCS)
RTL_LINT_TOP  := uart_axi_lite
else ifeq ($(SIM_TOP),uart_tb)
SIM_RTL_SRCS := $(RTL_SRCS)
TB_SRCS      := $(UART_TB_SRCS)
DEFAULT_TEST := uart_tx_sanity
ACTIVE_TESTS := $(UART_TESTS)
LEGACY_ALL   := 0
RTL_LINT_SRCS := $(RTL_SRCS)
RTL_LINT_TOP  := uart
else
$(error Unsupported SIM_TOP "$(SIM_TOP)"; use uart_tx_tb, uart_rx_tb, uart_reg_block_tb, uart_tb, uart_axi_lite_tb, or uart_axi_system_tb)
endif

TEST          ?= $(DEFAULT_TEST)
RUN_ALL_TESTS := $(if $(filter 1,$(RUN_ALL) $(LEGACY_ALL)),1,0)
SIM_BUILD_DIR := $(BUILD_DIR)/$(SIM_TOP)
SIM_BINARY    := $(SIM_BUILD_DIR)/V$(SIM_TOP)
SIM_LOG       ?= $(LOG_DIR)/$(SIM_TOP)_$(TEST).log
WAVE_FILE     ?= $(WAVE_DIR)/$(SIM_TOP)_$(TEST).vcd
SOURCES       := $(SIM_RTL_SRCS) $(TB_SRCS)

VERILATOR ?= verilator
GTKWAVE   ?= gtkwave

VERILATOR_FLAGS    ?= -Wall
VERILATOR_TB_FLAGS ?= -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL
SIM_DEFINES        ?= -DUART_SIM
SV_INCLUDE_DIRS    ?= -Irtl -Itb/common

.PHONY: all sim sim-build tx-sim rx-sim reg-sim uart-sim axi-sim \
	axi-uart-sim tx-sim-all rx-sim-all reg-sim-all uart-sim-all \
	axi-sim-all axi-uart-sim-all \
	lint wave clean

all: sim

sim-build:
	@mkdir -p "$(SIM_BUILD_DIR)" "$(LOG_DIR)" "$(WAVE_DIR)"
	$(VERILATOR) --binary --timing --trace --timescale $(TIMESCALE) \
		$(VERILATOR_FLAGS) $(VERILATOR_TB_FLAGS) $(SV_INCLUDE_DIRS) \
		$(SIM_DEFINES) $(SOURCES) \
		--top-module $(SIM_TOP) \
		--Mdir $(SIM_BUILD_DIR)

sim: sim-build
ifeq ($(RUN_ALL_TESTS),1)
	@tests=($(ACTIVE_TESTS)); \
	pids=(); \
	status=0; \
	for testname in "$${tests[@]}"; do \
		log_file="$(LOG_DIR)/$(SIM_TOP)_$${testname}.log"; \
		wave_file="$(WAVE_DIR)/$(SIM_TOP)_$${testname}.vcd"; \
		echo "[START] $${testname} -> $${log_file}"; \
		("$(SIM_BINARY)" \
			"+TEST=$${testname}" \
			"+WAVE_FILE=$${wave_file}" > "$${log_file}" 2>&1) & \
		pids+=("$$!"); \
	done; \
	for index in "$${!pids[@]}"; do \
		testname="$${tests[$${index}]}"; \
		log_file="$(LOG_DIR)/$(SIM_TOP)_$${testname}.log"; \
		if wait "$${pids[$${index}]}"; then \
			echo "[PASS]  $${testname}"; \
		else \
			echo "[FAIL]  $${testname} (see $${log_file})"; \
			status=1; \
		fi; \
	done; \
	exit "$$status"
else
	"$(SIM_BINARY)" "+TEST=$(TEST)" \
		"+WAVE_FILE=$(WAVE_FILE)" 2>&1 | tee "$(SIM_LOG)"
endif

tx-sim:
	$(MAKE) sim SIM_TOP=uart_tx_tb

rx-sim:
	$(MAKE) sim SIM_TOP=uart_rx_tb

reg-sim:
	$(MAKE) sim SIM_TOP=uart_reg_block_tb

uart-sim:
	$(MAKE) sim SIM_TOP=uart_tb

axi-sim:
	$(MAKE) sim SIM_TOP=uart_axi_lite_tb

axi-uart-sim:
	$(MAKE) sim SIM_TOP=uart_axi_system_tb

tx-sim-all:
	$(MAKE) sim SIM_TOP=uart_tx_tb RUN_ALL=1

rx-sim-all:
	$(MAKE) sim SIM_TOP=uart_rx_tb RUN_ALL=1

reg-sim-all:
	$(MAKE) sim SIM_TOP=uart_reg_block_tb RUN_ALL=1

uart-sim-all:
	$(MAKE) sim SIM_TOP=uart_tb RUN_ALL=1

axi-sim-all:
	$(MAKE) sim SIM_TOP=uart_axi_lite_tb RUN_ALL=1

axi-uart-sim-all:
	$(MAKE) sim SIM_TOP=uart_axi_system_tb RUN_ALL=1

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) $(SV_INCLUDE_DIRS) \
		$(RTL_LINT_SRCS) \
		--top-module $(RTL_LINT_TOP)
	$(VERILATOR) --lint-only --timing --timescale $(TIMESCALE) \
		$(VERILATOR_FLAGS) $(VERILATOR_TB_FLAGS) $(SV_INCLUDE_DIRS) \
		$(SIM_DEFINES) $(SOURCES) \
		--top-module $(SIM_TOP)

wave:
	$(GTKWAVE) $(WAVE_FILE)

clean:
	@rm -rf $(BUILD_DIR)
