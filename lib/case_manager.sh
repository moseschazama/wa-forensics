#!/usr/bin/env bash
# =============================================================================
#  CASE MANAGER — Creates and manages forensic cases
#  v2.3 - evidence/ + operations/ folder structure + Phone Serial Number
# =============================================================================

create_case_directories() {
    mkdir -p \
        "${CASE_DIR}/evidence" \
        "${CASE_DIR}/operations/logs" \
        "${CASE_DIR}/operations/reports" \
        "${CASE_DIR}/operations/reports/text" \
        "${CASE_DIR}/operations/reports/html" \
        "${CASE_DIR}/operations/reports/pdf" \
        "${CASE_DIR}/operations/reports/csv" \
        "${CASE_DIR}/operations/html" \
        "${CASE_DIR}/operations/pdf" \
        "${CASE_DIR}/operations/evidence" \
        "${CASE_DIR}/operations/extracted" \
        "${CASE_DIR}/operations/extracted/chats" \
        "${CASE_DIR}/operations/extracted/contacts" \
        "${CASE_DIR}/operations/extracted/media" \
        "${CASE_DIR}/operations/extracted/urls" \
        "${CASE_DIR}/operations/databases" \
        "${CASE_DIR}/operations/temp"
    
    print_ok "Case directory structure created (evidence/ + operations/)."
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
    
    # ── COLLECT ALL DETAILS FIRST ──────────────────────────────────────
    
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
    
    while true; do
        read -rp "  Investigator Phone No.   : " INVESTIGATOR_PHONE
        if [[ -z "$INVESTIGATOR_PHONE" ]]; then
            print_warn "Investigator phone number required."
        elif [[ ! "$INVESTIGATOR_PHONE" =~ ^[+]?[0-9]{7,15}$ ]]; then
            print_warn "Invalid phone number. Use digits only (e.g., +265888123456 or 0888123456)"
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
    
    while true; do
        read -rp "  Suspect Phone Number     : " SUSPECT_PHONE
        if [[ -z "$SUSPECT_PHONE" ]]; then
            print_warn "Suspect phone number required."
        elif [[ ! "$SUSPECT_PHONE" =~ ^[+]?[0-9]{7,15}$ ]]; then
            print_warn "Invalid phone number. Use digits only (e.g., +265999123456 or 0999123456)"
        else
            break
        fi
    done
    
    # Phone Brand
    echo ""
    echo -e "${CYAN}  ── DEVICE INFORMATION ──────────────────────────────────${RESET}"
    echo -e "${YELLOW}  Select phone brand or type custom:${RESET}"
    echo -e "    ${GREEN}1${RESET}. Samsung"
    echo -e "    ${GREEN}2${RESET}. Itel"
    echo -e "    ${GREEN}3${RESET}. Tecno"
    echo -e "    ${GREEN}4${RESET}. Huawei"
    echo -e "    ${GREEN}5${RESET}. Xiaomi"
    echo -e "    ${GREEN}6${RESET}. Apple (iPhone)"
    echo -e "    ${GREEN}7${RESET}. Oppo"
    echo -e "    ${GREEN}8${RESET}. Vivo"
    echo -e "    ${GREEN}9${RESET}. Nokia"
    echo -e "    ${GREEN}10${RESET}. Infinix"
    echo -e "    ${GREEN}11${RESET}. Google Pixel"
    echo -e "    ${GREEN}12${RESET}. Other (type manually)"
    echo ""
    read -rp "  Phone Brand (1-12): " brand_choice
    
    case "$brand_choice" in
        1)  PHONE_BRAND="Samsung" ;;
        2)  PHONE_BRAND="Itel" ;;
        3)  PHONE_BRAND="Tecno" ;;
        4)  PHONE_BRAND="Huawei" ;;
        5)  PHONE_BRAND="Xiaomi" ;;
        6)  PHONE_BRAND="Apple (iPhone)" ;;
        7)  PHONE_BRAND="Oppo" ;;
        8)  PHONE_BRAND="Vivo" ;;
        9)  PHONE_BRAND="Nokia" ;;
        10) PHONE_BRAND="Infinix" ;;
        11) PHONE_BRAND="Google Pixel" ;;
        12|*)
            read -rp "  Enter phone brand manually: " PHONE_BRAND
            [[ -z "$PHONE_BRAND" ]] && PHONE_BRAND="Unknown"
            ;;
    esac
    
    # Phone Model
    read -rp "  Phone Model (e.g., A12, Spark 7): " PHONE_MODEL
    PHONE_MODEL="${PHONE_MODEL:-Unknown}"
    
    # Phone Serial Number (NEW)
    while true; do
        read -rp "  Phone Serial / IMEI No.  : " PHONE_SERIAL
        if [[ -z "$PHONE_SERIAL" ]]; then
            print_warn "Phone Serial/IMEI number required."
        elif [[ ! "$PHONE_SERIAL" =~ ^[a-zA-Z0-9/-]+$ ]]; then
            print_warn "Invalid serial number. Use letters, numbers, hyphens, and forward slashes only."
        else
            break
        fi
    done
    
    # Case description
    read -rp "  Case Description         : " CASE_DESC
    CASE_DESC="${CASE_DESC:-Not specified}"
    
    # Export new variables
    export INVESTIGATOR_PHONE PHONE_BRAND PHONE_MODEL PHONE_SERIAL
    
    # ── REVIEW & CONFIRMATION STEP ─────────────────────────────────────
    while true; do
        banner
        print_section "REVIEW CASE DETAILS"
        
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║            PLEASE REVIEW ALL DETAILS CAREFULLY              ║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        
        echo -e "${BOLD}${WHITE}  ── CASE IDENTIFICATION ─────────────────────────────────${RESET}"
        printf "  ${CYAN}%-25s${RESET} ${GREEN}%s${RESET}\n" "Case ID:" "$CURRENT_CASE"
        echo ""
        
        echo -e "${BOLD}${WHITE}  ── INVESTIGATOR DETAILS ────────────────────────────────${RESET}"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Investigator Name:" "$INVESTIGATOR"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Badge / Employee ID:" "$BADGE_ID"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Investigator Phone:" "$INVESTIGATOR_PHONE"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Organization:" "$ORGANIZATION"
        echo ""
        
        echo -e "${BOLD}${WHITE}  ── LEGAL DETAILS ───────────────────────────────────────${RESET}"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Warrant / Case No:" "$WARRANT_NUM"
        echo ""
        
        echo -e "${BOLD}${WHITE}  ── SUSPECT & DEVICE DETAILS ────────────────────────────${RESET}"
        printf "  ${CYAN}%-25s${RESET} ${YELLOW}%s${RESET}\n" "Suspect Phone No:" "$SUSPECT_PHONE"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Phone Brand:" "$PHONE_BRAND"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Phone Model:" "$PHONE_MODEL"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Serial / IMEI No:" "$PHONE_SERIAL"
        echo ""
        
        echo -e "${BOLD}${WHITE}  ── CASE DESCRIPTION ────────────────────────────────────${RESET}"
        printf "  ${CYAN}%-25s${RESET} ${WHITE}%s${RESET}\n" "Description:" "$CASE_DESC"
        echo ""
        
        echo -e "${CYAN}  ─────────────────────────────────────────────────────────${RESET}"
        echo ""
        echo -e "${YELLOW}  Is all the information above correct?${RESET}"
        echo ""
        echo -e "    ${GREEN}C${RESET} — Confirm & Create Case"
        echo -e "    ${GREEN}E${RESET} — Edit a field"
        echo -e "    ${GREEN}Q${RESET} — Cancel (return to main menu)"
        echo ""
        read -rp "  Select option [C/e/q]: " review_choice
        
        case "$review_choice" in
            C|c|"")
                break
                ;;
            E|e)
                echo ""
                echo -e "${YELLOW}  Which field would you like to edit?${RESET}"
                echo ""
                echo -e "    ${GREEN}1${RESET}. Investigator Name: ${WHITE}${INVESTIGATOR}${RESET}"
                echo -e "    ${GREEN}2${RESET}. Badge / Employee ID: ${WHITE}${BADGE_ID}${RESET}"
                echo -e "    ${GREEN}3${RESET}. Investigator Phone: ${WHITE}${INVESTIGATOR_PHONE}${RESET}"
                echo -e "    ${GREEN}4${RESET}. Organization: ${WHITE}${ORGANIZATION}${RESET}"
                echo -e "    ${GREEN}5${RESET}. Warrant / Case No: ${WHITE}${WARRANT_NUM}${RESET}"
                echo -e "    ${GREEN}6${RESET}. Suspect Phone No: ${WHITE}${SUSPECT_PHONE}${RESET}"
                echo -e "    ${GREEN}7${RESET}. Phone Brand: ${WHITE}${PHONE_BRAND}${RESET}"
                echo -e "    ${GREEN}8${RESET}. Phone Model: ${WHITE}${PHONE_MODEL}${RESET}"
                echo -e "    ${GREEN}9${RESET}. Phone Serial / IMEI: ${WHITE}${PHONE_SERIAL}${RESET}"
                echo -e "    ${GREEN}10${RESET}. Case Description: ${WHITE}${CASE_DESC}${RESET}"
                echo ""
                read -rp "  Edit field (1-10): " edit_field
                
                case "$edit_field" in
                    1) read -rp "  Investigator Name: " INVESTIGATOR ;;
                    2) read -rp "  Badge / Employee ID: " BADGE_ID ;;
                    3) 
                        while true; do
                            read -rp "  Investigator Phone: " INVESTIGATOR_PHONE
                            if [[ ! "$INVESTIGATOR_PHONE" =~ ^[+]?[0-9]{7,15}$ ]]; then
                                print_warn "Invalid phone number. Use digits only."
                            else
                                break
                            fi
                        done
                        ;;
                    4) read -rp "  Organization: " ORGANIZATION ;;
                    5) read -rp "  Warrant / Case No: " WARRANT_NUM ;;
                    6) 
                        while true; do
                            read -rp "  Suspect Phone No: " SUSPECT_PHONE
                            if [[ ! "$SUSPECT_PHONE" =~ ^[+]?[0-9]{7,15}$ ]]; then
                                print_warn "Invalid phone number. Use digits only."
                            else
                                break
                            fi
                        done
                        ;;
                    7) read -rp "  Phone Brand: " PHONE_BRAND ;;
                    8) read -rp "  Phone Model: " PHONE_MODEL ;;
                    9) 
                        while true; do
                            read -rp "  Phone Serial / IMEI No: " PHONE_SERIAL
                            if [[ ! "$PHONE_SERIAL" =~ ^[a-zA-Z0-9/-]+$ ]]; then
                                print_warn "Invalid serial. Use letters, numbers, hyphens, forward slashes only."
                            else
                                break
                            fi
                        done
                        ;;
                    10) read -rp "  Case Description: " CASE_DESC ;;
                    *) print_warn "Invalid field number" ; sleep 1 ;;
                esac
                ;;
            Q|q)
                print_info "Case creation cancelled."
                return 1
                ;;
            *)
                print_warn "Invalid option. Please enter C, E, or Q."
                sleep 1
                ;;
        esac
    done
    
    # ── CREATE THE CASE ────────────────────────────────────────────────
    
    create_case_directories
    
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write case_info.txt to operations/
    cat > "${CASE_DIR}/operations/case_info.txt" <<EOF
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
  Phone Number   : ${INVESTIGATOR_PHONE}
  Organization   : ${ORGANIZATION}
