#!/bin/bash

# WhatsApp Forensics Acquisition 
# Evidence stored in evidence/ subfolder, operations/ excluded from hash

GREEN="${GREEN:-\033[0;32m}"
BLUE="${BLUE:-\033[0;34m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if [[ -n "${CASE_DIR:-}" && -d "${CASE_DIR}" ]]; then
    CASE_FOLDER="$CASE_DIR"
    echo -e "${GREEN}[*] Saving evidence into case folder: ${CASE_FOLDER}${NC}"
elif [[ -n "${CASES_ROOT:-}" ]]; then
    CASE_FOLDER="${CASES_ROOT}/case_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$CASE_FOLDER"
else
    CASE_FOLDER="${SCRIPT_DIR}/case_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$CASE_FOLDER"
fi

# Create folder structure
mkdir -p "$CASE_FOLDER/evidence/media"


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

pull_data() {
    echo -e "${GREEN}[*] Pulling data to ${CASE_FOLDER}/evidence/...${NC}"
    adb pull /sdcard/com.whatsapp "$CASE_FOLDER/evidence/" 2>/dev/null
    adb pull /sdcard/Android/media/com.whatsapp "$CASE_FOLDER/evidence/media/" 2>/dev/null

    if [ -d "$CASE_FOLDER/evidence/com.whatsapp" ] && [ "$(ls -A "$CASE_FOLDER/evidence/com.whatsapp" 2>/dev/null)" ]; then
        return 0
    else
        return 1
    fi
}

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ WHATSAPP FORENSICS ACQUISITION MODULE  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

check_emulator

# PART 1: ACQUIRE DATA FROM EMULATOR 
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

# ══════════════════════════════════════════════════════════════════════════
# PHASE 1: FORENSIC WRITE PROTECTION 
# ══════════════════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}[*] PHASE 1: APPLYING FORENSIC WRITE PROTECTION${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -d "$CASE_FOLDER/evidence/com.whatsapp" ]; then
    chmod -R -w "$CASE_FOLDER/evidence/com.whatsapp" 2>/dev/null
    chmod -R u-w,g-w,o-w "$CASE_FOLDER/evidence/com.whatsapp" 2>/dev/null
    echo -e "${GREEN}[✓] WhatsApp App Data folder is now READ-ONLY${NC}"
fi

if [ -d "$CASE_FOLDER/evidence/media/com.whatsapp" ]; then
    chmod -R -w "$CASE_FOLDER/evidence/media/com.whatsapp" 2>/dev/null
    chmod -R u-w,g-w,o-w "$CASE_FOLDER/evidence/media/com.whatsapp" 2>/dev/null
    echo -e "${GREEN}[✓] WhatsApp Media folder is now READ-ONLY${NC}"
fi

echo -e "\n${GREEN}[✓] FORENSIC WRITE PROTECTION APPLIED${NC}"
echo -e "${YELLOW}  → evidence/ subfolder is READ-ONLY${NC}"
echo -e "${YELLOW}  → operations/ folder remains writable for logs/reports${NC}"

# ══════════════════════════════════════════════════════════════════════════
# PHASE 2: GENERATE SHA256 HASH VALUES
# ══════════════════════════════════════════════════════════════════════════
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[*] PHASE 2: Generating SHA256 hash values...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Hash 1: WhatsApp App Data
if [ -d "$CASE_FOLDER/evidence/com.whatsapp" ]; then
    HASH_APP_DATA=$(find "$CASE_FOLDER/evidence/com.whatsapp" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
else
    HASH_APP_DATA="FOLDER_NOT_FOUND"
fi

# Hash 2: WhatsApp Media
if [ -d "$CASE_FOLDER/evidence/media/com.whatsapp" ]; then
    HASH_MEDIA=$(find "$CASE_FOLDER/evidence/media/com.whatsapp" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
else
    HASH_MEDIA="FOLDER_NOT_FOUND"
fi

# Hash 3: ENTIRE evidence/ folder 
HASH_FULL_CASE=$(find "$CASE_FOLDER/evidence" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)

# Save hashes to file (in operations/ folder)
echo "========================================" > "$CASE_FOLDER/operations/hashes.txt"
echo "WhatsApp Forensics Hash Values"          >> "$CASE_FOLDER/operations/hashes.txt"
echo "Generated: $(date)"                      >> "$CASE_FOLDER/operations/hashes.txt"
echo "========================================" >> "$CASE_FOLDER/operations/hashes.txt"
echo ""                                         >> "$CASE_FOLDER/operations/hashes.txt"
echo "Hash value for com.whatsapp (WhatsApp app data): $HASH_APP_DATA"    >> "$CASE_FOLDER/operations/hashes.txt"
echo "Hash value for com.whatsapp (WhatsApp media folder): $HASH_MEDIA"   >> "$CASE_FOLDER/operations/hashes.txt"
echo "Hash value for FULL CASE FOLDER (all case files): $HASH_FULL_CASE"  >> "$CASE_FOLDER/operations/hashes.txt"

chmod 444 "$CASE_FOLDER/operations/hashes.txt" 2>/dev/null

echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}HASH VALUES GENERATED${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "\n${BLUE}Hash value for com.whatsapp (WhatsApp app data):${NC} ${YELLOW}${HASH_APP_DATA}${NC}"
echo -e "${BLUE}Hash value for com.whatsapp (WhatsApp media folder):${NC} ${YELLOW}${HASH_MEDIA}${NC}"
echo -e "${BLUE}Hash value for FULL CASE FOLDER (all case files):${NC} ${YELLOW}${HASH_FULL_CASE}${NC}"

# Summary report
echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}ACQUISITION COMPLETE${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${YELLOW}Evidence saved to: ${CASE_FOLDER}/evidence/${NC}"
echo -e "${YELLOW}Hash file: ${CASE_FOLDER}/operations/hashes.txt${NC}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}FOLDER SIZES:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -d "$CASE_FOLDER/evidence/com.whatsapp" ]; then
    APP_SIZE=$(du -sh "$CASE_FOLDER/evidence/com.whatsapp" 2>/dev/null | cut -f1)
    APP_FILES=$(find "$CASE_FOLDER/evidence/com.whatsapp" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ WhatsApp App Data size:${NC} ${YELLOW}${APP_SIZE}${NC}"
    echo -e "  ${BLUE}↳ Files:${NC} ${APP_FILES}"
else
    echo -e "${RED}✗ WhatsApp App Data folder not found${NC}"
fi

echo ""

if [ -d "$CASE_FOLDER/evidence/media/com.whatsapp" ]; then
    MEDIA_SIZE=$(du -sh "$CASE_FOLDER/evidence/media/com.whatsapp" 2>/dev/null | cut -f1)
    MEDIA_FILES=$(find "$CASE_FOLDER/evidence/media/com.whatsapp" -type f 2>/dev/null | wc -l)
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
echo -e "  - Write protection: ${GREEN}[✓] ENFORCED (Applied BEFORE hashing)${NC}"
echo -e "  - Evidence preserved in: evidence/ (READ-ONLY)"
echo -e "  - Operations in: operations/ (writable)"

read -rp "$(echo -e ${BLUE}"Press ENTER to continue..."${NC})"

# POST-ACQUISITION OPTIONS
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
            export CASE_FOLDER
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