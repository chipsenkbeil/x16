#!/usr/bin/env bash
# =============================================================================
# clone-repos.sh - Clone or update all X16Community repositories
#
# Clones (or git-pulls) the 10 core X16Community repos into upstream/.
#
# Usage:
#   ./scripts/clone-repos.sh             # Full clone
#   ./scripts/clone-repos.sh --shallow   # Shallow clones (--depth 1)
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
error()   { printf "${RED}[ERR]${NC}   %s\n" "$*"; }
header()  { printf "\n${BOLD}=== %s ===${NC}\n" "$*"; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$PROJECT_ROOT/upstream"

# Parse flags
SHALLOW=false
if [[ "${1:-}" == "--shallow" ]]; then
    SHALLOW=true
fi

# The 10 X16Community repositories to clone
REPOS=(
    x16-emulator
    x16-rom
    x16-docs
    vera-module
    x16-smc
    x16-smc-bootloader
    x16-demo
    x16-flash
    x16-user-guide
    faq
)

GITHUB_ORG="https://github.com/X16Community"

# Counters
CLONED=0
UPDATED=0
FAILED=0
FAILED_NAMES=()

# ---------------------------------------------------------------------------
# Clone or update a single repo
# ---------------------------------------------------------------------------
process_repo() {
    local repo="$1"
    local repo_dir="$UPSTREAM_DIR/$repo"
    local repo_url="$GITHUB_ORG/$repo.git"

    if [[ -d "$repo_dir/.git" ]]; then
        # Repo exists - update it
        info "Updating $repo ..."
        if git -C "$repo_dir" pull --ff-only 2>&1; then
            success "Updated $repo"
            UPDATED=$((UPDATED + 1))
        else
            # pull --ff-only may fail if there are local changes; try plain pull
            if git -C "$repo_dir" pull 2>&1; then
                success "Updated $repo (with merge)"
                UPDATED=$((UPDATED + 1))
            else
                error "Failed to update $repo"
                FAILED=$((FAILED + 1))
                FAILED_NAMES+=("$repo")
            fi
        fi
    elif [[ -d "$repo_dir" ]]; then
        # Directory exists but not a git repo - warn and skip
        warn "$repo_dir exists but is not a git repository, skipping"
        FAILED=$((FAILED + 1))
        FAILED_NAMES+=("$repo")
    else
        # Fresh clone
        info "Cloning $repo ..."
        local clone_args=()
        if $SHALLOW; then
            clone_args+=(--depth 1)
        fi
        if git clone "${clone_args[@]}" "$repo_url" "$repo_dir" 2>&1; then
            success "Cloned $repo"
            CLONED=$((CLONED + 1))
        else
            error "Failed to clone $repo"
            FAILED=$((FAILED + 1))
            FAILED_NAMES+=("$repo")
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    header "Clone / Update X16Community Repositories"

    if $SHALLOW; then
        info "Shallow mode enabled (--depth 1)"
    fi

    # Ensure upstream directory exists
    mkdir -p "$UPSTREAM_DIR"

    info "Target directory: $UPSTREAM_DIR"
    info "Repositories: ${#REPOS[@]}"
    echo ""

    for repo in "${REPOS[@]}"; do
        process_repo "$repo"
    done

    # ---------------------------------------------------------------------------
    # Summary
    # ---------------------------------------------------------------------------
    header "Summary"

    local total=${#REPOS[@]}
    printf "${GREEN}Cloned:${NC}  %d / %d\n" "$CLONED" "$total"
    printf "${CYAN}Updated:${NC} %d / %d\n" "$UPDATED" "$total"

    if [[ $FAILED -gt 0 ]]; then
        printf "${RED}Failed:${NC}  %d / %d  (%s)\n" "$FAILED" "$total" "${FAILED_NAMES[*]}"
    else
        printf "${GREEN}Failed:${NC}  0 / %d\n" "$total"
    fi
    echo ""

    if [[ $FAILED -gt 0 ]]; then
        warn "Some repos could not be cloned/updated."
        exit 1
    else
        success "All repositories are up to date!"
    fi
}

main "$@"
