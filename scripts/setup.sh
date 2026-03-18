#!/usr/bin/env bash
# =============================================================================
# setup.sh - Commander X16 Development Environment Setup
#
# Detects macOS or Linux, installs cc65, ACME assembler, x16 emulator, ROM,
# and optional tools (Python3+Pillow, lzsa).
#
# Usage:
#   ./scripts/setup.sh            # Full install
#   ./scripts/setup.sh --minimal  # Only check/report what's installed
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
NC='\033[0m' # No Color

info()    { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERR]${NC}   %s\n" "$*"; }
header()  { printf "\n${BOLD}=== %s ===${NC}\n" "$*"; }

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$PROJECT_ROOT/upstream"

MINIMAL=false
if [[ "${1:-}" == "--minimal" ]]; then
    MINIMAL=true
fi

# Track what happened for the summary
declare -a INSTALLED=()
declare -a FOUND=()
declare -a SKIPPED=()
declare -a FAILED=()

# ---------------------------------------------------------------------------
# OS Detection
# ---------------------------------------------------------------------------
detect_os() {
    header "Detecting Operating System"
    case "$(uname -s)" in
        Darwin*)  OS="macos"; success "macOS detected ($(sw_vers -productVersion))" ;;
        Linux*)
            OS="linux"
            if [[ -f /etc/os-release ]]; then
                local distro_name
                distro_name="$(. /etc/os-release && echo "${PRETTY_NAME:-Linux}")"
                success "Linux detected: $distro_name ($(uname -r))"
            else
                success "Linux detected ($(uname -r))"
            fi
            ;;
        *)        error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac

    # Detect architecture
    ARCH="$(uname -m)"
    info "Architecture: $ARCH"
}

# ---------------------------------------------------------------------------
# Helpers: check if a command exists
# ---------------------------------------------------------------------------
cmd_exists() {
    command -v "$1" &>/dev/null
}

# ---------------------------------------------------------------------------
# Install cc65
# ---------------------------------------------------------------------------
install_cc65() {
    header "cc65 (6502 C Compiler Suite)"

    if cmd_exists cc65; then
        local ver
        ver="$(cc65 --version 2>&1 | head -1 || echo "unknown")"
        success "cc65 already installed: $ver"
        FOUND+=("cc65")
        return
    fi

    if $MINIMAL; then
        warn "cc65 is NOT installed"
        SKIPPED+=("cc65")
        return
    fi

    info "Installing cc65 ..."

    if [[ "$OS" == "macos" ]] && cmd_exists brew; then
        info "Using Homebrew ..."
        brew install cc65
    elif [[ "$OS" == "linux" ]] && cmd_exists pacman; then
        info "Using pacman ..."
        sudo pacman -S --noconfirm --needed cc65
    elif [[ "$OS" == "linux" ]] && cmd_exists apt-get; then
        info "Using apt ..."
        sudo apt-get update -qq
        sudo apt-get install -y cc65
    else
        # Fallback: build from source
        info "Building cc65 from source ..."
        local build_dir
        build_dir="$(mktemp -d)"
        git clone https://github.com/cc65/cc65.git "$build_dir/cc65"
        make -C "$build_dir/cc65" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"
        sudo make -C "$build_dir/cc65" install PREFIX=/usr/local
        rm -rf "$build_dir"
    fi

    if cmd_exists cc65; then
        success "cc65 installed successfully"
        INSTALLED+=("cc65")
    else
        error "cc65 installation failed"
        FAILED+=("cc65")
    fi
}

# ---------------------------------------------------------------------------
# Install ACME assembler
# ---------------------------------------------------------------------------
install_acme() {
    header "ACME Assembler"

    if cmd_exists acme; then
        local ver
        ver="$(acme --version 2>&1 | head -1 || echo "unknown")"
        success "ACME already installed: $ver"
        FOUND+=("acme")
        return
    fi

    if $MINIMAL; then
        warn "ACME is NOT installed"
        SKIPPED+=("acme")
        return
    fi

    info "Building ACME from source ..."
    local build_dir
    build_dir="$(mktemp -d)"
    git clone https://github.com/meonwax/acme.git "$build_dir/acme"
    make -C "$build_dir/acme/src" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"
    sudo cp "$build_dir/acme/src/acme" /usr/local/bin/acme
    rm -rf "$build_dir"

    if cmd_exists acme; then
        success "ACME installed successfully"
        INSTALLED+=("acme")
    else
        error "ACME installation failed"
        FAILED+=("acme")
    fi
}

