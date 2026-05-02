#!/usr/bin/env bash
# =============================================================================
#  WHATSAPP-FORENSICS TOOLKIT v9.0 — WhatsApp Digital Forensic Suite
# =============================================================================

set -uo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────────────────────
# GLOBALS & CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# Define module scripts
MODULE_ACQUISITION="${SCRIPT_DIR}/Acquisition.sh"
MODULE_INTEGRITY="${SCRIPT_DIR}/Integrity.sh"
MODULE_ANALYSIS="${SCRIPT_DIR}/Analysis.sh"
export MODULE_ACQUISITION MODULE_INTEGRITY MODULE_ANALYSIS

CASES_ROOT="${SCRIPT_DIR}/cases"
LIB_DIR="${SCRIPT_DIR}/lib"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

export CASES_ROOT LIB_DIR TEMPLATES_DIR

TOOLKIT_VERSION="9.0.0"
export TOOLKIT_VERSION

# Active case variables
CURRENT_CASE=""
CASE_DIR=""
INVESTIGATOR=""
ORGANIZATION=""
CASE_DESC=""
EVIDENCE_SOURCE=""
SUSPECT_PHONE=""
BADGE_ID=""
WARRANT_NUM=""
MSGSTORE_DB=""
WA_DB=""
INVESTIGATOR_PHONE=""
PHONE_BRAND=""
PHONE_MODEL=""
PHONE_SERIAL=""


# ✅ CORRECTED EXPORTS (with spaces, not underscores)
export CURRENT_CASE CASE_DIR INVESTIGATOR ORGANIZATION CASE_DESC
export EVIDENCE_SOURCE SUSPECT_PHONE BADGE_ID WARRANT_NUM
export INVESTIGATOR_PHONE PHONE_BRAND PHONE_MODEL PHONE_SERIAL
export MSGSTORE_DB WA_DB

# Session tracking
SESSION_ID="SID-$(date '+%Y%m%d%H%M%S')-$$"
SESSION_START=$(date '+%Y-%m-%d %H:%M:%S')
export SESSION_ID SESSION_START

# Temp directory for temporary files
TEMP_DIR="/tmp/wa_forensics_$$"
export TEMP_DIR
mkdir -p "$TEMP_DIR"

# Optional: Clean up on exit
trap "rm -rf $TEMP_DIR" EXIT

# ─────────────────────────────────────────────────────────────────────────────
# COLOUR CODES
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ✅ CORRECTED EXPORTS (with spaces)
export RED GREEN YELLOW CYAN BLUE MAGENTA WHITE RESET BOLD DIM NC

