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

# ✅ CORRECTED EXPORTS (with spaces, not underscores)
export CURRENT_CASE CASE_DIR INVESTIGATOR ORGANIZATION CASE_DESC
export EVIDENCE_SOURCE SUSPECT_PHONE BADGE_ID WARRANT_NUM
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

# ✅ CORRECTED EXPORTS (with spaces)
export RED GREEN YELLOW CYAN BLUE MAGENTA WHITE RESET BOLD

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
║    ██╗    ██╗ █████╗      ███████╗ ██████╗ ██████╗ ███████╗███╗   ██╗   ║
║    ██║    ██║██╔══██╗     ██╔════╝██╔═══██╗██╔══██╗██╔════╝████╗  ██║   ║
║    ██║ █╗ ██║███████║     █████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║   ║
║    ██║███╗██║██╔══██║     ██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║   ║
║    ╚███╔███╔╝██║  ██║     ██║     ╚██████╔╝██║  ██║███████╗██║ ╚████║   ║
║     ╚══╝╚══╝ ╚═╝  ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ║
╠══════════════════════════════════════════════════════════════════════════╣
║          Digital Forensic Toolkit v9.0 — WhatsApp Analysis Suite         ║
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
        echo "$entry" >> "${CASE_DIR}/logs/activity.log"
        echo "$entry" >> "${CASE_DIR}/logs/chain_of_custody.log"
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
    
    for cmd in sqlite3 sha256sum md5sum date awk sed grep python3; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_err "Missing required tools: ${missing[*]}"
        print_info "Run: sudo apt-get install sqlite3 coreutils python3"
        exit 1
    fi
    
    print_ok "All dependencies satisfied."
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

# ─────────────────────────────────────────────────────────────────────────────
# MAIN MENUS
# ─────────────────────────────────────────────────────────────────────────────

advanced_analysis_menu() {
    while true; do
        banner
        print_section "ADVANCED ANALYSIS MENU"
        
        echo "   1. Keyword Search Across All Chats"
        echo "   2. Timeline Analysis (Filtered)"
        echo "   3. Contact Communication Map"
        echo "   4. Suspicious Content Detection"
        echo "   5. Location Data Extraction"
        echo "   6. Group Chat Member Analysis"
        echo "   7. Custom SQL Query (Read-Only)"
        echo "   8. WAL Journal Recovery"
        echo "   9. Database Integrity Check"
        echo "  10. Export Raw Tables (CSV/JSON)"
        echo -e "   ${RED}0. Back to Analysis Menu${RESET}\n"
        
        read -rp "  Select option: " choice
        
        case "$choice" in
            1) keyword_search_menu ;;
            2) timeline_filtered ;;
            3) contact_communication_map ;;
            4) suspicious_content_detection ;;
            5) location_data_extraction ;;
            6) group_member_analysis ;;
            7) custom_sql_query ;;
            8) wal_recovery ;;
            9) database_integrity_check ;;
            10) export_raw_tables ;;
            0) break ;;
            *) print_warn "Invalid option."; sleep 1 ;;
        esac
    done
}

analysis_menu() {
    while true; do
        banner
        echo -e "  ${CYAN}Case: ${BOLD}${CURRENT_CASE}${RESET}${CYAN} | Analyst: ${INVESTIGATOR} | Warrant: ${WARRANT_NUM}${RESET}\n"
        print_section "FORENSIC ANALYSIS MENU"
        
        echo -e "  ${WHITE}── DATABASE OPERATIONS ──────────────────────────────────────────${RESET}"
        echo "   1. Load / Reload Evidence Databases"
        echo "   2. View Database Schema"
        echo "   3. Export All Tables (CSV/JSON)"
        echo ""
        echo -e "  ${WHITE}── CORE ANALYSIS ────────────────────────────────────────────────${RESET}"
        echo "   4. Communication Activity Profiling"
        echo "   5. Full Chat Reconstruction"
        echo "   6. Contact Identity Mapping"
        echo "   7. Media & File Reconstruction"
        echo "   8. Deleted Message Detection"
        echo "   9. URL & Link Extraction"
        echo ""
        echo -e "  ${WHITE}── CHAT EXPLORER ────────────────────────────────────────────────${RESET}"
        echo "  10. Deep Dive: Specific Chat ID"
        echo "  11. Search by Phone Number"
        echo "  12. Export Chat Transcript"
        echo ""
        echo -e "  ${WHITE}── REPORTS ─────────────────────────────────────────────────────${RESET}"
        echo "  13. Generate HTML Report"
        echo "  14. Generate PDF Report"
        echo "  15. View Chain of Custody"
        echo "  16. View Activity Log"
        echo ""
        echo -e "   ${RED}0. Return to Main Menu${RESET}\n"
        
        read -rp "  Select option: " choice
        
        case "$choice" in
            1) load_databases_interactive ;;
            2) view_schema ;;
            3) export_raw_tables ;;
            4) analyze_activity_profiling ;;
            5) analyze_chat_reconstruction ;;
            6) analyze_contact_mapping ;;
            7) analyze_media_reconstruction ;;
            8) analyze_deleted_messages ;;
            9) analyze_url_extraction ;;
            10) chat_deep_dive_menu ;;
            11) search_by_phone ;;
            12) export_chat_transcript_menu ;;
            13) generate_html_report ;;
            14) generate_pdf_report ;;
            15) view_chain_of_custody ;;
            16) view_activity_log ;;
            0) break ;;
            *) print_warn "Invalid option."; sleep 1 ;;
        esac
    done
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
        read -rp "  > " choice
        
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
                echo -e "${YELLOW}  Are you sure you want to exit?${RESET}"
                read -rp "  Exit? (y/n): " confirm_exit
                if [[ "$confirm_exit" =~ ^[Yy]$ ]]; then
                    echo -e "\n${GREEN}  Exiting WA-Forensics Toolkit. Evidence integrity maintained.${RESET}\n"
                    exit 0
                fi
                ;;
            *)
                print_warn "Invalid option: '$choice'"
                echo -e "${CYAN}  Please enter a number from 0-4${RESET}"
                sleep 1
                ;;
        esac
    done
}
# ─────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────

main_menu
