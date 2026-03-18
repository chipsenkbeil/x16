# Makefile for Commander X16 cc65 C project
# Uses cl65 to compile, assemble, and link in one step

# Project name derived from directory name
PROJECT_NAME := $(notdir $(CURDIR))

# Tools
CC65 := cl65
TARGET := cx16

# Directories
SRC_DIR := src
BUILD_DIR := build
ASSETS_DIR := assets

# Files
C_SOURCES := $(wildcard $(SRC_DIR)/*.c)
S_SOURCES := $(wildcard $(SRC_DIR)/*.s)
SOURCES := $(C_SOURCES) $(S_SOURCES)
OUTPUT := $(BUILD_DIR)/$(PROJECT_NAME).prg

# Linker config: use local cx16.cfg if present, otherwise use default
ifneq ($(wildcard cx16.cfg),)
  CFG_FLAG := -C cx16.cfg
else
  CFG_FLAG :=
endif

# Compiler flags
CFLAGS := -t $(TARGET) --cpu 65c02 -O $(CFG_FLAG)

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -prg $(OUTPUT) -run

# Default target
all: $(BUILD_DIR) $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT): $(SOURCES)
	@command -v $(CC65) >/dev/null 2>&1 || { \
		echo "Error: cl65 not found (part of cc65 suite)."; \
		echo "  macOS: brew install cc65"; \
		echo "  Linux: sudo apt install cc65  /  sudo pacman -S cc65"; \
		echo "  Or run: make setup"; \
		exit 1; \
	}
	$(CC65) $(CFLAGS) -o $@ $^

# Run in emulator
run: all
	$(EMULATOR) $(EMU_FLAGS)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/*

.PHONY: all clean run
