#!/usr/bin/env bash
# =============================================================================
#  CASE MANAGER — Creates and manages forensic cases
#  Features: Human-Readable Audit Log • Improved Navigation • Full Validation
# =============================================================================

create_case_directories() {
    mkdir -p \
        "${CASE_DIR}/raw" \
        "${CASE_DIR}/extracted" \
        "${CASE_DIR}/extracted/chats" \
        "${CASE_DIR}/extracted/contacts" \
        "${CASE_DIR}/extracted/media" \
        "${CASE_DIR}/extracted/urls" \
        "${CASE_DIR}/databases" \
        "${CASE_DIR}/media/images" \
        "${CASE_DIR}/media/videos" \
        "${CASE_DIR}/media/audio" \
        "${CASE_DIR}/media/documents" \
        "${CASE_DIR}/media/stickers" \
        "${CASE_DIR}/reports" \
        "${CASE_DIR}/reports/text" \
        "${CASE_DIR}/reports/html" \
        "${CASE_DIR}/reports/pdf" \
        "${CASE_DIR}/reports/csv" \
        "${CASE_DIR}/html" \
        "${CASE_DIR}/pdf" \
        "${CASE_DIR}/logs" \
        "${CASE_DIR}/evidence" \
        "${CASE_DIR}/temp"
    
    print_ok "Case directory structure created."
}

create_case_interactive() {
    banner
    print_section "CREATE NEW FORENSIC CASE"
    
    echo -e "${YELLOW}  Enter case details (all fields required):${RESET}\n"
    
    # Auto-generate case ID
    local auto_id="CASE-$(date '+%Y%m%d-%H%M%S')"
    while true; do
        echo -e "  ${CYAN}Auto-generated Case ID: ${auto_id}${RESET}"
        echo -e "  ${YELLOW}  [Y] Use this ID   [n] Enter custom ID   [b] Back to main menu${RESET}"
        read -rp "  Use this ID? [Y/n/b]: " use_auto
        case "$use_auto" in
            b|B)
                print_info "Returning to main menu."
                return 1
                ;;
            n|N)
                while true; do
                    echo -e "  ${YELLOW}  [b] Go back and auto-generate a new ID instead${RESET}"
                    read -rp "  Enter Case ID (or 'b' to go back): " CURRENT_CASE
                    if [[ "$CURRENT_CASE" == "b" || "$CURRENT_CASE" == "B" ]]; then
                        auto_id="CASE-$(date '+%Y%m%d-%H%M%S')"
                        break
                    elif [[ -z "$CURRENT_CASE" ]]; then
                        print_warn "Case ID cannot be empty."
                    elif [[ ! "$CURRENT_CASE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                        print_warn "Case ID can only contain letters, numbers, hyphens, and underscores."
                    else
                        break 2
                    fi
                done
                ;;
            *)
                CURRENT_CASE="$auto_id"
                break
                ;;
        esac
    done
    
    CASE_DIR="${CASES_ROOT}/${CURRENT_CASE}"
    
    if [[ -d "$CASE_DIR" ]]; then
        print_err "Case already exists: $CASE_DIR"
        echo ""
        echo -e "${YELLOW}  Options:${RESET}"
        echo "    1. Load existing case"
        echo "    2. Enter different Case ID"
        echo "    3. Cancel and return to menu"
        echo ""
        read -rp "  > " dup_choice
        case "$dup_choice" in
            1) load_case_by_id "$CURRENT_CASE"; return 0 ;;
            2) create_case_interactive; return $? ;;
            *) print_info "Cancelled."; return 1 ;;
        esac
    fi
    
    # Investigator details
    while true; do
        read -rp "  Investigator Name        : " INVESTIGATOR
        if [[ -z "$INVESTIGATOR" ]]; then
            print_warn "Investigator name required."
        else
            break
        fi
    done
    
    while true; do
        read -rp "  Badge / Employee ID      : " BADGE_ID
        if [[ -z "$BADGE_ID" ]]; then
            print_warn "Badge ID required."
        else
            break
        fi
    done
    
    read -rp "  Organization             : " ORGANIZATION
    ORGANIZATION="${ORGANIZATION:-Unknown}"
    
    while true; do
        read -rp "  Warrant / Case Number    : " WARRANT_NUM
        if [[ -z "$WARRANT_NUM" ]]; then
            print_warn "Warrant number required."
        else
            break
        fi
    done
    
    read -rp "  Suspect Phone Number     : " SUSPECT_PHONE
    read -rp "  Case Description         : " CASE_DESC
    read -rp "  Evidence Source          : " EVIDENCE_SOURCE
    
    # Create directories
    create_case_directories
    
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write case_info.txt
    cat > "${CASE_DIR}/case_info.txt" <<EOF
============================================================
  DIGITAL FORENSIC TOOLKIT v${TOOLKIT_VERSION} — CASE RECORD
============================================================
Case ID          : ${CURRENT_CASE}
Session ID       : ${SESSION_ID}
Created          : ${ts}
------------------------------------------------------------
INVESTIGATOR DETAILS
  Name           : ${INVESTIGATOR}
  Badge / ID     : ${BADGE_ID}
  Organization   : ${ORGANIZATION}
------------------------------------------------------------
CASE DETAILS
  Warrant No.    : ${WARRANT_NUM}
  Suspect Phone  : ${SUSPECT_PHONE:-Not specified}
  Description    : ${CASE_DESC:-Not specified}
  Evidence Source: ${EVIDENCE_SOURCE:-Not specified}
