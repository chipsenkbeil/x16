#!/usr/bin/env bash
# =============================================================================
# setup.sh - Commander X16 Development Environment Setup
#
# Detects macOS or Linux, installs cc65, ACME assembler, x16 emulator, ROM,
# and optional tools (Python3+Pillow, lzsa, prog8, llvm-mos, rust-mos).
#
# Usage:
#   ./scripts/setup.sh                    # Install core tools (cc65, acme, emulator, rom)
#   ./scripts/setup.sh --all              # Install everything
#   ./scripts/setup.sh --minimal          # Only check/report what's installed
#   ./scripts/setup.sh --core             # cc65 + acme + emulator + rom (default)
#   ./scripts/setup.sh --prog8            # Install prog8c
#   ./scripts/setup.sh --llvm-mos         # Install llvm-mos SDK
#   ./scripts/setup.sh --rust-mos         # Pull rust-mos Docker image
#   ./scripts/setup.sh cc65 prog8 emulator  # Named components
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

# Components to install
INSTALL_CC65=false
INSTALL_ACME=false
INSTALL_EMULATOR=false
INSTALL_ROM=false
INSTALL_PYTHON=false
INSTALL_LZSA=false
INSTALL_PROG8=false
INSTALL_LLVM_MOS=false
INSTALL_RUST_MOS=false

# Track what happened for the summary
declare -a INSTALLED=()
declare -a FOUND=()
declare -a SKIPPED=()
declare -a FAILED=()

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
parse_args() {
    if [[ $# -eq 0 ]]; then
        # Default: install core tools
        INSTALL_CC65=true
        INSTALL_ACME=true
        INSTALL_EMULATOR=true
        INSTALL_ROM=true
        INSTALL_PYTHON=true
        INSTALL_LZSA=true
        return
    fi

    for arg in "$@"; do
        case "$arg" in
            --minimal)
                MINIMAL=true
                # Check everything in minimal mode
                INSTALL_CC65=true
                INSTALL_ACME=true
                INSTALL_EMULATOR=true
                INSTALL_ROM=true
                INSTALL_PYTHON=true
                INSTALL_LZSA=true
                INSTALL_PROG8=true
                INSTALL_LLVM_MOS=true
                INSTALL_RUST_MOS=true
                ;;
            --all)
                INSTALL_CC65=true
                INSTALL_ACME=true
                INSTALL_EMULATOR=true
                INSTALL_ROM=true
                INSTALL_PYTHON=true
                INSTALL_LZSA=true
                INSTALL_PROG8=true
                INSTALL_LLVM_MOS=true
                # rust-mos excluded from --all (Docker pull is invasive)
                ;;
            --core)
                INSTALL_CC65=true
                INSTALL_ACME=true
                INSTALL_EMULATOR=true
                INSTALL_ROM=true
                ;;
            --prog8)
                INSTALL_PROG8=true
                ;;
            --llvm-mos)
                INSTALL_LLVM_MOS=true
                ;;
            --rust-mos)
                INSTALL_RUST_MOS=true
                ;;
            # Named components
            cc65)       INSTALL_CC65=true ;;
            acme)       INSTALL_ACME=true ;;
            emulator)   INSTALL_EMULATOR=true ;;
            rom)        INSTALL_ROM=true ;;
            python)     INSTALL_PYTHON=true ;;
            lzsa)       INSTALL_LZSA=true ;;
            prog8)      INSTALL_PROG8=true ;;
            llvm-mos)   INSTALL_LLVM_MOS=true ;;
            rust-mos)   INSTALL_RUST_MOS=true ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown argument: $arg"
                show_usage
                exit 1
                ;;
        esac
    done
}

