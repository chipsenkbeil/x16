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
SOURCES := $(wildcard $(SRC_DIR)/*.c)
OBJECTS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(SOURCES))
OUTPUT := $(BUILD_DIR)/$(PROJECT_NAME).prg

# Linker config: use local cx16.cfg if present, otherwise use default
ifneq ($(wildcard cx16.cfg),)
  CFG_FLAG := -C cx16.cfg
else
  CFG_FLAG :=
endif

# Compiler flags
CFLAGS := -t $(TARGET) -O $(CFG_FLAG)

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -prg $(OUTPUT) -run

# Default target
all: $(BUILD_DIR) $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT): $(SOURCES)
	$(CC65) $(CFLAGS) -o $@ $^

# Run in emulator
run: all
	$(EMULATOR) $(EMU_FLAGS)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/*

.PHONY: all clean run
