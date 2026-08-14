TOP       ?= uart
RTL       ?= rtl/uart.sv
TB        ?= tb/tb.cpp
BUILD_DIR ?= build
WAVE_FILE ?= dump.vcd

VERILATOR ?= verilator
GTKWAVE   ?= gtkwave

.PHONY: all sim lint wave clean

all: sim

sim:
	$(VERILATOR) --cc $(RTL) \
		--top-module $(TOP) \
		--exe $(TB) \
		--build \
		--Mdir $(BUILD_DIR)
	./$(BUILD_DIR)/V$(TOP)

lint:
	$(VERILATOR) --lint-only -Wall --top-module $(TOP) $(RTL)

wave:
	$(GTKWAVE) $(WAVE_FILE)

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(WAVE_FILE)