------------------------------------------------------------
CASE DETAILS
  Warrant No.    : ${WARRANT_NUM}
  Description    : ${CASE_DESC}
------------------------------------------------------------
SUSPECT & DEVICE DETAILS
  Suspect Phone  : ${SUSPECT_PHONE}
  Phone Brand    : ${PHONE_BRAND}
  Phone Model    : ${PHONE_MODEL}
  Serial / IMEI  : ${PHONE_SERIAL}
------------------------------------------------------------
LEGAL FRAMEWORK
  Standard       : ACPO Good Practice Guide for Digital Evidence
  Principle 1    : Data not altered/changed
  Principle 2    : Competent handling with documented justification
  Principle 3    : Audit trail created and preserved
  Principle 4    : Investigating officer accountable for ACPO compliance
============================================================
EOF

    # Initialize Chain of Custody in operations/logs/
    cat > "${CASE_DIR}/operations/logs/chain_of_custody.log" <<EOF
============================================================
  CHAIN OF CUSTODY LOG
  Case   : ${CURRENT_CASE}
  Opened : ${ts}
  Analyst: ${INVESTIGATOR} (${BADGE_ID})
============================================================

EOF

    # Initialize Activity Log in operations/logs/
    cat > "${CASE_DIR}/operations/logs/activity.log" <<EOF
============================================================
  ACTIVITY LOG — ${CURRENT_CASE}
  Session: ${SESSION_ID}
  Started: ${ts}
============================================================

EOF

    # Initialize Evidence Hash Registry in operations/evidence/
    cat > "${CASE_DIR}/operations/evidence/hash_registry.txt" <<EOF
============================================================
  EVIDENCE HASH REGISTRY
  Case: ${CURRENT_CASE}
============================================================

EOF

    log_action "Case Created" "${CASE_DIR}" "SUCCESS"
    
    echo ""
    print_ok "Case created successfully: ${CURRENT_CASE}"
    print_info "Case directory: ${CASE_DIR}"
    print_info "  evidence/   → READ-ONLY after acquisition"
    print_info "  operations/ → Logs, reports, case info"
    
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
            echo ""
            print_step "STARTING EVIDENCE ACQUISITION PROCESS..."
            echo ""
            
            if declare -f run_acquisition_module > /dev/null 2>&1; then
                if run_acquisition_module; then
                    echo ""
                    print_ok "Acquisition completed!"
                    echo ""
                    
                    print_step "RUNNING INTEGRITY VERIFICATION..."
                    echo ""
                    
                    if declare -f run_integrity_module > /dev/null 2>&1; then
                        if run_integrity_module; then
                            echo ""
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
                                    pause
                                    return 1
                                fi
                            fi
                        else
                            echo ""
                            echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
                            echo -e "${RED}║  ⛔ EVIDENCE INTEGRITY CHECK FAILED                        ║${NC}"
                            echo -e "${RED}║  Analysis has been PERMANENTLY BLOCKED for this case       ║${NC}"
                            echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
                            echo ""
                            
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
                        pause
                        return 1
                    fi
                else
                    print_err "Acquisition failed"
                    log_action "ACQUISITION FAILED" "${CASE_DIR}" "FAILED"
                    pause
                    return 1
                fi
            else
                print_err "Acquisition module not available"
                pause
                return 1
            fi
            ;;
        2)
            print_info "Case created but evidence NOT acquired"
            print_info "Use options from main menu to acquire and verify later"
            log_action "CASE CREATED - PENDING ACQUISITION" "${CASE_DIR}" "SUCCESS"
            sleep 2
            return 0
            ;;
        *)
            print_warn "Invalid choice - returning to menu"
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
INVESTIGATOR_PHONE="${INVESTIGATOR_PHONE}"
ORGANIZATION="${ORGANIZATION}"
CASE_DESC="${CASE_DESC}"
PHONE_BRAND="${PHONE_BRAND}"
PHONE_MODEL="${PHONE_MODEL}"
PHONE_SERIAL="${PHONE_SERIAL}"
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
    
    # ═══════════════════════════════════════════════════════════════
    # STRUCTURE VALIDATION — Must have evidence/ and operations/
    # ═══════════════════════════════════════════════════════════════
    if [[ ! -d "${CASE_DIR}/evidence" ]]; then
        print_err "Case structure INVALID — evidence/ folder missing!"
        print_err "This case cannot be loaded. It must be re-created."
        log_action "CASE LOAD BLOCKED" "${CASE_DIR}" "FAILED — evidence/ folder missing"
        pause
        return 1
    fi
    
    if [[ ! -d "${CASE_DIR}/operations" ]]; then
        print_err "Case structure INVALID — operations/ folder missing!"
        print_err "This case cannot be loaded. It must be re-created."
        log_action "CASE LOAD BLOCKED" "${CASE_DIR}" "FAILED — operations/ folder missing"
        pause
        return 1
    fi
    
    # ═══════════════════════════════════════════════════════════════
    # INTEGRITY GATE 1 — Block loading if case was previously failed
    # ═══════════════════════════════════════════════════════════════
    local failed_flag="${CASE_DIR}/.integrity_failed"
    if [[ -f "$failed_flag" ]]; then
        banner
        print_section "CASE PERMANENTLY BLOCKED"
        
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⛔ ACCESS PERMANENTLY DENIED                              ║${NC}"
        echo -e "${RED}║  This case failed integrity verification                   ║${NC}"
        echo -e "${RED}║  Evidence may be TAMPERED, DELETED, EDITED, or CORRUPTED   ║${NC}"
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
        print_err "Analysis is NOT possible on tampered evidence"
        log_action "CASE LOAD BLOCKED" "${CASE_DIR}" "FAILED — Integrity previously failed"
        pause
        return 1
    fi
    
    # ═══════════════════════════════════════════════════════════════
    # INTEGRITY GATE 2 — MANDATORY verification before loading
    # ═══════════════════════════════════════════════════════════════
    local verified_flag="${CASE_DIR}/.integrity_verified"
    
    if [[ ! -f "$verified_flag" ]]; then
        banner
        print_section "INTEGRITY VERIFICATION REQUIRED"
        
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠️  EVIDENCE INTEGRITY CHECK REQUIRED                      ║${NC}"
        echo -e "${YELLOW}║  This case must pass integrity verification before access   ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Check if hashes.txt exists in operations/
        if [[ -f "${CASE_DIR}/operations/hashes.txt" ]]; then
            echo -e "${CYAN}  Evidence hashes found. Running integrity verification...${NC}"
            echo -e "${CYAN}  This will check evidence/ folder for:${NC}"
            echo -e "    • File tampering/modification"
            echo -e "    • File deletion or addition"
            echo -e "    • Evidence corruption"
            echo ""
            
            if declare -f run_integrity_module > /dev/null 2>&1; then
                if run_integrity_module; then
                    echo ""
                    print_ok "✅ INTEGRITY VERIFIED — Evidence is forensically sound"
                    
                    if declare -f load_databases_from_case > /dev/null 2>&1; then
                        if ! load_databases_from_case; then
                            print_warn "Databases not found in evidence folder"
                            print_info "You may need to re-acquire evidence"
                            pause
                        fi
                    fi
                else
                    echo ""
                    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
                    echo -e "${RED}║  ⛔ INTEGRITY VERIFICATION FAILED                           ║${NC}"
                    echo -e "${RED}║  EVIDENCE HAS BEEN TAMPERED, DELETED, or CORRUPTED          ║${NC}"
                    echo -e "${RED}║  Case will be PERMANENTLY BLOCKED                          ║${NC}"
                    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
                    echo ""
                    
                    cat > "$failed_flag" <<EOF
