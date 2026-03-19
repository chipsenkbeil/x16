# Makefile for Commander X16 BASIC project
# BASIC programs are interpreted — no compilation step needed.
# Use `make run` to launch in the emulator.

# Project name derived from directory name
PROJECT_NAME := $(notdir $(CURDIR))

# Directories
SRC_DIR := src

# Main source file
MAIN_SRC := $(SRC_DIR)/main.bas

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -bas $(MAIN_SRC) -run

# Default target — nothing to compile
all:
	@echo "BASIC programs are interpreted, no build step needed."
	@echo "Use 'make run' to launch in the emulator."

# Run in emulator
run: $(MAIN_SRC)
	@command -v $(EMULATOR) >/dev/null 2>&1 || { \
		echo "Error: x16emu not found. Install with: make setup"; \
		echo "  See: https://github.com/X16Community/x16-emulator"; \
		exit 1; \
	}
	$(EMULATOR) $(EMU_FLAGS)

# Clean — nothing to clean for BASIC
clean:
	@echo "Nothing to clean (BASIC programs are interpreted)."

.PHONY: all clean run
