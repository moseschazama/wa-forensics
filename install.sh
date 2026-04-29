#!/usr/bin/env bash
# =============================================================================
#  WA-Forensics Toolkit — Installer
#  Cross-platform (macOS + Linux) dependency installer with Python venv
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

print_ok()   { echo -e "${GREEN}  [✔] $*${RESET}"; }
print_warn() { echo -e "${YELLOW}  [⚠] $*${RESET}"; }
print_err()  { echo -e "${RED}  [✘] $*${RESET}"; }
print_info() { echo -e "${CYAN}  [ℹ] $*${RESET}"; }
print_step() { echo -e "\n${BOLD}${CYAN}━━ $* ${RESET}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     WA-Forensics Toolkit — Installer v9.0.0         ║"
echo "║     macOS + Linux Cross-Platform Setup               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ── 1. Detect OS ──────────────────────────────────────────────────────────────
detect_os() {
    case "$OSTYPE" in
        linux-gnu*)
            echo "linux"
            ;;
        darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

OS_TYPE=$(detect_os)
print_info "Detected OS: ${OS_TYPE} ($OSTYPE)"

# ── 2. Install system dependencies ────────────────────────────────────────────
install_system_deps() {
    print_step "Checking and installing system dependencies"

    local missing=()

    for cmd in sqlite3 python3 awk grep sed date tar; do
        if command -v "$cmd" &>/dev/null; then
            print_ok "$cmd found"
        else
            missing+=("$cmd")
        fi
    done

    # Hash commands (platform-specific)
    if command -v sha256sum &>/dev/null || command -v shasum &>/dev/null; then
        print_ok "SHA-256 tool found"
    else
        missing+=("sha256sum or shasum")
    fi

    if command -v md5sum &>/dev/null || command -v md5 &>/dev/null; then
        print_ok "MD5 tool found"
    else
        missing+=("md5sum or md5")
    fi

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_ok "All system dependencies satisfied"
        return 0
    fi

    print_warn "Missing: ${missing[*]}"
    print_info "Installing missing packages..."

    case "$OS_TYPE" in
        linux)
            if command -v apt-get &>/dev/null; then
                print_info "Using apt package manager..."
                sudo apt-get update -qq
                sudo apt-get install -y sqlite3 coreutils python3 python3-venv tar 2>/dev/null || {
                    print_err "apt install failed. Please install manually:"
                    print_info "sudo apt-get install sqlite3 coreutils python3 python3-venv tar"
                    return 1
                }
            elif command -v yum &>/dev/null; then
                print_info "Using yum package manager..."
                sudo yum install -y sqlite coreutils python3 python3-libs tar 2>/dev/null || {
                    print_err "yum install failed. Please install manually."
                    return 1
                }
            elif command -v dnf &>/dev/null; then
                print_info "Using dnf package manager..."
                sudo dnf install -y sqlite coreutils python3 tar 2>/dev/null || {
                    print_err "dnf install failed. Please install manually."
                    return 1
                }
            else
                print_err "No supported package manager found (apt/yum/dnf)"
                print_info "Please install dependencies manually:"
                print_info "  sqlite3, coreutils, python3, python3-venv, tar"
                return 1
            fi
            ;;
        macos)
            if command -v brew &>/dev/null; then
                print_info "Using Homebrew package manager..."
                brew install sqlite3 python3 2>/dev/null || {
                    print_err "brew install failed. Please install manually:"
                    print_info "brew install sqlite3 python3"
                    return 1
                }
            else
                print_err "Homebrew not found."
                print_info "Install Homebrew first: https://brew.sh"
                print_info "Or install manually: python3 (macOS includes python3 by default)"
                return 1
            fi
            ;;
        *)
            print_err "Unsupported OS. Please install dependencies manually."
            return 1
            ;;
    esac

    print_ok "System dependencies installed"
}