show_usage() {
    echo "Usage: $0 [options] [components...]"
    echo ""
    echo "Options:"
    echo "  (no args)     Install core tools (cc65, acme, emulator, rom)"
    echo "  --all         Install everything (except rust-mos Docker image)"
    echo "  --minimal     Only check/report what's installed"
    echo "  --core        Install core tools (cc65, acme, emulator, rom)"
    echo "  --prog8       Install prog8c compiler"
    echo "  --llvm-mos    Install llvm-mos SDK"
    echo "  --rust-mos    Pull rust-mos Docker image"
    echo "  --help        Show this help"
    echo ""
    echo "Components (can combine multiple):"
    echo "  cc65 acme emulator rom python lzsa prog8 llvm-mos rust-mos"
    echo ""
    echo "Examples:"
    echo "  $0                     # Install core toolchain"
    echo "  $0 --all               # Install everything"
    echo "  $0 --prog8             # Install just prog8c"
    echo "  $0 cc65 prog8 emulator # Install specific components"
}

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
# Install Prog8 compiler
# ---------------------------------------------------------------------------
install_prog8() {
    header "Prog8 Compiler"

    if cmd_exists prog8c; then
        local ver
        ver="$(prog8c --version 2>&1 | head -1 || echo "unknown")"
        success "prog8c already installed: $ver"
        FOUND+=("prog8c")
        return
    fi

    if $MINIMAL; then
        warn "prog8c is NOT installed"
        SKIPPED+=("prog8c")
        return
    fi

    info "Installing prog8c ..."

    if [[ "$OS" == "macos" ]] && cmd_exists brew; then
        info "Using Homebrew ..."
        brew install prog8
    else
        # Check for Java (required dependency)
        if ! cmd_exists java; then
            warn "Java 11+ is required for prog8c."
            if [[ "$OS" == "linux" ]] && cmd_exists pacman; then
                info "Installing Java via pacman ..."
                sudo pacman -S --noconfirm --needed jdk-openjdk
            elif [[ "$OS" == "linux" ]] && cmd_exists apt-get; then
                info "Installing Java via apt ..."
                sudo apt-get update -qq
                sudo apt-get install -y default-jdk
            else
                error "Please install Java 11+ manually, then re-run this script."
                FAILED+=("prog8c")
                return
            fi
        fi

        # Check for 64tass (required assembler backend)
        if ! cmd_exists 64tass; then
            info "Installing 64tass (required by prog8c) ..."
            local build_dir
            build_dir="$(mktemp -d)"
            if git clone https://github.com/irmen/64tass.git "$build_dir/64tass" 2>/dev/null; then
                make -C "$build_dir/64tass" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"
                sudo cp "$build_dir/64tass/64tass" /usr/local/bin/64tass
                chmod +x /usr/local/bin/64tass
                rm -rf "$build_dir"
            else
                warn "64tass build failed. prog8c requires 64tass to work."
            fi
        fi

        # Download prog8c release JAR
        info "Downloading prog8c from GitHub releases ..."
        local download_url
        download_url="$(curl -sL https://api.github.com/repos/irmen/prog8/releases/latest | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data.get('assets', []):
    if asset['name'].endswith('.jar'):
        print(asset['browser_download_url'])
        break
" 2>/dev/null || true)"

        if [[ -n "$download_url" ]]; then
            local install_dir="$HOME/.local/share/prog8"
            mkdir -p "$install_dir"
            local jar_name
            jar_name="$(basename "$download_url")"
            info "Downloading: $download_url"
            if curl -sL "$download_url" -o "$install_dir/$jar_name"; then
                # Create wrapper script
                mkdir -p "$HOME/.local/bin"
                cat > "$HOME/.local/bin/prog8c" << WRAPPER
#!/usr/bin/env bash
exec java -jar "$install_dir/$jar_name" "\$@"
WRAPPER
                chmod +x "$HOME/.local/bin/prog8c"
                info "Installed prog8c wrapper to ~/.local/bin/prog8c"
                info "Make sure ~/.local/bin is in your PATH."
            else
                error "Failed to download prog8c JAR"
                FAILED+=("prog8c")
                return
            fi
        else
            error "Could not find prog8c release on GitHub"
            FAILED+=("prog8c")
            return
        fi
    fi

    if cmd_exists prog8c; then
        success "prog8c installed successfully"
        INSTALLED+=("prog8c")
    else
        warn "prog8c installed to ~/.local/bin/prog8c — add ~/.local/bin to PATH"
        INSTALLED+=("prog8c")
    fi
}

