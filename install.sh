#!/usr/bin/env bash
# =============================================================================
#  WA-Forensics Toolkit — Automated Installer
#  Checks and installs all system dependencies
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'; BOLD='\033[1m'

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     WA-Forensics Toolkit — Installer v9.0.0         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ── 1. Check OS ──────────────────────────────────────────────────────────────
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}[✘] This toolkit requires a Linux environment (Ubuntu, CAINE OS, Kali, etc.)${RESET}"
    exit 1
fi

echo -e "${CYAN}[ℹ] Detected OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -sr)${RESET}"
echo ""

# ── 2. Check and install system packages ────────────────────────────────────
REQUIRED_CMDS=(sqlite3 sha256sum md5sum python3 pip3 awk grep sed date)
MISSING_PKGS=()

echo -e "${BOLD}Checking required system tools...${RESET}"
for cmd in "${REQUIRED_CMDS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}[✔] $cmd${RESET}"
    else
        echo -e "  ${RED}[✘] $cmd — NOT FOUND${RESET}"
        MISSING_PKGS+=("$cmd")
    fi
done

# Check optional tools
echo ""
echo -e "${BOLD}Checking optional tools...${RESET}"
for cmd in wkhtmltopdf adb xdg-open; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}[✔] $cmd (optional)${RESET}"
    else
        echo -e "  ${YELLOW}[⚠] $cmd — not found (optional; needed for PDF/ADB features)${RESET}"
    fi
done

echo ""

# ── 3. Install missing packages ──────────────────────────────────────────────
if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}[⚠] Missing: ${MISSING_PKGS[*]}${RESET}"
    echo -e "${CYAN}Installing missing packages...${RESET}"
    sudo apt-get update -qq
    sudo apt-get install -y sqlite3 coreutils python3 python3-pip 2>/dev/null
fi

# ── 4. Install Python dependencies ──────────────────────────────────────────
echo -e "${BOLD}Installing Python dependencies...${RESET}"
if pip3 install -r "$(dirname "$0")/requirements.txt" --quiet; then
    echo -e "  ${GREEN}[✔] pycryptodome installed${RESET}"
else
    echo -e "  ${YELLOW}[⚠] pip3 install failed — decryption features may be unavailable${RESET}"
fi

echo ""

# ── 5. Set file permissions ──────────────────────────────────────────────────
echo -e "${BOLD}Setting executable permissions...${RESET}"
chmod +x "$(dirname "$0")/wa-forensics.sh"
chmod +x "$(dirname "$0")/lib/"*.sh
chmod +x "$(dirname "$0")/lib/decrypt_helper.py"
echo -e "  ${GREEN}[✔] Permissions set${RESET}"

# ── 6. Create cases directory ────────────────────────────────────────────────
mkdir -p "$(dirname "$0")/cases"
echo -e "  ${GREEN}[✔] Cases directory ready${RESET}"

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║     Installation complete! Run:                      ║${RESET}"
echo -e "${GREEN}${BOLD}║     ./wa-forensics.sh                                ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