INTEGRITY FAILURE RECORD
========================
Date: $(date)
Case: ${CURRENT_CASE}
Analyst: ${INVESTIGATOR:-Unknown}
Session: ${SESSION_ID}
Status: PERMANENTLY BLOCKED
Reason: SHA-256 hash mismatch — evidence tampered, deleted, or corrupted
Evidence Path: ${CASE_DIR}/evidence/
Required Action: Delete case and re-acquire evidence from source
EOF
                    
                    log_action "CASE BLOCKED ON LOAD" "${CASE_DIR}" "FAILED — Integrity check failed"
                    pause
                    return 1
                fi
            else
                print_err "Integrity module (run_integrity_module) not available"
                print_err "Cannot verify evidence integrity — ACCESS DENIED"
                pause
                return 1
            fi
        else
            echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║  ⛔ NO EVIDENCE HASHES FOUND                                ║${NC}"
            echo -e "${RED}║  operations/hashes.txt missing — acquisition incomplete     ║${NC}"
            echo -e "${RED}║  Evidence cannot be verified — ACCESS DENIED                ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${YELLOW}  Required Action:${NC}"
            echo "    • Delete this case"
            echo "    • Create a new case"
            echo "    • Complete the full acquisition process"
            echo ""
            pause
            return 1
        fi
    else
        echo ""
        print_ok "✅ Integrity: PREVIOUSLY VERIFIED — Evidence is forensically sound"
        cat "$verified_flag" 2>/dev/null | head -5
        echo ""
    fi
    
    load_case_state
    
    # Reload from case_info if state file missing
    if [[ -z "$INVESTIGATOR" ]] && [[ -f "${CASE_DIR}/operations/case_info.txt" ]]; then
        INVESTIGATOR=$(grep "Name" "${CASE_DIR}/operations/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        BADGE_ID=$(grep "Badge" "${CASE_DIR}/operations/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        WARRANT_NUM=$(grep "Warrant" "${CASE_DIR}/operations/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        SUSPECT_PHONE=$(grep "Suspect Phone" "${CASE_DIR}/operations/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
        ORGANIZATION=$(grep "Organization" "${CASE_DIR}/operations/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
    fi
    
    # Check for databases
    [[ -f "${CASE_DIR}/operations/databases/msgstore.db" ]] && MSGSTORE_DB="${CASE_DIR}/operations/databases/msgstore.db"
    [[ -f "${CASE_DIR}/operations/databases/wa.db" ]] && WA_DB="${CASE_DIR}/operations/databases/wa.db"
    
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
        local inv=$(grep "Name" "${d}/operations/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | tr -d "'\"" | xargs 2>/dev/null || echo "Unknown")
        local created=$(grep "Created" "${d}/operations/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
        
        local status_icon=""
        if [[ -f "${d}/.integrity_failed" ]]; then
            status_icon=" ${RED}[BLOCKED]${NC}"
        elif [[ -f "${d}/.integrity_verified" ]]; then
            status_icon=" ${GREEN}[VERIFIED]${NC}"
        elif [[ -f "${d}/operations/hashes.txt" ]]; then
            status_icon=" ${YELLOW}[UNVERIFIED]${NC}"
        else
            status_icon=" ${CYAN}[NO EVIDENCE]${NC}"
        fi
        
        echo -e "  ${GREEN}${i}.${RESET} ${YELLOW}${case_id}${RESET} — ${inv:-Unknown} (${created:-Unknown})${status_icon}"
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
            
            if [[ -f "${CASES_ROOT}/${chosen}/.integrity_failed" ]]; then
                echo ""
                echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║  ⛔ THIS CASE IS PERMANENTLY BLOCKED                       ║${NC}"
                echo -e "${RED}║  Case: ${chosen}${NC}"
                echo -e "${RED}║  Reason: Failed integrity verification                     ║${NC}"
                echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                cat "${CASES_ROOT}/${chosen}/.integrity_failed" 2>/dev/null
                echo ""
                echo -e "${YELLOW}  What would you like to do?${NC}"
                echo ""
                echo -e "    ${RED}1${RESET}. Delete this blocked case permanently"
                echo -e "    ${GREEN}2${RESET}. Choose a different case"
                echo -e "    ${GREEN}0${RESET}. Return to main menu"
                echo ""
                read -rp "  Select option (0-2): " blocked_choice
                
                case "$blocked_choice" in
                    1)
                        echo ""
                        print_warn "You are about to DELETE: ${chosen}"
                        read -rp "  Type the Case ID to confirm deletion: " confirm_id
                        if [[ "$confirm_id" == "$chosen" ]]; then
                            rm -rf "${CASES_ROOT}/${chosen}"
                            print_ok "Blocked case deleted: ${chosen}"
                            log_action "BLOCKED CASE DELETED" "${chosen}" "SUCCESS"
                            pause
                        else
                            print_err "Case ID does not match. Deletion cancelled."
                            pause
                        fi
                        return 1
                        ;;
                    2)
                        load_case_interactive
                        return $?
                        ;;
                    *)
                        return 1
                        ;;
                esac
                return 1
            fi
            
            if ! load_case_by_id "$chosen"; then
                print_err "Failed to load case: $chosen"
                echo ""
                echo -e "${YELLOW}  Try again? (y/n):${RESET}"
                read -rp "  > " retry
                if [[ "$retry" =~ ^[Yy]$ ]]; then
                    load_case_interactive
                    return $?
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
        local created=$(grep "Created" "${d}/operations/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
        local inv=$(grep "Name" "${d}/operations/case_info.txt" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
        local has_msgstore=""
        local has_wa=""
        [[ -f "${d}/operations/databases/msgstore.db" ]] && has_msgstore="📱"
        [[ -f "${d}/operations/databases/wa.db" ]] && has_wa="📇"
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
    print_menu_header "CHAIN OF CUSTODY — EVIDENCE HANDLING RECORD"
    
    local logfile="${CASE_DIR}/operations/logs/chain_of_custody.log"
    
    if [[ ! -f "$logfile" ]]; then
        print_warn "Chain of custody log not found: ${logfile}"
        pause
        return
    fi
    
    # Count entries
    local total_entries=$(grep -c '^\[' "$logfile" 2>/dev/null || echo "0")
    
    # ── CLI DISPLAY ──────────────────────────────────────────────────
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    CHAIN OF CUSTODY — EVIDENCE HANDLING & INTEGRITY TRACKING RECORD                           ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Evidence Records: ${YELLOW}%s${RESET}  ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$total_entries"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    # ACPO compliance display
    echo -e "${BOLD}${WHITE}  ⚖️  ACPO COMPLIANCE FRAMEWORK${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}  │${RESET} ${GREEN}P1${RESET} No data alteration    │ Evidence accessed via READ-ONLY mode; files set to chmod 444         ${CYAN}│${RESET}"
    echo -e "${CYAN}  │${RESET} ${GREEN}P2${RESET} Competent handling    │ Investigator credentials and warrant verified before access              ${CYAN}│${RESET}"
    echo -e "${CYAN}  │${RESET} ${GREEN}P3${RESET} Audit trail created   │ This Chain of Custody document + Activity Log provide complete audit trail ${CYAN}│${RESET}"
    echo -e "${CYAN}  │${RESET} ${GREEN}P4${RESET} Officer accountable   │ ${INVESTIGATOR} (${BADGE_ID}) is accountable for all actions recorded herein  ${CYAN}│${RESET}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    # Purpose explanation
    echo -e "${BOLD}${WHITE}  📋 PURPOSE:${RESET} This record tracks ${GREEN}WHO${RESET} handled the evidence and ${GREEN}HOW${RESET} it was preserved."
    echo -e "  ${CYAN}├─${RESET} Tracks: Evidence collection, transfer, storage, verification, and access"
    echo -e "  ${CYAN}├─${RESET} Audience: ${YELLOW}Court, lawyers, judge${RESET} (for legal admissibility)"
    echo -e "  ${CYAN}├─${RESET} Key Question: ${WHITE}\"Can this evidence be trusted as authentic?\"${RESET}"
    echo -e "  ${CYAN}└─${RESET} ${DIM}See also: Activity Log (Option 13) for technical operations record${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  🔗 EVIDENCE HANDLING CHRONOLOGY${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-6s %-20s %-70s${RESET}\n" \
        "#" "Timestamp" "Evidence Handling Record"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    local line_count=0
    local page_size=12
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == *"============"* ]] && continue
        
        if [[ "$line" =~ ^\[([0-9-]+)\ ([0-9:]+)\]\ (.*) ]]; then
            local date="${BASH_REMATCH[1]}"
            local time="${BASH_REMATCH[2]}"
            local entry="${BASH_REMATCH[3]}"
            
            ((line_count++))
            
            local entry_color="$WHITE"
            local icon="📋"
            
            if [[ "$entry" == *"EVIDENCE COLLECTION INITIATED"* ]]; then
                entry_color="$CYAN"; icon="📱"
            elif [[ "$entry" == *"EVIDENCE ACQUISITION"* ]]; then
                entry_color="$BLUE"; icon="📥"
            elif [[ "$entry" == *"VERIFICATION PASSED"* ]]; then
                entry_color="$GREEN"; icon="✅"
            elif [[ "$entry" == *"VERIFICATION FAILED"* ]]; then
                entry_color="$RED"; icon="❌"
            elif [[ "$entry" == *"EVIDENCE TRANSFER"* ]]; then
                entry_color="$YELLOW"; icon="📂"
            elif [[ "$entry" == *"FORENSIC ANALYSIS"* ]]; then
                entry_color="$MAGENTA"; icon="🔍"
            elif [[ "$entry" == *"FORENSIC REPORT"* ]]; then
                entry_color="$GREEN"; icon="📊"
            elif [[ "$entry" == *"CASE RE-OPENED"* ]]; then
                entry_color="$CYAN"; icon="🔓"
            elif [[ "$entry" == *"WARNING"* ]]; then
                entry_color="$YELLOW"; icon="⚠️"
            elif [[ "$entry" == *"ACCESS DENIED"* || "$entry" == *"PERMANENTLY SEALED"* ]]; then
                entry_color="$RED"; icon="⛔"
            fi
            
            local display_entry="$entry"
            [[ ${#display_entry} -gt 69 ]] && display_entry="${display_entry:0:66}..."
            
            printf "  ${WHITE}%-5s${RESET}  ${CYAN}%-10s${RESET} ${WHITE}%-8s${RESET}  ${entry_color}%s %s${RESET}\n" \
                "$line_count" "$date" "$time" "$icon" "$display_entry"
            
            if (( line_count >= page_size )); then
                echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                echo -e "  ${YELLOW}📄 Press Enter for more or '0' to return${RESET}"
                read -rp "  > " nav
                [[ "$nav" == "0" ]] && return
                line_count=0
                echo ""
                printf "  ${BOLD}%-6s %-20s %-70s${RESET}\n" \
                    "#" "Timestamp" "Evidence Handling Record"
                echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
            fi
        fi
    done < "$logfile"
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    # ── GENERATE HTML REPORT ────────────────────────────────────────
    print_step "Generating HTML chain of custody report..."
    
    local htmlfile="${CASE_DIR}/operations/html/chain_of_custody.html"
    mkdir -p "${CASE_DIR}/operations/html"
    build_custody_html_report "$htmlfile" "$total_entries"
    
    log_action "VIEW CHAIN OF CUSTODY" "$htmlfile" "SUCCESS"
    
    echo -e "  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$htmlfile${RESET}"
    
    if command -v xdg-open &>/dev/null; then
        xdg-open "$htmlfile" 2>/dev/null &
        print_info "Opening report in browser..."
    fi
    
    # Post-view menu
    echo -e "\n${CYAN}  ═════════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}  📌 Options:${RESET}"
    echo -e "    ${GREEN}1${RESET}. Return to Analysis Menu"
    echo -e "    ${GREEN}2${RESET}. View HTML Report in browser"
    echo -e "    ${GREEN}3${RESET}. Export as TXT file"
    echo -e "    ${GREEN}0${RESET}. Main Menu"
    echo ""
    read -rp "  Select option (0-3): " choice
    
    case "$choice" in
        1) return 0 ;;
        2) command -v xdg-open &>/dev/null && xdg-open "$htmlfile" 2>/dev/null & pause ;;
        3)
            local exportfile="${CASE_DIR}/operations/evidence/chain_of_custody_export.txt"
            {
                echo "═══════════════════════════════════════════════════════════════"
                echo "  CHAIN OF CUSTODY — EVIDENCE HANDLING RECORD"
                echo "═══════════════════════════════════════════════════════════════"
                echo "  Case: ${CURRENT_CASE}"
                echo "  Analyst: ${INVESTIGATOR} (${BADGE_ID})"
                echo "  Organization: ${ORGANIZATION}"
                echo "  Warrant: ${WARRANT_NUM}"
                echo "  Exported: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "EVIDENCE HANDLING CHRONOLOGY:"
                echo "───────────────────────────────────────────────────────────────"
                cat "$logfile"
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "  ACPO COMPLIANCE STATEMENT"
                echo "═══════════════════════════════════════════════════════════════"
                echo "  P1: All evidence accessed in READ-ONLY mode"
                echo "  P2: Analysis performed by qualified investigator"
                echo "  P3: Complete audit trail maintained (this document)"
                echo "  P4: ${INVESTIGATOR} (${BADGE_ID}) accountable for all actions"
                echo "═══════════════════════════════════════════════════════════════"
            } > "$exportfile"
            print_ok "Exported to: $exportfile"
            pause
            ;;
        0) return 0 ;;
        *) return 0 ;;
    esac
}

