#!/bin/bash

# Integrity Verification Script for WhatsApp Forensics
# Includes write protection verification
# Runs before loading databases

# Color codes — use exported values from wa-forensics.sh if available, else define own
GREEN="${GREEN:-\033[0;32m}"
BLUE="${BLUE:-\033[0;34m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# ── Banner ────────────────────────────────────────────────────────────────────
show_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         INTEGRITY VERIFICATION MODULE                      ║${NC}"
    echo -e "${BLUE}║          WhatsApp Evidence Validator                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

# ── Validate case folder exists ───────────────────────────────────────────────
# Uses return (not exit) so calling process (wa-forensics.sh) is not killed
check_case_folder() {
    if [ -z "$1" ]; then
        echo -e "${RED}[-] Please provide the case folder path${NC}"
        echo -e "${YELLOW}Usage: ./Integrity.sh /path/to/case_folder${NC}"
        return 1
    fi
    if [ ! -d "$1" ]; then
        echo -e "${RED}[-] Case folder not found: $1${NC}"
        return 1
    fi
    echo -e "${GREEN}[+] Case folder found: $1${NC}"
}

# ── Write-protection check (called AFTER CASE_FOLDER is confirmed) ────────────
verify_write_protection() {
    echo -e "\n${BLUE}[*] VERIFYING WRITE PROTECTION...${NC}"

    if [ -d "$CASE_FOLDER/com.whatsapp" ]; then
        if [ -w "$CASE_FOLDER/com.whatsapp" ]; then
            echo -e "${RED}⚠️  Warning: App Data folder is writable!${NC}"
        else
            echo -e "${GREEN}[✓] App Data folder write verification PASSED (READ-ONLY)${NC}"
        fi
    fi

    if [ -d "$CASE_FOLDER/media/com.whatsapp" ]; then
        if [ -w "$CASE_FOLDER/media/com.whatsapp" ]; then
            echo -e "${RED}⚠️  Warning: Media folder is writable!${NC}"
        else
            echo -e "${GREEN}[✓] Media folder write verification PASSED (READ-ONLY)${NC}"
        fi
    fi
}

# ── Verify app data integrity ─────────────────────────────────────────────────
verify_app_data() {
    local case_folder="$1"
    local hash_file="$case_folder/hashes.txt"

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[*]       VERIFYING WHATSAPP APP DATA INTEGRITY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ ! -d "$case_folder/com.whatsapp" ]; then
        echo -e "${RED}[✗] WhatsApp App Data folder not found!${NC}"
        return 1
    fi

    if [ ! -f "$hash_file" ]; then
        echo -e "${RED}[✗] Hash file not found: $hash_file${NC}"
        return 1
    fi

    # BUG FIX: was cut -d':' -f3 — the line has ONE colon so f3 is always empty.
    # Correct field is f2 (everything after the single colon separator).
    ORIGINAL_APP_HASH=$(grep "Hash value for com.whatsapp (WhatsApp app data):" "$hash_file" | cut -d':' -f2 | xargs)

    if [ -z "$ORIGINAL_APP_HASH" ]; then
        echo -e "${RED}[✗] Could not extract original app data hash from hash file${NC}"
        return 1
    fi

    echo -e "${BLUE}[*] Original App Data Hash:${NC} ${YELLOW}$ORIGINAL_APP_HASH${NC}"
    echo -e "${BLUE}[*] Recalculating current App Data hash...${NC}"

    CURRENT_APP_HASH=$(tar -c "$case_folder/com.whatsapp" 2>/dev/null | sha256sum | cut -d' ' -f1)

    if [ -z "$CURRENT_APP_HASH" ]; then
        echo -e "${RED}[✗] Failed to calculate current hash${NC}"
        return 1
    fi

    echo -e "${BLUE}[*] Current App Data Hash:${NC} ${YELLOW}$CURRENT_APP_HASH${NC}"

    if [ "$CURRENT_APP_HASH" = "$ORIGINAL_APP_HASH" ]; then
        echo -e "${GREEN}[✓] App Data INTEGRITY VERIFIED${NC}"
        return 0
    else
        echo -e "${RED}[✗] App Data INTEGRITY FAILED!${NC}"
        echo -e "${RED}    Expected: $ORIGINAL_APP_HASH${NC}"
        echo -e "${RED}    Got:      $CURRENT_APP_HASH${NC}"
        return 1
    fi
}

# ── Verify media integrity ────────────────────────────────────────────────────
verify_media() {
    local case_folder="$1"
    local hash_file="$case_folder/hashes.txt"

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[*]       VERIFYING WHATSAPP MEDIA INTEGRITY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ ! -d "$case_folder/media/com.whatsapp" ]; then
        echo -e "${RED}[✗] WhatsApp Media folder not found!${NC}"
        return 1
    fi

    if [ ! -f "$hash_file" ]; then
        echo -e "${RED}[✗] Hash file not found: $hash_file${NC}"
        return 1
    fi

    # BUG FIX: same as above — f2 not f3
    ORIGINAL_MEDIA_HASH=$(grep "Hash value for com.whatsapp (WhatsApp media folder):" "$hash_file" | cut -d':' -f2 | xargs)

    if [ -z "$ORIGINAL_MEDIA_HASH" ]; then
        echo -e "${RED}[✗] Could not extract original media hash from hash file${NC}"
        return 1
    fi

    echo -e "${BLUE}[*] Original Media Hash:${NC} ${YELLOW}$ORIGINAL_MEDIA_HASH${NC}"
    echo -e "${BLUE}[*] Recalculating current Media hash...${NC}"

    CURRENT_MEDIA_HASH=$(tar -c "$case_folder/media/com.whatsapp" 2>/dev/null | sha256sum | cut -d' ' -f1)

    if [ -z "$CURRENT_MEDIA_HASH" ]; then
        echo -e "${RED}[✗] Failed to calculate current hash${NC}"
        return 1
    fi

    echo -e "${BLUE}[*] Current Media Hash:${NC} ${YELLOW}$CURRENT_MEDIA_HASH${NC}"

    if [ "$CURRENT_MEDIA_HASH" = "$ORIGINAL_MEDIA_HASH" ]; then
        echo -e "${GREEN}[✓] Media INTEGRITY VERIFIED${NC}"
        return 0
    else
        echo -e "${RED}[✗] Media INTEGRITY FAILED!${NC}"
        echo -e "${RED}    Expected: $ORIGINAL_MEDIA_HASH${NC}"
        echo -e "${RED}    Got:      $CURRENT_MEDIA_HASH${NC}"
        return 1
    fi
}

