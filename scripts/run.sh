#!/usr/bin/env bash
# =============================================================================
# run.sh - Build and run a Commander X16 project in the emulator
#
# Usage:
#   ./scripts/run.sh [project-path] [extra-emu-args...]
#
# Examples:
#   ./scripts/run.sh projects/my-game
#   ./scripts/run.sh projects/my-game -scale 2 -debug
#   ./scripts/run.sh .                           # Run from current directory
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors and helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERR]${NC}   %s\n" "$*" >&2; }
header()  { printf "\n${BOLD}=== %s ===${NC}\n" "$*"; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$PROJECT_ROOT/upstream"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
# First argument is the project path (optional, defaults to current directory)
# Remaining arguments are passed to x16emu

PROJECT_PATH=""
EXTRA_ARGS=()

if [[ $# -ge 1 && ! "$1" =~ ^- ]]; then
    PROJECT_PATH="$1"
    shift
else
    PROJECT_PATH="."
fi

EXTRA_ARGS=("$@")

# Resolve to absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
    error "Project directory not found: $PROJECT_PATH"
    exit 1
}

# ---------------------------------------------------------------------------
# Step 1: Build the project (if Makefile exists)
# ---------------------------------------------------------------------------
header "Build"

if [[ -f "$PROJECT_PATH/Makefile" ]]; then
    info "Found Makefile in $PROJECT_PATH"
    info "Running make ..."
    if make -C "$PROJECT_PATH"; then
        success "Build succeeded"
    else
        error "Build failed! Fix errors above and try again."
        exit 1
    fi
else
    info "No Makefile found, skipping build step"
fi

# ---------------------------------------------------------------------------
# Step 2: Find the program file (.prg or .bas)
# ---------------------------------------------------------------------------
header "Locate Program"

PRG_FILE=""
BAS_FILE=""

# Check for BASIC source first (src/main.bas)
if [[ -f "$PROJECT_PATH/src/main.bas" ]]; then
    BAS_FILE="$PROJECT_PATH/src/main.bas"
fi

# Look for .prg file
# Priority 1: build/ subdirectory
if [[ -d "$PROJECT_PATH/build" ]]; then
    PRG_FILE="$(find "$PROJECT_PATH/build" -maxdepth 2 -name '*.prg' -type f 2>/dev/null | head -1)"
fi

# Priority 2: project root
if [[ -z "$PRG_FILE" ]]; then
    PRG_FILE="$(find "$PROJECT_PATH" -maxdepth 1 -name '*.prg' -type f 2>/dev/null | head -1)"
fi

# Priority 3: any .prg anywhere in the project
if [[ -z "$PRG_FILE" ]]; then
    PRG_FILE="$(find "$PROJECT_PATH" -name '*.prg' -type f 2>/dev/null | head -1)"
fi

# Decide which file to use
if [[ -n "$PRG_FILE" ]]; then
    success "Found: $PRG_FILE"
elif [[ -n "$BAS_FILE" ]]; then
    success "Found BASIC source: $BAS_FILE"
else
    error "No .prg or .bas file found in $PROJECT_PATH"
    error ""
    error "Looked in:"
    error "  $PROJECT_PATH/build/"
    error "  $PROJECT_PATH/"
    error "  $PROJECT_PATH/src/main.bas"
    error ""
    error "Make sure your project builds a .prg file (or has a .bas source), then try again."
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 3: Find x16emu
# ---------------------------------------------------------------------------
header "Locate Emulator"

X16EMU=""

# Priority 1: PATH
if command -v x16emu &>/dev/null; then
    X16EMU="$(command -v x16emu)"
    success "x16emu found in PATH: $X16EMU"
fi

# Priority 2: Common install locations
if [[ -z "$X16EMU" ]]; then
    COMMON_LOCATIONS=(
        /usr/local/bin/x16emu
        /usr/bin/x16emu
        "$HOME/.local/bin/x16emu"
        /opt/x16emu/x16emu
        /Applications/x16emu.app/Contents/MacOS/x16emu
    )
    for loc in "${COMMON_LOCATIONS[@]}"; do
        if [[ -x "$loc" ]]; then
            X16EMU="$loc"
            success "x16emu found at: $X16EMU"
            break
        fi
    done
fi

# Priority 3: upstream/x16-emulator/
if [[ -z "$X16EMU" ]]; then
    if [[ -x "$UPSTREAM_DIR/x16-emulator/x16emu" ]]; then
        X16EMU="$UPSTREAM_DIR/x16-emulator/x16emu"
        success "x16emu found in upstream: $X16EMU"
    fi
fi

if [[ -z "$X16EMU" ]]; then
    error "x16emu not found!"
    error ""
    error "Looked in:"
    error "  - PATH"
    error "  - Common locations (/usr/local/bin, etc.)"
    error "  - $UPSTREAM_DIR/x16-emulator/x16emu"
    error ""
    error "Install the emulator with:  ./scripts/setup.sh"
    error "Or clone the repos with:    ./scripts/clone-repos.sh"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 4: Find ROM
# ---------------------------------------------------------------------------
header "Locate ROM"

ROM_FILE=""
EMU_DIR="$(dirname "$X16EMU")"

# Priority 1: alongside emulator
ROM_CANDIDATES=(
    "$EMU_DIR/rom.bin"
    "$EMU_DIR/ROM.BIN"
)

for rom in "${ROM_CANDIDATES[@]}"; do
    if [[ -f "$rom" ]]; then
        ROM_FILE="$rom"
        break
    fi
done

# Priority 2: upstream/x16-rom/
if [[ -z "$ROM_FILE" ]]; then
    ROM_CANDIDATES=(
        "$UPSTREAM_DIR/x16-rom/rom.bin"
        "$UPSTREAM_DIR/x16-rom/build/x16/rom.bin"
    )
    for rom in "${ROM_CANDIDATES[@]}"; do
        if [[ -f "$rom" ]]; then
            ROM_FILE="$rom"
            break
        fi
    done
fi

# Build the ROM arguments (only add -rom if ROM is not alongside the emulator)
ROM_ARGS=()
if [[ -n "$ROM_FILE" ]]; then
    success "ROM found: $ROM_FILE"
    # Only explicitly pass -rom if it's not in the same directory as the emulator
    # (the emulator auto-discovers rom.bin in its own directory)
    if [[ "$(dirname "$ROM_FILE")" != "$EMU_DIR" ]]; then
        ROM_ARGS=(-rom "$ROM_FILE")
    fi
else
    warn "ROM not found - the emulator may fail if it can't find rom.bin"
    warn ""
    warn "Looked in:"
    warn "  - $EMU_DIR/"
    warn "  - $UPSTREAM_DIR/x16-rom/"
    warn ""
    warn "Proceeding anyway (emulator may have its own ROM) ..."
fi

# ---------------------------------------------------------------------------
# Step 5: Launch the emulator
# ---------------------------------------------------------------------------
header "Launch"

# Build the full command
if [[ -n "$PRG_FILE" ]]; then
    CMD=("$X16EMU" -prg "$PRG_FILE" -run)
else
    CMD=("$X16EMU" -bas "$BAS_FILE" -run)
fi
[[ ${#ROM_ARGS[@]} -gt 0 ]] && CMD+=("${ROM_ARGS[@]}")
[[ ${#EXTRA_ARGS[@]} -gt 0 ]] && CMD+=("${EXTRA_ARGS[@]}")

info "Running:"
printf "  ${BOLD}%s${NC}\n" "${CMD[*]}"
echo ""

# Execute the emulator
exec "${CMD[@]}"
