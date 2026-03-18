# Makefile for Commander X16 ACME assembly project
# Single-step build: ACME assembles directly to .prg

# Project name derived from directory name
PROJECT_NAME := $(notdir $(CURDIR))

# Tools
AS := acme

# Directories
SRC_DIR := src
INC_DIR := include
BUILD_DIR := build
ASSETS_DIR := assets

# Files
MAIN_SRC := $(SRC_DIR)/main.a
OUTPUT := $(BUILD_DIR)/$(PROJECT_NAME).prg

# Assembler flags
# -f cbm: output CBM .prg format (2-byte load address header)
# -o: output file
# -I: include search path
ASFLAGS := -f cbm -I $(INC_DIR) -o $(OUTPUT)

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -prg $(OUTPUT) -run

# Default target
all: $(BUILD_DIR) $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT): $(MAIN_SRC) $(wildcard $(INC_DIR)/*.a) $(wildcard $(SRC_DIR)/*.a)
	@command -v $(AS) >/dev/null 2>&1 || { \
		echo "Error: acme not found."; \
		echo "  Build from source: https://github.com/meonwax/acme"; \
		echo "  Or run: make setup"; \
		exit 1; \
	}
	$(AS) $(ASFLAGS) $(MAIN_SRC)

# Run in emulator
run: all
	$(EMULATOR) $(EMU_FLAGS)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/*

.PHONY: all clean run