# ─────────────────────────────────────────────────────────────────────────────
# SOURCE MODULES
# ─────────────────────────────────────────────────────────────────────────────
source "${LIB_DIR}/case_manager.sh" 2>/dev/null || {
    echo "ERROR: Cannot find case_manager.sh"
    exit 1
}
source "${LIB_DIR}/db_handler.sh" 2>/dev/null || {
    echo "ERROR: Cannot find db_handler.sh"
    exit 1
}
source "${LIB_DIR}/chat_analyzer.sh" 2>/dev/null || {
    echo "ERROR: Cannot find chat_analyzer.sh"
    exit 1
}
source "${LIB_DIR}/report_generator.sh" 2>/dev/null || {
    echo "ERROR: Cannot find report_generator.sh"
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

banner() {
    clear
    cat << "BANNER"
╔══════════════════════════════════════════════════════════════════════════╗
║    ██╗    ██╗ █████╗      ███████╗ ██████╗ ██████╗ ███████╗███╗   ██╗    ║ 
║    ██║    ██║██╔══██╗     ██╔════╝██╔═══██╗██╔══██╗██╔════╝████╗  ██║    ║
║    ██║ █╗ ██║███████║     █████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║    ║
║    ██║███╗██║██╔══██║     ██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║    ║
║    ╚███╔███╔╝██║  ██║     ██║     ╚██████╔╝██║  ██║███████╗██║ ╚████║    ║
║     ╚══╝╚══╝ ╚═╝  ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝    ║
╠══════════════════════════════════════════════════════════════════════════╣
║          Digital Forensic Toolkit — WhatsApp Analysis Suite              ║
║          ACPO Compliant  •  Chain-of-Custody  •  Read-Only Mode          ║
╚══════════════════════════════════════════════════════════════════════════╝
BANNER
    echo ""
    if [[ -n "$CURRENT_CASE" ]]; then
        echo -e "  ${CYAN}Session: ${SESSION_ID} | Case: ${BOLD}${CURRENT_CASE}${RESET} | Analyst: ${INVESTIGATOR}${RESET}"
        echo ""
    fi
}

log_action() {
    local action="$1"
    local file="${2:-N/A}"
    local result="${3:-SUCCESS}"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[${ts}] SESSION:${SESSION_ID} | ACTION: ${action} | ANALYST: ${INVESTIGATOR:-SYSTEM} | FILE: ${file} | RESULT: ${result}"
    
    if [[ -n "$CASE_DIR" ]]; then
        echo "$entry" >> "${CASE_DIR}/operations/logs/activity.log"
        echo "$entry" >> "${CASE_DIR}/operations/logs/chain_of_custody.log"
    fi
    echo "$entry" >> "${CASES_ROOT}/global_audit.log" 2>/dev/null || true
}
export -f log_action

print_section() {
    echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${WHITE}  $1${RESET}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════${RESET}\n"
}
export -f print_section

print_ok()   { echo -e "${GREEN}  [✔] $*${RESET}"; }
print_warn() { echo -e "${YELLOW}  [⚠] $*${RESET}"; }
print_err()  { echo -e "${RED}  [✘] $*${RESET}"; }
print_info() { echo -e "${CYAN}  [ℹ] $*${RESET}"; }
print_step() { echo -e "\n${MAGENTA}  ━━ $* ${RESET}"; }

export -f print_ok print_warn print_err print_info print_step

pause() {
    echo ""
    read -rp "  Press [ENTER] to continue..." _
}
export -f pause

confirm() {
    local prompt="${1:-Are you sure?}"
    local response
    read -rp "  ${prompt} [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}
export -f confirm

check_dependencies() {
    print_step "Checking system dependencies..."
    local missing=()
    
    # Check required system commands
    for cmd in sqlite3 sha256sum md5sum date awk sed grep python3; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_err "Missing required tools: ${missing[*]}"
        print_info "Run: sudo apt-get install sqlite3 coreutils python3"
        exit 1
    fi
    
    print_ok "All system dependencies satisfied."
    
    # Check for optional external modules
    echo ""
    print_info "Scanning for external modules..."
    
    echo -n "  Acquisition Module (Acquisition.sh) .... "
    if [[ -f "$MODULE_ACQUISITION" ]]; then
        echo -e "${GREEN}✓ FOUND${RESET}"
    else
        echo -e "${YELLOW}○ NOT FOUND (auto-acquisition disabled)${RESET}"
    fi
    
    echo -n "  Integrity Module (Integrity.sh) ........ "
    if [[ -f "$MODULE_INTEGRITY" ]]; then
        echo -e "${GREEN}✓ FOUND${RESET}"
    else
        echo -e "${YELLOW}○ NOT FOUND (auto-verification disabled)${RESET}"
    fi
    
    echo -n "  Analysis Module (Analysis.sh) .......... "
    if [[ -f "$MODULE_ANALYSIS" ]]; then
        echo -e "${GREEN}✓ FOUND${RESET}"
    else
        echo -e "${YELLOW}○ NOT FOUND${RESET}"
    fi
    
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# QUICK START — FULL AUTOMATED ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────

quick_start() {
    banner
    print_section "QUICK START — FULL AUTOMATED ANALYSIS"
    
    print_info "This will create a case, load databases, run all analyses, and generate reports."
    confirm "Proceed?" || { return; }
    
    # Create case
    if ! create_case_interactive; then
        print_err "Case creation failed."
        return 1
    fi
    
    # Load databases
    if ! load_databases_interactive; then
        print_err "Database loading failed."
        return 1
    fi
    
    # Run full analysis
    run_full_analysis_pipeline
    
    print_ok "Quick Start complete! All reports generated."
    print_info "HTML Report: ${CASE_DIR}/html/forensic_report.html"
    print_info "PDF Report:  ${CASE_DIR}/pdf/forensic_report.pdf"
    print_info "Case Directory: ${CASE_DIR}"
    pause
}

run_full_analysis_pipeline() {
    print_section "RUNNING FULL ANALYSIS PIPELINE"
    
    # 1. Database schema extraction
    print_step "1/8 Extracting database schema..."
    extract_schema
    
    # 2. Activity profiling
    print_step "2/8 Communication activity profiling..."
    analyze_activity_profiling
    
    # 3. Chat reconstruction
    print_step "3/8 Full chat reconstruction..."
    analyze_chat_reconstruction
    
    # 4. Contact mapping
    print_step "4/8 Contact identity mapping..."
    analyze_contact_mapping
    
    # 5. Media reconstruction
    print_step "5/8 Media & file reconstruction..."
    analyze_media_reconstruction
    
    # 6. Deleted messages
    print_step "6/8 Deleted message detection..."
    analyze_deleted_messages
    
    # 7. URL extraction
    print_step "7/8 URL & link extraction..."
    analyze_url_extraction
    
    # 8. Generate reports
    print_step "8/8 Generating forensic reports..."
    generate_html_report
    generate_pdf_report
    generate_csv_exports
    generate_final_text_report
    
    print_ok "Full analysis pipeline complete!"
}

analysis_menu() {
    # ===== STRICT INTEGRITY GATE =====
    local integrity_flag="${CASE_DIR}/.integrity_verified"
    local failed_flag="${CASE_DIR}/.integrity_failed"
    
    # Check if case is permanently blocked
    if [[ -f "$failed_flag" ]]; then
        banner
        print_section "CASE BLOCKED - INTEGRITY FAILURE"
        
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⛔ ACCESS PERMANENTLY DENIED                              ║${NC}"
        echo -e "${RED}║  This case failed integrity verification                   ║${NC}"
        echo -e "${RED}║  Analysis is not possible on tampered evidence             ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  Failure Record:${NC}"
        cat "$failed_flag"
        echo ""
        echo -e "${YELLOW}  Required Action:${NC}"
        echo "    • Delete this case (use option 4 from main menu)"
        echo "    • Create a new case"
        echo "    • Re-acquire evidence from original source"
        echo ""
        print_err "Analysis is NOT possible on compromised evidence"
        pause
        return 1
    fi
    
    # Check if integrity verified
    if [[ ! -f "$integrity_flag" ]]; then
        banner
        print_section "INTEGRITY VERIFICATION REQUIRED"
        
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⛔ ACCESS DENIED                                          ║${NC}"
        echo -e "${RED}║  Evidence must be acquired and verified first              ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  Before analysis can begin, you must:${NC}"
        echo "    1. Acquire evidence from emulator/device"
        echo "    2. Pass integrity verification (SHA-256 check)"
        echo ""
        echo -e "${CYAN}  Proceed with evidence acquisition:${NC}"
        echo ""
        echo -e "    ${GREEN}1${RESET}. Start Acquisition → Verification (Full Process)"
        echo -e "    ${CYAN}0${RESET}. Return to Main Menu"
        echo ""
        echo -e "${RED}  ⚠️  There is NO option to bypass verification.${NC}"
        echo -e "${RED}  ⚠️  Evidence integrity is MANDATORY for analysis.${NC}"
        echo ""
        read -rp "  Select option (0-1): " gate_choice
        
        case "$gate_choice" in
            1)
                echo ""
                print_step "STARTING EVIDENCE ACQUISITION & VERIFICATION..."
                echo ""
                
                # Run acquisition
                if ! run_acquisition_module; then
                    echo ""
                    print_err "ACQUISITION FAILED"
                    echo -e "${YELLOW}  Evidence could not be acquired from the source.${NC}"
                    echo -e "${YELLOW}  Check emulator connection and try again.${NC}"
                    log_action "ACQUISITION FAILED" "${CASE_DIR}" "FAILED"
                    pause
                    return 1
                fi
                
                echo ""
                print_step "RUNNING INTEGRITY VERIFICATION..."
                echo ""
                
                # Run integrity check
                if ! run_integrity_module; then
                    echo ""
                    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
                    echo -e "${RED}║  ⛔ INTEGRITY VERIFICATION FAILED                           ║${NC}"
                    echo -e "${RED}║  Case will be PERMANENTLY BLOCKED                          ║${NC}"
                    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
                    echo ""
                    
                    # Create permanent block
                    cat > "$failed_flag" <<EOF
INTEGRITY FAILURE RECORD
========================
Date: $(date)
Case: ${CURRENT_CASE}
Analyst: ${INVESTIGATOR:-Unknown}
Session: ${SESSION_ID}
Status: PERMANENTLY BLOCKED
Reason: SHA-256 hash mismatch - evidence tampered or corrupted
Evidence Path: ${CASE_DIR}
Required Action: Delete case, create new case, re-acquire from source
EOF
                    
                    log_action "CASE PERMANENTLY BLOCKED" "${CASE_DIR}" "FAILED — Integrity check failed"
                    pause
                    return 1
                fi
                
                echo ""
                print_step "LOADING VERIFIED DATABASES..."
                echo ""
                
                # Load databases
                if ! load_databases_from_case; then
                    print_err "Failed to load databases"
                    print_warn "Databases not found in case folder"
                    print_info "Check: ${CASE_DIR}/com.whatsapp/databases/"
                    pause
                    return 1
                fi
                
                echo ""
                echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║  ✓ ALL CHECKS PASSED - EVIDENCE READY                      ║${NC}"
                echo -e "${GREEN}║  Proceeding to analysis menu...                            ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
                sleep 2
                ;;
            0)
                return 0
                ;;
            *)
                print_warn "Invalid choice"
                pause
                return 1
                ;;
        esac
    fi
    
    # ===== INTEGRITY VERIFIED - SHOW ANALYSIS MENU (RENUMBERED 1-11) =====
    while true; do
        banner
        print_menu_header "FORENSIC ANALYSIS MENU"
        
        # Database status display
        local db_status_line=""
        if [[ -n "$MSGSTORE_DB" ]] && [[ -n "$WA_DB" ]]; then
            db_status_line="${GREEN}✓ MSGSTORE: LOADED  |  ✓ WA.DB: LOADED${RESET}"
        elif [[ -n "$MSGSTORE_DB" ]]; then
            db_status_line="${GREEN}✓ MSGSTORE: LOADED  |  ${RED}✗ WA.DB: NOT LOADED${RESET}"
        elif [[ -n "$WA_DB" ]]; then
            db_status_line="${RED}✗ MSGSTORE: NOT LOADED  |  ${GREEN}✓ WA.DB: LOADED${RESET}"
        else
            db_status_line="${RED}✗ NO DATABASES LOADED${RESET}"
        fi
        echo -e "  ${BOLD}DATABASE STATUS:${RESET} ${db_status_line}"
        
        # Show verification status
        if [[ -f "$integrity_flag" ]]; then
            local verify_date=$(grep "Verified:" "$integrity_flag" 2>/dev/null | head -1 | awk -F': ' '{print $2}')
            echo -e "  ${BOLD}INTEGRITY STATUS:${RESET} ${GREEN}✓ VERIFIED${RESET} ${CYAN}(${verify_date})${NC}"
        fi
        echo ""
        
        echo -e "  ${WHITE}── CORE ANALYSIS ────────────────────────────────${RESET}"
        echo -e "    ${GREEN}1${RESET}. Communication Activity Profiling (Q1)"
        echo -e "    ${GREEN}2${RESET}. Full Chat Reconstruction (Q2)"
        echo -e "    ${GREEN}3${RESET}. Contact Identity Mapping (Q3)"
        echo -e "    ${GREEN}4${RESET}. Media & File Reconstruction (Q4)"
        echo -e "    ${GREEN}5${RESET}. Deleted Message Detection (Q5)"
        echo -e "    ${GREEN}6${RESET}. URL & Link Extraction (Q6)"
        echo ""
        echo -e "  ${WHITE}── CHAT EXPLORER ────────────────────────────────${RESET}"
        echo -e "    ${GREEN}7${RESET}. Deep Dive: Specific Chat ID"
        echo -e "    ${GREEN}8${RESET}. Search by Phone Number"
        echo -e "    ${GREEN}9${RESET}. Export Chat Transcript"
        echo ""
        echo -e "  ${WHITE}── REPORTS & EVIDENCE ───────────────────────────${RESET}"
        echo -e "    ${GREEN}10${RESET}. Generate HTML Report"
        echo -e "    ${GREEN}11${RESET}. Generate PDF Report"
        echo -e "    ${GREEN}12${RESET}. View Chain of Custody"
        echo -e "    ${GREEN}13${RESET}. View Activity Log"
        echo ""
        echo -e "    ${CYAN}0${RESET}. Back to Main Menu"
        echo ""
        
        local valid=0
        while [[ $valid -eq 0 ]]; do
            read -rp "  Select option (0-13): " choice
            if validate_menu_input "$choice" 0 13; then
                choice="$VALIDATED_CHOICE"
                valid=1
            fi
        done
        
        case "$choice" in
            1) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || analyze_activity_profiling
                ;;
            2) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || analyze_chat_reconstruction
                ;;
            3) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || analyze_contact_mapping
                ;;
            4) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || analyze_media_reconstruction
                ;;
            5) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || analyze_deleted_messages
                ;;
            6) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || analyze_url_extraction
                ;;
            7) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || chat_deep_dive_menu
                ;;
            8) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || search_by_phone
                ;;
            9) 
                [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db required"; pause; } || export_chat_transcript_menu
                ;;
            10) generate_html_report ;;
            11) generate_pdf_report ;;
            12) view_chain_of_custody ;;
            13) view_activity_log ;;
            0) return 0 ;;
            *)
                print_warn "Invalid option. Please try again."
                pause
                ;;
        esac
    done
}
# GLOBAL INPUT VALIDATION — Reusable across all menus
# ─────────────────────────────────────────────────────────────────────────────


