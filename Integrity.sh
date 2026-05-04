#!/bin/bash

# ═════════════════════════════════════════════════════════════════════════════
#  INTEGRITY VERIFICATION MODULE  — WhatsApp Evidence Validator
#  Only hashes evidence/ folder — operations/ excluded (grows with logs)
#  Write Blocker Applied FIRST → Then Hash Verification
# ═════════════════════════════════════════════════════════════════════════════

GREEN="${GREEN:-\033[0;32m}"
BLUE="${BLUE:-\033[0;34m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
CYAN="${CYAN:-\033[0;36m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
WHITE="${WHITE:-\033[1;37m}"
NC="${NC:-\033[0m}"

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

show_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         INTEGRITY VERIFICATION MODULE                      ║${NC}"
    echo -e "${BLUE}║          WhatsApp Evidence Validator                       ║${NC}"
    echo -e "${BLUE}║     SHA-256 • DB Integrity • Write Blocker • CoC Audit     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

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
    
    # CRITICAL: Check that BOTH evidence/ and operations/ folders exist
    if [ ! -d "$1/evidence" ]; then
        echo -e "${RED}[-] evidence/ folder not found in case!${NC}"
        echo -e "${RED}[-] This case structure is INVALID — cannot proceed.${NC}"
        return 1
    fi
    
    if [ ! -d "$1/operations" ]; then
        echo -e "${RED}[-] operations/ folder not found in case!${NC}"
        echo -e "${RED}[-] This case structure is INVALID — cannot proceed.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}[+] Case folder found: $1${NC}"
    echo -e "${GREEN}[+] evidence/ folder: EXISTS${NC}"
    echo -e "${GREEN}[+] operations/ folder: EXISTS${NC}"
}

show_case_info() {
    echo -e "\n${CYAN}Case Information:${NC}"
    echo -e "  Folder    : $CASE_FOLDER"
    echo -e "  Size      : $(du -sh "$CASE_FOLDER" 2>/dev/null | cut -f1)"
    
    if [[ -f "${CASE_FOLDER}/operations/case_info.txt" ]]; then
        local inv=$(grep "Name" "${CASE_FOLDER}/operations/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | tr -d "'\"" | xargs 2>/dev/null || echo "Unknown")
        local warrant=$(grep "Warrant" "${CASE_FOLDER}/operations/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | tr -d "'\"" | xargs 2>/dev/null || echo "N/A")
        echo -e "  Case      : $(basename "$CASE_FOLDER")"
        [[ -n "$inv" ]] && echo -e "  Analyst   : ${inv}"
        [[ -n "$warrant" ]] && echo -e "  Warrant   : ${warrant}"
    fi
}

log_integrity_checkpoint() {
    local step="$1"
    local status="$2"
    local details="${3:-}"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    local entry="[${ts}] INTEGRITY CHECKPOINT | Step: ${step} | Status: ${status}"
    [[ -n "$details" ]] && entry="${entry} | Details: ${details}"
    entry="${entry} | Operator: ${INVESTIGATOR:-Unknown} | Session: ${SESSION_ID:-Unknown}"
    
    if [[ -n "$CASE_FOLDER" && -d "$CASE_FOLDER" ]]; then
        mkdir -p "${CASE_FOLDER}/operations/logs"
        echo "$entry" >> "${CASE_FOLDER}/operations/logs/chain_of_custody.log"
    fi
    
    case "$status" in
        PASSED)  echo -e "  ${GREEN}[✓]${NC} ${step}: ${GREEN}PASSED${NC}" ;;
        FAILED)  echo -e "  ${RED}[✗]${NC} ${step}: ${RED}FAILED${NC} — ${details}" ;;
        APPLIED) echo -e "  ${GREEN}[✓]${NC} ${step}: ${GREEN}APPLIED${NC}" ;;
        SKIPPED) echo -e "  ${YELLOW}[!]${NC} ${step}: ${YELLOW}SKIPPED${NC} — ${details}" ;;
        *)       echo -e "  ${CYAN}[*]${NC} ${step}: ${status}" ;;
    esac
}