------------------------------------------------------------
LEGAL FRAMEWORK
  Standard       : ACPO Good Practice Guide for Digital Evidence
  Principle 1    : Data not altered/changed
  Principle 2    : Competent handling with documented justification
  Principle 3    : Audit trail created and preserved
  Principle 4    : Investigating officer accountable for ACPO compliance
============================================================
EOF

    # Initialize Chain of Custody
    cat > "${CASE_DIR}/logs/chain_of_custody.log" <<EOF
============================================================
  CHAIN OF CUSTODY LOG
  Case   : ${CURRENT_CASE}
  Opened : ${ts}
  Analyst: ${INVESTIGATOR} (${BADGE_ID})
============================================================

EOF

    # Initialize Activity Log
    cat > "${CASE_DIR}/logs/activity.log" <<EOF
============================================================
  ACTIVITY LOG — ${CURRENT_CASE}
  Session: ${SESSION_ID}
  Started: ${ts}
============================================================

EOF

    # Initialize Evidence Hash Registry
    cat > "${CASE_DIR}/evidence/hash_registry.txt" <<EOF
============================================================
  EVIDENCE HASH REGISTRY
  Case: ${CURRENT_CASE}
============================================================

EOF

    log_action "Case Created" "${CASE_DIR}" "SUCCESS"
    
    print_ok "Case created successfully: ${CURRENT_CASE}"
    print_info "Case directory: ${CASE_DIR}"
    
    # Save case state for persistence
    save_case_state
    
    # =========================================================================
    # MANDATORY ACQUISITION & VERIFICATION AFTER CASE CREATION
    # =========================================================================
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  CASE CREATED SUCCESSFULLY                                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}  ⚠️  NEXT STEP: Evidence acquisition is REQUIRED${NC}"
    echo -e "${YELLOW}  You must acquire evidence before analysis can begin.${NC}"
    echo ""
    echo -e "${CYAN}  What would you like to do?${NC}"
    echo ""
    echo -e "    ${GREEN}1${RESET}. Acquire Evidence Now (Required for analysis)"
    echo -e "    ${GREEN}2${RESET}. Return to Main Menu (Evidence NOT acquired)"
    echo ""
    read -rp "  Select option (1-2): " post_create_choice
    
    case "$post_create_choice" in
        1)
            # User wants to acquire now
            echo ""
            print_step "STARTING EVIDENCE ACQUISITION PROCESS..."
            echo ""
            
            # Call acquisition module from wa-forensics.sh
            if declare -f run_acquisition_module > /dev/null 2>&1; then
                if run_acquisition_module; then
                    echo ""
                    print_ok "Acquisition completed!"
                    echo ""
                    
                    # Immediately run integrity verification
                    print_step "RUNNING INTEGRITY VERIFICATION..."
                    echo ""
                    
                    if declare -f run_integrity_module > /dev/null 2>&1; then
                        if run_integrity_module; then
                            echo ""
                            
                            # Load databases from case folder
                            print_step "LOADING DATABASES..."
                            echo ""
                            
                            if declare -f load_databases_from_case > /dev/null 2>&1; then
                                if load_databases_from_case; then
                                    echo ""
                                    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
                                    echo -e "${GREEN}║  ✓ EVIDENCE READY FOR ANALYSIS                            ║${NC}"
                                    echo -e "${GREEN}║  Acquired → Verified → Databases Loaded                    ║${NC}"
                                    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
                                    echo ""
                                    print_info "Proceeding to Analysis Menu..."
                                    sleep 2
                                    return 0
                                else
                                    print_err "Failed to load databases"
                                    print_warn "Databases not found in case folder after acquisition"
                                    pause
                                    return 1
                                fi
                            else
                                # Fallback: load databases manually
                                print_warn "load_databases_from_case not available - loading manually"
                                if declare -f load_databases_interactive > /dev/null 2>&1; then
                                    load_databases_interactive
                                    return 0
                                fi
                            fi
                        else
                            # INTEGRITY FAILED
                            echo ""
                            echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
                            echo -e "${RED}║  ⛔ EVIDENCE INTEGRITY CHECK FAILED                        ║${NC}"
                            echo -e "${RED}║  Analysis has been PERMANENTLY BLOCKED for this case       ║${NC}"
                            echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
                            echo ""
                            echo -e "${YELLOW}  The acquired evidence failed integrity verification.${NC}"
                            echo -e "${YELLOW}  This means the data is corrupted or tampered.${NC}"
                            echo ""
                            echo -e "${YELLOW}  REQUIRED ACTION:${NC}"
                            echo "    1. Delete this case and create a new one"
                            echo "    2. Re-acquire evidence from the source"
                            echo "    3. Ensure no modifications occur during acquisition"
                            echo ""
                            echo -e "${RED}  ⚠️  THIS CASE CANNOT BE USED FOR ANALYSIS${NC}"
                            echo ""
                            
                            # Mark case as FAILED
                            local failed_flag="${CASE_DIR}/.integrity_failed"
                            cat > "$failed_flag" <<EOF
