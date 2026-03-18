# Makefile for Commander X16 ca65 assembly project
# Two-step build: ca65 assembles .s to .o, ld65 links .o to .prg

# Project name derived from directory name
PROJECT_NAME := $(notdir $(CURDIR))

# Tools
AS := ca65
LD := ld65

# Directories
SRC_DIR := src
INC_DIR := include
BUILD_DIR := build
ASSETS_DIR := assets

# Files
SOURCES := $(wildcard $(SRC_DIR)/*.s)
OBJECTS := $(patsubst $(SRC_DIR)/%.s,$(BUILD_DIR)/%.o,$(SOURCES))
OUTPUT := $(BUILD_DIR)/$(PROJECT_NAME).prg
CFG := cx16-asm.cfg

# Assembler flags
ASFLAGS := -I $(INC_DIR) -t cx16

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -prg $(OUTPUT) -run

# Default target
all: $(BUILD_DIR) $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Assemble .s files to .o files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.s
	@command -v $(AS) >/dev/null 2>&1 || { \
		echo "Error: ca65 not found (part of cc65 suite)."; \
		echo "  macOS: brew install cc65"; \
		echo "  Linux: sudo apt install cc65  /  sudo pacman -S cc65"; \
		echo "  Or run: make setup"; \
		exit 1; \
	}
	$(AS) $(ASFLAGS) -o $@ $<

# Link .o files to .prg
$(OUTPUT): $(OBJECTS)
	$(LD) -C $(CFG) -o $@ $^

# Run in emulator
run: all
	$(EMULATOR) $(EMU_FLAGS)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/*

.PHONY: all clean run
