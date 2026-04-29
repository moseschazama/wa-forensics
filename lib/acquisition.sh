#!/bin/bash

# WhatsApp Forensics Acquisition Script
# For use with rooted Android emulator
# Cross-platform compatible (macOS + Linux)

# ── Resolve toolkit root directory ───────────────────────────────────────────
# This script lives in lib/, so SCRIPT_DIR must point to the parent (toolkit root)
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${TOOLKIT_DIR}/lib"

# ── Load cross-platform helpers ───────────────────────────────────────────────
source "${LIB_DIR}/cross_platform.sh" 2>/dev/null || true

# Color codes — inherit from wa-forensics.sh if available, else define own
GREEN="${GREEN:-\033[0;32m}"
BLUE="${BLUE:-\033[0;34m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# ── Resolve where to save acquired evidence ───────────────────────────────────
# When called from wa-forensics.sh: CASE_DIR and CASES_ROOT are already exported.
# Evidence goes INTO the existing case folder so the parent toolkit can find it.
# When run standalone: create a timestamped folder next to the toolkit root.

if [[ -n "${CASE_DIR:-}" && -d "${CASE_DIR}" ]]; then
    # Running inside wa-forensics.sh — use the already-created case folder
    CASE_FOLDER="$CASE_DIR"
    echo -e "${GREEN}[*] Saving evidence into case folder: ${CASE_FOLDER}${NC}"
elif [[ -n "${CASES_ROOT:-}" ]]; then
    CASE_FOLDER="${CASES_ROOT}/case_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$CASE_FOLDER"
else
    # Standalone mode
    CASE_FOLDER="${TOOLKIT_DIR}/case_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$CASE_FOLDER"
fi
mkdir -p "$CASE_FOLDER/media"

# ── Check emulator connection ─────────────────────────────────────────────────
check_emulator() {
    echo -e "${BLUE}[*] Checking for emulator connection...${NC}"
    adb wait-for-device 2>/dev/null
    DEVICE_COUNT=$(adb devices 2>/dev/null | grep -c "emulator.*device$")

    if [ $DEVICE_COUNT -eq 0 ]; then
        echo -e "${RED}[-] No emulator found!${NC}"
        echo -e "${YELLOW}Please:${NC}"
        echo "  1. Start your Android emulator"
        echo "  2. Wait for it to fully boot"
        echo "  3. Run this script again"
        exit 1
    fi

    echo -e "${GREEN}[+] Emulator connected: $(adb devices 2>/dev/null | grep 'emulator.*device$' | head -1)${NC}"
    echo -e "${BLUE}[*] Waiting for emulator to fully boot...${NC}"
    while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
        sleep 2
    done
    echo -e "${GREEN}[+] Emulator fully booted${NC}"
}

# ── Acquire data from emulator ────────────────────────────────────────────────
acquire_data() {
    echo -e "${GREEN}[*] Acquiring WhatsApp data...${NC}"
    adb shell << EOF 2>/dev/null
su
cd /data
cd data
cp -r /data/data/com.whatsapp /sdcard/
exit
exit
EOF
    if adb shell "ls /sdcard/com.whatsapp" 2>/dev/null | grep -q "No such file"; then
        return 1
    else
        return 0
    fi
}