# ── 3. Create Python virtual environment ──────────────────────────────────────
setup_python_venv() {
    print_step "Setting up Python virtual environment"

    local venv_dir="${SCRIPT_DIR}/.venv"

    # Determine python command
    local python_cmd="python3"
    if ! command -v python3 &>/dev/null && command -v python &>/dev/null; then
        python_cmd="python"
    fi

    # Verify Python works (detect broken installations)
    if ! $python_cmd -c "import sys; print(sys.version)" &>/dev/null; then
        print_warn "Python is installed but broken (syntax errors detected)"
        print_warn "Core toolkit features will work - decryption features unavailable"
        print_info "Fix Python: brew upgrade python@3.14 (or reinstall Python)"
        echo "$venv_dir" > "${SCRIPT_DIR}/.venv_path"
        return 0
    fi

    # Clean stale venv if present
    if [[ -d "$venv_dir" ]]; then
        rm -rf "$venv_dir"
    fi

    print_info "Creating virtual environment at .venv..."

    if $python_cmd -m venv "$venv_dir" 2>/dev/null; then
        print_ok "Virtual environment created"
    else
        print_warn "venv creation failed, using --without-pip..."
        $python_cmd -m venv --without-pip "$venv_dir" 2>/dev/null || {
            if command -v virtualenv &>/dev/null; then
                virtualenv "$venv_dir" 2>/dev/null || {
                    print_warn "Could not create venv - Python features disabled"
                    echo "$venv_dir" > "${SCRIPT_DIR}/.venv_path"
                    return 0
                }
            else
                print_warn "Could not create venv - Python features disabled"
                echo "$venv_dir" > "${SCRIPT_DIR}/.venv_path"
                return 0
            fi
        }
        print_ok "Virtual environment created"
    fi

    # Activate venv
    source "${venv_dir}/bin/activate"

    # Ensure pip is available
    if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
        $python_cmd -m ensurepip 2>/dev/null || {
            local get_pip="${SCRIPT_DIR}/.get_pip_temp.py"
            if curl -sS -o "$get_pip" https://bootstrap.pypa.io/get-pip.py 2>/dev/null; then
                $python_cmd "$get_pip" 2>/dev/null || true
                rm -f "$get_pip"
            fi
        }
    fi

    # Install Python dependencies
    if [[ -f "${SCRIPT_DIR}/requirements.txt" ]]; then
        if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
            print_info "Installing Python dependencies..."
            pip install --upgrade pip --quiet 2>/dev/null || true
            if pip install -r "${SCRIPT_DIR}/requirements.txt" --quiet 2>/dev/null; then
                print_ok "Python dependencies installed"
            else
                print_warn "pip install failed - decryption features unavailable"
            fi
        else
            print_warn "pip not available - decryption features disabled"
        fi
    fi

    echo "$venv_dir" > "${SCRIPT_DIR}/.venv_path"
    print_ok "Python environment ready"
}

# ── 4. Set file permissions ──────────────────────────────────────────────────
setup_permissions() {
    print_step "Setting file permissions"

    chmod +x "${SCRIPT_DIR}/wa-forensics.sh"
    chmod +x "${SCRIPT_DIR}/install.sh"
    chmod +x "${SCRIPT_DIR}/lib/"*.sh 2>/dev/null
    chmod +x "${SCRIPT_DIR}/lib/decrypt_helper.py" 2>/dev/null

    print_ok "Permissions set"
}

# ── 5. Create directories ────────────────────────────────────────────────────
setup_directories() {
    print_step "Creating working directories"

    mkdir -p "${SCRIPT_DIR}/cases"
    mkdir -p "${SCRIPT_DIR}/temp"

    print_ok "Directories ready"
}

# ── 6. Check optional tools ──────────────────────────────────────────────────
check_optional_tools() {
    print_step "Checking optional tools"

    local optional_tools=(
        "wkhtmltopdf:PDF generation"
        "adb:Android device acquisition"
    )

    for tool_info in "${optional_tools[@]}"; do
        local tool="${tool_info%%:*}"
        local desc="${tool_info##*:}"
        if command -v "$tool" &>/dev/null; then
            print_ok "$tool ($desc)"
        else
            print_warn "$tool not found ($desc)"
            if [[ "$OS_TYPE" == "macos" ]]; then
                print_info "  Install: brew install $tool"
            else
                print_info "  Install: sudo apt-get install $tool"
            fi
        fi
    done
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    install_system_deps
    setup_python_venv
    setup_permissions
    setup_directories
    check_optional_tools

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║  Installation complete!                              ║${RESET}"
    echo -e "${GREEN}${BOLD}║                                                    ║${RESET}"
    echo -e "${GREEN}${BOLD}║  Run the toolkit:                                  ║${RESET}"
    echo -e "${GREEN}${BOLD}║    ./wa-forensics.sh                               ║${RESET}"
    echo -e "${GREEN}${BOLD}║                                                    ║${RESET}"
    echo -e "${GREEN}${BOLD}║  The toolkit will automatically activate the       ║${RESET}"
    echo -e "${GREEN}${BOLD}║  Python virtual environment on startup.            ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

main "$@"
