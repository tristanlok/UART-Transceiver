SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

SIM_TOP   ?= uart_tx_tb
RTL_TOP   ?= uart
TX_SIM    ?= 0
RX_SIM    ?= 0
RUN_ALL   ?= 0
TX_TESTS  ?= tx_sim_sanity \
             tx_send_data_and_assert_reset \
             tx_hold_request_data_stability \
             tx_reset_every_state
RX_TESTS  ?= rx_sim_sanity \
             rx_false_start \
             rx_data_majority_vote \
             rx_reset_every_state
UART_TESTS ?= $(RX_TESTS)
BUILD_DIR ?= build
LOG_DIR   ?= $(BUILD_DIR)/logs
WAVE_DIR  ?= $(BUILD_DIR)/waves
TIMESCALE ?= 1ns/1ps

RTL_SRCS := rtl/baud_generator.sv \
		    rtl/uart_rx.sv \
		    rtl/uart_tx.sv \
		    rtl/uart.sv

TX_RTL_SRCS := rtl/baud_generator.sv \
		       rtl/uart_tx.sv

RX_RTL_SRCS := rtl/baud_generator.sv \
		       rtl/uart_rx.sv

# Keep the files in declaration order: package, interface, classes, then top.
TX_TB_SRCS := tb/tx/uart_tx_tb_pkg.sv \
		      tb/common/uart_tb_ctrl_if.sv \
		      tb/tx/uart_tx_if.sv \
		      tb/common/uart_reset_driver.sv \
		      tb/tx/uart_tx_driver.sv \
		      tb/tx/uart_tx_monitor.sv \
		      tb/tx/uart_tx_scoreboard.sv \
		      tb/tx/uart_tx_tests.sv \
		      tb/tx/uart_tx_tb.sv

RX_TB_SRCS := tb/rx/uart_rx_tb_pkg.sv \
		      tb/common/uart_tb_ctrl_if.sv \
		      tb/rx/uart_rx_if.sv \
		      tb/common/uart_reset_driver.sv \
		      tb/rx/uart_rx_driver.sv \
		      tb/rx/uart_rx_monitor.sv \
		      tb/rx/uart_rx_scoreboard.sv \
		      tb/rx/uart_rx_tests.sv \
		      tb/rx/uart_rx_tb.sv

# The first integrated bench reuses the verified TX/RX components. Its current
# test selection intentionally remains the RX suite until duplex tests exist.
UART_TB_SRCS := tb/tx/uart_tx_tb_pkg.sv \
			tb/rx/uart_rx_tb_pkg.sv \
			tb/common/uart_tb_ctrl_if.sv \
			tb/tx/uart_tx_if.sv \
			tb/rx/uart_rx_if.sv \
			tb/common/uart_reset_driver.sv \
			tb/tx/uart_tx_driver.sv \
			tb/tx/uart_tx_monitor.sv \
			tb/tx/uart_tx_scoreboard.sv \
			tb/rx/uart_rx_driver.sv \
			tb/rx/uart_rx_monitor.sv \
			tb/rx/uart_rx_scoreboard.sv \
			tb/rx/uart_rx_tests.sv \
			tb/uart_env.sv \
			tb/uart_tests.sv \
			tb/uart_tb.sv

ifeq ($(SIM_TOP),uart_tx_tb)
SIM_RTL_SRCS := $(TX_RTL_SRCS)
TB_SRCS      := $(TX_TB_SRCS)
DEFAULT_TEST := tx_sim_sanity
ACTIVE_TESTS := $(TX_TESTS)
LEGACY_ALL   := $(TX_SIM)
else ifeq ($(SIM_TOP),uart_rx_tb)
SIM_RTL_SRCS := $(RX_RTL_SRCS)
TB_SRCS      := $(RX_TB_SRCS)
DEFAULT_TEST := rx_sim_sanity
ACTIVE_TESTS := $(RX_TESTS)
LEGACY_ALL   := $(RX_SIM)
else ifeq ($(SIM_TOP),uart_tb)
SIM_RTL_SRCS := $(RTL_SRCS)
TB_SRCS      := $(UART_TB_SRCS)
DEFAULT_TEST := rx_sim_sanity
ACTIVE_TESTS := $(UART_TESTS)
LEGACY_ALL   := 0
else
$(error Unsupported SIM_TOP "$(SIM_TOP)"; use uart_tx_tb, uart_rx_tb, or uart_tb)
endif