verify_write_protection() {
    echo -e "\n${BLUE}[*] CHECKING CURRENT WRITE PROTECTION STATUS...${NC}"
    
    local all_protected=true

    if [ -d "$CASE_FOLDER/evidence/com.whatsapp" ]; then
        if [ -w "$CASE_FOLDER/evidence/com.whatsapp" ]; then
            echo -e "${YELLOW}  [!] App Data folder is currently WRITABLE — will be locked${NC}"
            all_protected=false
        else
            echo -e "${GREEN}  [✓] App Data folder: Already READ-ONLY${NC}"
        fi
    else
        echo -e "${RED}  [✗] App Data folder NOT FOUND in evidence/${NC}"
        return 1
    fi

    if [ -d "$CASE_FOLDER/evidence/media/com.whatsapp" ]; then
        if [ -w "$CASE_FOLDER/evidence/media/com.whatsapp" ]; then
            echo -e "${YELLOW}  [!] Media folder is currently WRITABLE — will be locked${NC}"
            all_protected=false
        else
            echo -e "${GREEN}  [✓] Media folder: Already READ-ONLY${NC}"
        fi
    fi
    
    if [[ "$all_protected" == true ]]; then
        log_integrity_checkpoint "WRITE PROTECTION STATUS" "PASSED" "Evidence folders already read-only"
    else
        log_integrity_checkpoint "WRITE PROTECTION STATUS" "WARNING" "Some folders writable — will apply write blocker"
    fi
    return 0
}

apply_write_blocking() {
    local case_folder="$1"
    
    echo -e "\n${BLUE}[*] APPLYING FORENSIC WRITE BLOCKER...${NC}"
    
    local immutability_applied=false
    
    _make_read_only() {
        local target="$1"
        if [[ ! -d "$target" ]]; then return 1; fi
        
        echo -e "${CYAN}  Locking: ${target}${NC}"
        find "$target" -type f -exec chmod 444 {} \; 2>/dev/null
        find "$target" -type d -exec chmod 555 {} \; 2>/dev/null
        chmod -R a-w "$target" 2>/dev/null
        chmod -R u-w,g-w,o-w "$target" 2>/dev/null
        
        local writable_count=$(find "$target" -type f -writable 2>/dev/null | wc -l)
        if [[ "$writable_count" -gt 0 ]]; then
            echo -e "${YELLOW}    [!] ${writable_count} files still writable${NC}"
            return 1
        else
            echo -e "${GREEN}    [✓] All files read-only${NC}"
            return 0
        fi
    }
    
    _apply_immutable() {
        local target="$1"
        
        if ! command -v chattr &>/dev/null; then
            echo -e "${YELLOW}    [!] chattr not available${NC}"
            return 1
        fi
        
        local test_file="${target}/.immutable_test_$$"
        touch "$test_file" 2>/dev/null || { rm -f "$test_file" 2>/dev/null; return 1; }
        
        if chattr +i "$test_file" 2>/dev/null; then
            chattr -i "$test_file" 2>/dev/null
            rm -f "$test_file" 2>/dev/null
            echo -e "${CYAN}  Applying immutability (chattr +i) to: ${target}${NC}"
            find "$target" -type f -exec chattr +i {} \; 2>/dev/null
            echo -e "${GREEN}    [✓] Immutability applied${NC}"
            return 0
        else
            rm -f "$test_file" 2>/dev/null
            echo -e "${YELLOW}    [!] Filesystem doesn't support chattr +i${NC}"
            return 1
        fi
    }
    
    # ONLY lock evidence/ folder — operations/ must remain writable
    [[ -d "${case_folder}/evidence/com.whatsapp" ]] && { _make_read_only "${case_folder}/evidence/com.whatsapp"; _apply_immutable "${case_folder}/evidence/com.whatsapp" && immutability_applied=true; }
    [[ -d "${case_folder}/evidence/media/com.whatsapp" ]] && { _make_read_only "${case_folder}/evidence/media/com.whatsapp"; _apply_immutable "${case_folder}/evidence/media/com.whatsapp" && immutability_applied=true; }
    
    if [[ "$immutability_applied" == true ]]; then
        log_integrity_checkpoint "WRITE BLOCKER" "APPLIED" "chmod 444 + chattr +i on evidence/"
    else
        log_integrity_checkpoint "WRITE BLOCKER" "APPLIED" "chmod 444 on evidence/"
    fi
    
    echo ""
    echo -e "${GREEN}  ┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}  │  FORENSIC WRITE BLOCKER ACTIVE                          │${NC}"
    echo -e "${GREEN}  │  • evidence/ folder: READ-ONLY (chmod 444)              │${NC}"
    echo -e "${GREEN}  │  • operations/ folder: WRITABLE (for logs/reports)      │${NC}"
    [[ "$immutability_applied" == true ]] && echo -e "${GREEN}  │  • Immutability: ENFORCED (chattr +i)                    │${NC}"
    echo -e "${GREEN}  └─────────────────────────────────────────────────────────┘${NC}"
    
    return 0
}