INTEGRITY FAILURE RECORD
========================
Date: $(date)
Case: ${CURRENT_CASE}
Analyst: ${INVESTIGATOR}
Status: PERMANENTLY BLOCKED
Reason: Evidence failed SHA-256 verification
Action Required: Delete case and re-acquire
EOF
                            
                            log_action "CASE BLOCKED" "${CASE_DIR}" "FAILED — Integrity check failed after acquisition"
                            pause
                            return 1
                        fi
                    else
                        print_err "Integrity module not available"
                        print_err "Cannot verify evidence - analysis blocked"
                        pause
                        return 1
                    fi
                else
                    # ACQUISITION FAILED
                    print_err "Acquisition failed"
                    echo ""
                    echo -e "${YELLOW}  Evidence could not be acquired.${NC}"
                    echo -e "${YELLOW}  You can try again from the main menu.${NC}"
                    log_action "ACQUISITION FAILED" "${CASE_DIR}" "FAILED"
                    pause
                    return 1
                fi
            else
                # Acquisition module not loaded
                print_err "Acquisition module not available (run_acquisition_module not found)"
                print_warn "This function must be sourced from wa-forensics.sh"
                print_info "Returning to main menu - use option 5 or 6 from main menu"
                pause
                return 1
            fi
            ;;
        2)
            # User wants to return to menu
            print_info "Case created but evidence NOT acquired"
            print_info "Use options from main menu to acquire and verify later"
            print_info "Case folder: ${CASE_DIR}"
            log_action "CASE CREATED - PENDING ACQUISITION" "${CASE_DIR}" "SUCCESS"
            sleep 2
            return 0
            ;;
        *)
            print_warn "Invalid choice - returning to menu"
            print_info "Case created but evidence NOT acquired"
            sleep 1
            return 0
            ;;
    esac
    
    return 0
}
save_case_state() {
    cat > "${CASE_DIR}/.case_state" <<EOF
CURRENT_CASE="${CURRENT_CASE}"
CASE_DIR="${CASE_DIR}"
INVESTIGATOR="${INVESTIGATOR}"
ORGANIZATION="${ORGANIZATION}"
CASE_DESC="${CASE_DESC}"
EVIDENCE_SOURCE="${EVIDENCE_SOURCE}"
SUSPECT_PHONE="${SUSPECT_PHONE}"
BADGE_ID="${BADGE_ID}"
WARRANT_NUM="${WARRANT_NUM}"
MSGSTORE_DB="${MSGSTORE_DB}"
WA_DB="${WA_DB}"
EOF
}

load_case_state() {
    if [[ -f "${CASE_DIR}/.case_state" ]]; then
        source "${CASE_DIR}/.case_state"
    fi
}

load_case_by_id() {
    local case_id="$1"
    CURRENT_CASE="$case_id"
    CASE_DIR="${CASES_ROOT}/${CURRENT_CASE}"
    
    if [[ ! -d "$CASE_DIR" ]]; then
        print_err "Case not found: $CASE_DIR"
        return 1
    fi
    
    load_case_state
    
    # Reload from case_info if state file missing
    if [[ -z "$INVESTIGATOR" ]] && [[ -f "${CASE_DIR}/case_info.txt" ]]; then
        INVESTIGATOR=$(grep "Name" "${CASE_DIR}/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        BADGE_ID=$(grep "Badge" "${CASE_DIR}/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        WARRANT_NUM=$(grep "Warrant" "${CASE_DIR}/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        SUSPECT_PHONE=$(grep "Suspect Phone" "${CASE_DIR}/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        ORGANIZATION=$(grep "Organization" "${CASE_DIR}/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
    fi
    
    # Check for databases
    [[ -f "${CASE_DIR}/databases/msgstore.db" ]] && MSGSTORE_DB="${CASE_DIR}/databases/msgstore.db"
    [[ -f "${CASE_DIR}/databases/wa.db" ]] && WA_DB="${CASE_DIR}/databases/wa.db"
    
    log_action "Case Loaded" "${CASE_DIR}" "SUCCESS"
    print_ok "Case loaded: ${CURRENT_CASE}"
    [[ -n "$MSGSTORE_DB" ]] && print_ok "msgstore.db: loaded"
    [[ -n "$WA_DB" ]] && print_ok "wa.db: loaded"
    
    return 0
}

load_case_interactive() {
    banner
    print_section "LOAD EXISTING CASE"
    
    if [[ ! -d "$CASES_ROOT" ]] || [[ -z "$(ls -A "$CASES_ROOT" 2>/dev/null)" ]]; then
        print_warn "No existing cases found in: $CASES_ROOT"
        echo ""
        echo -e "${YELLOW}  Would you like to create a new case? (y/n):${RESET}"
        read -rp "  > " create_new
        if [[ "$create_new" =~ ^[Yy]$ ]]; then
            create_case_interactive
        fi
        pause
        return 1
    fi
    
    echo -e "${CYAN}  Existing cases:${RESET}"
    echo ""
    local cases=()
    local i=1
    
    while IFS= read -r -d '' d; do
        local case_id=$(basename "$d")
        local inv=$(grep "Name" "${d}/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
        local created=$(grep "Created" "${d}/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
        echo -e "  ${GREEN}${i}.${RESET} ${YELLOW}${case_id}${RESET} — ${inv:-Unknown} (${created:-Unknown})"
        cases+=("$case_id")
        ((i++))
    done < <(find "$CASES_ROOT" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)
    
    echo ""
    echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}  Options:${RESET}"
    echo "    [1-${#cases[@]}] - Select a case by number"
    echo "    Type Case ID directly to load"
    echo "    b - Go back"
    echo "    q - Quit to main menu"
    echo ""
    read -rp "  > " selection
    
    case "$selection" in
        b|B|back)
            return 1
            ;;
        q|Q|quit)
            return 1
            ;;
        "")
            print_warn "No selection made."
            pause
            load_case_interactive
            return $?
            ;;
        *)
            local chosen
            if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#cases[@]}" ]]; then
                chosen="${cases[$((selection - 1))]}"
            else
                chosen="$selection"
            fi
            
            if ! load_case_by_id "$chosen"; then
                print_err "Failed to load case: $chosen"
                echo ""
                echo -e "${YELLOW}  Try again? (y/n):${RESET}"
                read -rp "  > " retry
                if [[ "$retry" =~ ^[Yy]$ ]]; then
                    load_case_interactive
                fi
                return 1
            fi
            return 0
            ;;
    esac
}

