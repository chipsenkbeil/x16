#!/usr/bin/env bash
# =============================================================================
# select-project.sh - Interactive project selector for make build/run/clean
#
# Usage:
#   ./scripts/select-project.sh [--allow-all]
#
# Displays a numbered menu of projects to stderr, reads choice from /dev/tty,
# and outputs the selected project path (or "ALL") to stdout.
#
# Options:
#   --allow-all    Include an "All projects" option (outputs literal "ALL")
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

info()    { printf "${CYAN}[INFO]${NC}  %s\n" "$*" >&2; }
error()   { printf "${RED}[ERR]${NC}   %s\n" "$*" >&2; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$PROJECT_ROOT/projects"

ALLOW_ALL=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --allow-all) ALLOW_ALL=true ;;
        *) error "Unknown option: $arg"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# TTY detection
# ---------------------------------------------------------------------------
if [[ ! -t 0 ]] && [[ ! -t 2 ]]; then
    error "Non-interactive shell. Use: make build PROJECT=projects/<name>"
    exit 1
fi

# ---------------------------------------------------------------------------
# Discover projects
# ---------------------------------------------------------------------------
projects=()
for dir in "$PROJECTS_DIR"/*/; do
    if [[ -f "$dir/Makefile" ]]; then
        projects+=("$(basename "$dir")")
    fi
done

if [[ ${#projects[@]} -eq 0 ]]; then
    error "No projects found in $PROJECTS_DIR/"
    error "Create one with: make new-project NAME=<name>"
    exit 1
fi

# Sort projects alphabetically
IFS=$'\n' projects=($(sort <<<"${projects[*]}")); unset IFS

# ---------------------------------------------------------------------------
# Build menu
# ---------------------------------------------------------------------------
echo "" >&2
printf "${BOLD}Select a project:${NC}\n" >&2
echo "" >&2

idx=1
for p in "${projects[@]}"; do
    printf "  ${CYAN}%d)${NC} %s\n" "$idx" "$p" >&2
    ((idx++))
done

if $ALLOW_ALL; then
    printf "  ${CYAN}%d)${NC} All projects\n" "$idx" >&2
    all_idx=$idx
    ((idx++))
fi

printf "  ${CYAN}%d)${NC} Custom path...\n" "$idx" >&2
custom_idx=$idx

echo "" >&2
printf "Choice [1-%d]: " "$idx" >&2

# ---------------------------------------------------------------------------
# Read user choice
# ---------------------------------------------------------------------------
read -r choice </dev/tty

# Validate input is a number
if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
    error "Invalid choice: '$choice'"
    exit 1
fi

if [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$custom_idx" ]]; then
    error "Choice out of range: $choice"
    exit 1
fi

# ---------------------------------------------------------------------------
# Handle selection
# ---------------------------------------------------------------------------

# All projects
if $ALLOW_ALL && [[ "$choice" -eq "$all_idx" ]]; then
    echo "ALL"
    exit 0
fi

# Custom path
if [[ "$choice" -eq "$custom_idx" ]]; then
    printf "Enter project path: " >&2
    read -r custom_path </dev/tty

    if [[ -z "$custom_path" ]]; then
        error "No path entered."
        exit 1
    fi

    if [[ ! -d "$custom_path" ]]; then
        error "Directory not found: $custom_path"
        exit 1
    fi

    if [[ ! -f "$custom_path/Makefile" ]]; then
        error "No Makefile found in $custom_path"
        exit 1
    fi

    echo "$custom_path"
    exit 0
fi

# Regular project selection
selected="${projects[$((choice - 1))]}"
echo "projects/$selected"