# ── Pull data to case folder ──────────────────────────────────────────────────
pull_data() {
    echo -e "${GREEN}[*] Pulling data to ${CASE_FOLDER}...${NC}"
    adb pull /sdcard/com.whatsapp "$CASE_FOLDER/" 2>/dev/null
    adb pull /sdcard/Android/media/com.whatsapp "$CASE_FOLDER/media/" 2>/dev/null

    if [ -d "$CASE_FOLDER/com.whatsapp" ] && [ "$(ls -A "$CASE_FOLDER/com.whatsapp" 2>/dev/null)" ]; then
        return 0
    else
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ WHATSAPP FORENSICS ACQUISITION MODULE  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

check_emulator

# PART 1: ACQUIRE DATA FROM EMULATOR WITH RETRY
while true; do
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp "$(echo -e ${BLUE}"Press ENTER to acquire data from emulator..."${NC})"

    if acquire_data; then
        echo -e "${GREEN}[✓] DATA ACQUIRED SUCCESSFULLY${NC}"
        break
    else
        echo -e "${RED}[✗] DATA ACQUISITION FAILED${NC}"
        echo -e "${YELLOW}Failed to copy WhatsApp data from emulator.${NC}"
        echo -e "${YELLOW}Possible reasons:${NC}"
        echo "  - Emulator might not be rooted"
        echo "  - WhatsApp might not be installed"
        echo "  - Permission issues"
        while true; do
            read -rp "$(echo -e ${BLUE}"Press ENTER to try again or 'q' to quit: "${NC})" choice
            if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
                echo -e "${RED}[!] Acquisition aborted by user${NC}"
                exit 1
            else
                break
            fi
        done
    fi
done

# PART 2: PULL DATA TO CASE FOLDER
while true; do
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp "$(echo -e ${BLUE}"Press ENTER to pull data to case folder..."${NC})"

    if pull_data; then
        echo -e "${GREEN}[✓] DATA PULLED SUCCESSFULLY${NC}"
        break
    else
        echo -e "${RED}[✗] DATA PULL FAILED${NC}"
        echo -e "${YELLOW}Failed to pull data from emulator to case folder.${NC}"
        while true; do
            read -rp "$(echo -e ${BLUE}"Press ENTER to retry pulling or 'q' to quit: "${NC})" choice
            if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
                echo -e "${RED}[!] Acquisition aborted by user${NC}"
                exit 1
            else
                break
            fi
        done
    fi
done

# GENERATE SHA256 HASH VALUES
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[*] Generating SHA256 hash values...${NC}"

if [ -d "$CASE_FOLDER/com.whatsapp" ]; then
    HASH_APP_DATA=$(tar -c "$CASE_FOLDER/com.whatsapp" 2>/dev/null | cross_sha256sum)
else
    HASH_APP_DATA="FOLDER_NOT_FOUND"
fi

if [ -d "$CASE_FOLDER/media/com.whatsapp" ]; then
    HASH_MEDIA=$(tar -c "$CASE_FOLDER/media/com.whatsapp" 2>/dev/null | cross_sha256sum)
else
    HASH_MEDIA="FOLDER_NOT_FOUND"
fi

# Save hashes to file — format must match exactly what Integrity.sh parses:
# "Hash value for com.whatsapp (WhatsApp app data): <hash>"
# Integrity.sh uses: grep "..." | cut -d':' -f2 | xargs
echo "========================================" > "$CASE_FOLDER/hashes.txt"
echo "WhatsApp Forensics Hash Values"          >> "$CASE_FOLDER/hashes.txt"
echo "Generated: $(date)"                      >> "$CASE_FOLDER/hashes.txt"
echo "========================================" >> "$CASE_FOLDER/hashes.txt"
echo ""                                         >> "$CASE_FOLDER/hashes.txt"
echo "Hash value for com.whatsapp (WhatsApp app data): $HASH_APP_DATA"    >> "$CASE_FOLDER/hashes.txt"
echo "Hash value for com.whatsapp (WhatsApp media folder): $HASH_MEDIA"   >> "$CASE_FOLDER/hashes.txt"

echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}HASH VALUES GENERATED${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "\n${BLUE}Hash value for com.whatsapp (WhatsApp app data):${NC} ${YELLOW}${HASH_APP_DATA}${NC}"
echo -e "${BLUE}Hash value for com.whatsapp (WhatsApp media folder):${NC} ${YELLOW}${HASH_MEDIA}${NC}"

# FORENSIC WRITE PROTECTION
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}[*] APPLYING FORENSIC WRITE PROTECTION${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Protect evidence subfolders (recursive, both methods)
if [ -d "$CASE_FOLDER/com.whatsapp" ]; then
    chmod -R -w "$CASE_FOLDER/com.whatsapp"
    chmod -R u-w,g-w,o-w "$CASE_FOLDER/com.whatsapp"
    echo -e "${GREEN}[✓] WhatsApp App Data folder is now READ-ONLY${NC}"
fi

if [ -d "$CASE_FOLDER/media/com.whatsapp" ]; then
    chmod -R -w "$CASE_FOLDER/media/com.whatsapp"
    chmod -R u-w,g-w,o-w "$CASE_FOLDER/media/com.whatsapp"
    echo -e "${GREEN}[✓] WhatsApp Media folder is now READ-ONLY${NC}"
fi

# Protect the hash file
if [ -f "$CASE_FOLDER/hashes.txt" ]; then
    chmod -w "$CASE_FOLDER/hashes.txt"
    chmod u-w,g-w,o-w "$CASE_FOLDER/hashes.txt"
    echo -e "${GREEN}[✓] Hash file is now READ-ONLY${NC}"
fi

# BUG FIX: Do NOT chmod -w on CASE_FOLDER itself or CASE_FOLDER/media/
# wa-forensics.sh needs to write .integrity_verified / .integrity_failed
# flag files into the case root AFTER this script exits.
# Only lock the evidence directory entry (not recursive — already done above)
chmod -w "$CASE_FOLDER/com.whatsapp" 2>/dev/null
chmod u-w,g-w,o-w "$CASE_FOLDER/com.whatsapp" 2>/dev/null
# media/ parent stays writable so toolkit can manage state files inside case root

echo -e "\n${GREEN}[✓] FORENSIC WRITE PROTECTION APPLIED${NC}"
echo -e "${YELLOW}  → Evidence subfolders and hash file are READ-ONLY${NC}"
echo -e "${YELLOW}  → Case root remains writable for toolkit flag files${NC}"

# Summary report
echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}ACQUISITION COMPLETE${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${YELLOW}Evidence saved to: ${CASE_FOLDER}${NC}"
echo -e "${YELLOW}Hash file: ${CASE_FOLDER}/hashes.txt${NC}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}FOLDER SIZES:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -d "$CASE_FOLDER/com.whatsapp" ]; then
    APP_SIZE=$(du -sh "$CASE_FOLDER/com.whatsapp" 2>/dev/null | cut -f1)
    APP_FILES=$(find "$CASE_FOLDER/com.whatsapp" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ WhatsApp App Data size:${NC} ${YELLOW}${APP_SIZE}${NC}"
    echo -e "  ${BLUE}↳ Files:${NC} ${APP_FILES}"
else
    echo -e "${RED}✗ WhatsApp App Data folder not found${NC}"
fi

echo ""

if [ -d "$CASE_FOLDER/media/com.whatsapp" ]; then
    MEDIA_SIZE=$(du -sh "$CASE_FOLDER/media/com.whatsapp" 2>/dev/null | cut -f1)
    MEDIA_FILES=$(find "$CASE_FOLDER/media/com.whatsapp" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ WhatsApp Media size:${NC} ${YELLOW}${MEDIA_SIZE}${NC}"
    echo -e "  ${BLUE}↳ Files:${NC} ${MEDIA_FILES}"
else
    echo -e "${RED}✗ WhatsApp Media folder not found${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
TOTAL_SIZE=$(du -sh "$CASE_FOLDER" 2>/dev/null | cut -f1)
TOTAL_FILES=$(find "$CASE_FOLDER" -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓ Total evidence size:${NC} ${YELLOW}${TOTAL_SIZE}${NC}"
echo -e "${GREEN}✓ Total files:${NC} ${YELLOW}${TOTAL_FILES}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${BLUE}Chain of custody:${NC}"
echo -e "  - Acquisition timestamp: $(date)"
echo -e "  - Hash algorithm: SHA256"
echo -e "  - Write protection: ${GREEN}[✓] ENFORCED${NC}"
echo -e "  - Evidence preserved for forensic analysis"

read -rp "$(echo -e ${BLUE}"Press ENTER to continue..."${NC})"

# POST-ACQUISITION OPTIONS
# BUG FIX: Option 1 no longer tries to launch Analysis.sh (which doesn't exist
# as a standalone file). Instead we exit 0 so wa-forensics.sh resumes control
# and handles the integrity + analysis flow itself.
while true; do
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}       POST-ACQUISITION OPTIONS        ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}1.${NC} Continue to Integrity Verification & Analysis"
    echo -e "${CYAN}2.${NC} Exit"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    read -rp "$(echo -e ${BLUE}"Enter your option (1-2): "${NC})" post_choice

    case $post_choice in
        1)
            echo -e "\n${GREEN}[*] Returning to toolkit for verification and analysis...${NC}"
            export CASE_FOLDER   # make visible to parent process env
            exit 0
            ;;
        2)
            echo -e "\n${RED}[!] Exiting forensic toolkit...${NC}"
            echo -e "${YELLOW}Evidence saved to: ${CASE_FOLDER}${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}[✗] Invalid option: '$post_choice'${NC}"
            echo -e "${YELLOW}Please enter 1 or 2${NC}"
            ;;
    esac
done