list_all_cases() {
    banner
    print_section "ALL CASES"
    
    if [[ ! -d "$CASES_ROOT" ]] || [[ -z "$(ls -A "$CASES_ROOT" 2>/dev/null)" ]]; then
        print_warn "No cases found."
        echo ""
        echo -e "${YELLOW}  Press Enter to return to menu...${RESET}"
        read -r
        return
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                              ALL FORENSIC CASES                               ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BOLD}${WHITE}  Case ID                    | Created              | Investigator          | Status${RESET}"
    echo -e "${CYAN}  ───────────────────────────┼──────────────────────┼───────────────────────┼─────────${RESET}"
    
    local total_cases=0
    for d in "${CASES_ROOT}"/*/; do
        [[ -d "$d" ]] || continue
        local cid=$(basename "$d")
        local created=$(grep "Created" "${d}/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
        local inv=$(grep "Name" "${d}/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
        local has_msgstore=""
        local has_wa=""
        [[ -f "${d}/databases/msgstore.db" ]] && has_msgstore="📱"
        [[ -f "${d}/databases/wa.db" ]] && has_wa="📇"
        local status="${has_msgstore}${has_wa}"
        [[ -z "$status" ]] && status="📁"
        
        printf "  %-26s | %-20s | %-21s | %s\n" "$cid" "${created:-Unknown}" "${inv:-Unknown:0:19}" "$status"
        ((total_cases++))
    done
    
    echo ""
    echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${GREEN}Total Cases: ${total_cases}${RESET}"
    echo ""
    echo -e "${CYAN}  Legend: 📱 = msgstore.db loaded | 📇 = wa.db loaded | 📁 = No databases${RESET}"
    echo ""
    echo -e "${YELLOW}  Press Enter to return to menu...${RESET}"
    read -r
}
delete_case_menu() {
    banner
    print_section "DELETE CASE"
    
    if [[ ! -d "$CASES_ROOT" ]] || [[ -z "$(ls -A "$CASES_ROOT" 2>/dev/null)" ]]; then
        print_warn "No cases found."
        pause
        return
    fi
    
    list_all_cases
    
    echo ""
    echo -e "${RED}${BOLD}  ⚠️  WARNING: This action is IRREVERSIBLE!${RESET}"
    echo ""
    read -rp "  Enter Case ID to delete (or 'b' to go back): " case_id
    
    [[ -z "$case_id" || "$case_id" == "b" || "$case_id" == "B" ]] && return
    
    local case_path="${CASES_ROOT}/${case_id}"
    
    if [[ ! -d "$case_path" ]]; then
        print_err "Case not found: $case_id"
        echo ""
        echo -e "${YELLOW}  Try again? (y/n):${RESET}"
        read -rp "  > " retry
        if [[ "$retry" =~ ^[Yy]$ ]]; then
            delete_case_menu
        fi
        return
    fi
    
    echo ""
    print_warn "You are about to permanently delete:"
    echo -e "  ${YELLOW}Case ID: ${case_id}${RESET}"
    echo -e "  ${YELLOW}Location: ${case_path}${RESET}"
    echo ""
    print_warn "This action ${RED}CAMNOT BE UNDONE${RESET}."
    echo ""
    
    read -rp "  Type the Case ID to confirm deletion: " confirm_id
    
    if [[ "$confirm_id" != "$case_id" ]]; then
        print_err "Case ID does not match. Deletion cancelled."
        pause
        return
    fi
    
    if confirm "Are you absolutely sure you want to delete this case?"; then
        rm -rf "$case_path"
        log_action "Case Deleted" "$case_path" "SUCCESS"
        print_ok "Case deleted: $case_id"
        
        # Clear current case if it was the deleted one
        if [[ "$CURRENT_CASE" == "$case_id" ]]; then
            CURRENT_CASE=""
            CASE_DIR=""
            MSGSTORE_DB=""
            WA_DB=""
        fi
    else
        print_info "Deletion cancelled."
    fi
    
    pause
}

view_chain_of_custody() {
    banner
    print_section "CHAIN OF CUSTODY LOG"
    
    if [[ ! -f "${CASE_DIR}/logs/chain_of_custody.log" ]]; then
        print_warn "Chain of custody log not found."
        pause
        return
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                            CHAIN OF CUSTODY LOG                               ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    cat "${CASE_DIR}/logs/chain_of_custody.log"
    
    echo ""
    echo -e "${YELLOW}  Options:${RESET}"
    echo "    e - Export log to file"
    echo "    q - Return"
    echo ""
    read -rp "  > " opt
    
    case "$opt" in
        e|E)
            local export_file="${CASE_DIR}/evidence/chain_of_custody_export.txt"
            cp "${CASE_DIR}/logs/chain_of_custody.log" "$export_file"
            print_ok "Exported to: $export_file"
            pause
            ;;
    esac
}
# ─────────────────────────────────────────────────────────────────────────────
# UPDATED FUNCTION: view_activity_log()
# Simple, clean log viewer — generates HTML report with full history
# No sub-menus, no filtering complexity
# ─────────────────────────────────────────────────────────────────────────────
view_activity_log() {
    banner
    print_menu_header "ACTIVITY LOG — HTML REPORT"
    
    local logfile="${CASE_DIR}/logs/activity.log"
    
    if [[ ! -f "$logfile" ]]; then
        print_warn "Activity log not found: ${logfile}"
        pause
        return
    fi
    
    # Count entries
    local total_entries=$(grep -c '^\[' "$logfile" 2>/dev/null || echo "0")
    
    echo -e "  ${BOLD}Log File:${RESET} ${CYAN}${logfile}${RESET}"
    echo -e "  ${BOLD}Total Entries:${RESET} ${YELLOW}${total_entries}${RESET}"
    echo -e "  ${BOLD}Session:${RESET} ${CYAN}${SESSION_ID}${RESET}"
    echo ""
    
    print_step "Generating HTML activity log report..."
    
    # Generate HTML report
    local htmlfile="${CASE_DIR}/html/activity_log.html"
    mkdir -p "${CASE_DIR}/html"
    
    cat > "$htmlfile" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Activity Log — ${CURRENT_CASE}</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI','Consolas',monospace;background:#0d1117;color:#c9d1d9;padding:24px;line-height:1.5}
        .container{max-width:1400px;margin:0 auto}
        .header{background:linear-gradient(135deg,#1a73e8,#0d47a1);border-radius:16px;padding:30px;margin-bottom:24px;color:white}
        .header h1{font-size:1.8rem;margin-bottom:8px}
        .badge{display:inline-block;background:rgba(255,255,255,0.2);padding:4px 12px;border-radius:20px;font-size:0.75rem;margin-right:8px}
        .stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin-bottom:24px}
        .stat-card{background:#161b22;border-radius:12px;padding:18px;text-align:center;border:1px solid #30363d}
        .stat-number{font-size:2rem;font-weight:bold;color:#58a6ff}
        .stat-label{font-size:0.7rem;color:#8b949e;text-transform:uppercase;letter-spacing:0.5px;margin-top:4px}
        .section{background:#161b22;border-radius:16px;padding:24px;margin-bottom:24px;border:1px solid #30363d}
        .section h2{color:#58a6ff;margin-bottom:16px;font-size:1.2rem;border-bottom:1px solid #30363d;padding-bottom:10px}
        .table-container{overflow-x:auto;border-radius:8px;border:1px solid #30363d;max-height:70vh;overflow-y:auto}
        table{width:100%;border-collapse:collapse;font-size:0.78rem}
        th{background:#1f6feb;color:white;font-weight:500;padding:10px 14px;text-align:left;position:sticky;top:0;z-index:1;white-space:nowrap}
        td{padding:8px 14px;border-bottom:1px solid #21262d;vertical-align:top}
        tr:hover td{background:#1a2332}
        .result-success{color:#7ee787;font-weight:600}
        .result-failed{color:#f85149;font-weight:600}
        .session-id{font-family:'Consolas',monospace;font-size:0.7rem;color:#8b949e}
        .action-text{color:#e6e6e6}
        .file-path{font-family:'Consolas',monospace;font-size:0.68rem;color:#8b949e;max-width:250px;word-break:break-all}
        .footer{text-align:center;padding:20px;color:#8b949e;font-size:0.75rem;border-top:1px solid #30363d;margin-top:20px}
        .btn{display:inline-block;padding:10px 20px;background:#1a73e8;color:white;border:none;border-radius:8px;cursor:pointer;text-decoration:none;font-size:0.85rem;margin-right:10px;margin-bottom:16px}
        .btn:hover{opacity:0.85}
        @media print{body{background:white;color:black}.header{background:#1a73e8!important;-webkit-print-color-adjust:exact}.btn{display:none}}
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>📋 Activity Log Report</h1>
        <div style="opacity:0.9;margin-bottom:10px;">Complete Forensic Activity History</div>
        <div>
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
            <span class="badge">🔒 Read-Only</span>
        </div>
    </div>

    <div style="margin-bottom:16px;">
        <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn" onclick="exportToCSV()">📥 Export CSV</button>
    </div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total_entries}</div><div class="stat-label">Total Actions</div></div>
        <div class="stat-card"><div class="stat-number">$(grep -c "SUCCESS" "$logfile" 2>/dev/null || echo "0")</div><div class="stat-label">Successful</div></div>
        <div class="stat-card"><div class="stat-number">$(grep -c "FAILED" "$logfile" 2>/dev/null || echo "0")</div><div class="stat-label">Failed</div></div>
        <div class="stat-card"><div class="stat-number">${SESSION_ID}</div><div class="stat-label">Current Session</div></div>
    </div>

    <div class="section">
        <h2>📋 Complete Activity Log</h2>
        <div class="table-container">
            <table id="activityTable">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Timestamp</th>
                        <th>Session ID</th>
                        <th>Action</th>
                        <th>Analyst</th>
                        <th>Source File</th>
                        <th>Result</th>
                    </tr>
                </thead>
                <tbody>
HTMLEOF

    # Populate table rows
    local row_num=0
    while IFS= read -r line; do
        # Skip empty lines and headers
        [[ -z "$line" ]] && continue
        [[ "$line" == *"============"* ]] && continue
        
        # Parse the log line
        if [[ "$line" =~ \[([0-9-]+)\ ([0-9:]+)\].*SESSION:([A-Za-z0-9-]+).*ACTION:\ ([^|]+).*ANALYST:\ ([^|]+).*FILE:\ ([^|]+).*RESULT:\ ([A-Za-z]+) ]]; then
            local date="${BASH_REMATCH[1]}"
            local time="${BASH_REMATCH[2]}"
            local session="${BASH_REMATCH[3]}"
            local action="${BASH_REMATCH[4]}"
            local analyst="${BASH_REMATCH[5]}"
            local file="${BASH_REMATCH[6]}"
            local result="${BASH_REMATCH[7]}"
            
            ((row_num++))
            
            # Determine result class
            local result_class=""
            local result_icon=""
            if [[ "$result" == "SUCCESS" ]]; then
                result_class="result-success"
                result_icon="✅"
            elif [[ "$result" == "FAILED" ]]; then
                result_class="result-failed"
                result_icon="❌"
            else
                result_icon="⚠️"
            fi
            
            # Escape HTML entities
            local esc_action="${action//&/&amp;}"
            esc_action="${esc_action//</&lt;}"
            esc_action="${esc_action//>/&gt;}"
            local esc_file="${file//&/&amp;}"
            esc_file="${esc_file//</&lt;}"
            esc_file="${esc_file//>/&gt;}"
            
            cat >> "$htmlfile" <<EOF
                    <tr>
                        <td>${row_num}</td>
                        <td>${date} ${time}</td>
                        <td class="session-id">${session}</td>
                        <td class="action-text">${esc_action}</td>
                        <td>${analyst}</td>
                        <td class="file-path">${esc_file}</td>
                        <td class="${result_class}">${result_icon} ${result}</td>
                    </tr>
EOF
        fi
    done < "$logfile"

    # Close HTML
    cat >> "$htmlfile" <<HTMLEOF
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer">
        <p>🔒 WhatsApp Forensic Toolkit v${TOOLKIT_VERSION} — Court-Admissible Evidence</p>
        <p>All actions performed in READ-ONLY mode | Original evidence not modified | ACPO Compliant</p>
        <p>Report generated: $(date) | Case: ${CURRENT_CASE} | Analyst: ${INVESTIGATOR}</p>
    </div>
</div>

<script>
function exportToCSV() {
    const table = document.getElementById('activityTable');
    const rows = table.querySelectorAll('tr');
    const csv = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        csv.push(Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""').replace(/\\n/g, ' ') + '"').join(','));
    }
    const blob = new Blob(['\\uFEFF' + csv.join('\\n')], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'activity_log_${CURRENT_CASE}.csv';
    link.click();
}
</script>
</body>
</html>
HTMLEOF

    print_ok "HTML report generated: ${htmlfile}"
    log_action "VIEW ACTIVITY LOG" "$htmlfile" "SUCCESS"
    
    # Open in browser
    if command -v xdg-open &>/dev/null; then
        xdg-open "$htmlfile" 2>/dev/null &
        print_info "Opening report in browser..."
    fi
    
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Display structured log (full, paginated)
# ─────────────────────────────────────────────────────────────────────────────
_display_structured_log() {
    local logfile="$1"
    
    banner
    print_menu_header "FULL ACTIVITY LOG — STRUCTURED VIEW"
    print_info "Displaying all ${total_entries:-0} entries (paginated)."
    echo ""
    
    local line_count=0
    local page_size=25
    
    while IFS= read -r line; do
        # Skip empty lines and separator lines
        [[ -z "$line" ]] && continue
        [[ "$line" == *"============"* ]] && continue
        
        # Parse the line into structured format
        if [[ "$line" =~ \[([0-9-]+)\ ([0-9:]+)\].*SESSION:([A-Za-z0-9-]+).*ACTION:\ ([^|]+).*ANALYST:\ ([^|]+).*FILE:\ ([^|]+).*RESULT:\ ([A-Za-z]+) ]]; then
            local date="${BASH_REMATCH[1]}"
            local time="${BASH_REMATCH[2]}"
            local session="${BASH_REMATCH[3]}"
            local action="${BASH_REMATCH[4]}"
            local analyst="${BASH_REMATCH[5]}"
            local file="${BASH_REMATCH[6]}"
            local result="${BASH_REMATCH[7]}"
            
            # Color result
            local result_color="$WHITE"
            [[ "$result" == "SUCCESS" ]] && result_color="$GREEN"
            [[ "$result" == "FAILED" ]] && result_color="$RED"
            [[ "$result" == *"WARN"* ]] && result_color="$YELLOW"
            
            echo -e "${CYAN}[${date} ${time}]${RESET}"
            echo -e "  ${DIM}SESSION :${RESET} ${CYAN}${session}${RESET}"
            echo -e "  ${DIM}ACTION  :${RESET} ${WHITE}${action}${RESET}"
            echo -e "  ${DIM}ANALYST :${RESET} ${GREEN}${analyst}${RESET}"
            echo -e "  ${DIM}SOURCE  :${RESET} ${YELLOW}${file}${RESET}"
            echo -e "  ${DIM}RESULT  :${RESET} ${result_color}${result}${RESET}"
            echo -e "  ${CYAN}────────────────────────────${RESET}"
            
            ((line_count++))
        fi
        
        # Paginate
        if (( line_count >= page_size )); then
            echo -e "\n${YELLOW}  ── Page break — Press Enter for more or '0' to return ──${RESET}"
            read -rp "  > " nav
            [[ "$nav" == "0" ]] && return
            line_count=0
            echo ""
        fi
    done < "$logfile"
    
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Filter by Session ID
# ─────────────────────────────────────────────────────────────────────────────
_filter_log_by_session() {
    local logfile="$1"
    
    banner
    print_menu_header "FILTER BY SESSION ID"
    
    # Show available sessions
    echo -e "${CYAN}  Available Sessions:${RESET}"
    grep -oP 'SESSION:\K[A-Za-z0-9-]+' "$logfile" 2>/dev/null | sort -u | nl -w2 -s'. '
    echo ""
    
    read -rp "  Enter Session ID (or 0 to go back): " session_filter
    [[ -z "$session_filter" || "$session_filter" == "0" ]] && return
    
    echo ""
    local count=0
    grep "SESSION:${session_filter}" "$logfile" 2>/dev/null | while IFS= read -r line; do
        echo "  $line"
        ((count++))
    done
    
    echo ""
    print_info "Found entries matching session: ${session_filter}"
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Filter by Action Type (Q1-Q6)
# ─────────────────────────────────────────────────────────────────────────────
_filter_log_by_action() {
    local logfile="$1"
    
    banner
    print_menu_header "FILTER BY ACTION TYPE"
    
    echo -e "  ${YELLOW}Select Action Type:${RESET}"
    echo -e "    ${GREEN}1${RESET}. Q1 — Activity Profiling"
    echo -e "    ${GREEN}2${RESET}. Q2 — Chat Reconstruction"
    echo -e "    ${GREEN}3${RESET}. Q3 — Contact Mapping"
    echo -e "    ${GREEN}4${RESET}. Q4 — Media Reconstruction"
    echo -e "    ${GREEN}5${RESET}. Q5 — Deleted Messages"
    echo -e "    ${GREEN}6${RESET}. Q6 — URL Extraction"
    echo -e "    ${GREEN}0${RESET}. Back"
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        read -rp "  Select (0-6): " act_choice
        if validate_menu_input "$act_choice" 0 6; then
            act_choice="$VALIDATED_CHOICE"
            valid=1
        fi
    done
    
    [[ "$act_choice" == "0" ]] && return
    
    local filter="Q${act_choice}:"
    
    echo ""
    echo -e "${CYAN}  Results for ${filter}:${RESET}"
    echo ""
    
    grep "$filter" "$logfile" 2>/dev/null | while IFS= read -r line; do
        echo "  $line"
    done
    
    local match_count=$(grep -c "$filter" "$logfile" 2>/dev/null || echo "0")
    echo ""
    print_info "Found ${match_count} entries for ${filter}"
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Filter by Date Range
# ─────────────────────────────────────────────────────────────────────────────
_filter_log_by_date() {
    local logfile="$1"
    
    banner
    print_menu_header "FILTER BY DATE RANGE"
    
    echo -e "${YELLOW}  Enter date range (YYYY-MM-DD format):${RESET}"
    read -rp "  Start date (or 0 to go back): " start_date
    [[ -z "$start_date" || "$start_date" == "0" ]] && return
    
    read -rp "  End date: " end_date
    [[ -z "$end_date" ]] && end_date="$(date '+%Y-%m-%d')"
    
    echo ""
    echo -e "${CYAN}  Results from ${start_date} to ${end_date}:${RESET}"
    echo ""
    
    awk -v start="$start_date" -v end="$end_date" '
        /^\[/ {
            date = substr($0, 2, 10)
            if (date >= start && date <= end) print
        }
    ' "$logfile" | while IFS= read -r line; do
        echo "  $line"
    done
    
    echo ""
    print_info "Filter applied: ${start_date} → ${end_date}"
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Search by Keyword
# ─────────────────────────────────────────────────────────────────────────────
_search_log_keyword() {
    local logfile="$1"
    
    banner
    print_menu_header "SEARCH ACTIVITY LOG"
    
    read -rp "  Enter search term (or 0 to go back): " search_term
    [[ -z "$search_term" || "$search_term" == "0" ]] && return
    
    echo ""
    echo -e "${CYAN}  Search results for: \"${search_term}\"${RESET}"
    echo ""
    
    local match_count=0
    grep -i "$search_term" "$logfile" 2>/dev/null | while IFS= read -r line; do
        # Highlight the match
        echo -e "  ${line//$search_term/$YELLOW$search_term$RESET}"
        ((match_count++))
    done
    
    local total=$(grep -ic "$search_term" "$logfile" 2>/dev/null || echo "0")
    echo ""
    print_info "Found ${total} matching entries."
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Export Log as TXT
# ─────────────────────────────────────────────────────────────────────────────
_export_log_txt() {
    local logfile="$1"
    local export_file="${CASE_DIR}/evidence/activity_log_export_$(date '+%Y%m%d_%H%M%S').txt"
    
    {
        echo "============================================================"
        echo "  ACTIVITY LOG EXPORT"
        echo "  Case: ${CURRENT_CASE}"
        echo "  Session: ${SESSION_ID}"
        echo "  Exported: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Analyst: ${INVESTIGATOR}"
        echo "============================================================"
        echo ""
        cat "$logfile"
    } > "$export_file"
    
    local export_hash=$(sha256sum "$export_file" | awk '{print $1}')
    echo "SHA-256: ${export_hash}" >> "$export_file"
    
    print_ok "Log exported to: ${export_file}"
    print_info "SHA-256: ${export_hash}"
    log_action "EXPORT ACTIVITY LOG" "$export_file" "SUCCESS"
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Export Log as CSV
# ─────────────────────────────────────────────────────────────────────────────
_export_log_csv() {
    local logfile="$1"
    local export_file="${CASE_DIR}/evidence/activity_log_export_$(date '+%Y%m%d_%H%M%S').csv"
    
    {
        echo "Timestamp,Session ID,Analyst,Action,Source File,Result"
        while IFS= read -r line; do
            if [[ "$line" =~ \[([0-9-]+)\ ([0-9:]+)\].*SESSION:([A-Za-z0-9-]+).*ACTION:\ ([^|]+).*ANALYST:\ ([^|]+).*FILE:\ ([^|]+).*RESULT:\ ([A-Za-z]+) ]]; then
                echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]},${BASH_REMATCH[3]},\"${BASH_REMATCH[5]}\",\"${BASH_REMATCH[4]}\",\"${BASH_REMATCH[6]}\",${BASH_REMATCH[7]}"
            fi
        done < "$logfile"
    } > "$export_file"
    
    print_ok "CSV exported to: ${export_file}"
    log_action "EXPORT ACTIVITY LOG CSV" "$export_file" "SUCCESS"
    pause
}
view_global_audit_log() {
    banner
    print_section "GLOBAL AUDIT LOG"
    
    local logfile="${CASES_ROOT}/global_audit.log"
    
    if [[ ! -f "$logfile" ]]; then
        print_warn "Global audit log not found."
        pause
        return
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                                          GLOBAL AUDIT LOG SUMMARY                                             ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    # Statistics summary
    local total_entries=$(wc -l < "$logfile")
    local total_cases=$(grep -c "Case Created" "$logfile" 2>/dev/null || echo "0")
    local total_analyses=$(grep -cE "Q[1-8]:" "$logfile" 2>/dev/null || echo "0")
    local total_exports=$(grep -c "EXPORT" "$logfile" 2>/dev/null || echo "0")
    local total_acquires=$(grep -c "ACQUIRE" "$logfile" 2>/dev/null || echo "0")
    
    echo -e "${BOLD}${WHITE}  📊 SUMMARY STATISTICS${RESET}"
    echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    printf "  ${GREEN}%-30s${RESET} ${YELLOW}%10s${RESET}\n" "Total Log Entries:" "$total_entries"
    printf "  ${GREEN}%-30s${RESET} ${YELLOW}%10s${RESET}\n" "Cases Created:" "$total_cases"
    printf "  ${GREEN}%-30s${RESET} ${YELLOW}%10s${RESET}\n" "Evidence Acquisitions:" "$total_acquires"
    printf "  ${GREEN}%-30s${RESET} ${YELLOW}%10s${RESET}\n" "Analyses Run:" "$total_analyses"
    printf "  ${GREEN}%-30s${RESET} ${YELLOW}%10s${RESET}\n" "Exports Performed:" "$total_exports"
    echo ""
    
    echo -e "${BOLD}${WHITE}  📋 RECENT ACTIVITY (Last 30 Entries)${RESET}"
    echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    # Table header
    echo -e "${BOLD}${WHITE}  Date       Time     │ Session ID          │ Analyst        │ Action                          │ Result${RESET}"
    echo -e "${CYAN}  ───────────────────┼─────────────────────┼────────────────┼─────────────────────────────────┼─────────${RESET}"
    
    # Parse and display last 30 entries in readable format
    tail -30 "$logfile" | while IFS= read -r line; do
        # Extract fields using pattern matching
        if [[ "$line" =~ \[([0-9-]+)\ ([0-9:]+)\].*SESSION:([A-Za-z0-9-]+).*ACTION:\ ([^|]+).*ANALYST:\ ([^|]+).*RESULT:\ ([A-Z]+) ]]; then
            local date="${BASH_REMATCH[1]}"
            local time="${BASH_REMATCH[2]}"
            local session="${BASH_REMATCH[3]:0:19}"
            local analyst="${BASH_REMATCH[5]}"
            local action="${BASH_REMATCH[4]}"
            local result="${BASH_REMATCH[6]}"
            
            # Truncate long fields
            [[ ${#session} -gt 19 ]] && session="${session:0:16}..."
            [[ ${#analyst} -gt 14 ]] && analyst="${analyst:0:11}..."
            [[ ${#action} -gt 31 ]] && action="${action:0:28}..."
            
            # Color the result
            local result_color=""
            case "$result" in
                SUCCESS) result_color="${GREEN}SUCCESS${RESET}" ;;
                FAILED)  result_color="${RED}FAILED ${RESET}" ;;
                *)       result_color="${YELLOW}${result}${RESET}" ;;
            esac
            
            # Color the action based on type
            local action_color=""
            if [[ "$action" == *"Case Created"* ]] || [[ "$action" == *"Case Loaded"* ]]; then
                action_color="${CYAN}${action}${RESET}"
            elif [[ "$action" == *"ACQUIRE"* ]]; then
                action_color="${BLUE}${action}${RESET}"
            elif [[ "$action" == *"Q"[1-8]* ]]; then
                action_color="${MAGENTA}${action}${RESET}"
            elif [[ "$action" == *"EXPORT"* ]]; then
                action_color="${YELLOW}${action}${RESET}"
            elif [[ "$action" == *"Case Deleted"* ]]; then
                action_color="${RED}${action}${RESET}"
            else
                action_color="${WHITE}${action}${RESET}"
            fi
            
            printf "  ${WHITE}%-10s${RESET} ${WHITE}%-8s${RESET} │ ${CYAN}%-19s${RESET} │ ${GREEN}%-14s${RESET} │ %-31s │ %s\n" \
                "$date" "$time" "$session" "$analyst" "$action_color" "$result_color"
        fi
    done
    
    echo ""
    echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "${YELLOW}  Options:${RESET}"
    echo "    f - View full log (less)"
    echo "    e - Export log to file"
    echo "    s - Search log"
    echo "    c - Clear screen and continue"
    echo "    q - Return to menu"
    echo ""
    read -rp "  > " option
    
    case "$option" in
        f|F|full)
            less "$logfile"
            view_global_audit_log
            ;;
        e|E|export)
            local export_file="${CASES_ROOT}/audit_log_export_$(date +%Y%m%d_%H%M%S).txt"
            cp "$logfile" "$export_file"
            print_ok "Log exported to: $export_file"
            pause
            ;;
        s|S|search)
            echo ""
            read -rp "  Enter search term: " search_term
            if [[ -n "$search_term" ]]; then
                echo -e "\n${CYAN}  Search results for: \"$search_term\"${RESET}\n"
                grep -i "$search_term" "$logfile" | tail -20 | while IFS= read -r line; do
                    echo "  $line"
                done
                pause
            fi
            view_global_audit_log
            ;;
        c|C|clear)
            return
            ;;
        q|Q|"")
            return
            ;;
        *)
            return
            ;;
    esac
}