VALIDATED_CHOICE=""
validate_menu_input() {
    local input="$1"
    local min="${2:-1}"
    local max="${3:-99}"
    
    VALIDATED_CHOICE=""
    
    # Strip whitespace
    input="${input## }"
    input="${input%% }"
    
    # Check if empty
    if [[ -z "$input" ]]; then
        print_err "No input provided. Please enter a number (${min}-${max}) or 0 to go back."
        sleep 1.5
        return 1
    fi
    
    # Check if numeric
    if [[ ! "$input" =~ ^[0-9]+$ ]]; then
        print_err "Invalid input: '${input}'. Please enter a number only."
        sleep 1.5
        return 1
    fi
    
    # Special: 0 always means "back" — always valid
    if [[ "$input" -eq 0 ]]; then
        VALIDATED_CHOICE="0"
        return 0
    fi
    
    # Check range
    if [[ "$input" -lt "$min" || "$input" -gt "$max" ]]; then
        print_err "Option '${input}' is out of range (${min}-${max}). Please try again."
        sleep 1.5
        return 1
    fi
    
    VALIDATED_CHOICE="$input"
    return 0
}
export -f validate_menu_input

# ── Standardized menu header ──────────────────────────────────────────────────
print_menu_header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${WHITE}  ${title}${RESET}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════${RESET}"
    if [[ -n "${CURRENT_CASE:-}" ]]; then
        echo -e "  ${CYAN}Case: ${BOLD}${CURRENT_CASE}${RESET}  ${CYAN}|  Session: ${BOLD}${SESSION_ID}${RESET}  ${CYAN}|  Analyst: ${BOLD}${INVESTIGATOR:-N/A}${RESET}${RESET}"
    fi
    echo ""
}
export -f print_menu_header

