SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

SIM_TOP   ?= uart_tx_tb
RTL_TOP   ?= uart
TEST      ?= tx_sim_sanity
TX_SIM    ?= 0
TX_TESTS  ?= tx_sim_sanity \
             tx_send_data_and_assert_reset \
             tx_hold_request_data_stability
BUILD_DIR ?= build
LOG_DIR   ?= $(BUILD_DIR)/logs
WAVE_DIR  ?= $(BUILD_DIR)/waves
SIM_LOG   ?= $(LOG_DIR)/$(SIM_TOP)_$(TEST).log
WAVE_FILE ?= $(WAVE_DIR)/$(SIM_TOP)_$(TEST).vcd
TIMESCALE ?= 1ns/1ps

RTL_SRCS := rtl/baud_generator.sv \
	        rtl/uart_tx.sv \
	        rtl/uart.sv

TB_DIR            := tb/tx
TB_PACKAGE        := $(TB_DIR)/uart_tx_tb_pkg.sv
TB_INTERFACE      := $(TB_DIR)/uart_tx_if.sv
TB_TOP_SOURCE     := $(TB_DIR)/uart_tx_tb.sv
TB_COMPONENT_SRCS := $(filter-out $(TB_PACKAGE) $(TB_INTERFACE) $(TB_TOP_SOURCE),\
	                 $(wildcard $(TB_DIR)/*.sv))
TB_SRCS           := $(TB_PACKAGE) $(TB_INTERFACE) $(TB_COMPONENT_SRCS) \
	                 $(TB_TOP_SOURCE)
SOURCES  := $(RTL_SRCS) $(TB_SRCS)

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

.PHONY: all sim sim-build lint wave formal formal-tasks formal-version clean

all: sim

sim-build:
	@mkdir -p "$(LOG_DIR)" "$(WAVE_DIR)"
	$(VERILATOR) --binary --timing --trace --timescale $(TIMESCALE) \
		$(VERILATOR_FLAGS) $(VERILATOR_TB_FLAGS) $(SIM_DEFINES) $(SOURCES) \
		--top-module $(SIM_TOP) \
		--Mdir $(BUILD_DIR)

sim: sim-build
ifeq ($(TX_SIM),1)
	@tests=($(TX_TESTS)); \
	pids=(); \
	status=0; \
	for testname in "$${tests[@]}"; do \
		log_file="$(LOG_DIR)/$(SIM_TOP)_$${testname}.log"; \
		wave_file="$(WAVE_DIR)/$(SIM_TOP)_$${testname}.vcd"; \
		echo "[START] $${testname} -> $${log_file}"; \
		(./$(BUILD_DIR)/V$(SIM_TOP) \
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
	./$(BUILD_DIR)/V$(SIM_TOP) "+TEST=$(TEST)" \
		"+WAVE_FILE=$(WAVE_FILE)" 2>&1 | tee "$(SIM_LOG)"
endif

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) $(RTL_SRCS) \
		--top-module $(RTL_TOP)
	$(VERILATOR) --lint-only --timing \
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
