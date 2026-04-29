#!/bin/bash

# Integrity Verification Script for WhatsApp Forensics
# Includes write protection verification
# Runs before loading databases
# Cross-platform compatible (macOS + Linux)

# ── Resolve toolkit root directory ───────────────────────────────────────────
# This script lives in lib/, so TOOLKIT_DIR points to the parent
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${TOOLKIT_DIR}/lib"

# ── Load cross-platform helpers ───────────────────────────────────────────────
source "${LIB_DIR}/cross_platform.sh" 2>/dev/null || true

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
        echo -e "${YELLOW}Usage: ./wa-forensics.sh (or: bash lib/integrity.sh /path/to/case_folder)${NC}"
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

    CURRENT_APP_HASH=$(tar -c "$case_folder/com.whatsapp" 2>/dev/null | cross_sha256sum)

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

    CURRENT_MEDIA_HASH=$(tar -c "$case_folder/media/com.whatsapp" 2>/dev/null | cross_sha256sum)

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

# ── Verify SQLite database integrity ──────────────────────────────────────────
# Uses PRAGMA integrity_check in read-only mode — never modifies databases
verify_database_integrity() {
    local case_folder="$1"
    local db_path="$case_folder/com.whatsapp/databases"
    local db_result=0

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[*]       VERIFYING SQLite DATABASE INTEGRITY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ ! -d "$db_path" ]; then
        echo -e "${RED}[✗] Database directory not found: $db_path${NC}"
        return 1
    fi

    # Check if sqlite3 is available
    if ! command -v sqlite3 &>/dev/null; then
        echo -e "${RED}[✗] sqlite3 command not found. Please install SQLite3.${NC}"
        return 1
    fi

    # Verify msgstore.db
    if [ -f "$db_path/msgstore.db" ]; then
        echo -e "${BLUE}[*] Checking msgstore.db...${NC}"
        local result=$(sqlite3 -readonly "$db_path/msgstore.db" "PRAGMA integrity_check;" 2>&1)
        if [ "$result" = "ok" ]; then
            echo -e "${GREEN}[✓] msgstore.db integrity: PASSED${NC}"
        else
            echo -e "${RED}[✗] msgstore.db integrity: FAILED${NC}"
            echo -e "${RED}    Details: $result${NC}"
            db_result=1
        fi
    else
        echo -e "${YELLOW}[!] msgstore.db not found (may not have messages)${NC}"
    fi

    # Verify wa.db
    if [ -f "$db_path/wa.db" ]; then
        echo -e "${BLUE}[*] Checking wa.db...${NC}"
        local result=$(sqlite3 -readonly "$db_path/wa.db" "PRAGMA integrity_check;" 2>&1)
        if [ "$result" = "ok" ]; then
            echo -e "${GREEN}[✓] wa.db integrity: PASSED${NC}"
        else
            echo -e "${RED}[✗] wa.db integrity: FAILED${NC}"
            echo -e "${RED}    Details: $result${NC}"
            db_result=1
        fi
    else
        echo -e "${YELLOW}[!] wa.db not found (may not have contacts)${NC}"
    fi

    if [ $db_result -eq 0 ]; then
        echo -e "${GREEN}[✓] Database Integrity VERIFIED${NC}"
        return 0
    else
        echo -e "${RED}[✗] Database Integrity FAILED${NC}"
        return 1
    fi
}

# ── Apply write blocking and immutability ─────────────────────────────────────
# Calls writeblocker.py to chmod evidence read-only and apply immutable flags
apply_write_blocking() {
    local case_folder="$1"

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[*]       APPLYING FORENSIC WRITE PROTECTION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local writeblocker="${TOOLKIT_DIR}/lib/writeblocker.py"

    if [ ! -f "$writeblocker" ]; then
        echo -e "${RED}[✗] writeblocker.py not found: $writeblocker${NC}"
        return 1
    fi

    # Check if python3 is available
    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}[✗] python3 command not found. Please install Python3.${NC}"
        return 1
    fi

    echo -e "${BLUE}[*] Applying read-only permissions (chmod 444)...${NC}"
    python3 "$writeblocker" "$case_folder" 2>&1
    local write_block_result=$?

    if [ $write_block_result -eq 0 ]; then
        echo -e "${GREEN}[✓] Write Protection APPLIED${NC}"
        return 0
    else
        echo -e "${YELLOW}[!] Write protection completed with warnings${NC}"
        # Don't fail hard—immutability may not be supported on all filesystems
        return 0
    fi
}