# =============================================================================
# MODULE EXECUTION FUNCTIONS - Call external scripts from main toolkit
# =============================================================================

# Function to execute Acquisition module
run_acquisition_module() {
    print_step "LAUNCHING ACQUISITION MODULE"
    
    if [[ ! -f "$MODULE_ACQUISITION" ]]; then
        print_err "Acquisition module not found: ${MODULE_ACQUISITION}"
        echo -e "${YELLOW}  Place Acquisition.sh in the same directory as wa-forensics.sh${NC}"
        echo -e "${YELLOW}  Expected location: ${SCRIPT_DIR}/Acquisition.sh${NC}"
        log_action "MODULE NOT FOUND" "Acquisition.sh" "FAILED"
        return 1
    fi
    
    echo -e "${BLUE}[*] Executing: ${MODULE_ACQUISITION}${NC}"
    echo -e "${CYAN}  This will connect to emulator and extract WhatsApp data${NC}"
    echo ""
    
    # Make executable
    chmod +x "$MODULE_ACQUISITION" 2>/dev/null
    
    # Execute acquisition script — export CASE_DIR/CASES_ROOT/SCRIPT_DIR so
    # Acquisition.sh writes evidence into the existing case folder, not CWD
    CASE_DIR="$CASE_DIR" CASES_ROOT="$CASES_ROOT" SCRIPT_DIR="$SCRIPT_DIR" \
        bash "$MODULE_ACQUISITION"
    local result=$?

    if [[ $result -eq 0 ]]; then
        print_ok "Acquisition module completed successfully"

        # CASE_DIR was pre-set and Acquisition.sh wrote into it — just confirm.
        # If somehow unset (standalone sub-case), find the newest folder created.
        if [[ -z "${CASE_DIR:-}" ]] || [[ ! -d "${CASE_DIR}" ]]; then
            local latest_case
            latest_case=$(ls -td "${CASES_ROOT}"/case_* 2>/dev/null | head -1)
            [[ -z "$latest_case" ]] && \
                latest_case=$(ls -td "${SCRIPT_DIR}"/case_* 2>/dev/null | head -1)
            if [[ -n "$latest_case" && -d "$latest_case" ]]; then
                CASE_DIR="$latest_case"
                CURRENT_CASE=$(basename "$latest_case")
                export CASE_DIR CURRENT_CASE
                print_info "Acquisition folder detected: ${CASE_DIR}"
                save_case_state
            fi
        else
            print_info "Evidence acquired into: ${CASE_DIR}"
        fi
        
        log_action "ACQUISITION MODULE" "${MODULE_ACQUISITION}" "SUCCESS"
        return 0
    else
        print_err "Acquisition module failed with exit code: $result"
        log_action "ACQUISITION MODULE" "${MODULE_ACQUISITION}" "FAILED (code: $result)"
        return 1
    fi
}

