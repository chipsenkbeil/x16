# Commander X16 Development Environment
# Run `make help` to see available targets.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Default values
NAME     ?=
TEMPLATE ?= cc65-c
PROJECT  ?=

# Colors
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
RESET  := \033[0m

.PHONY: help setup clone-upstream new-project build run clean list-templates

## help: Show this help message
help:
	@echo ""
	@echo "Commander X16 Development Environment"
	@echo "======================================"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //' | \
		awk -F': ' '{printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make setup                              Install toolchain"
	@echo "  make new-project NAME=my-game           Create project from default template"
	@echo "  make new-project NAME=demo TEMPLATE=ca65-asm"
	@echo "  make build PROJECT=projects/my-game     Build a project"
	@echo "  make run PROJECT=projects/my-game       Build and run in emulator"
	@echo ""

## setup: Install toolchain (cc65, emulator, ROM)
setup:
	@./scripts/setup.sh

## clone-upstream: Clone all X16Community repos into upstream/
clone-upstream:
	@./scripts/clone-repos.sh

## new-project: Scaffold new project (NAME=foo TEMPLATE=cc65-c)
new-project:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make new-project NAME=<project-name> [TEMPLATE=cc65-c|ca65-asm|acme-asm|basic|prog8|llvm-mos-c|rust-mos]"; \
		exit 1; \
	fi
	@./scripts/new-project.sh "$(NAME)" "$(TEMPLATE)"

## build: Build a project (PROJECT=projects/foo)
build:
	@if [ -z "$(PROJECT)" ]; then \
		echo "Usage: make build PROJECT=projects/<name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(PROJECT)" ]; then \
		echo "Error: Project directory '$(PROJECT)' not found"; \
		exit 1; \
	fi
	@if [ -f "$(PROJECT)/Makefile" ]; then \
		$(MAKE) -C "$(PROJECT)"; \
	else \
		echo "Error: No Makefile found in $(PROJECT)"; \
		exit 1; \
	fi

## run: Build + run in emulator (PROJECT=projects/foo)
run:
	@if [ -z "$(PROJECT)" ]; then \
		echo "Usage: make run PROJECT=projects/<name>"; \
		exit 1; \
	fi
	@./scripts/run.sh "$(PROJECT)"

## clean: Remove build artifacts from a project
clean:
	@if [ -z "$(PROJECT)" ]; then \
		echo "Cleaning all projects..."; \
		for dir in projects/*/; do \
			if [ -f "$$dir/Makefile" ]; then \
				echo "  Cleaning $$dir"; \
				$(MAKE) -C "$$dir" clean 2>/dev/null || true; \
			fi; \
		done; \
	else \
		if [ -f "$(PROJECT)/Makefile" ]; then \
			$(MAKE) -C "$(PROJECT)" clean; \
		else \
			echo "Error: No Makefile found in $(PROJECT)"; \
			exit 1; \
		fi; \
	fi

## list-templates: Show available project templates
list-templates:
	@echo ""
	@echo "Available templates:"
	@echo ""
	@for dir in projects/templates/*/; do \
		name=$$(basename "$$dir"); \
		if [ "$$name" != "shared" ]; then \
			desc=""; status=""; \
			case "$$name" in \
				cc65-c)     desc="C project using cc65 (recommended for beginners)"; \
					        command -v cc65 >/dev/null 2>&1 && status="✓" || status="✗ cc65 not found" ;; \
				ca65-asm)   desc="Assembly project using ca65 + ld65"; \
					        command -v ca65 >/dev/null 2>&1 && status="✓" || status="✗ cc65 not found" ;; \
				acme-asm)   desc="Assembly project using ACME assembler"; \
					        command -v acme >/dev/null 2>&1 && status="✓" || status="✗ acme not found" ;; \
				basic)      desc="Interpreted BASIC (no compiler needed)"; status="✓" ;; \
				prog8)      desc="Prog8 compiled language"; \
					        command -v prog8c >/dev/null 2>&1 && status="✓" || status="✗ prog8c not found" ;; \
				llvm-mos-c) desc="C project using llvm-mos (modern LLVM)"; \
					        command -v mos-cx16-clang >/dev/null 2>&1 && status="✓" || status="✗ llvm-mos not found" ;; \
				rust-mos)   desc="Rust (EXPERIMENTAL, requires Docker)"; \
					        command -v docker >/dev/null 2>&1 && status="✓ docker" || status="✗ docker not found" ;; \
				*)          desc="Custom template"; status="" ;; \
			esac; \
			printf "  $(CYAN)%-15s$(RESET) %-45s %s\n" "$$name" "$$desc" "$$status"; \
		fi; \
	done
	@echo ""
	@echo "Usage: make new-project NAME=<name> TEMPLATE=<template>"
	@echo ""