# ---------------------------------------------------------------------------
# Install x16 emulator
# ---------------------------------------------------------------------------
install_emulator() {
    header "Commander X16 Emulator"

    # Check common locations
    if cmd_exists x16emu; then
        success "x16emu found in PATH"
        FOUND+=("x16emu")
        return
    fi

    if [[ -x "$UPSTREAM_DIR/x16-emulator/x16emu" ]]; then
        success "x16emu found at $UPSTREAM_DIR/x16-emulator/x16emu"
        FOUND+=("x16emu")
        return
    fi

    if $MINIMAL; then
        warn "x16emu is NOT installed"
        SKIPPED+=("x16emu")
        return
    fi

    info "Attempting to download latest x16-emulator release ..."
    mkdir -p "$UPSTREAM_DIR/x16-emulator"

    # Determine the asset name pattern for the current platform
    local asset_pattern=""
    if [[ "$OS" == "macos" ]]; then
        asset_pattern="mac"
    elif [[ "$OS" == "linux" ]]; then
        asset_pattern="linux"
    fi

    # Try to download the latest release from GitHub
    local download_success=false
    if cmd_exists curl; then
        info "Querying GitHub releases for x16-emulator ..."
        local release_json
        release_json="$(curl -sL https://api.github.com/repos/X16Community/x16-emulator/releases/latest)" || true

        if [[ -n "$release_json" ]]; then
            # Extract download URL matching our platform
            local download_url
            download_url="$(echo "$release_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
pattern = '$asset_pattern'
for asset in data.get('assets', []):
    name = asset['name'].lower()
    if pattern in name and (name.endswith('.zip') or name.endswith('.tar.gz') or name.endswith('.tgz')):
        print(asset['browser_download_url'])
        break
" 2>/dev/null || true)"

            if [[ -n "$download_url" ]]; then
                info "Downloading: $download_url"
                local archive_file
                archive_file="$(mktemp)"
                if curl -sL "$download_url" -o "$archive_file"; then
                    info "Extracting emulator ..."
                    local ext_dir
                    ext_dir="$(mktemp -d)"
                    if [[ "$download_url" == *.zip ]]; then
                        unzip -q "$archive_file" -d "$ext_dir"
                    else
                        tar xzf "$archive_file" -C "$ext_dir"
                    fi
                    # Find the x16emu binary in extracted files
                    local emu_bin
                    emu_bin="$(find "$ext_dir" -name 'x16emu' -type f 2>/dev/null | head -1)"
                    if [[ -n "$emu_bin" ]]; then
                        cp "$emu_bin" "$UPSTREAM_DIR/x16-emulator/x16emu"
                        chmod +x "$UPSTREAM_DIR/x16-emulator/x16emu"
                        # Also copy any supporting files (rom.bin, etc.) that may be bundled
                        local emu_parent
                        emu_parent="$(dirname "$emu_bin")"
                        find "$emu_parent" -maxdepth 1 -type f ! -name 'x16emu' -exec cp {} "$UPSTREAM_DIR/x16-emulator/" \;
                        download_success=true
                    fi
                    rm -rf "$ext_dir"
                fi
                rm -f "$archive_file"
            fi
        fi
    fi

    # Fallback: build from source
    if ! $download_success; then
        warn "Release download failed, building from source ..."
        info "SDL2 is required to build the emulator."

        # Install SDL2 dependency
        if [[ "$OS" == "macos" ]] && cmd_exists brew; then
            brew install sdl2
        elif [[ "$OS" == "linux" ]] && cmd_exists pacman; then
            sudo pacman -S --noconfirm --needed sdl2
        elif [[ "$OS" == "linux" ]] && cmd_exists apt-get; then
            sudo apt-get install -y libsdl2-dev
        fi

        local build_dir
        build_dir="$(mktemp -d)"
        git clone https://github.com/X16Community/x16-emulator.git "$build_dir/x16-emulator"
        make -C "$build_dir/x16-emulator" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"
        cp "$build_dir/x16-emulator/x16emu" "$UPSTREAM_DIR/x16-emulator/x16emu"
        chmod +x "$UPSTREAM_DIR/x16-emulator/x16emu"
        rm -rf "$build_dir"
    fi

    if [[ -x "$UPSTREAM_DIR/x16-emulator/x16emu" ]]; then
        success "x16emu installed to $UPSTREAM_DIR/x16-emulator/x16emu"
        INSTALLED+=("x16emu")
    else
        error "x16emu installation failed"
        FAILED+=("x16emu")
    fi
}