# Function to execute Integrity verification module
run_integrity_module() {
    print_step "LAUNCHING INTEGRITY VERIFICATION MODULE"
    
    if [[ ! -f "$MODULE_INTEGRITY" ]]; then
        print_err "Integrity module not found: ${MODULE_INTEGRITY}"
        echo -e "${YELLOW}  Place Integrity.sh in the same directory as wa-forensics.sh${NC}"
        echo -e "${YELLOW}  Expected location: ${SCRIPT_DIR}/Integrity.sh${NC}"
        log_action "MODULE NOT FOUND" "Integrity.sh" "FAILED"
        return 1
    fi
    
    if [[ -z "${CASE_DIR:-}" ]]; then
        print_err "No case folder set. Cannot run integrity check."
        print_info "Create or load a case first, then run acquisition."
        return 1
    fi
    
    echo -e "${BLUE}[*] Executing: ${MODULE_INTEGRITY}${NC}"
    echo -e "${CYAN}  Case folder: ${CASE_DIR}${NC}"
    echo -e "${CYAN}  Verifying SHA-256 hashes and write protection${NC}"
    echo ""
    
    # Make executable
    chmod +x "$MODULE_INTEGRITY" 2>/dev/null
    
    # Execute integrity script with case folder as argument
    bash "$MODULE_INTEGRITY" "${CASE_DIR}"
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        print_ok "✓ INTEGRITY VERIFICATION PASSED"
        echo -e "${GREEN}  Evidence is forensically sound - no tampering detected${NC}"
        
        # Create verification flag file
        local flag_file="${CASE_DIR}/.integrity_verified"
        cat > "$flag_file" <<EOF
INTEGRITY VERIFICATION RECORD
=============================
Verified: $(date '+%Y-%m-%d %H:%M:%S')
Case: ${CURRENT_CASE}
Case Folder: ${CASE_DIR}
Analyst: ${INVESTIGATOR:-Unknown}
Module: Integrity.sh
Result: PASSED
Session: ${SESSION_ID}
EOF
        
        log_action "INTEGRITY MODULE" "${CASE_DIR}" "SUCCESS"
        return 0
    else
        print_err "✗ INTEGRITY VERIFICATION FAILED"
        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⚠️  EVIDENCE INTEGRITY COMPROMISED                       ║${NC}"
        echo -e "${RED}║  The acquired data has been modified or corrupted         ║${NC}"
        echo -e "${RED}║  DO NOT use this evidence for analysis                    ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  Possible causes:${NC}"
        echo "    • Files modified after acquisition"
        echo "    • Storage corruption or disk errors"
        echo "    • Incomplete or interrupted acquisition"
        echo "    • Unauthorized access to evidence files"
        echo ""
        echo -e "${YELLOW}  Recommended actions:${NC}"
        echo "    1. Re-acquire evidence from original source"
        echo "    2. Document this incident in chain of custody"
        echo "    3. Do NOT perform analysis on this case"
        echo ""
        
        log_action "INTEGRITY MODULE" "${CASE_DIR}" "FAILED — Evidence tampered"
        return 1
    fi
}