TEST          ?= $(DEFAULT_TEST)
RUN_ALL_TESTS := $(if $(filter 1,$(RUN_ALL) $(LEGACY_ALL)),1,0)
SIM_BUILD_DIR := $(BUILD_DIR)/$(SIM_TOP)
SIM_BINARY    := $(SIM_BUILD_DIR)/V$(SIM_TOP)
SIM_LOG       ?= $(LOG_DIR)/$(SIM_TOP)_$(TEST).log
WAVE_FILE     ?= $(WAVE_DIR)/$(SIM_TOP)_$(TEST).vcd
SOURCES       := $(SIM_RTL_SRCS) $(TB_SRCS)

OSS_CAD_SUITE ?= $(HOME)/.local/opt/oss-cad-suite
FORMAL_CONFIG ?= formal/uart.sby
FORMAL_TASKS  ?=

VERILATOR ?= verilator
GTKWAVE   ?= gtkwave
SBY       ?= $(OSS_CAD_SUITE)/bin/sby
YOSYS     ?= $(OSS_CAD_SUITE)/bin/yosys
Z3        ?= $(OSS_CAD_SUITE)/bin/z3

VERILATOR_FLAGS    ?= -Wall
VERILATOR_TB_FLAGS ?= -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL
SIM_DEFINES         ?= -DUART_SIM

.PHONY: all sim sim-build tx-sim rx-sim uart-sim tx-sim-all rx-sim-all \
	lint wave formal formal-tasks formal-version clean

all: sim

sim-build:
	@mkdir -p "$(SIM_BUILD_DIR)" "$(LOG_DIR)" "$(WAVE_DIR)"
	$(VERILATOR) --binary --timing --trace --timescale $(TIMESCALE) \
		$(VERILATOR_FLAGS) $(VERILATOR_TB_FLAGS) $(SIM_DEFINES) $(SOURCES) \
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

uart-sim:
	$(MAKE) sim SIM_TOP=uart_tb

tx-sim-all:
	$(MAKE) sim SIM_TOP=uart_tx_tb RUN_ALL=1

rx-sim-all:
	$(MAKE) sim SIM_TOP=uart_rx_tb RUN_ALL=1

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) $(RTL_SRCS) \
		--top-module $(RTL_TOP)
	$(VERILATOR) --lint-only --timing --timescale $(TIMESCALE) \
		$(VERILATOR_FLAGS) $(VERILATOR_TB_FLAGS) $(SIM_DEFINES) $(SOURCES) \
		--top-module $(SIM_TOP)

wave:
	$(GTKWAVE) $(WAVE_FILE)

formal:
	@test -f "$(FORMAL_CONFIG)" || { echo "Missing $(FORMAL_CONFIG)"; exit 1; }
	PATH="$(OSS_CAD_SUITE)/bin:$$PATH" $(SBY) -f $(FORMAL_CONFIG) $(FORMAL_TASKS)

formal-tasks:
	@test -f "$(FORMAL_CONFIG)" || { echo "Missing $(FORMAL_CONFIG)"; exit 1; }
	PATH="$(OSS_CAD_SUITE)/bin:$$PATH" $(SBY) --dumptasks $(FORMAL_CONFIG)

formal-version:
	$(SBY) --version
	$(YOSYS) --version
	$(Z3) --version

clean:
	@rm -rf $(BUILD_DIR)