build_custody_html_report() {
    local htmlfile="$1"
    local total="$2"
    local logfile="${CASE_DIR}/operations/logs/chain_of_custody.log"
    
    # ── Gather case details from the ACTUAL global variables ──────────
    
    # Get case creation date from case_info.txt (fallback if variable empty)
    local case_created=""
    if [[ -f "${CASE_DIR}/operations/case_info.txt" ]]; then
        case_created=$(grep "Created" "${CASE_DIR}/operations/case_info.txt" | head -1 | awk -F': ' '{print $2}' | xargs)
    fi
    [[ -z "$case_created" ]] && case_created="Not recorded"
    
    # Evidence verification status
    local evidence_status="⚠️ VERIFICATION PENDING"
    local integrity_date=""
    
    if [[ -f "${CASE_DIR}/.integrity_failed" ]]; then
        evidence_status="⛔ EVIDENCE COMPROMISED — Analysis Blocked"
    elif [[ -f "${CASE_DIR}/.integrity_verified" ]]; then
        evidence_status="✅ EVIDENCE VERIFIED — Forensically Sound"
        integrity_date=$(grep "Verified:" "${CASE_DIR}/.integrity_verified" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs)
    fi
    [[ -z "$integrity_date" ]] && integrity_date="Not yet verified"
    
    # Get hash values from hashes.txt
    local app_hash=""
    local media_hash=""
    if [[ -f "${CASE_DIR}/operations/hashes.txt" ]]; then
        app_hash=$(grep "Hash value for com.whatsapp (WhatsApp app data):" "${CASE_DIR}/operations/hashes.txt" 2>/dev/null | cut -d':' -f2 | xargs)
        media_hash=$(grep "Hash value for com.whatsapp (WhatsApp media folder):" "${CASE_DIR}/operations/hashes.txt" 2>/dev/null | cut -d':' -f2 | xargs)
    fi
    [[ -z "$app_hash" ]] && app_hash="Not available"
    [[ -z "$media_hash" ]] && media_hash="Not available"
    
    # Database file details
    local msgstore_size="Not found"
    local wa_size="Not found"
    local msgstore_hash="Not available"
    local wa_hash="Not available"
    
    if [[ -f "${CASE_DIR}/operations/databases/msgstore.db" ]]; then
        local raw_size=$(stat -c%s "${CASE_DIR}/operations/databases/msgstore.db" 2>/dev/null || stat -f%z "${CASE_DIR}/operations/databases/msgstore.db" 2>/dev/null || echo "0")
        msgstore_size=$(numfmt --to=iec-i --suffix=B "$raw_size" 2>/dev/null || echo "${raw_size} bytes")
        if command -v sha256sum &>/dev/null; then
            msgstore_hash=$(sha256sum "${CASE_DIR}/operations/databases/msgstore.db" | awk '{print $1}')
        fi
    fi
    
    if [[ -f "${CASE_DIR}/operations/databases/wa.db" ]]; then
        local raw_size2=$(stat -c%s "${CASE_DIR}/operations/databases/wa.db" 2>/dev/null || stat -f%z "${CASE_DIR}/operations/databases/wa.db" 2>/dev/null || echo "0")
        wa_size=$(numfmt --to=iec-i --suffix=B "$raw_size2" 2>/dev/null || echo "${raw_size2} bytes")
        if command -v sha256sum &>/dev/null; then
            wa_hash=$(sha256sum "${CASE_DIR}/operations/databases/wa.db" | awk '{print $1}')
        fi
    fi
    
    # Current timestamps
    local report_ts=$(date '+%Y-%m-%d %H:%M:%S')
    local report_date=$(date '+%Y-%m-%d')
    
    # Sanitize variables for safe HTML embedding (prevent injection)
    local safe_investigator="${INVESTIGATOR//&/&amp;}"; safe_investigator="${safe_investigator//</&lt;}"; safe_investigator="${safe_investigator//>/&gt;}"
    local safe_badge="${BADGE_ID//&/&amp;}"; safe_badge="${safe_badge//</&lt;}"; safe_badge="${safe_badge//>/&gt;}"
    local safe_org="${ORGANIZATION//&/&amp;}"; safe_org="${safe_org//</&lt;}"; safe_org="${safe_org//>/&gt;}"
    local safe_warrant="${WARRANT_NUM//&/&amp;}"; safe_warrant="${safe_warrant//</&lt;}"; safe_warrant="${safe_warrant//>/&gt;}"
    local safe_phone="${SUSPECT_PHONE//&/&amp;}"; safe_phone="${safe_phone//</&lt;}"; safe_phone="${safe_phone//>/&gt;}"
    local safe_inv_phone="${INVESTIGATOR_PHONE//&/&amp;}"; safe_inv_phone="${safe_inv_phone//</&lt;}"; safe_inv_phone="${safe_inv_phone//>/&gt;}"
    local safe_brand="${PHONE_BRAND//&/&amp;}"; safe_brand="${safe_brand//</&lt;}"; safe_brand="${safe_brand//>/&gt;}"
    local safe_model="${PHONE_MODEL//&/&amp;}"; safe_model="${safe_model//</&lt;}"; safe_model="${safe_model//>/&gt;}"
    local safe_desc="${CASE_DESC//&/&amp;}"; safe_desc="${safe_desc//</&lt;}"; safe_desc="${safe_desc//>/&gt;}"
    
    # ── Fallback values for empty fields ──────────────────────────────
    [[ -z "$safe_investigator" ]] && safe_investigator="Not recorded"
    [[ -z "$safe_badge" ]] && safe_badge="Not recorded"
    [[ -z "$safe_org" ]] && safe_org="Not recorded"
    [[ -z "$safe_warrant" ]] && safe_warrant="Not recorded"
    [[ -z "$safe_phone" ]] && safe_phone="Not recorded"
    [[ -z "$safe_inv_phone" ]] && safe_inv_phone="Not recorded"
    [[ -z "$safe_brand" ]] && safe_brand="Not recorded"
    [[ -z "$safe_model" ]] && safe_model="Not recorded"
    [[ -z "$safe_desc" ]] && safe_desc="Not specified"
    
    # ── START BUILDING HTML ───────────────────────────────────────────
    
    # Part 1: Head & Header
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chain of Custody — Evidence Handling Record | WhatsApp Forensic Report</title>
    <style>
        :root {
            --bg-primary: #0d1117; --bg-secondary: #161b22; --bg-tertiary: #21262d;
            --border: #30363d; --text-primary: #c9d1d9; --text-secondary: #8b949e;
            --accent-purple: #6e40c9; --accent-green: #238636; --accent-red: #da3633;
            --accent-yellow: #d2991d; --accent-cyan: #39c5cf; --accent-blue: #1a73e8;
        }
        * { margin:0; padding:0; box-sizing:border-box; }
        body { font-family:'Segoe UI','Consolas',monospace; background:var(--bg-primary); color:var(--text-primary); padding:20px; line-height:1.6; }
        .container { max-width:1400px; margin:0 auto; }
        
        .header { background:linear-gradient(135deg, var(--accent-purple) 0%, #4a148c 100%); border-radius:16px; padding:30px; margin-bottom:24px; color:white; border:2px solid rgba(255,255,255,0.1); }
        .header h1 { font-size:2rem; margin-bottom:8px; }
        .badge { display:inline-block; background:rgba(255,255,255,0.15); padding:4px 12px; border-radius:20px; font-size:0.8rem; margin-right:8px; margin-bottom:4px; border:1px solid rgba(255,255,255,0.2); }
        .badge-highlight { background:rgba(255,255,255,0.25); border:2px solid rgba(255,255,255,0.5); font-weight:bold; }
        
        .action-bar { display:flex; gap:12px; margin-bottom:20px; flex-wrap:wrap; }
        .btn { padding:10px 20px; border-radius:8px; border:none; cursor:pointer; font-weight:500; font-size:0.85rem; transition:all 0.2s; }
        .btn-primary { background:var(--accent-purple); color:white; }
        .btn-secondary { background:var(--accent-blue); color:white; }
        .btn:hover { opacity:0.85; transform:translateY(-1px); }
        
        .info-box { background:linear-gradient(135deg, #1a2332, var(--bg-secondary)); border:2px solid var(--accent-purple); border-radius:12px; padding:20px 24px; margin-bottom:24px; }
        .info-box h2 { color:var(--accent-purple); margin-bottom:12px; font-size:1.1rem; }
        .info-box p { color:var(--text-secondary); font-size:0.85rem; line-height:1.7; }
        .contrast { display:grid; grid-template-columns:1fr 1fr; gap:16px; margin-top:16px; }
        .contrast-card { background:rgba(0,0,0,0.3); border-radius:8px; padding:14px; border:1px solid var(--border); }
        .contrast-card h3 { font-size:0.9rem; margin-bottom:8px; }
        .contrast-card.this { border-color:var(--accent-purple); } .contrast-card.this h3 { color:var(--accent-purple); }
        .contrast-card.other { border-color:var(--accent-cyan); } .contrast-card.other h3 { color:var(--accent-cyan); }
        .contrast-card ul { list-style:none; font-size:0.8rem; color:var(--text-secondary); }
        .contrast-card ul li { padding:3px 0; }
        .contrast-card ul li::before { content:"• "; color:var(--accent-purple); }
        .contrast-card.other ul li::before { color:var(--accent-cyan); }
        
        .case-details-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(320px, 1fr)); gap:16px; margin-bottom:24px; }
        .detail-box { background:var(--bg-secondary); border-radius:12px; padding:20px; border:1px solid var(--border); }
        .detail-box h3 { color:var(--accent-purple); font-size:1rem; margin-bottom:16px; padding-bottom:10px; border-bottom:1px solid var(--border); display:flex; align-items:center; gap:8px; }
        .detail-row { display:flex; justify-content:space-between; padding:7px 0; border-bottom:1px solid rgba(255,255,255,0.04); font-size:0.82rem; }
        .detail-row:last-child { border-bottom:none; }
        .detail-label { color:var(--text-secondary); min-width:140px; }
        .detail-value { color:var(--text-primary); font-weight:500; text-align:right; word-break:break-all; }
        .detail-value.phone { color:#79c0ff; font-family:'Consolas',monospace; }
        .detail-value.hash { color:#d2a8ff; font-family:'Consolas',monospace; font-size:0.68rem; }
        .detail-value.status-ok { color:#7ee787; }
        .detail-value.status-fail { color:#f85149; }
        
        .evidence-table { width:100%; border-collapse:collapse; font-size:0.82rem; margin-top:16px; }
        .evidence-table th { background:var(--bg-tertiary); color:var(--text-secondary); font-weight:500; padding:10px 14px; text-align:left; border-bottom:2px solid var(--border); font-size:0.72rem; text-transform:uppercase; letter-spacing:0.5px; }
        .evidence-table td { padding:10px 14px; border-bottom:1px solid var(--bg-tertiary); }
        .evidence-table tr:hover td { background:rgba(110,64,201,0.05); }
        .evidence-table .hash-cell { font-family:'Consolas',monospace; font-size:0.68rem; color:var(--text-secondary); max-width:300px; word-break:break-all; }
        
        .acpo-grid { display:grid; grid-template-columns:repeat(4, 1fr); gap:10px; margin-bottom:24px; }
        .acpo-card { background:var(--bg-secondary); border-radius:8px; padding:14px; border:1px solid var(--border); text-align:center; }
        .acpo-card .pnum { font-size:1.5rem; font-weight:bold; color:var(--accent-purple); }
        .acpo-card .ptitle { font-size:0.8rem; color:var(--text-primary); margin:6px 0; }
        .acpo-card .pdesc { font-size:0.7rem; color:var(--text-secondary); }
        
        .section { background:var(--bg-secondary); border-radius:16px; padding:24px; margin-bottom:24px; border:1px solid var(--border); }
        .section h2 { color:var(--accent-purple); margin-bottom:20px; border-bottom:1px solid var(--border); padding-bottom:12px; }
        
        .filter-bar { display:flex; gap:10px; margin-bottom:16px; }
        .filter-bar input { flex:1; padding:10px 14px; background:var(--bg-primary); border:1px solid var(--border); border-radius:8px; color:var(--text-primary); }
        .filter-bar button { padding:10px 18px; background:var(--accent-green); border:none; border-radius:8px; color:white; cursor:pointer; }
        .table-container { overflow-x:auto; border-radius:8px; border:1px solid var(--border); max-height:500px; overflow-y:auto; }
        .chrono-table { width:100%; border-collapse:collapse; font-size:0.82rem; }
        .chrono-table th { background:var(--accent-purple); color:white; font-weight:500; padding:12px 14px; text-align:left; position:sticky; top:0; z-index:1; }
        .chrono-table td { padding:10px 14px; border-bottom:1px solid var(--bg-tertiary); vertical-align:middle; }
        .chrono-table tr:hover td { background:rgba(110,64,201,0.05); }
        
        .entry-collection { color:#39c5cf; } .entry-acquisition { color:#79c0ff; } .entry-verification { color:#7ee787; }
        .entry-transfer { color:#d2991d; } .entry-analysis { color:#d2a8ff; } .entry-report { color:#56d364; }
        .entry-warning { color:#d2991d; font-weight:600; } .entry-blocked { color:#f85149; font-weight:600; } .entry-reopened { color:#39c5cf; }
        
        .signature-block { background:linear-gradient(135deg, #1a2332, var(--bg-secondary)); border:2px solid var(--accent-purple); border-radius:12px; padding:30px; margin-bottom:24px; }
        .signature-block h2 { color:var(--accent-purple); margin-bottom:20px; text-align:center; font-size:1.3rem; }
        .sig-content { max-width:700px; margin:0 auto; }
        .sig-content p { margin-bottom:10px; font-size:0.9rem; }
        .sig-content .sig-label { color:var(--text-secondary); font-size:0.75rem; margin-bottom:4px; }
        .sig-content .sig-value { color:var(--text-primary); font-weight:500; font-size:0.95rem; margin-bottom:16px; padding:8px 12px; background:rgba(0,0,0,0.2); border-radius:6px; border:1px solid var(--border); }
        .sig-line { border-bottom:1px solid var(--text-secondary); width:300px; margin:30px 0 5px; }
        .sig-date { border-bottom:1px solid var(--text-secondary); width:200px; margin:30px 0 5px; }
        
        .legal-notice { background:rgba(218,54,51,0.08); border:1px solid rgba(218,54,51,0.3); border-radius:12px; padding:20px; margin-bottom:24px; text-align:center; }
        .legal-notice h3 { color:var(--accent-red); margin-bottom:10px; }
        .legal-notice p { color:var(--text-secondary); font-size:0.82rem; line-height:1.6; }
        
        .footer { text-align:center; padding:20px; color:var(--text-secondary); font-size:0.75rem; border-top:1px solid var(--border); margin-top:20px; }
        .footer .seal { display:inline-block; border:2px solid var(--accent-purple); padding:8px 20px; border-radius:6px; margin:10px 0; font-family:'Consolas',monospace; color:var(--accent-purple); }
        
        @media print { body { background:white; color:black; } .action-bar, .filter-bar { display:none; } .header, .chrono-table th { -webkit-print-color-adjust:exact; } .detail-box, .section, .signature-block { border:1px solid #ccc; } @page { margin:15mm; } }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    # ── Part 2: Header with DIRECT variable substitution ──────────────
    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>🔗 Chain of Custody — Evidence Handling Record</h1>
        <div class="subtitle" style="opacity:0.9;margin-bottom:16px;">WhatsApp Forensic Investigation • Court-Admissible Evidence Package • ACPO Compliant</div>
        <div>
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Officer: ${safe_investigator}</span>
            <span class="badge">🪪 Badge: ${safe_badge}</span>
            <span class="badge">📜 Warrant: ${safe_warrant}</span>
            <span class="badge badge-highlight">📅 Generated: ${report_ts}</span>
        </div>
    </div>

    <div class="action-bar">
        <button class="btn btn-primary" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn btn-secondary" onclick="window.location.reload()">🔄 Refresh Report</button>
    </div>

    <!-- ═══ PURPOSE BOX ═══ -->
    <div class="info-box">
        <h2>🔗 WHAT THIS RECORD TRACKS</h2>
        <p>This is the <strong>Chain of Custody (Evidence Handling Record)</strong>. It records <strong>WHO</strong> handled the evidence and <strong>HOW</strong> it was preserved from collection to presentation. This document is essential for <strong>legal admissibility</strong> — it proves that evidence has not been tampered with and is authentic under Section 16 of the Malawi Electronic Transactions and Cyber Security Act No. 33 of 2016.</p>
        <div class="contrast">
            <div class="contrast-card this">
                <h3>🔗 Chain of Custody (THIS DOCUMENT)</h3>
                <ul>
                    <li>Records: Evidence handling &amp; transfer</li>
                    <li>Audience: Court, lawyers, judge</li>
                    <li>Key Question: "Can evidence be trusted?"</li>
                    <li>Contains: Collection, storage, verification, access logs</li>
                    <li>Nature: Procedural — requires officer accountability</li>
                </ul>
            </div>
            <div class="contrast-card other">
                <h3>📋 Activity Log (SEPARATE DOCUMENT)</h3>
                <ul>
                    <li>Records: Technical operations performed</li>
                    <li>Audience: Forensic analysts &amp; peer reviewers</li>
                    <li>Key Question: "Can findings be reproduced?"</li>
                    <li>Contains: Commands, queries, tools, results</li>
                    <li>Nature: Automatic, system-generated</li>
                </ul>
            </div>
        </div>
    </div>

    <!-- ═══ CASE DETAILS ═══ -->
    <div class="case-details-grid">
        <div class="detail-box">
            <h3>📋 CASE INFORMATION</h3>
            <div class="detail-row"><span class="detail-label">Case ID</span><span class="detail-value">${CURRENT_CASE}</span></div>
            <div class="detail-row"><span class="detail-label">Case Opened</span><span class="detail-value">${case_created}</span></div>
            <div class="detail-row"><span class="detail-label">Warrant Number</span><span class="detail-value">${safe_warrant}</span></div>
            <div class="detail-row"><span class="detail-label">Organization</span><span class="detail-value">${safe_org}</span></div>
            <div class="detail-row"><span class="detail-label">Case Description</span><span class="detail-value">${safe_desc}</span></div>
            <div class="detail-row"><span class="detail-label">Evidence Status</span><span class="detail-value status-ok">${evidence_status}</span></div>
            <div class="detail-row"><span class="detail-label">Verified On</span><span class="detail-value">${integrity_date}</span></div>
        </div>
        
        <div class="detail-box">
            <h3>📱 SUSPECT &amp; DEVICE DETAILS</h3>
            <div class="detail-row"><span class="detail-label">Suspect Phone No.</span><span class="detail-value phone">${safe_phone}</span></div>
            <div class="detail-row"><span class="detail-label">Phone Brand</span><span class="detail-value">${safe_brand}</span></div>
            <div class="detail-row"><span class="detail-label">Phone Model</span><span class="detail-value">${safe_model}</span></div>
            <div class="detail-row"><span class="detail-label">Acquisition Method</span><span class="detail-value">Logical (ADB Pull)</span></div>
            <div class="detail-row"><span class="detail-label">Acquisition Source</span><span class="detail-value">Rooted Android Emulator</span></div>
            <div class="detail-row"><span class="detail-label">Write Protection</span><span class="detail-value status-ok">✅ Applied (chmod 444)</span></div>
        </div>
        
        <div class="detail-box">
            <h3>👤 INVESTIGATOR DETAILS</h3>
            <div class="detail-row"><span class="detail-label">Full Name</span><span class="detail-value">${safe_investigator}</span></div>
            <div class="detail-row"><span class="detail-label">Badge / ID</span><span class="detail-value">${safe_badge}</span></div>
            <div class="detail-row"><span class="detail-label">Phone Number</span><span class="detail-value phone">${safe_inv_phone}</span></div>
            <div class="detail-row"><span class="detail-label">Organization</span><span class="detail-value">${safe_org}</span></div>
            <div class="detail-row"><span class="detail-label">Session ID</span><span class="detail-value" style="font-family:'Consolas',monospace;font-size:0.75rem;">${SESSION_ID}</span></div>
            <div class="detail-row"><span class="detail-label">Report Generated</span><span class="detail-value">${report_ts}</span></div>
        </div>
        
        <div class="detail-box">
            <h3>🔐 EVIDENCE INTEGRITY</h3>
            <table class="evidence-table">
                <thead>
                    <tr><th>Evidence Item</th><th>Size</th><th>SHA-256 Hash</th></tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>msgstore.db</strong><br/><span style="font-size:0.7rem;color:var(--text-secondary);">WhatsApp Chat Database</span></td>
                        <td>${msgstore_size}</td>
                        <td class="hash-cell">${msgstore_hash}</td>
                    </tr>
                    <tr>
                        <td><strong>wa.db</strong><br/><span style="font-size:0.7rem;color:var(--text-secondary);">WhatsApp Contacts Database</span></td>
                        <td>${wa_size}</td>
                        <td class="hash-cell">${wa_hash}</td>
                    </tr>
                    <tr>
                        <td><strong>App Data Folder</strong><br/><span style="font-size:0.7rem;color:var(--text-secondary);">com.whatsapp/ (acquisition hash)</span></td>
                        <td>—</td>
                        <td class="hash-cell">${app_hash}</td>
                    </tr>
                    <tr>
                        <td><strong>Media Folder</strong><br/><span style="font-size:0.7rem;color:var(--text-secondary);">media/com.whatsapp/ (acquisition hash)</span></td>
                        <td>—</td>
                        <td class="hash-cell">${media_hash}</td>
                    </tr>
                </tbody>
            </table>
            <div style="margin-top:12px;font-size:0.72rem;color:var(--text-secondary);text-align:center;">
                🔐 All hashes computed using SHA-256 algorithm | Hash Registry: operations/evidence/hash_registry.txt
            </div>
        </div>
    </div>

    <!-- ═══ ACPO COMPLIANCE ═══ -->
    <div class="acpo-grid">
        <div class="acpo-card">
            <div class="pnum">P1</div>
            <div class="ptitle">No Data Alteration</div>
            <div class="pdesc">READ-ONLY access enforced<br/>Files protected (chmod 444)<br/>sqlite3 -readonly mode</div>
        </div>
        <div class="acpo-card">
            <div class="pnum">P2</div>
            <div class="ptitle">Competent Handling</div>
            <div class="pdesc">Qualified investigator<br/>${safe_investigator}<br/>Credentials verified</div>
        </div>
        <div class="acpo-card">
            <div class="pnum">P3</div>
            <div class="ptitle">Audit Trail</div>
            <div class="pdesc">This document +<br/>Activity Log +<br/>Hash Registry maintained</div>
        </div>
        <div class="acpo-card">
            <div class="pnum">P4</div>
            <div class="ptitle">Accountability</div>
            <div class="pdesc">${safe_investigator}<br/>${safe_badge}<br/>Accountable for all actions</div>
        </div>
    </div>

    <!-- ═══ EVIDENCE HANDLING CHRONOLOGY ═══ -->
    <div class="section">
        <h2>🔗 EVIDENCE HANDLING CHRONOLOGY</h2>
        <div class="filter-bar">
            <input type="text" id="tableFilter" placeholder="🔍 Filter by type (collection, acquisition, verification, transfer, analysis)..." onkeyup="filterTable()">
            <button onclick="filterTable()">🔍 Filter</button>
            <button onclick="clearFilter()" style="background:#30363d;">✕ Clear</button>
        </div>
        <div class="table-container">
            <table class="chrono-table" id="custodyTable">
                <thead>
                    <tr>
                        <th style="width:30px;">#</th>
                        <th style="width:160px;">Timestamp</th>
                        <th>Evidence Handling Record</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # ── Part 3: Populate chronology from chain_of_custody.log ─────────
    local row_num=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == *"============"* ]] && continue
        
        if [[ "$line" =~ ^\[([0-9-]+)\ ([0-9:]+)\]\ (.*) ]]; then
            local date="${BASH_REMATCH[1]}"
            local time="${BASH_REMATCH[2]}"
            local entry="${BASH_REMATCH[3]}"
            
            ((row_num++))
            
            local entry_class="" icon="📋"
            
            if [[ "$entry" == *"EVIDENCE COLLECTION"* ]]; then entry_class="entry-collection"; icon="📱"
            elif [[ "$entry" == *"EVIDENCE ACQUISITION"* ]]; then entry_class="entry-acquisition"; icon="📥"
            elif [[ "$entry" == *"VERIFICATION PASSED"* ]]; then entry_class="entry-verification"; icon="✅"
            elif [[ "$entry" == *"VERIFICATION FAILED"* ]]; then entry_class="entry-blocked"; icon="❌"
            elif [[ "$entry" == *"EVIDENCE TRANSFER"* ]]; then entry_class="entry-transfer"; icon="📂"
            elif [[ "$entry" == *"FORENSIC ANALYSIS"* ]]; then entry_class="entry-analysis"; icon="🔍"
            elif [[ "$entry" == *"FORENSIC REPORT"* ]]; then entry_class="entry-report"; icon="📊"
            elif [[ "$entry" == *"CASE RE-OPENED"* ]]; then entry_class="entry-reopened"; icon="🔓"
            elif [[ "$entry" == *"WARNING"* ]]; then entry_class="entry-warning"; icon="⚠️"
            elif [[ "$entry" == *"ACCESS DENIED"* || "$entry" == *"PERMANENTLY SEALED"* ]]; then entry_class="entry-blocked"; icon="⛔"
            fi
            
            local esc_entry="${entry//&/&amp;}"; esc_entry="${esc_entry//</&lt;}"; esc_entry="${esc_entry//>/&gt;}"
            
            cat >> "$htmlfile" <<ROWEOF
                    <tr><td class="entry-icon">${icon}</td><td style="white-space:nowrap;">${date} ${time}</td><td class="${entry_class}">${esc_entry}</td></tr>
ROWEOF
        fi
    done < "$logfile"

    # ── Part 4: Signature block, legal notice, footer with DIRECT values ──
    cat >> "$htmlfile" <<EOF
                </tbody>
            </table>
        </div>
        <div style="margin-top:12px;color:var(--text-secondary);font-size:0.75rem;">
            📍 This Chain of Custody document is maintained in compliance with ACPO Good Practice Guide for Digital Evidence (v5, 2012) and Section 16 of the Malawi Electronic Transactions and Cyber Security Act No. 33 of 2016. All timestamps are recorded in system local time.
        </div>
    </div>

    <!-- ═══ INVESTIGATOR CERTIFICATION ═══ -->
    <div class="signature-block">
        <h2>✍️ INVESTIGATOR CERTIFICATION</h2>
        <div class="sig-content">
            <p style="color:var(--text-secondary);margin-bottom:20px;text-align:center;">
                I hereby certify that all evidence listed in this Chain of Custody document was handled in accordance with ACPO Guidelines for Digital Evidence and that the integrity of the evidence has been maintained throughout the investigation from collection to presentation.
            </p>
            
            <div class="sig-label">Investigator Full Name:</div>
            <div class="sig-value">${safe_investigator}</div>
            
            <div class="sig-label">Badge / Employee ID:</div>
            <div class="sig-value">${safe_badge}</div>
            
            <div class="sig-label">Organization:</div>
            <div class="sig-value">${safe_org}</div>
            
            <div class="sig-label">Investigator Phone:</div>
            <div class="sig-value">${safe_inv_phone}</div>
            
            <div class="sig-label">Warrant / Case Number:</div>
            <div class="sig-value">${safe_warrant}</div>
            
            <div class="sig-label">Date of Certification:</div>
            <div class="sig-value">${report_date}</div>
            
            <div style="margin-top:30px;display:flex;gap:60px;">
                <div>
                    <div class="sig-line"></div>
                    <p style="color:var(--text-secondary);font-size:0.85rem;">Investigator's Signature</p>
                </div>
                <div>
                    <div class="sig-date"></div>
                    <p style="color:var(--text-secondary);font-size:0.85rem;">Date</p>
                </div>
            </div>
            
            <div style="margin-top:30px;">
                <div class="sig-line"></div>
                <p style="color:var(--text-secondary);font-size:0.85rem;">Witness / Supervisor's Signature (if applicable)</p>
            </div>
        </div>
    </div>

    <!-- ═══ LEGAL NOTICE ═══ -->
    <div class="legal-notice">
        <h3>⚠️ LEGAL NOTICE — COURT ADMISSIBILITY</h3>
        <p>
            This Chain of Custody document, together with the accompanying Activity Log, Evidence Hash Registry, and Forensic Analysis Reports, constitutes the complete evidentiary record for Case <strong>${CURRENT_CASE}</strong>.
        </p>
        <p>
            Any tampering with, modification of, or unauthorized access to the evidence files referenced herein will be detectable through SHA-256 hash verification. The evidence files are stored with read-only permissions (chmod 444) and all analysis was performed in READ-ONLY mode.
        </p>
        <p>
            Per Section 16 of the Electronic Transactions and Cyber Security Act No. 33 of 2016 (Malawi), the integrity and authenticity of this digital evidence is verifiable through the cryptographic hashes recorded in this document.
        </p>
    </div>

    <div class="footer">
        <div class="seal">⚖️ CHAIN OF CUSTODY — EVIDENCE INTEGRITY MAINTAINED</div>
        <p style="margin-top:12px;">
            This Chain of Custody document was generated using <strong>WhatsApp Forensic Toolkit v${TOOLKIT_VERSION}</strong><br>
            All evidence handled in <strong>READ-ONLY</strong> mode | ACPO Compliant | Court-Admissible<br>
            Document generated: ${report_ts} | Case: ${CURRENT_CASE} | Session: ${SESSION_ID}
        </p>
    </div>
</div>

<script>
function filterTable() {
    const filter = document.getElementById('tableFilter').value.toLowerCase();
    document.querySelectorAll('#custodyTable tbody tr').forEach(row => {
        row.style.display = row.innerText.toLowerCase().includes(filter) ? '' : 'none';
    });
}
function clearFilter() {
    document.getElementById('tableFilter').value = '';
    filterTable();
}
</script>
</body>
</html>
EOF

    # ── Generate PDF if wkhtmltopdf is available ────────────────────
    if command -v wkhtmltopdf &>/dev/null; then
        wkhtmltopdf --quiet \
            --page-size A4 \
            --margin-top 10mm \
            --margin-bottom 10mm \
            --margin-left 10mm \
            --margin-right 10mm \
            --title "Chain of Custody - ${CURRENT_CASE}" \
            "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
    fi
}

view_activity_log() {
    banner
    print_menu_header "ACTIVITY LOG — HTML REPORT"
    
    local logfile="${CASE_DIR}/operations/logs/activity.log"
    
    if [[ ! -f "$logfile" ]]; then
        print_warn "Activity log not found: ${logfile}"
        pause
        return
    fi
    
    local total_entries=$(grep -c '^\[' "$logfile" 2>/dev/null || echo "0")
    
    echo -e "  ${BOLD}Log File:${RESET} ${CYAN}${logfile}${RESET}"
    echo -e "  ${BOLD}Total Entries:${RESET} ${YELLOW}${total_entries}${RESET}"
    echo -e "  ${BOLD}Session:${RESET} ${CYAN}${SESSION_ID}${RESET}"
    echo ""
    
    print_step "Generating HTML activity log report..."
    
    local htmlfile="${CASE_DIR}/operations/html/activity_log.html"
    mkdir -p "${CASE_DIR}/operations/html"
    
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
                    <tr><th>#</th><th>Timestamp</th><th>Session ID</th><th>Action</th><th>Analyst</th><th>Source File</th><th>Result</th></tr>
                </thead>
                <tbody>
HTMLEOF

    local row_num=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == *"============"* ]] && continue
        
        if [[ "$line" =~ \[([0-9-]+)\ ([0-9:]+)\].*SESSION:([A-Za-z0-9-]+).*ACTION:\ ([^|]+).*ANALYST:\ ([^|]+).*FILE:\ ([^|]+).*RESULT:\ ([A-Za-z]+) ]]; then
            local date="${BASH_REMATCH[1]}"
            local time="${BASH_REMATCH[2]}"
            local session="${BASH_REMATCH[3]}"
            local action="${BASH_REMATCH[4]}"
            local analyst="${BASH_REMATCH[5]}"
            local file="${BASH_REMATCH[6]}"
            local result="${BASH_REMATCH[7]}"
            
            ((row_num++))
            
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
    
    if command -v xdg-open &>/dev/null; then
        xdg-open "$htmlfile" 2>/dev/null &
        print_info "Opening report in browser..."
    fi
    
    pause
}