# Function to execute Analysis module
run_analysis_module() {
    print_step "LAUNCHING ANALYSIS MODULE"
    
    if [[ -f "$MODULE_ANALYSIS" ]]; then
        echo -e "${BLUE}[*] Executing: ${MODULE_ANALYSIS}${NC}"
        echo -e "${CYAN}  Passing case folder: ${CASE_DIR}${NC}"
        echo ""
        
        chmod +x "$MODULE_ANALYSIS" 2>/dev/null
        bash "$MODULE_ANALYSIS" "${CASE_DIR}"
        local result=$?
        
        log_action "ANALYSIS MODULE" "${CASE_DIR}" "SUCCESS (code: $result)"
        return $result
    else
        print_err "Analysis module not found: ${MODULE_ANALYSIS}"
        return 1
    fi
}

# Function to load databases from case folder (after acquisition & verification)
load_databases_from_case() {
    print_step "LOADING DATABASES FROM CASE FOLDER"
    
    local db_found=false
    local search_paths=(
        "${CASE_DIR}/evidence/com.whatsapp/databases"
        "${CASE_DIR}/operations/databases"
    )
    
    # Search for msgstore.db
    for path in "${search_paths[@]}"; do
        if [[ -f "${path}/msgstore.db" ]] && [[ "$db_found" == false ]]; then
            print_ok "Found msgstore.db at: ${path}/msgstore.db"
            
            mkdir -p "${CASE_DIR}/databases"
            cp "${path}/msgstore.db" "${CASE_DIR}/databases/msgstore.db" 2>/dev/null
            chmod 444 "${CASE_DIR}/databases/msgstore.db" 2>/dev/null
            
            # Copy WAL and SHM files if present
            [[ -f "${path}/msgstore.db-wal" ]] && cp "${path}/msgstore.db-wal" "${CASE_DIR}/databases/"
            [[ -f "${path}/msgstore.db-shm" ]] && cp "${path}/msgstore.db-shm" "${CASE_DIR}/databases/"
            
            MSGSTORE_DB="${CASE_DIR}/databases/msgstore.db"
            export MSGSTORE_DB
            print_ok "msgstore.db loaded"
            db_found=true
        fi
    done
    
    # Search for wa.db
    local wa_found=false
    for path in "${search_paths[@]}"; do
        if [[ -f "${path}/wa.db" ]] && [[ "$wa_found" == false ]]; then
            print_ok "Found wa.db at: ${path}/wa.db"
            
            mkdir -p "${CASE_DIR}/databases"
            cp "${path}/wa.db" "${CASE_DIR}/databases/wa.db" 2>/dev/null
            chmod 444 "${CASE_DIR}/databases/wa.db" 2>/dev/null
            
            WA_DB="${CASE_DIR}/databases/wa.db"
            export WA_DB
            print_ok "wa.db loaded"
            wa_found=true
        fi
    done
    
    if [[ "$db_found" == true ]] || [[ "$wa_found" == true ]]; then
        save_case_state
        log_action "LOAD DATABASES" "${CASE_DIR}" "SUCCESS"
        return 0
    else
        print_warn "No databases found in case folder"
        log_action "LOAD DATABASES" "${CASE_DIR}" "WARNING — No databases found"
        return 1
    fi
}

