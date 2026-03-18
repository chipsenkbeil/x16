# Makefile for Commander X16 Rust project (EXPERIMENTAL)
# Uses rust-mos (Docker) to compile Rust to .prg
#
# rust-mos is a fork of the Rust compiler with an llvm-mos backend.
# It requires Docker to run.
#
# x86_64: docker pull mrkits/rust-mos
# ARM/Apple Silicon: docker pull mikaellund/rust-mos

# Project name derived from directory name
PROJECT_NAME := $(notdir $(CURDIR))

# Docker image (override with RUST_MOS_IMAGE=... if needed)
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),arm64)
  RUST_MOS_IMAGE ?= mikaellund/rust-mos
else ifeq ($(UNAME_M),aarch64)
  RUST_MOS_IMAGE ?= mikaellund/rust-mos
else
  RUST_MOS_IMAGE ?= mrkits/rust-mos
endif

# Directories
BUILD_DIR := build

# Output binary — cargo puts it here inside the container
CARGO_OUTPUT := target/mos-cx16-none/release/$(PROJECT_NAME)
OUTPUT := $(BUILD_DIR)/$(PROJECT_NAME).prg

# Emulator (adjust path as needed)
EMULATOR := x16emu
EMU_FLAGS := -prg $(OUTPUT) -run

# Default target
all: $(BUILD_DIR) $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT): src/main.rs Cargo.toml
	@command -v docker >/dev/null 2>&1 || { \
		echo "Error: docker not found. rust-mos requires Docker."; \
		echo "  Install Docker: https://docs.docker.com/get-docker/"; \
		echo "  Then pull rust-mos:"; \
		echo "    x86_64:        docker pull mrkits/rust-mos"; \
		echo "    Apple Silicon:  docker pull mikaellund/rust-mos"; \
		exit 1; \
	}
	docker run --rm -v "$(CURDIR)":/src -w /src $(RUST_MOS_IMAGE) \
		cargo build --release
	cp $(CARGO_OUTPUT) $(OUTPUT)

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
	rm -rf target

.PHONY: all clean run
