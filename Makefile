PROJ = icesugar-riscv

PACKAGE = sg48
DEVICE = up5k
SERIES = synth_ice40
ROUTE_ARG = -dsp
FREQ = 13
SEED = 10
PROGRAMMER = icesprog

# ----------------------------------------------------------------------------------

FPGA_SRC = ./src
PIN_DEF = ./icesugar.pcf
TOP_FILE = $(shell echo $(FPGA_SRC)/top.v)
TB_FILE :=  $(shell echo $(FPGA_SRC)/*_tb.v)
TEST_FILE :=  $(shell echo $(FPGA_SRC)/*_test.v)

# ----------------------------------------------------------------------------------

FW_DIR = ./firmware
FW_INCLUDE = $(FW_DIR)/include
FW_SRC = $(FW_DIR)/src
CROSS = riscv32-unknown-elf-
CFLAGS = -ffreestanding -nostdlib 
OFFSET = 0x00100000

# ----------------------------------------------------------------------------------

FORMAT = "verilog-format"
TOOLCHAIN_PATH = /opt/fpga
BUILD_DIR = build
#Creates a temporary PATH.
TOOLCHAIN_PATH := $(shell echo $$(readlink -f $(TOOLCHAIN_PATH)))
PATH := $(shell echo $(TOOLCHAIN_PATH)/*/bin | sed 's/ /:/g'):$(PATH)

all: assemble build_fw

assemble: $(BUILD_DIR) $(BUILD_DIR)/$(PROJ).bin
# rules for building the blif file
$(BUILD_DIR)/%.json: $(TOP_FILE) $(FPGA_SRC)/*.v
	yosys -q -l $(BUILD_DIR)/build.log -p '$(SERIES) $(ROUTE_ARG) -top top -json $@; show -format dot -prefix $(BUILD_DIR)/$(PROJ)' $< 
# asc
$(BUILD_DIR)/%.asc: $(BUILD_DIR)/%.json $(PIN_DEF)
	nextpnr-ice40 -l $(BUILD_DIR)/nextpnr.log --seed $(SEED) --freq $(FREQ) --package $(PACKAGE) --$(DEVICE) --asc $@ --pcf $(PIN_DEF) --json $<
# bin, for programming
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.asc
	icepack $< $@
# timing
$(BUILD_DIR)/%.rpt: $(BUILD_DIR)/%.asc
	icetime -d $(DEVICE) -mtr $@ $<

sim: $(BUILD_DIR) $(BUILD_DIR)/%.vcd 
$(BUILD_DIR)/%.vcd: $(BUILD_DIR)/testbench.out $(BUILD_DIR)/$(PROJ)_fw.hex
	vvp -v -M $(TOOLCHAIN_PATH)/toolchain-iverilog/lib/ivl $< +firmware=$(BUILD_DIR)/$(PROJ)_fw.hex
	mv ./*.vcd $(BUILD_DIR)

$(BUILD_DIR)/testbench.out: $(FPGA_SRC)/*.v
	iverilog -o $@ -B $(TOOLCHAIN_PATH)/toolchain-iverilog/lib/ivl $(TOOLCHAIN_PATH)/toolchain-yosys/share/yosys/ice40/cells_sim.v $(TOP_FILE) $(TB_FILE)

flash: $(BUILD_DIR)/$(PROJ).bin
# Flash memory firmware
	$(PROGRAMMER) $<

prog: $(BUILD_DIR)/$(PROJ).bin
# Flash in SRAM
	$(PROGRAMMER) -S $<

formatter:
	if [ $(FORMAT) == "istyle" ]; then istyle  -t4 -b -o --pad=block $(FPGA_SRC)/*.v; fi
	if [ $(FORMAT) == "verilog-format" ]; then find ./src/*.v | xargs -t -L1 java -jar ${TOOLCHAIN_PATH}/verilog-format/bin/verilog-format.jar -s .verilog-format -f ; fi
	
build_fw: $(BUILD_DIR) $(BUILD_DIR)/$(PROJ)_fw.bin
# Building code for riscv
$(BUILD_DIR)/%_fw.elf: $(FW_SRC)/*.c $(FW_INCLUDE)/*.h $(FW_DIR)/sections.lds $(FW_DIR)/start.s
	$(CROSS)gcc $(CFLAGS) -o $@ -mabi=ilp32 -march=rv32ic -Wl,-Bstatic,-T,$(FW_DIR)/sections.lds,--strip-debug -I $(FW_INCLUDE) $(FW_DIR)/start.s $<

$(BUILD_DIR)/%_fw.bin: $(BUILD_DIR)/$(PROJ)_fw.elf
	$(CROSS)objcopy -O binary $< $@

$(BUILD_DIR)/%_fw.hex: $(BUILD_DIR)/$(PROJ)_fw.elf
	$(CROSS)objcopy -O verilog $< $@

flash_fw: $(BUILD_DIR)/$(PROJ)_fw.bin
# flash ROM to given address
	$(PROGRAMMER) -o $(OFFSET) $<

clean:
	rm -f $(BUILD_DIR)/*

toolchain:
	chmod +x ./toolchain/*.sh
	sudo ./toolchain/install.sh $(TOOLCHAIN_PATH)
	if [ -d ".vscode" ]; then sed -i 's@\(\"verilog.linting.path\":\)[^,]*@\1 "${TOOLCHAIN_PATH}/toolchain-iverilog/bin/"@' .vscode/settings.json; fi
	if [ -d ".vscode" ]; then sed -i 's@\(\"verilog.linting.iverilog.arguments\":\)[^,]*@\1 "-B ${TOOLCHAIN_PATH}/toolchain-iverilog/lib/ivl"@' .vscode/settings.json; fi

# ----------------------------------------------------------------------------------

#for testing individual fragments
test: $(BUILD_DIR) $(BUILD_DIR)/%_test.vcd 
$(BUILD_DIR)/%_test.vcd: $(BUILD_DIR)/test.out
	vvp -v -M $(TOOLCHAIN_PATH)/toolchain-iverilog/lib/ivl $<
	mv ./*.vcd $(BUILD_DIR)

$(BUILD_DIR)/test.out: $(FPGA_SRC)/*.v
	iverilog -o $@ -B $(TOOLCHAIN_PATH)/toolchain-iverilog/lib/ivl $(TEST_FILE)

#secondary needed or make will remove useful intermediate files
.SECONDARY:
.PHONY: all assemble sim flash prog formatter build_fw flash_fw clean toolchain test

# $@ The file name of the target of the rule.rule
# $< first pre requisite
# $^ names of all preerquisites