# ---------------------------------------------------------------------------
# Install ROM binary
# ---------------------------------------------------------------------------
install_rom() {
    header "Commander X16 ROM"

    # Check common locations
    local rom_locations=(
        "$UPSTREAM_DIR/x16-emulator/rom.bin"
        "$UPSTREAM_DIR/x16-rom/build/x16/rom.bin"
        "$UPSTREAM_DIR/x16-rom/rom.bin"
    )

    for loc in "${rom_locations[@]}"; do
        if [[ -f "$loc" ]]; then
            success "ROM found at $loc"
            FOUND+=("rom.bin")
            return
        fi
    done

    if $MINIMAL; then
        warn "ROM binary is NOT installed"
        SKIPPED+=("rom.bin")
        return
    fi

    info "Downloading latest ROM binary from GitHub releases ..."
    mkdir -p "$UPSTREAM_DIR/x16-rom"

    local download_success=false
    if cmd_exists curl; then
        local release_json
        release_json="$(curl -sL https://api.github.com/repos/X16Community/x16-rom/releases/latest)" || true

        if [[ -n "$release_json" ]]; then
            local download_url
            download_url="$(echo "$release_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data.get('assets', []):
    name = asset['name'].lower()
    if 'rom' in name and (name.endswith('.zip') or name.endswith('.tar.gz') or name.endswith('.tgz') or name.endswith('.bin')):
        print(asset['browser_download_url'])
        break
" 2>/dev/null || true)"

            if [[ -n "$download_url" ]]; then
                info "Downloading: $download_url"
                local archive_file
                archive_file="$(mktemp)"
                if curl -sL "$download_url" -o "$archive_file"; then
                    # Check if it's a direct binary or an archive
                    if [[ "$download_url" == *.bin ]]; then
                        cp "$archive_file" "$UPSTREAM_DIR/x16-rom/rom.bin"
                        download_success=true
                    elif [[ "$download_url" == *.zip ]]; then
                        local ext_dir
                        ext_dir="$(mktemp -d)"
                        unzip -q "$archive_file" -d "$ext_dir"
                        local rom_bin
                        rom_bin="$(find "$ext_dir" -name 'rom.bin' -type f 2>/dev/null | head -1)"
                        if [[ -n "$rom_bin" ]]; then
                            cp "$rom_bin" "$UPSTREAM_DIR/x16-rom/rom.bin"
                            download_success=true
                        fi
                        rm -rf "$ext_dir"
                    else
                        local ext_dir
                        ext_dir="$(mktemp -d)"
                        tar xzf "$archive_file" -C "$ext_dir" 2>/dev/null || true
                        local rom_bin
                        rom_bin="$(find "$ext_dir" -name 'rom.bin' -type f 2>/dev/null | head -1)"
                        if [[ -n "$rom_bin" ]]; then
                            cp "$rom_bin" "$UPSTREAM_DIR/x16-rom/rom.bin"
                            download_success=true
                        fi
                        rm -rf "$ext_dir"
                    fi
                fi
                rm -f "$archive_file"
            fi
        fi
    fi

    if $download_success && [[ -f "$UPSTREAM_DIR/x16-rom/rom.bin" ]]; then
        success "ROM installed to $UPSTREAM_DIR/x16-rom/rom.bin"
        INSTALLED+=("rom.bin")
    else
        error "ROM download failed - you may need to build it from source"
        error "  git clone https://github.com/X16Community/x16-rom.git"
        error "  cd x16-rom && make"
        FAILED+=("rom.bin")
    fi
}

# ---------------------------------------------------------------------------
# Optional: Python3 + Pillow
# ---------------------------------------------------------------------------
install_python_pillow() {
    header "Optional: Python3 + Pillow"

    if cmd_exists python3; then
        success "Python3 found: $(python3 --version 2>&1)"
        FOUND+=("python3")

        if python3 -c "import PIL" 2>/dev/null; then
            success "Pillow is installed"
            FOUND+=("pillow")
        else
            if $MINIMAL; then
                warn "Pillow is NOT installed (pip3 install Pillow)"
                SKIPPED+=("pillow")
            else
                info "Installing Pillow ..."
                pip3 install --user Pillow && {
                    success "Pillow installed"
                    INSTALLED+=("pillow")
                } || {
                    warn "Pillow installation failed (non-critical)"
                    FAILED+=("pillow")
                }
            fi
        fi
    else
        warn "Python3 not found (optional, needed for asset conversion)"
        SKIPPED+=("python3")
    fi
}

