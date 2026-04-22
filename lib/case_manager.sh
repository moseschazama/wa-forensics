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
                        break   # re-loop outer while to show new auto_id
                    elif [[ -z "$CURRENT_CASE" ]]; then
                        print_warn "Case ID cannot be empty."
                    elif [[ ! "$CURRENT_CASE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                        print_warn "Case ID can only contain letters, numbers, hyphens, and underscores."
                    else
                        break 2  # valid custom ID — exit both loops
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
    
    sleep 1
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
    for d in "${CASES_ROOT}"/CASE-*/; do
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

view_activity_log() {
    banner
    print_section "ACTIVITY LOG"
    
    if [[ ! -f "${CASE_DIR}/logs/activity.log" ]]; then
        print_warn "Activity log not found."
        pause
        return
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                               ACTIVITY LOG                                    ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${CYAN}  Showing last 50 entries:${RESET}\n"
    
    tail -50 "${CASE_DIR}/logs/activity.log" | while IFS= read -r line; do
        if [[ "$line" == *"SUCCESS"* ]]; then
            echo -e "  ${GREEN}✓${RESET} $line"
        elif [[ "$line" == *"FAILED"* ]] || [[ "$line" == *"ERROR"* ]]; then
            echo -e "  ${RED}✗${RESET} $line"
        elif [[ "$line" == *"WARN"* ]]; then
            echo -e "  ${YELLOW}⚠${RESET} $line"
        else
            echo "    $line"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}  Options:${RESET}"
    echo "    f - View full log (less)"
    echo "    q - Return"
    echo ""
    read -rp "  > " opt
    
    case "$opt" in
        f|F)
            less "${CASE_DIR}/logs/activity.log"
            ;;
    esac
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