# ── Load databases (informational display only — actual load done by wa-forensics) ──
load_databases() {
    local case_folder="$1"

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[*]       LOADING DATABASES FOR ANALYSIS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local DB_PATH="$case_folder/com.whatsapp/databases"

    if [ -d "$DB_PATH" ]; then
        echo -e "${GREEN}[+] Databases found at: $DB_PATH${NC}"
        echo -e "\n${YELLOW}Available databases:${NC}"
        ls -lah "$DB_PATH" | grep -E "\.db$|\.db-wal$|\.db-shm$"

        [ -f "$DB_PATH/msgstore.db" ] && echo -e "\n${GREEN}[✓] msgstore.db ready${NC}" \
                                      || echo -e "${RED}[✗] msgstore.db not found${NC}"
        [ -f "$DB_PATH/wa.db" ]       && echo -e "${GREEN}[✓] wa.db ready${NC}" \
                                      || echo -e "${RED}[✗] wa.db not found${NC}"

        echo -e "\n${GREEN}[✓] Databases ready for analysis${NC}"
    else
        echo -e "${RED}[✗] No databases directory found at: $DB_PATH${NC}"
        echo -e "${YELLOW}    WhatsApp may not have been properly acquired${NC}"
        return 1
    fi
}

# ── Failure handler ───────────────────────────────────────────────────────────
handle_failure() {
    local app_result=$1
    local media_result=$2

    echo -e "\n${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}         INTEGRITY VERIFICATION FAILED${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "\n${RED}[✗] SORRY YOU CANNOT PROCEED WITH ANALYSIS!${NC}"
    echo -e "${RED}[✗] Evidence has been compromised or corrupted${NC}"

    echo -e "\n${YELLOW}[!] Summary of failures:${NC}"
    [ $app_result   -ne 0 ] && echo -e "  ${RED}• WhatsApp App Data: INTEGRITY FAILED${NC}"
    [ $media_result -ne 0 ] && echo -e "  ${RED}• WhatsApp Media: INTEGRITY FAILED${NC}"

    echo -e "\n${YELLOW}[!] Possible reasons:${NC}"
    echo -e "    1. Files were modified after acquisition"
    echo -e "    2. Files were deleted or added"
    echo -e "    3. Storage corruption"
    echo -e "    4. Incomplete acquisition"

    echo -e "\n${YELLOW}[!] REQUIRED ACTION:${NC}"
    echo -e "    → Acquire FRESH evidence from the emulator"
    echo -e "    → DO NOT use this corrupted evidence for analysis"
    echo -e "    → Delete or archive this corrupted case folder"

    echo -e "\n${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}[!] EXITING. No analysis will be performed.${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"

    exit 1
}

# ═════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═════════════════════════════════════════════════════════════════════════════
clear
show_banner

# Get case folder from argument or prompt
if [ $# -ge 1 ]; then
    CASE_FOLDER="$1"
else
    echo -e "\n${YELLOW}[?] Please enter the path to the case folder:${NC}"
    read -rp "> " CASE_FOLDER
fi

# Validate — exit cleanly if invalid (return 1 inside check_case_folder)
if ! check_case_folder "$CASE_FOLDER"; then
    exit 1
fi

# Show case info
echo -e "\n${CYAN}Case Information:${NC}"
echo -e "  Folder  : $CASE_FOLDER"
echo -e "  Size    : $(du -sh "$CASE_FOLDER" 2>/dev/null | cut -f1)"
echo -e "  Modified: $(stat -c %y "$CASE_FOLDER" 2>/dev/null | cut -d'.' -f1)"

# Write-protection check (now CASE_FOLDER is confirmed valid)
verify_write_protection

# Hash verification
verify_app_data "$CASE_FOLDER"
APP_RESULT=$?

verify_media "$CASE_FOLDER"
MEDIA_RESULT=$?

# Final decision
if [ $APP_RESULT -eq 0 ] && [ $MEDIA_RESULT -eq 0 ]; then
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓✓✓ ALL INTEGRITY CHECKS PASSED ✓✓✓${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "\n${GREEN}[+] Evidence is forensically sound and ready for analysis${NC}"

    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp "$(echo -e ${BLUE}"Press ENTER to load the databases for analysis..."${NC})"

    load_databases "$CASE_FOLDER"

    echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  DATABASES READY FOR ANALYSIS${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Remember: Always work on COPIES of the evidence files${NC}"

    exit 0
else
    handle_failure $APP_RESULT $MEDIA_RESULT
fi