# ---------------------------------------------------------------------------
# Optional: lzsa
# ---------------------------------------------------------------------------
install_lzsa() {
    header "Optional: lzsa (compression)"

    if cmd_exists lzsa; then
        success "lzsa found in PATH"
        FOUND+=("lzsa")
        return
    fi

    if $MINIMAL; then
        warn "lzsa is NOT installed"
        SKIPPED+=("lzsa")
        return
    fi

    info "Building lzsa from source ..."
    local build_dir
    build_dir="$(mktemp -d)"
    if git clone https://github.com/emmanuel-marty/lzsa.git "$build_dir/lzsa" 2>/dev/null; then
        if make -C "$build_dir/lzsa" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)" 2>/dev/null; then
            sudo cp "$build_dir/lzsa/lzsa" /usr/local/bin/lzsa
            chmod +x /usr/local/bin/lzsa
            success "lzsa installed"
            INSTALLED+=("lzsa")
        else
            warn "lzsa build failed (non-critical)"
            FAILED+=("lzsa")
        fi
        rm -rf "$build_dir"
    else
        warn "lzsa clone failed (non-critical)"
        FAILED+=("lzsa")
    fi
}

# ---------------------------------------------------------------------------
# Verify installations
# ---------------------------------------------------------------------------
verify_installations() {
    header "Verifying Installations"

    local all_good=true

    # cc65
    if cmd_exists cc65; then
        success "cc65:   $(cc65 --version 2>&1 | head -1)"
    else
        warn "cc65:   not found"
        all_good=false
    fi

    # ca65 (ships with cc65)
    if cmd_exists ca65; then
        success "ca65:   $(ca65 --version 2>&1 | head -1)"
    else
        warn "ca65:   not found"
    fi

    # ACME
    if cmd_exists acme; then
        success "acme:   $(acme --version 2>&1 | head -1)"
    else
        warn "acme:   not found"
        all_good=false
    fi

    # x16emu
    if cmd_exists x16emu; then
        success "x16emu: found in PATH"
    elif [[ -x "$UPSTREAM_DIR/x16-emulator/x16emu" ]]; then
        success "x16emu: $UPSTREAM_DIR/x16-emulator/x16emu"
    else
        warn "x16emu: not found"
        all_good=false
    fi

    # ROM
    local rom_found=false
    for loc in "$UPSTREAM_DIR/x16-emulator/rom.bin" "$UPSTREAM_DIR/x16-rom/rom.bin" "$UPSTREAM_DIR/x16-rom/build/x16/rom.bin"; do
        if [[ -f "$loc" ]]; then
            success "ROM:    $loc ($(wc -c < "$loc" | tr -d ' ') bytes)"
            rom_found=true
            break
        fi
    done
    if ! $rom_found; then
        warn "ROM:    not found"
        all_good=false
    fi

    # Python3
    if cmd_exists python3; then
        success "python3: $(python3 --version 2>&1)"
    else
        info "python3: not found (optional)"
    fi

    # lzsa
    if cmd_exists lzsa; then
        success "lzsa:   found"
    else
        info "lzsa:   not found (optional)"
    fi

    echo ""
    if $all_good; then
        success "All core tools are available!"
    else
        warn "Some tools are missing. Re-run setup or install them manually."
    fi
}

# ---------------------------------------------------------------------------
# Print summary
# ---------------------------------------------------------------------------
print_summary() {
    header "Summary"

    if [[ ${#FOUND[@]} -gt 0 ]]; then
        printf "${GREEN}Already installed:${NC} %s\n" "${FOUND[*]}"
    fi
    if [[ ${#INSTALLED[@]} -gt 0 ]]; then
        printf "${GREEN}Newly installed:${NC}   %s\n" "${INSTALLED[*]}"
    fi
    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        printf "${YELLOW}Skipped/missing:${NC}   %s\n" "${SKIPPED[*]}"
    fi
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        printf "${RED}Failed:${NC}            %s\n" "${FAILED[*]}"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    header "Commander X16 Development Environment Setup"

    if $MINIMAL; then
        info "Running in --minimal mode (check only, no installs)"
    fi

    detect_os

    install_cc65
    install_acme
    install_emulator
    install_rom
    install_python_pillow
    install_lzsa

    verify_installations
    print_summary

    if $MINIMAL; then
        info "Run without --minimal to install missing tools."
    fi
}

main "$@"