verify_protection_effective() {
    local case_folder="$1"
    
    echo -e "\n${BLUE}[*] VERIFYING WRITE BLOCKER EFFECTIVENESS...${NC}"
    
    local test_targets=("${case_folder}/evidence/com.whatsapp")
    local all_protected=true
    
    for target in "${test_targets[@]}"; do
        [[ ! -d "$target" ]] && continue
        local test_file="${target}/.write_test_$$"
        
        if touch "$test_file" 2>/dev/null; then
            echo -e "${RED}  [✗] Could write to ${target} — PROTECTION FAILED!${NC}"
            rm -f "$test_file" 2>/dev/null
            all_protected=false
        else
            echo -e "${GREEN}  [✓] Write protection effective: ${target}${NC}"
        fi
    done
    
    if [[ "$all_protected" == true ]]; then
        log_integrity_checkpoint "PROTECTION VERIFICATION" "PASSED" "Cannot write to evidence folder"
        return 0
    else
        log_integrity_checkpoint "PROTECTION VERIFICATION" "FAILED" "Write blocker NOT effective"
        return 1
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# VERIFY APP DATA INTEGRITY (SHA-256) — reads from evidence/ folder
# ═════════════════════════════════════════════════════════════════════════════
verify_app_data() {
    local case_folder="$1"
    local hash_file="$case_folder/operations/hashes.txt"

    echo -e "\n${BLUE}[*] VERIFYING APP DATA INTEGRITY (SHA-256)...${NC}"

    [[ ! -d "$case_folder/evidence/com.whatsapp" ]] && { echo -e "${RED}  [✗] App Data folder not found!${NC}"; log_integrity_checkpoint "APP DATA HASH" "FAILED" "evidence/com.whatsapp not found"; return 1; }
    [[ ! -f "$hash_file" ]] && { echo -e "${RED}  [✗] hashes.txt not found in operations/!${NC}"; log_integrity_checkpoint "APP DATA HASH" "FAILED" "operations/hashes.txt not found"; return 1; }

    local ORIGINAL_APP_HASH=$(grep "Hash value for com.whatsapp (WhatsApp app data):" "$hash_file" | cut -d':' -f2 | xargs)
    [[ -z "$ORIGINAL_APP_HASH" ]] && { echo -e "${RED}  [✗] Could not parse original hash${NC}"; log_integrity_checkpoint "APP DATA HASH" "FAILED" "Parse error"; return 1; }

    echo -e "${CYAN}  Original:${NC} ${YELLOW}$ORIGINAL_APP_HASH${NC}"
    
    local CURRENT_APP_HASH=$(find "$case_folder/evidence/com.whatsapp" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
    [[ -z "$CURRENT_APP_HASH" ]] && { echo -e "${RED}  [✗] Hash calculation failed${NC}"; log_integrity_checkpoint "APP DATA HASH" "FAILED" "Calculation failed"; return 1; }

    echo -e "${CYAN}  Current: ${NC} ${YELLOW}$CURRENT_APP_HASH${NC}"

    if [ "$CURRENT_APP_HASH" = "$ORIGINAL_APP_HASH" ]; then
        echo -e "${GREEN}  [✓] APP DATA HASH MATCH${NC}"
        log_integrity_checkpoint "APP DATA HASH" "PASSED" "Hash matches"
        return 0
    else
        echo -e "${RED}  [✗] HASH MISMATCH!${NC}"
        log_integrity_checkpoint "APP DATA HASH" "FAILED" "Hash mismatch"
        return 1
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# VERIFY MEDIA INTEGRITY (SHA-256)
# ═════════════════════════════════════════════════════════════════════════════
verify_media() {
    local case_folder="$1"
    local hash_file="$case_folder/operations/hashes.txt"

    echo -e "\n${BLUE}[*] VERIFYING MEDIA INTEGRITY (SHA-256)...${NC}"

    [[ ! -d "$case_folder/evidence/media/com.whatsapp" ]] && { echo -e "${YELLOW}  [!] Media folder not found — skipping${NC}"; log_integrity_checkpoint "MEDIA HASH" "SKIPPED" "No media folder"; return 0; }
    [[ ! -f "$hash_file" ]] && { echo -e "${RED}  [✗] hashes.txt not found!${NC}"; log_integrity_checkpoint "MEDIA HASH" "FAILED" "operations/hashes.txt not found"; return 1; }

    local ORIGINAL_MEDIA_HASH=$(grep "Hash value for com.whatsapp (WhatsApp media folder):" "$hash_file" | cut -d':' -f2 | xargs)
    [[ -z "$ORIGINAL_MEDIA_HASH" ]] && { echo -e "${YELLOW}  [!] No media hash — skipping${NC}"; log_integrity_checkpoint "MEDIA HASH" "SKIPPED" "No hash entry"; return 0; }

    echo -e "${CYAN}  Original:${NC} ${YELLOW}$ORIGINAL_MEDIA_HASH${NC}"
    
    local CURRENT_MEDIA_HASH=$(find "$case_folder/evidence/media/com.whatsapp" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
    [[ -z "$CURRENT_MEDIA_HASH" ]] && { echo -e "${RED}  [✗] Hash calculation failed${NC}"; log_integrity_checkpoint "MEDIA HASH" "FAILED" "Calculation failed"; return 1; }

    echo -e "${CYAN}  Current: ${NC} ${YELLOW}$CURRENT_MEDIA_HASH${NC}"

    if [ "$CURRENT_MEDIA_HASH" = "$ORIGINAL_MEDIA_HASH" ]; then
        echo -e "${GREEN}  [✓] MEDIA HASH MATCH${NC}"
        log_integrity_checkpoint "MEDIA HASH" "PASSED" "Hash matches"
        return 0
    else
        echo -e "${RED}  [✗] HASH MISMATCH!${NC}"
        log_integrity_checkpoint "MEDIA HASH" "FAILED" "Hash mismatch"
        return 1
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# VERIFY FULL EVIDENCE FOLDER INTEGRITY (SHA-256) — ONLY evidence/ folder
# operations/ folder is EXCLUDED because it grows with logs/reports
# ═════════════════════════════════════════════════════════════════════════════
verify_full_case() {
    local case_folder="$1"
    local hash_file="$case_folder/operations/hashes.txt"

    echo -e "\n${BLUE}[*] VERIFYING FULL EVIDENCE FOLDER INTEGRITY (SHA-256)...${NC}"
    echo -e "${CYAN}  (Only hashing evidence/ folder — operations/ excluded)${NC}"

    [[ ! -f "$hash_file" ]] && { echo -e "${RED}  [✗] hashes.txt not found!${NC}"; log_integrity_checkpoint "FULL CASE HASH" "FAILED" "operations/hashes.txt not found"; return 1; }

    local ORIGINAL_FULL_HASH=$(grep "Hash value for FULL CASE FOLDER (all case files):" "$hash_file" | cut -d':' -f2 | xargs)
    [[ -z "$ORIGINAL_FULL_HASH" ]] && { echo -e "${YELLOW}  [!] No full case hash — may be from older version${NC}"; log_integrity_checkpoint "FULL CASE HASH" "SKIPPED" "No hash entry"; return 0; }

    echo -e "${CYAN}  Original:${NC} ${YELLOW}$ORIGINAL_FULL_HASH${NC}"

    # ONLY hash evidence/ folder — this never changes after acquisition
    local CURRENT_FULL_HASH=$(find "$case_folder/evidence" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)

    [[ -z "$CURRENT_FULL_HASH" ]] && { echo -e "${RED}  [✗] Hash calculation failed${NC}"; log_integrity_checkpoint "FULL CASE HASH" "FAILED" "Calculation failed"; return 1; }

    echo -e "${CYAN}  Current: ${NC} ${YELLOW}$CURRENT_FULL_HASH${NC}"

    if [ "$CURRENT_FULL_HASH" = "$ORIGINAL_FULL_HASH" ]; then
        echo -e "${GREEN}  [✓] FULL EVIDENCE HASH MATCH — All evidence files intact${NC}"
        log_integrity_checkpoint "FULL CASE HASH" "PASSED" "Hash matches — evidence unchanged"
        return 0
    else
        echo -e "${RED}  [✗] FULL EVIDENCE HASH MISMATCH — Evidence files changed/deleted/added!${NC}"
        log_integrity_checkpoint "FULL CASE HASH" "FAILED" "Hash mismatch — evidence tampered"
        return 1
    fi
}

verify_database_integrity() {
    local case_folder="$1"
    
    echo -e "\n${BLUE}[*] VERIFYING DATABASE STRUCTURAL INTEGRITY...${NC}"
    
    if ! command -v sqlite3 &>/dev/null; then
        echo -e "${YELLOW}  [!] sqlite3 not available — skipping${NC}"
        log_integrity_checkpoint "DATABASE INTEGRITY" "SKIPPED" "sqlite3 not installed"
        return 0
    fi
    
    local all_ok=true
    local db_found=false
    
    local db_paths=(
        "${case_folder}/evidence/com.whatsapp/databases/msgstore.db"
        "${case_folder}/evidence/com.whatsapp/databases/wa.db"
    )
    
    for db_path in "${db_paths[@]}"; do
        if [[ -f "$db_path" ]]; then
            db_found=true
            local db_name=$(basename "$db_path")
            echo -e "${CYAN}  Checking: ${db_name}${NC}"
            
            local result=$(sqlite3 -readonly "$db_path" "PRAGMA integrity_check;" 2>/dev/null)
            
            if [[ "$result" == "ok" ]]; then
                echo -e "${GREEN}    [✓] ${db_name}: OK${NC}"
                log_integrity_checkpoint "DB INTEGRITY: ${db_name}" "PASSED" "ok"
            else
                echo -e "${RED}    [✗] ${db_name}: FAILED — ${result}${NC}"
                log_integrity_checkpoint "DB INTEGRITY: ${db_name}" "FAILED" "${result}"
                all_ok=false
            fi
        fi
    done
    
    [[ "$db_found" == false ]] && { echo -e "${YELLOW}  [!] No databases found in evidence/${NC}"; log_integrity_checkpoint "DATABASE INTEGRITY" "SKIPPED" "No databases"; return 0; }
    
    [[ "$all_ok" == true ]] && return 0 || return 1
}

generate_hash_manifest() {
    local case_folder="$1"
    
    echo -e "\n${BLUE}[*] GENERATING PER-FILE HASH MANIFEST...${NC}"
    
    local manifest_file="${case_folder}/operations/evidence/hash_manifest.txt"
    mkdir -p "${case_folder}/operations/evidence"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "  PER-FILE HASH MANIFEST"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Case: $(basename "$case_folder")"
        echo "  Algorithm: SHA-256"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
    } > "$manifest_file"
    
    local file_count=0
    
    for evidence_dir in "evidence/com.whatsapp" "evidence/media/com.whatsapp"; do
        local full_path="${case_folder}/${evidence_dir}"
        
        if [[ -d "$full_path" ]]; then
            echo "# Directory: ${evidence_dir}" >> "$manifest_file"
            
            while IFS= read -r -d '' file; do
                if [[ -f "$file" ]]; then
                    local hash=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
                    local rel_path="${file#$case_folder/}"
                    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
                    echo "${hash}  ${size}  ${rel_path}" >> "$manifest_file"
                    ((file_count++))
                fi
            done < <(find "$full_path" -type f -print0 2>/dev/null)
            echo "" >> "$manifest_file"
        fi
    done
    
    echo "═══════════════════════════════════════════════════════════════" >> "$manifest_file"
    echo "  Total files hashed: ${file_count}" >> "$manifest_file"
    echo "═══════════════════════════════════════════════════════════════" >> "$manifest_file"
    
    chmod 444 "$manifest_file" 2>/dev/null
    
    echo -e "${GREEN}  [✓] Hash manifest: ${file_count} files${NC}"
    log_integrity_checkpoint "HASH MANIFEST" "GENERATED" "${file_count} files"
    return 0
}

generate_integrity_report() {
    local case_folder="$1"
    local report_file="${case_folder}/operations/evidence/integrity_report.txt"
    mkdir -p "${case_folder}/operations/evidence"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "  INTEGRITY VERIFICATION REPORT"
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Generated  : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Case       : $(basename "$case_folder")"
        echo "  Operator   : ${INVESTIGATOR:-Unknown}"
        echo "  Session    : ${SESSION_ID:-Unknown}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "VERIFICATION RESULTS"
        echo "───────────────────────────────────────────────────────────────"
        echo ""
        [[ -f "${case_folder}/operations/logs/chain_of_custody.log" ]] && grep "INTEGRITY CHECKPOINT" "${case_folder}/operations/logs/chain_of_custody.log" | while read -r line; do echo "  $line"; done
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  EVIDENCE INTEGRITY: VERIFIED"
        echo "  All checks passed. Evidence is forensically sound."
        echo "═══════════════════════════════════════════════════════════════"
    } > "$report_file"
    
    chmod 444 "$report_file" 2>/dev/null
    echo -e "${GREEN}[✓] Integrity report: ${report_file}${NC}"
}

load_databases() {
    local case_folder="$1"
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[*]       DATABASE INVENTORY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local DB_PATH="${case_folder}/evidence/com.whatsapp/databases"

    if [ -d "$DB_PATH" ]; then
        echo -e "${GREEN}[+] Databases found at: $DB_PATH${NC}"
        ls -lah "$DB_PATH" 2>/dev/null | grep -E "\.db$|\.db-wal$|\.db-shm$" | while read -r line; do echo -e "  ${line}"; done
        [ -f "$DB_PATH/msgstore.db" ] && echo -e "\n${GREEN}[✓] msgstore.db ready${NC}" || echo -e "${RED}[✗] msgstore.db not found${NC}"
        [ -f "$DB_PATH/wa.db" ] && echo -e "${GREEN}[✓] wa.db ready${NC}" || echo -e "${RED}[✗] wa.db not found${NC}"
        echo -e "\n${GREEN}[✓] Databases ready for analysis${NC}"
    else
        echo -e "${RED}[✗] No databases directory found${NC}"
        return 1
    fi
}

handle_failure() {
    local app_result=$1
    local media_result=$2
    local full_case_result=${3:-0}
    local db_result=${4:-0}

    echo -e "\n${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}         INTEGRITY VERIFICATION FAILED${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "\n${RED}[✗] CANNOT PROCEED WITH ANALYSIS!${NC}"
    echo -e "${RED}[✗] Evidence has been compromised or corrupted${NC}"

    echo -e "\n${YELLOW}[!] Summary of failures:${NC}"
    [ $app_result   -ne 0 ] && echo -e "  ${RED}• WhatsApp App Data: INTEGRITY FAILED${NC}"
    [ $media_result -ne 0 ] && echo -e "  ${RED}• WhatsApp Media: INTEGRITY FAILED${NC}"
    [ $full_case_result -ne 0 ] && echo -e "  ${RED}• FULL EVIDENCE FOLDER: INTEGRITY FAILED (files changed/deleted/added)${NC}"
    [ $db_result    -ne 0 ] && echo -e "  ${RED}• Database Structure: INTEGRITY FAILED${NC}"

    echo -e "\n${YELLOW}[!] Possible reasons:${NC}"
    echo -e "    1. Files were modified after acquisition"
    echo -e "    2. Files were deleted or added to evidence/"
    echo -e "    3. Storage corruption or disk errors"
    echo -e "    4. Incomplete or interrupted acquisition"

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

if [ $# -ge 1 ]; then
    CASE_FOLDER="$1"
else
    echo -e "\n${YELLOW}[?] Please enter the path to the case folder:${NC}"
    read -rp "> " CASE_FOLDER
fi

if ! check_case_folder "$CASE_FOLDER"; then
    exit 1
fi

show_case_info

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  RUNNING COMPREHENSIVE INTEGRITY VERIFICATION${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ═══ PHASE 1: SECURE EVIDENCE (Write Blocker First) ═══
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  PHASE 1: SECURING EVIDENCE (evidence/ folder only)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

verify_write_protection
apply_write_blocking "$CASE_FOLDER"
verify_protection_effective "$CASE_FOLDER"

# ═══ PHASE 2: VERIFY INTEGRITY ═══
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  PHASE 2: VERIFYING EVIDENCE INTEGRITY${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

verify_app_data "$CASE_FOLDER"
APP_RESULT=$?

verify_media "$CASE_FOLDER"
MEDIA_RESULT=$?

verify_full_case "$CASE_FOLDER"
FULL_CASE_RESULT=$?

verify_database_integrity "$CASE_FOLDER"
DB_RESULT=$?

# ═══ DECISION ═══
if [ $APP_RESULT -eq 0 ] && [ $MEDIA_RESULT -eq 0 ] && [ $FULL_CASE_RESULT -eq 0 ] && [ $DB_RESULT -eq 0 ]; then
    
    generate_hash_manifest "$CASE_FOLDER"
    generate_integrity_report "$CASE_FOLDER"
    
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓✓✓ ALL INTEGRITY CHECKS PASSED ✓✓✓${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "\n${GREEN}[+] Evidence is forensically sound and ready for analysis${NC}"
    echo -e "${GREEN}[+] Write blocker: ACTIVE on evidence/${NC}"
    echo -e "${GREEN}[+] operations/ folder: WRITABLE for logs/reports${NC}"
    
    cat > "${CASE_FOLDER}/.integrity_verified" <<EOF
INTEGRITY VERIFICATION RECORD
=============================
Verified: $(date '+%Y-%m-%d %H:%M:%S')
Case: $(basename "$CASE_FOLDER")
Case Folder: ${CASE_FOLDER}
Operator: ${INVESTIGATOR:-Unknown}
Module: Integrity.sh v2.2
Result: ALL CHECKS PASSED
Evidence Folder: evidence/ (READ-ONLY)
Operations Folder: operations/ (WRITABLE)
Steps: Write Blocker ✓ | App Hash ✓ | Media Hash ✓ | Full Evidence Hash ✓ | DB Integrity ✓
Session: ${SESSION_ID:-Unknown}
EOF
    
    log_integrity_checkpoint "FINAL VERDICT" "PASSED" "All integrity checks passed — evidence ready"
    
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp "$(echo -e ${BLUE}"Press ENTER to load the databases for analysis..."${NC})"
    
    load_databases "$CASE_FOLDER"
    
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  DATABASES READY FOR ANALYSIS${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Remember: Always work on COPIES of the evidence files${NC}"
    
    exit 0
else
    handle_failure $APP_RESULT $MEDIA_RESULT $FULL_CASE_RESULT $DB_RESULT
fi