# =============================================================================
# COMPLETE FORENSIC WORKFLOW - Chains all modules together
# =============================================================================
full_forensic_workflow() {
    banner
    print_section "COMPLETE FORENSIC WORKFLOW"
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  PHASE 1: ACQUIRE  →  PHASE 2: VERIFY  →  PHASE 3: LOAD  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Phase 1: Acquisition
    echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}  PHASE 1 of 3: EVIDENCE ACQUISITION${NC}"
    echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if ! run_acquisition_module; then
        echo ""
        print_err "PHASE 1 FAILED: Could not acquire evidence"
        echo -e "${YELLOW}  The workflow cannot continue without successful acquisition${NC}"
        echo ""
        
        if confirm "Retry acquisition?"; then
            full_forensic_workflow
        fi
        return 1
    fi
    
    # Phase 2: Integrity Verification
    echo ""
    echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}  PHASE 2 of 3: INTEGRITY VERIFICATION${NC}"
    echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if ! run_integrity_module; then
        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  PHASE 2 FAILED: EVIDENCE INTEGRITY COMPROMISED            ║${NC}"
        echo -e "${RED}║  Analysis CANNOT proceed with tampered evidence            ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  Options:${NC}"
        echo "    1. Re-acquire fresh evidence (start over)"
        echo "    2. Exit (preserve case folder for investigation)"
        echo ""
        read -rp "  Select (1-2): " fail_choice
        
        case "$fail_choice" in
            1) 
                print_info "Restarting workflow from acquisition..."
                full_forensic_workflow
                return $?
                ;;
            2)
                print_info "Exiting. Case preserved at: ${CASE_DIR}"
                return 1
                ;;
            *)
                return 1
                ;;
        esac
        return 1
    fi
    
    # Phase 3: Load Databases
    echo ""
    echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}  PHASE 3 of 3: LOAD DATABASES${NC}"
    echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    load_databases_from_case
    
    # Save that integrity was verified
    local flag_file="${CASE_DIR}/.integrity_verified"
    if [[ ! -f "$flag_file" ]]; then
        cat > "$flag_file" <<EOF