# ── Log integrity checkpoint to chain of custody ───────────────────────────────
log_integrity_checkpoint() {
    local case_folder="$1"
    local checkpoint_type="$2"
    local status="$3"
    local details="$4"
    local coc_file="$case_folder/chain_of_custody.log"

    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local operator="${OPERATOR:-system}"

    # Initialize log file if needed
    if [ ! -f "$coc_file" ]; then
        {
            echo "═══════════════════════════════════════════════════════════════"
            echo "CHAIN OF CUSTODY LOG"
            echo "═══════════════════════════════════════════════════════════════"
            echo "Case: $case_folder"
            echo "Created: $(date)"
            echo "═══════════════════════════════════════════════════════════════"
        } > "$coc_file"
    fi

    # Append checkpoint entry
    {
        echo ""
        echo "[${timestamp}] CHECKPOINT: $checkpoint_type"
        echo "  Status: $status"
        if [ -n "$details" ]; then
            echo "  Details: $details"
        fi
        echo "  Operator: $operator"
    } >> "$coc_file"
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
echo -e "  Modified: $(cross_file_moddate "$CASE_FOLDER")"

# Write-protection check (now CASE_FOLDER is confirmed valid)
verify_write_protection
log_integrity_checkpoint "$CASE_FOLDER" "WRITE_PROTECTION" "CHECKED" || true

# Hash verification — App Data
verify_app_data "$CASE_FOLDER"
APP_RESULT=$?
if [ $APP_RESULT -eq 0 ]; then
    log_integrity_checkpoint "$CASE_FOLDER" "APP_DATA_INTEGRITY" "PASSED" "SHA256 hash match verified" || true
else
    log_integrity_checkpoint "$CASE_FOLDER" "APP_DATA_INTEGRITY" "FAILED" "Hash mismatch detected" || true
fi

# Hash verification — Media
verify_media "$CASE_FOLDER"
MEDIA_RESULT=$?
if [ $MEDIA_RESULT -eq 0 ]; then
    log_integrity_checkpoint "$CASE_FOLDER" "MEDIA_INTEGRITY" "PASSED" "SHA256 hash match verified" || true
else
    log_integrity_checkpoint "$CASE_FOLDER" "MEDIA_INTEGRITY" "FAILED" "Hash mismatch detected" || true
fi

# Database integrity check
verify_database_integrity "$CASE_FOLDER"
DB_RESULT=$?
if [ $DB_RESULT -eq 0 ]; then
    log_integrity_checkpoint "$CASE_FOLDER" "DATABASE_INTEGRITY" "PASSED" "PRAGMA integrity_check passed for all databases" || true
else
    log_integrity_checkpoint "$CASE_FOLDER" "DATABASE_INTEGRITY" "FAILED" "Database corruption detected" || true
fi

# Apply write blocking if all previous checks passed
if [ $APP_RESULT -eq 0 ] && [ $MEDIA_RESULT -eq 0 ] && [ $DB_RESULT -eq 0 ]; then
    apply_write_blocking "$CASE_FOLDER"
    WB_RESULT=$?
    if [ $WB_RESULT -eq 0 ]; then
        log_integrity_checkpoint "$CASE_FOLDER" "WRITE_BLOCKING" "APPLIED" "Read-only permissions + immutability flags set" || true
    else
        log_integrity_checkpoint "$CASE_FOLDER" "WRITE_BLOCKING" "WARNING" "Write blocking had warnings but continuing" || true
    fi
fi

# Final decision
if [ $APP_RESULT -eq 0 ] && [ $MEDIA_RESULT -eq 0 ] && [ $DB_RESULT -eq 0 ]; then
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
    
    log_integrity_checkpoint "$CASE_FOLDER" "ANALYSIS_READY" "SUCCESS" "All integrity checks passed, databases loaded" || true
    exit 0
else
    handle_failure $APP_RESULT $MEDIA_RESULT
    log_integrity_checkpoint "$CASE_FOLDER" "INTEGRITY_VERIFICATION" "FAILED" "Cannot proceed with analysis" || true
fi
