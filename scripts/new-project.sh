#!/usr/bin/env bash
# =============================================================================
# new-project.sh - Create a new Commander X16 project from a template
#
# Usage:
#   ./scripts/new-project.sh <name> [template]
#
# Templates:
#   cc65-c     (default) - C project using cc65
#   ca65-asm             - Assembly project using ca65
#   acme-asm             - Assembly project using ACME
#   basic                - Interpreted BASIC (no compiler needed)
#   prog8                - Prog8 compiled language
#   llvm-mos-c           - C project using llvm-mos
#   rust-mos             - Rust project (experimental, requires Docker)
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
TEMPLATES_DIR="$PROJECT_ROOT/projects/templates"
PROJECTS_DIR="$PROJECT_ROOT/projects"

VALID_TEMPLATES=("cc65-c" "ca65-asm" "acme-asm" "basic" "prog8" "llvm-mos-c" "rust-mos")

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $0 <project-name> [template]"
    echo ""
    echo "Templates:"
    echo "  cc65-c       C project using cc65 (default)"
    echo "  ca65-asm     Assembly project using ca65"
    echo "  acme-asm     Assembly project using ACME assembler"
    echo "  basic        Interpreted BASIC (no compiler needed)"
    echo "  prog8        Prog8 compiled language"
    echo "  llvm-mos-c   C project using llvm-mos (modern LLVM)"
    echo "  rust-mos     Rust project (EXPERIMENTAL, requires Docker)"
    echo ""
    echo "Example:"
    echo "  $0 my-game cc65-c"
    exit 1
}

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    error "Missing project name."
    usage
fi

PROJECT_NAME="$1"
TEMPLATE="${2:-cc65-c}"

# Validate project name (alphanumeric, hyphens, underscores)
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    error "Invalid project name: '$PROJECT_NAME'"
    error "Name must start with a letter and contain only letters, digits, hyphens, and underscores."
    exit 1
fi

# Validate template name
template_valid=false
for t in "${VALID_TEMPLATES[@]}"; do
    if [[ "$t" == "$TEMPLATE" ]]; then
        template_valid=true
        break
    fi
done

if ! $template_valid; then
    error "Unknown template: '$TEMPLATE'"
    error "Valid templates: ${VALID_TEMPLATES[*]}"
    exit 1
fi

TEMPLATE_DIR="$TEMPLATES_DIR/$TEMPLATE"
DEST_DIR="$PROJECTS_DIR/$PROJECT_NAME"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
header "Creating project: $PROJECT_NAME (template: $TEMPLATE)"

# Check template exists
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    error "Template directory not found: $TEMPLATE_DIR"
    error "Make sure project templates are set up in projects/templates/"
    error "Expected templates: ${VALID_TEMPLATES[*]}"
    exit 1
fi

# Check project doesn't already exist
if [[ -d "$DEST_DIR" ]]; then
    error "Project already exists: $DEST_DIR"
    error "Choose a different name or remove the existing project first."
    exit 1
fi

# ---------------------------------------------------------------------------
# Create project from template
# ---------------------------------------------------------------------------
info "Copying template from $TEMPLATE_DIR ..."
mkdir -p "$PROJECTS_DIR"
cp -R "$TEMPLATE_DIR" "$DEST_DIR"

# ---------------------------------------------------------------------------
# Replace placeholders in all files
# ---------------------------------------------------------------------------
info "Replacing placeholders ..."

CURRENT_DATE="$(date +%Y-%m-%d)"
CURRENT_YEAR="$(date +%Y)"

# Find all files in the new project directory and perform substitutions
# Using a portable approach that works on both macOS and Linux
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]] && file "$file" | grep -q text; then
        # macOS sed requires '' after -i, Linux does not
        if [[ "$(uname -s)" == "Darwin" ]]; then
            sed -i '' \
                -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
                -e "s/{{DATE}}/$CURRENT_DATE/g" \
                -e "s/{{YEAR}}/$CURRENT_YEAR/g" \
                "$file"
        else
            sed -i \
                -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
                -e "s/{{DATE}}/$CURRENT_DATE/g" \
                -e "s/{{YEAR}}/$CURRENT_YEAR/g" \
                "$file"
        fi
    fi
done < <(find "$DEST_DIR" -type f -print0)

success "Project created at $DEST_DIR"

# ---------------------------------------------------------------------------
# Check toolchain availability for the chosen template
# ---------------------------------------------------------------------------
check_template_toolchain() {
    local template="$1"
    local missing=()
    case "$template" in
        cc65-c|ca65-asm)
            cmd_exists cc65 || missing+=("cc65 (run: make setup)")
            ;;
        acme-asm)
            cmd_exists acme || missing+=("acme (run: make setup)")
            ;;
        basic)
            cmd_exists x16emu || missing+=("x16emu (run: make setup)")
            ;;
        prog8)
            cmd_exists prog8c || missing+=("prog8c (see: https://prog8.readthedocs.io)")
            cmd_exists java   || missing+=("java 11+ (required by prog8c)")
            ;;
        llvm-mos-c)
            cmd_exists mos-cx16-clang || missing+=("mos-cx16-clang (see: https://github.com/llvm-mos/llvm-mos-sdk/releases)")
            ;;
        rust-mos)
            cmd_exists docker || missing+=("docker (rust-mos requires Docker)")
            ;;
    esac
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        warn "Missing tools for '$template' template:"
        for m in "${missing[@]}"; do
            warn "  - $m"
        done
        warn "The project was created, but you won't be able to build until these are installed."
    fi
}

cmd_exists() {
    command -v "$1" &>/dev/null
}

check_template_toolchain "$TEMPLATE"

# ---------------------------------------------------------------------------
# Print next steps
# ---------------------------------------------------------------------------
header "Next Steps"

echo ""
printf "  ${CYAN}cd${NC} projects/%s\n" "$PROJECT_NAME"
printf "  ${CYAN}make${NC}            # Build the project\n"
printf "  ${CYAN}make run${NC}        # Build and run in emulator\n"
echo ""

# Also show the contents of the new project
info "Project contents:"
find "$DEST_DIR" -type f | sort | while read -r f; do
    printf "  %s\n" "${f#$DEST_DIR/}"
done
echo ""

success "Happy coding on the Commander X16!"