INTEGRITY VERIFICATION RECORD
=============================
Verified: $(date '+%Y-%m-%d %H:%M:%S')
Case: ${CURRENT_CASE}
Analyst: ${INVESTIGATOR:-Unknown}
Workflow: Acquire → Verify → Load
Status: PASSED
EOF
    fi
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ ALL PHASES COMPLETED SUCCESSFULLY                       ║${NC}"
    echo -e "${GREEN}║  Evidence is ready for forensic analysis                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}  Summary:${NC}"
    echo -e "    Case: ${GREEN}${CURRENT_CASE}${NC}"
    echo -e "    Folder: ${CASE_DIR}"
    echo -e "    msgstore.db: ${GREEN}${MSGSTORE_DB:-Not loaded}${NC}"
    echo -e "    wa.db: ${GREEN}${WA_DB:-Not loaded}${NC}"
    echo -e "    Integrity: ${GREEN}VERIFIED ✓${NC}"
    echo ""
    
    log_action "FULL WORKFLOW COMPLETE" "${CASE_DIR}" "SUCCESS"
    pause
    return 0
}

main_menu() {
    check_dependencies
    mkdir -p "$CASES_ROOT"
    
    while true; do
        banner
        print_section "MAIN MENU"
        
        echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}  ║                      AVAILABLE OPTIONS                            ║${RESET}"
        echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        
        echo -e "${BOLD}${WHITE}  [ CASE MANAGEMENT ]${RESET}"
        echo -e "    ${GREEN}1${RESET}. Create New Case"
        echo -e "    ${GREEN}2${RESET}. Load Existing Case"
        echo -e "    ${GREEN}3${RESET}. List All Cases"
        echo -e "    ${GREEN}4${RESET}. Delete Case"
        echo ""
        echo -e "${BOLD}${WHITE}  [ EXIT ]${RESET}"
        echo -e "    ${RED}0${RESET}. Exit Toolkit"
        echo ""
        echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────${RESET}"
        echo -e "${YELLOW}  Enter option (0-4):${RESET}"
        echo ""

        local valid=0
        while [[ $valid -eq 0 ]]; do
            read -rp "  > " choice
            
            if validate_menu_input "$choice" 0 4; then
                choice="$VALIDATED_CHOICE"
                valid=1
            fi
        done
        
        case "$choice" in
            1)
                if create_case_interactive; then
                    analysis_menu
                else
                    print_warn "Case creation cancelled."
                    sleep 1
                fi
                ;;
            2)
                if load_case_interactive; then
                    analysis_menu
                else
                    print_warn "Could not load case."
                    sleep 1
                fi
                ;;
            3)
                list_all_cases
                ;;
            4)
                delete_case_menu
                ;;
            0)
                echo ""
                print_section "EXIT TOOLKIT"
                if confirm "Are you sure you want to exit?"; then
                    echo -e "\n${GREEN}  Exiting WA-Forensics Toolkit. Evidence integrity maintained.${RESET}\n"
                    exit 0
                fi
                ;;
        esac

        
    done              
}                    

# ─────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────

main_menu
