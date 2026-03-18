# Makefile for Commander X16 Prog8 project
# Uses prog8c to compile .p8 source to .prg

# Project name derived from directory name
PROJECT_NAME := $(notdir $(CURDIR))

# Tools
P8C := prog8c

# Directories
SRC_DIR := src
BUILD_DIR := build

# Files
MAIN_SRC := $(SRC_DIR)/main.p8
OUTPUT := $(BUILD_DIR)/main.prg

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -prg $(OUTPUT) -run

# Default target
all: $(BUILD_DIR) $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT): $(MAIN_SRC) $(wildcard $(SRC_DIR)/*.p8)
	@command -v $(P8C) >/dev/null 2>&1 || { \
		echo "Error: prog8c not found."; \
		echo "  macOS: brew install prog8"; \
		echo "  Other: download from https://github.com/irmen/prog8/releases"; \
		echo "  Docs:  https://prog8.readthedocs.io"; \
		exit 1; \
	}
	$(P8C) -target cx16 -out $(BUILD_DIR) $<

# Run in emulator
run: all
	@command -v $(EMULATOR) >/dev/null 2>&1 || { \
		echo "Error: x16emu not found. Install with: make setup"; \
		exit 1; \
	}
	$(EMULATOR) $(EMU_FLAGS)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/*

.PHONY: all clean run
