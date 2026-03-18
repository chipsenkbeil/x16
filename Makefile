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
	@printf "  %-46s %s\n" "make setup" "Install toolchain"
	@printf "  %-46s %s\n" "make new-project NAME=my-game" "Create project (default template)"
	@printf "  %-46s %s\n" "make new-project NAME=demo TEMPLATE=ca65-asm" "Create project (ca65 template)"
	@printf "  %-46s %s\n" "make build" "Build a project (interactive selector)"
	@printf "  %-46s %s\n" "make build PROJECT=projects/my-game" "Build a specific project"
	@printf "  %-46s %s\n" "make run" "Build and run in emulator (interactive)"
	@printf "  %-46s %s\n" "make run PROJECT=projects/my-game" "Build and run a specific project"
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
		PROJECT=$$(./scripts/select-project.sh) || exit 1; \
	else \
		PROJECT="$(PROJECT)"; \
	fi; \
	if [ ! -d "$$PROJECT" ]; then \
		echo "Error: Project directory '$$PROJECT' not found"; \
		exit 1; \
	fi; \
	if [ -f "$$PROJECT/Makefile" ]; then \
		$(MAKE) -C "$$PROJECT"; \
	else \
		echo "Error: No Makefile found in $$PROJECT"; \
		exit 1; \
	fi

## run: Build + run in emulator (PROJECT=projects/foo)
run:
	@if [ -z "$(PROJECT)" ]; then \
		PROJECT=$$(./scripts/select-project.sh) || exit 1; \
	else \
		PROJECT="$(PROJECT)"; \
	fi; \
	./scripts/run.sh "$$PROJECT"

## clean: Remove build artifacts from a project
clean:
	@if [ -z "$(PROJECT)" ]; then \
		PROJECT=$$(./scripts/select-project.sh --allow-all) || exit 1; \
	else \
		PROJECT="$(PROJECT)"; \
	fi; \
	if [ "$$PROJECT" = "ALL" ]; then \
		echo "Cleaning all projects..."; \
		for dir in projects/*/; do \
			if [ -f "$$dir/Makefile" ]; then \
				echo "  Cleaning $$dir"; \
				$(MAKE) -C "$$dir" clean 2>/dev/null || true; \
			fi; \
		done; \
	else \
		if [ -f "$$PROJECT/Makefile" ]; then \
			$(MAKE) -C "$$PROJECT" clean; \
		else \
			echo "Error: No Makefile found in $$PROJECT"; \
			exit 1; \
		fi; \
	fi

## list-templates: Show available project templates
list-templates:
	@echo ""
	@echo "Available templates:"
	@echo ""
	@for dir in templates/*/; do \
		name=$$(basename "$$dir"); \
		if [ "$$name" != "shared" ]; then \
			desc=""; ok=""; miss=""; \
			case "$$name" in \
				cc65-c)     desc="C (cc65) - recommended for beginners"; \
				            ok="cc65"; miss="cc65"; \
				            command -v cc65 >/dev/null 2>&1 && found=1 || found=0 ;; \
				ca65-asm)   desc="Assembly (ca65 + ld65)"; \
				            ok="ca65"; miss="cc65"; \
				            command -v ca65 >/dev/null 2>&1 && found=1 || found=0 ;; \
				acme-asm)   desc="Assembly (ACME)"; \
				            ok="acme"; miss="acme"; \
				            command -v acme >/dev/null 2>&1 && found=1 || found=0 ;; \
				basic)      desc="Interpreted BASIC (no compiler needed)"; \
				            ok="ready"; miss=""; found=1 ;; \
				prog8)      desc="Prog8 compiled language"; \
				            ok="prog8c"; miss="prog8c"; \
				            command -v prog8c >/dev/null 2>&1 && found=1 || found=0 ;; \
				llvm-mos-c) desc="C/C++ (llvm-mos, modern LLVM)"; \
				            ok="llvm-mos"; miss="llvm-mos"; \
				            command -v mos-cx16-clang >/dev/null 2>&1 && found=1 || found=0 ;; \
				rust-mos)   desc="Rust (experimental, requires Docker)"; \
				            ok="docker"; miss="docker"; \
				            command -v docker >/dev/null 2>&1 && found=1 || found=0 ;; \
				*)          desc="Custom template"; found=1; ok=""; miss="" ;; \
			esac; \
			if [ "$$found" = "1" ]; then \
				printf "  $(CYAN)%-14s$(RESET) %-40s $(GREEN)✓ %s$(RESET)\n" "$$name" "$$desc" "$$ok"; \
			else \
				printf "  $(CYAN)%-14s$(RESET) %-40s $(YELLOW)✗ %s not found$(RESET)\n" "$$name" "$$desc" "$$miss"; \
			fi; \
		fi; \
	done
	@echo ""
	@echo "Usage: make new-project NAME=<name> TEMPLATE=<template>"
	@echo ""