# ---------------------------------------------------------------------------
# Install llvm-mos SDK
# ---------------------------------------------------------------------------
install_llvm_mos() {
    header "llvm-mos SDK"

    if cmd_exists mos-cx16-clang; then
        success "mos-cx16-clang found in PATH"
        FOUND+=("llvm-mos")
        return
    fi

    if $MINIMAL; then
        warn "llvm-mos (mos-cx16-clang) is NOT installed"
        SKIPPED+=("llvm-mos")
        return
    fi

    info "Installing llvm-mos SDK ..."

    local platform_slug=""
    if [[ "$OS" == "macos" ]]; then
        platform_slug="macos"
    elif [[ "$OS" == "linux" ]]; then
        platform_slug="linux"
    fi

    if [[ -z "$platform_slug" ]]; then
        error "Unsupported platform for llvm-mos SDK download"
        FAILED+=("llvm-mos")
        return
    fi

    local install_dir="$HOME/.local/share/llvm-mos"

    info "Downloading llvm-mos SDK for $platform_slug ..."
    local archive_file
    archive_file="$(mktemp)"
    local download_url="https://github.com/llvm-mos/llvm-mos-sdk/releases/latest/download/llvm-mos-${platform_slug}.tar.xz"

    if curl -sL "$download_url" -o "$archive_file"; then
        info "Extracting to $install_dir ..."
        mkdir -p "$install_dir"
        tar xf "$archive_file" -C "$HOME/.local/share/" 2>/dev/null || {
            # Try .tar.gz if .tar.xz fails
            rm -f "$archive_file"
            download_url="https://github.com/llvm-mos/llvm-mos-sdk/releases/latest/download/llvm-mos-${platform_slug}.tar.gz"
            archive_file="$(mktemp)"
            curl -sL "$download_url" -o "$archive_file"
            tar xzf "$archive_file" -C "$HOME/.local/share/"
        }
        rm -f "$archive_file"

        if [[ -x "$install_dir/bin/mos-cx16-clang" ]]; then
            success "llvm-mos SDK installed to $install_dir"
            info "Add to PATH:  export PATH=\"$install_dir/bin:\$PATH\""
            INSTALLED+=("llvm-mos")
        else
            error "llvm-mos SDK extraction succeeded but mos-cx16-clang not found"
            FAILED+=("llvm-mos")
        fi
    else
        error "Failed to download llvm-mos SDK"
        error "Download manually from: https://github.com/llvm-mos/llvm-mos-sdk/releases"
        FAILED+=("llvm-mos")
    fi
}

