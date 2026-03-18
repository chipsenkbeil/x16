# Makefile for Commander X16 llvm-mos C project
# Uses mos-cx16-clang to compile C to .prg

# Project name derived from directory name
PROJECT_NAME := $(notdir $(CURDIR))

# Tools
CC := mos-cx16-clang

# Directories
SRC_DIR := src
BUILD_DIR := build
ASSETS_DIR := assets

# Files
SOURCES := $(wildcard $(SRC_DIR)/*.c)
OUTPUT := $(BUILD_DIR)/$(PROJECT_NAME).prg

# Compiler flags
CFLAGS := -Os

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -prg $(OUTPUT) -run

# Default target
all: $(BUILD_DIR) $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT): $(SOURCES)
	@command -v $(CC) >/dev/null 2>&1 || { \
		echo "Error: mos-cx16-clang not found."; \
		echo "  Download the llvm-mos SDK from:"; \
		echo "  https://github.com/llvm-mos/llvm-mos-sdk/releases"; \
		echo "  Then add llvm-mos/bin to your PATH."; \
		exit 1; \
	}
	$(CC) $(CFLAGS) -o $@ $^

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