# ---------------------------------------------------------------------------
# Install rust-mos (Docker)
# ---------------------------------------------------------------------------
install_rust_mos() {
    header "rust-mos (Rust for 6502 via Docker)"

    if ! cmd_exists docker; then
        if $MINIMAL; then
            warn "docker is NOT installed (required for rust-mos)"
            SKIPPED+=("rust-mos")
        else
            error "Docker is required for rust-mos but not installed."
            error "Install Docker: https://docs.docker.com/get-docker/"
            FAILED+=("rust-mos")
        fi
        return
    fi

    success "Docker found: $(docker --version 2>&1)"

    if $MINIMAL; then
        # Just check if the image exists
        if docker image inspect mrkits/rust-mos &>/dev/null || docker image inspect mikaellund/rust-mos &>/dev/null; then
            success "rust-mos Docker image found"
            FOUND+=("rust-mos")
        else
            warn "rust-mos Docker image not pulled yet"
            SKIPPED+=("rust-mos")
        fi
        return
    fi

    local image=""
    case "$ARCH" in
        arm64|aarch64)
            image="mikaellund/rust-mos"
            info "ARM architecture detected, using $image"
            ;;
        *)
            image="mrkits/rust-mos"
            info "x86 architecture, using $image"
            ;;
    esac

    info "Pulling Docker image: $image ..."
    if docker pull "$image"; then
        success "rust-mos Docker image pulled: $image"
        INSTALLED+=("rust-mos")
    else
        error "Failed to pull rust-mos Docker image"
        FAILED+=("rust-mos")
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
        success "cc65:      $(cc65 --version 2>&1 | head -1)"
    else
        warn "cc65:      not found"
        all_good=false
    fi

    # ca65 (ships with cc65)
    if cmd_exists ca65; then
        success "ca65:      $(ca65 --version 2>&1 | head -1)"
    else
        warn "ca65:      not found"
    fi

    # ACME
    if cmd_exists acme; then
        success "acme:      $(acme --version 2>&1 | head -1)"
    else
        warn "acme:      not found"
        all_good=false
    fi

    # x16emu
    if cmd_exists x16emu; then
        success "x16emu:    found in PATH"
    elif [[ -x "$UPSTREAM_DIR/x16-emulator/x16emu" ]]; then
        success "x16emu:    $UPSTREAM_DIR/x16-emulator/x16emu"
    else
        warn "x16emu:    not found"
        all_good=false
    fi

    # ROM
    local rom_found=false
    for loc in "$UPSTREAM_DIR/x16-emulator/rom.bin" "$UPSTREAM_DIR/x16-rom/rom.bin" "$UPSTREAM_DIR/x16-rom/build/x16/rom.bin"; do
        if [[ -f "$loc" ]]; then
            success "ROM:       $loc ($(wc -c < "$loc" | tr -d ' ') bytes)"
            rom_found=true
            break
        fi
    done
    if ! $rom_found; then
        warn "ROM:       not found"
        all_good=false
    fi

    # Python3
    if cmd_exists python3; then
        success "python3:   $(python3 --version 2>&1)"
    else
        info "python3:   not found (optional)"
    fi

    # lzsa
    if cmd_exists lzsa; then
        success "lzsa:      found"
    else
        info "lzsa:      not found (optional)"
    fi

    # prog8c
    if cmd_exists prog8c; then
        success "prog8c:    $(prog8c --version 2>&1 | head -1 || echo "found")"
    else
        info "prog8c:    not found (install with: $0 --prog8)"
    fi

    # llvm-mos
    if cmd_exists mos-cx16-clang; then
        success "llvm-mos:  found in PATH"
    elif [[ -x "$HOME/.local/share/llvm-mos/bin/mos-cx16-clang" ]]; then
        success "llvm-mos:  $HOME/.local/share/llvm-mos/bin/mos-cx16-clang"
    else
        info "llvm-mos:  not found (install with: $0 --llvm-mos)"
    fi

    # Docker (for rust-mos)
    if cmd_exists docker; then
        success "docker:    $(docker --version 2>&1)"
    else
        info "docker:    not found (needed for rust-mos template)"
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
    parse_args "$@"

    header "Commander X16 Development Environment Setup"

    if $MINIMAL; then
        info "Running in --minimal mode (check only, no installs)"
    fi

    detect_os

    $INSTALL_CC65     && install_cc65
    $INSTALL_ACME     && install_acme
    $INSTALL_EMULATOR && install_emulator
    $INSTALL_ROM      && install_rom
    $INSTALL_PYTHON   && install_python_pillow
    $INSTALL_LZSA     && install_lzsa
    $INSTALL_PROG8    && install_prog8
    $INSTALL_LLVM_MOS && install_llvm_mos
    $INSTALL_RUST_MOS && install_rust_mos

    verify_installations
    print_summary

    if $MINIMAL; then
        info "Run without --minimal to install missing tools."
    fi
}

main "$@"
