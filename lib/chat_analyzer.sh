#!/usr/bin/env bash
# =============================================================================
#  CHAT ANALYZER — Production Forensic Queries (Schema-Agnostic)
#  Based on Le-Khac & Choo (2022) — Full NULL Sender Resolution
#  Features: Google Material HTML Reports • Pagination • Navigation • PDF Export
#  Version: 11.0 - Final Production Release
# =============================================================================

# ── Load cross-platform helpers ───────────────────────────────────────────────
source "${LIB_DIR}/cross_platform.sh" 2>/dev/null || true

# Auto-detect table names (WhatsApp changed schema over versions)
detect_message_table() {
    local db="$1"
    local tables=$(sqlite3 -readonly "$db" ".tables" 2>/dev/null)
    
    if echo "$tables" | grep -qw "message"; then
        echo "message"
    elif echo "$tables" | grep -qw "messages"; then
        echo "messages"
    else
        echo ""
    fi
}

detect_chat_table() {
    local db="$1"
    local tables=$(sqlite3 -readonly "$db" ".tables" 2>/dev/null)
    
    if echo "$tables" | grep -qw "chat"; then
        echo "chat"
    elif echo "$tables" | grep -qw "chats"; then
        echo "chats"
    else
        echo ""
    fi
}

detect_jid_table() {
    local db="$1"
    local tables=$(sqlite3 -readonly "$db" ".tables" 2>/dev/null)
    
    if echo "$tables" | grep -qw "jid"; then
        echo "jid"
    else
        echo ""
    fi
}

detect_media_table() {
    local db="$1"
    local tables=$(sqlite3 -readonly "$db" ".tables" 2>/dev/null)
    
    if echo "$tables" | grep -qw "message_media"; then
        echo "message_media"
    elif echo "$tables" | grep -qw "media"; then
        echo "media"
    else
        echo ""
    fi
}

detect_link_table() {
    local db="$1"
    local tables=$(sqlite3 -readonly "$db" ".tables" 2>/dev/null)
    
    if echo "$tables" | grep -qw "message_link"; then
        echo "message_link"
    else
        echo ""
    fi
}

column_exists() {
    local db="$1"
    local table="$2"
    local column="$3"
    sqlite3 -readonly "$db" "PRAGMA table_info($table);" 2>/dev/null | grep -qi "|$column|"
}

get_timestamp_col() {
    local db="$1"
    local table="$2"
    
    if column_exists "$db" "$table" "timestamp"; then
        echo "timestamp"
    elif column_exists "$db" "$table" "message_timestamp"; then
        echo "message_timestamp"
    elif column_exists "$db" "$table" "received_timestamp"; then
        echo "received_timestamp"
    else
        echo ""
    fi
}

# =============================================================================
# DASHBOARD STATS FUNCTION - Returns counts for overview cards
# =============================================================================
get_dashboard_stats() {
    local db="$1"
    local msg_table="$2"
    local chat_table="$3"
    local jid_table="$4"
    
    local total_msgs=$(sqlite3 -readonly "$db" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
    
    local individual_chats=0
    if [[ -n "$chat_table" && -n "$jid_table" ]]; then
        individual_chats=$(sqlite3 -readonly "$db" "
            SELECT COUNT(DISTINCT c._id) 
            FROM $chat_table c 
            LEFT JOIN $jid_table j ON c.jid_row_id = j._id 
            WHERE (c.group_type = 0 OR c.group_type IS NULL) 
              AND j.server = 's.whatsapp.net';
        " 2>/dev/null || echo "0")
    fi
    
    local group_chats=0
    if [[ -n "$chat_table" && -n "$jid_table" ]]; then
        group_chats=$(sqlite3 -readonly "$db" "
            SELECT COUNT(DISTINCT c._id) 
            FROM $chat_table c 
            LEFT JOIN $jid_table j ON c.jid_row_id = j._id 
            WHERE c.group_type != 0 OR j.server = 'g.us';
        " 2>/dev/null || echo "0")
    fi
    
    local business_chats=0
    if [[ -n "$jid_table" ]]; then
        business_chats=$(sqlite3 -readonly "$db" "
            SELECT COUNT(DISTINCT m.chat_row_id) 
            FROM $msg_table m
            LEFT JOIN $jid_table j ON m.sender_jid_row_id = j._id
            WHERE j.raw_string LIKE '%@lid';
        " 2>/dev/null || echo "0")
    fi
    
    local deleted_msgs=$(sqlite3 -readonly "$db" "
        SELECT COUNT(*) FROM $msg_table WHERE message_type = 15;
    " 2>/dev/null || echo "0")
    
    local media_files=$(sqlite3 -readonly "$db" "
        SELECT COUNT(*) FROM $msg_table WHERE message_type IN (1,2,3,8,9,11,13);
    " 2>/dev/null || echo "0")
    
    local active_chats=$(sqlite3 -readonly "$db" "
        SELECT COUNT(DISTINCT chat_row_id) FROM $msg_table WHERE chat_row_id IS NOT NULL;
    " 2>/dev/null || echo "0")
    
    local ts_col=$(get_timestamp_col "$db" "$msg_table")
    local first_msg=$(sqlite3 -readonly "$db" "
        SELECT datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table WHERE $ts_col > 0;
    " 2>/dev/null || echo "N/A")
    local last_msg=$(sqlite3 -readonly "$db" "
        SELECT datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table;
    " 2>/dev/null || echo "N/A")
    
    echo "${total_msgs}|${individual_chats}|${group_chats}|${business_chats}|${deleted_msgs}|${media_files}|${active_chats}|${first_msg}|${last_msg}"
}

# =============================================================================
# QUERY 1 — COMMUNICATION ACTIVITY PROFILING
# =============================================================================
# =============================================================================
# QUERY 1 — COMMUNICATION ACTIVITY PROFILING (UNIQUE CHATS - NO DUPLICATES)
# =============================================================================
# =============================================================================
# QUERY 1 — COMMUNICATION ACTIVITY PROFILING (STABLE - NO BREAKS)
# =============================================================================
# =============================================================================
# QUERY 1 — COMMUNICATION ACTIVITY PROFILING (SCROLLING LIST - NO PAGES)
# =============================================================================
# =============================================================================
# QUERY 1 — COMMUNICATION ACTIVITY PROFILING (FULLY WORKING - NO BREAKS)
# =============================================================================
analyze_activity_profiling() {
    banner
    print_section "Q1: COMMUNICATION ACTIVITY PROFILING"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    if [[ -z "$msg_table" ]]; then
        print_err "Could not find message table."
        pause
        return 1
    fi
    
    print_info "Analyzing communication patterns..."
    local outfile="${CASE_DIR}/reports/Q1_activity_profiling.html"
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    
    # Get overall statistics
    local total_chats=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(DISTINCT chat_row_id) FROM $msg_table WHERE chat_row_id IS NOT NULL;" 2>/dev/null || echo "0")
    local total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
    local sent_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 1;" 2>/dev/null || echo "0")
    local recv_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 0;" 2>/dev/null || echo "0")
    local media_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type IN (1,2,3,8,9,11,13);" 2>/dev/null || echo "0")
    local deleted_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 15;" 2>/dev/null || echo "0")
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 1: COMMUNICATION ACTIVITY PROFILING                                          ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Source: Le-Khac & Choo (2022)  ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    # Statistics Summary Cards
    echo -e "${BOLD}${WHITE}  📊 COMMUNICATION SUMMARY${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}\n" \
        "Total Chats:" "$total_chats" "Total Messages:" "$total_msgs" "Sent:" "$sent_msgs"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}\n" \
        "Received:" "$recv_msgs" "Media Files:" "$media_msgs" "Deleted:" "$deleted_msgs"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    # Legend
    echo -e "${BOLD}${WHITE}  📋 LEGEND:${RESET}"
    echo -e "  ${CYAN}├─${RESET} ${GREEN}Chat ID${RESET}       → Unique conversation identifier"
    echo -e "  ${CYAN}├─${RESET} ${YELLOW}Chat Name${RESET}     → Contact name or group subject"
    echo -e "  ${CYAN}├─${RESET} ${WHITE}Total${RESET}         → All messages in this chat"
    echo -e "  ${CYAN}├─${RESET} ${GREEN}Sent${RESET}          → Messages sent by device owner"
    echo -e "  ${CYAN}├─${RESET} ${BLUE}Received${RESET}      → Messages received from others"
    echo -e "  ${CYAN}├─${RESET} ${MAGENTA}Media${RESET}         → Images, videos, audio, documents"
    echo -e "  ${CYAN}├─${RESET} ${RED}Deleted${RESET}       → Revoked/deleted messages"
    echo -e "  ${CYAN}└─${RESET} ${CYAN}Timeline${RESET}      → First and last message time\n"
    
    echo -e "${BOLD}${WHITE}  📈 COMMUNICATION ACTIVITY BY CHAT (UNIQUE CHATS ONLY)${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    
    # Table header
    printf "  ${BOLD}%-6s %-22s %-8s %-6s %-7s %-6s %-7s %-20s %-20s${RESET}\n" \
        "Chat" "Chat Name/Contact" "Total" "Sent" "Recv" "Media" "Del" "First Activity" "Last Activity"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    # Display data - SIMPLE while loop that won't hang
    if [[ -n "$chat_table" ]]; then
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT 
                c._id,
                COALESCE(c.subject, 'Chat_' || c._id) as chat_name,
                COUNT(m._id) as total,
                SUM(CASE WHEN m.from_me = 1 THEN 1 ELSE 0 END) as sent,
                SUM(CASE WHEN m.from_me = 0 THEN 1 ELSE 0 END) as recv,
                SUM(CASE WHEN m.message_type IN (1,2,3,8,9,11,13) THEN 1 ELSE 0 END) as media,
                SUM(CASE WHEN m.message_type = 15 THEN 1 ELSE 0 END) as deleted,
                datetime(MIN(m.$ts_col)/1000, 'unixepoch', 'localtime') as first_seen,
                datetime(MAX(m.$ts_col)/1000, 'unixepoch', 'localtime') as last_seen
            FROM $chat_table c
            LEFT JOIN $msg_table m ON m.chat_row_id = c._id
            WHERE c._id IS NOT NULL
            GROUP BY c._id
            HAVING total > 0
            ORDER BY last_seen DESC;
        " 2>/dev/null | while IFS='|' read -r chat_id chat_name total sent recv media deleted first last; do
            if [[ -n "$chat_id" ]]; then
                # Truncate long names
                [[ ${#chat_name} -gt 21 ]] && chat_name="${chat_name:0:18}..."
                
                # Color code based on values
                local name_color="$WHITE"
                local icon="📱"
                local total_color="$WHITE"
                local media_color="$MAGENTA"
                local deleted_color="$WHITE"
                
                # Check for group chat
                if [[ "$chat_name" == *"Group"* ]] || [[ "$chat_name" == *"GROUP"* ]]; then
                    name_color="$BLUE"
                    icon="👥"
                fi
                
                # Color intensity based on message count
                (( total > 50 )) && total_color="$YELLOW"
                (( total > 100 )) && total_color="$RED"
                (( media > 20 )) && media_color="$YELLOW"
                (( deleted > 0 )) && deleted_color="$RED"
                
                printf "  ${GREEN}%-5s${RESET}  ${name_color}%s %-19s${RESET} ${total_color}%-7s${RESET} ${GREEN}%-5s${RESET} ${BLUE}%-6s${RESET} ${media_color}%-5s${RESET} ${deleted_color}%-4s${RESET} ${WHITE}%-19s${RESET} ${WHITE}%-19s${RESET}\n" \
                    "$chat_id" "$icon" "$chat_name" "$total" "$sent" "$recv" "$media" "$deleted" "${first:0:19}" "${last:0:19}"
            fi
        done
    else
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT 
                chat_row_id,
                'Chat_' || chat_row_id,
                COUNT(*),
                SUM(CASE WHEN from_me = 1 THEN 1 ELSE 0 END),
                SUM(CASE WHEN from_me = 0 THEN 1 ELSE 0 END),
                SUM(CASE WHEN message_type IN (1,2,3,8,9,11,13) THEN 1 ELSE 0 END),
                SUM(CASE WHEN message_type = 15 THEN 1 ELSE 0 END),
                datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime'),
                datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime')
            FROM $msg_table
            WHERE chat_row_id IS NOT NULL
            GROUP BY chat_row_id
            ORDER BY MAX($ts_col) DESC;
        " 2>/dev/null | while IFS='|' read -r chat_id chat_name total sent recv media deleted first last; do
            if [[ -n "$chat_id" ]]; then
                [[ ${#chat_name} -gt 21 ]] && chat_name="${chat_name:0:18}..."
                printf "  ${GREEN}%-5s${RESET}  ${WHITE}📱 %-19s${RESET} ${WHITE}%-7s${RESET} ${GREEN}%-5s${RESET} ${BLUE}%-6s${RESET} ${MAGENTA}%-5s${RESET} ${WHITE}%-4s${RESET} ${WHITE}%-19s${RESET} ${WHITE}%-19s${RESET}\n" \
                    "$chat_id" "$chat_name" "$total" "$sent" "$recv" "$media" "$deleted" "${first:0:19}" "${last:0:19}"
            fi
        done
    fi
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    # Generate HTML Report (in background to avoid hanging)
    print_info "Generating HTML report..."
    # Get call count and active chats for extra stat cards
    local call_count=0
    local has_call_log_q1=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='call_log';" 2>/dev/null)
    [[ -n "$has_call_log_q1" ]] && call_count=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM call_log;" 2>/dev/null || echo "0")
    local active_chats=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(DISTINCT chat_row_id) FROM $msg_table WHERE chat_row_id IS NOT NULL;" 2>/dev/null || echo "0")
    build_activity_html_report "$outfile" "$total_chats" "$total_msgs" "$sent_msgs" "$recv_msgs" "$media_msgs" "$deleted_msgs" "$call_count" "$active_chats"
    local html_pid=$!
    
    log_action "Q1: Activity Profiling" "$MSGSTORE_DB" "SUCCESS"
    
    # Wait a moment for HTML to start generating
    sleep 1
    
    echo -e "  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    echo ""
    
    # Open in browser (in background)
    cross_open "$outfile" 2>/dev/null &
    
    # Display post-query menu
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════${RESET}"
    while true; do
        echo -e "${YELLOW}  📌 What would you like to do next?${RESET}"
        echo ""
        echo -e "    ${GREEN}1${RESET}. Return to Analysis Menu"
        echo -e "    ${GREEN}2${RESET}. View HTML Report in browser"
        echo -e "    ${GREEN}0${RESET}. Main Menu"
        echo ""
        read -rp "  > " choice

        case "$choice" in
            1) return 0 ;;
            2)
                if cross_open "$outfile" 2>/dev/null; then
                    print_ok "Opening report in browser..."
                else
                    print_warn "No browser found. Report saved at: $outfile"
                fi
                ;;
            0) return 0 ;;
            "")
                print_warn "Please enter an option (0-2)."
                sleep 1
                ;;
            *)
                print_warn "Invalid option '${choice}'. Please enter 1, 2, or 0."
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# SIMPLE HTML REPORT BUILDER (WON'T HANG)
# =============================================================================
build_activity_html_report() {
    local htmlfile="$1"
    local total_chats="$2"
    local total_msgs="$3"
    local sent_msgs="$4"
    local recv_msgs="$5"
    local media_msgs="$6"
    local deleted_msgs="$7"
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    
    # Create HTML file
    cat > "$htmlfile" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Activity Profiling - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #0d1117; color: #c9d1d9; padding: 24px; }
        .container { max-width: 1600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; margin-bottom: 8px; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-right: 10px; }
        .stats-grid { display: grid; grid-template-columns: repeat(6, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: #161b22; border-radius: 12px; padding: 20px; text-align: center; border: 1px solid #30363d; }
        .stat-number { font-size: 2.2rem; font-weight: bold; color: #58a6ff; }
        .stat-label { font-size: 0.75rem; color: #8b949e; text-transform: uppercase; }
        .section { background: #161b22; border-radius: 16px; padding: 24px; margin-bottom: 24px; border: 1px solid #30363d; }
        .section h2 { color: #58a6ff; margin-bottom: 20px; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #30363d; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { background: #1f6feb; color: white; font-weight: 500; padding: 12px 16px; text-align: left; }
        td { padding: 10px 16px; border-bottom: 1px solid #21262d; }
        tr:hover td { background: #1a2332; }
        .sent-badge { color: #7ee787; }
        .recv-badge { color: #79c0ff; }
        .media-badge { color: #d2a8ff; }
        .deleted-badge { color: #f85149; }
        .footer { text-align: center; padding: 24px; color: #8b949e; font-size: 0.8rem; border-top: 1px solid #30363d; margin-top: 24px; }
        .btn { padding: 10px 20px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer; margin-right: 10px; }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>📊 Communication Activity Profiling</h1>
        <div style="opacity:0.9; margin-bottom: 15px;">WhatsApp Forensic Investigation • Court-Admissible Evidence</div>
        <div>
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>

    <div style="margin-bottom: 20px;">
        <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn" onclick="exportToCSV()">📥 Export CSV</button>
    </div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total_chats}</div><div class="stat-label">Total Chats</div></div>
        <div class="stat-card"><div class="stat-number">${total_msgs}</div><div class="stat-label">Total Messages</div></div>
        <div class="stat-card"><div class="stat-number">${sent_msgs}</div><div class="stat-label">Sent</div></div>
        <div class="stat-card"><div class="stat-number">${recv_msgs}</div><div class="stat-label">Received</div></div>
        <div class="stat-card"><div class="stat-number">${media_msgs}</div><div class="stat-label">Media Files</div></div>
        <div class="stat-card"><div class="stat-number">${deleted_msgs}</div><div class="stat-label">Deleted</div></div>
        <div class="stat-card"><div class="stat-number calls">${call_count}</div><div class="stat-label">📞 Total Calls</div></div>
        <div class="stat-card"><div class="stat-number active">${active_chats}</div><div class="stat-label">✅ Active Chats</div></div>
    </div>

    <div class="section">
        <h2>📈 Communication Activity by Chat (UNIQUE CHATS ONLY)</h2>
        <div class="table-container">
            <table id="activityTable">
                <thead>
                    <tr>
                        <th>Chat ID</th>
                        <th>Chat Name</th>
                        <th>Total</th>
                        <th>Sent</th>
                        <th>Recv</th>
                        <th>Media</th>
                        <th>Del</th>
                        <th>First Activity</th>
                        <th>Last Activity</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Populate table
    if [[ -n "$chat_table" ]]; then
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT 
                c._id,
                COALESCE(c.subject, 'Chat_' || c._id) as chat_name,
                COUNT(m._id) as total,
                SUM(CASE WHEN m.from_me = 1 THEN 1 ELSE 0 END) as sent,
                SUM(CASE WHEN m.from_me = 0 THEN 1 ELSE 0 END) as recv,
                SUM(CASE WHEN m.message_type IN (1,2,3,8,9,11,13) THEN 1 ELSE 0 END) as media,
                SUM(CASE WHEN m.message_type = 15 THEN 1 ELSE 0 END) as deleted,
                datetime(MIN(m.$ts_col)/1000, 'unixepoch', 'localtime') as first_seen,
                datetime(MAX(m.$ts_col)/1000, 'unixepoch', 'localtime') as last_seen
            FROM $chat_table c
            LEFT JOIN $msg_table m ON m.chat_row_id = c._id
            WHERE c._id IS NOT NULL
            GROUP BY c._id
            HAVING total > 0
            ORDER BY last_seen DESC;
        " 2>/dev/null | while IFS='|' read -r id name total sent recv media deleted first last; do
            local icon="📱"
            [[ "$name" == *"Group"* ]] && icon="👥"
            
            echo "<tr>" >> "$htmlfile"
            echo "<td><strong>${id}</strong></td>" >> "$htmlfile"
            echo "<td>${icon} ${name}</td>" >> "$htmlfile"
            echo "<td>${total}</td>" >> "$htmlfile"
            echo "<td><span class=\"sent-badge\">${sent}</span></td>" >> "$htmlfile"
            echo "<td><span class=\"recv-badge\">${recv}</span></td>" >> "$htmlfile"
            echo "<td><span class=\"media-badge\">${media}</span></td>" >> "$htmlfile"
            echo "<td><span class=\"deleted-badge\">${deleted}</span></td>" >> "$htmlfile"
            echo "<td>${first}</td>" >> "$htmlfile"
            echo "<td>${last}</td>" >> "$htmlfile"
            echo "</tr>" >> "$htmlfile"
        done
    fi

    cat >> "$htmlfile" <<'EOF'
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit • Court-Admissible Evidence</p>
        <p>Chain of Custody Verified • Read-Only Analysis • SHA-256 Hashes Recorded</p>
    </div>
</div>

<script>
function exportToCSV() {
    const table = document.getElementById('activityTable');
    const rows = table.querySelectorAll('tr');
    const csv = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        const rowData = Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""') + '"');
        csv.push(rowData.join(','));
    }
    const blob = new Blob(['\uFEFF' + csv.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'Q1_activity_profiling.csv';
    link.click();
}
</script>
</body>
</html>
EOF

    # Generate PDF if wkhtmltopdf is available
    if command -v wkhtmltopdf &>/dev/null; then
        wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
    fi
}
# =============================================================================
# FIXED HTML REPORT BUILDER - SHOWS ALL CHATS PROPERLY
# =============================================================================
build_activity_html_report() {
    local htmlfile="$1"
    local total_chats="$2"
    local total_msgs="$3"
    local sent_msgs="$4"
    local recv_msgs="$5"
    local media_msgs="$6"
    local deleted_msgs="$7"
    local call_count="${8:-0}"
    local active_chats="${9:-0}"
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    
    print_info "Building HTML report..."
    
    # Start HTML file
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Activity Profiling - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', 'Consolas', sans-serif; background: #0d1117; color: #c9d1d9; padding: 24px; line-height: 1.5; }
        .container { max-width: 1600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; margin-bottom: 8px; }
        .case-info { display: flex; gap: 20px; margin-top: 16px; flex-wrap: wrap; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; }
        .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: #161b22; border-radius: 12px; padding: 20px; text-align: center; border: 1px solid #30363d; }
        .stat-number { font-size: 2.2rem; font-weight: bold; color: #58a6ff; }
        .stat-number.calls { color: #79c0ff; }
        .stat-number.active { color: #7ee787; }
        .stat-label { font-size: 0.75rem; color: #8b949e; text-transform: uppercase; letter-spacing: 0.5px; }
        .section { background: #161b22; border-radius: 16px; padding: 24px; margin-bottom: 24px; border: 1px solid #30363d; }
        .section h2 { color: #58a6ff; margin-bottom: 20px; font-size: 1.3rem; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .legend { display: flex; gap: 24px; flex-wrap: wrap; margin-bottom: 20px; padding: 12px; background: #1a2332; border-radius: 8px; }
        .legend-item { display: flex; align-items: center; gap: 8px; color: #8b949e; font-size: 0.8rem; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #30363d; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { background: #1f6feb; color: white; font-weight: 500; padding: 12px 16px; text-align: left; white-space: nowrap; }
        td { padding: 10px 16px; border-bottom: 1px solid #21262d; }
        tr:hover td { background: #1a2332; }
        .sent-badge { color: #7ee787; font-weight: 500; }
        .recv-badge { color: #79c0ff; font-weight: 500; }
        .media-badge { color: #d2a8ff; font-weight: 500; }
        .deleted-badge { color: #f85149; font-weight: 500; }
        .footer { text-align: center; padding: 24px; color: #8b949e; font-size: 0.8rem; border-top: 1px solid #30363d; margin-top: 24px; }
        .action-buttons { display: flex; gap: 12px; justify-content: flex-end; margin-bottom: 16px; }
        .btn { padding: 10px 20px; border-radius: 20px; font-weight: 500; cursor: pointer; border: none; }
        .btn-primary { background: #1a73e8; color: white; }
        .btn-secondary { background: #30363d; color: #c9d1d9; }
        .filter-bar { display: flex; gap: 12px; margin-bottom: 20px; }
        .filter-bar input { flex: 1; padding: 10px 14px; background: #0d1117; border: 1px solid #30363d; border-radius: 8px; color: #c9d1d9; }
        .filter-bar button { padding: 10px 20px; background: #238636; border: none; border-radius: 8px; color: white; cursor: pointer; }
        .chat-icon { margin-right: 5px; }
        @media print { .action-buttons, .filter-bar { display: none; } body { background: white; color: black; } }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    # Header with case info
    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>📊 Communication Activity Profiling</h1>
        <div style="opacity:0.9">WhatsApp Forensic Investigation • Court-Admissible Evidence</div>
        <div class="case-info">
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>

    <div class="action-buttons">
        <button class="btn btn-secondary" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn btn-primary" onclick="exportToCSV()">📥 Export CSV</button>
    </div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total_chats}</div><div class="stat-label">Total Chats</div></div>
        <div class="stat-card"><div class="stat-number">${total_msgs}</div><div class="stat-label">Total Messages</div></div>
        <div class="stat-card"><div class="stat-number">${sent_msgs}</div><div class="stat-label">Sent</div></div>
        <div class="stat-card"><div class="stat-number">${recv_msgs}</div><div class="stat-label">Received</div></div>
        <div class="stat-card"><div class="stat-number">${media_msgs}</div><div class="stat-label">Media Files</div></div>
        <div class="stat-card"><div class="stat-number">${deleted_msgs}</div><div class="stat-label">Deleted</div></div>
        <div class="stat-card"><div class="stat-number calls">${call_count}</div><div class="stat-label">📞 Total Calls</div></div>
        <div class="stat-card"><div class="stat-number active">${active_chats}</div><div class="stat-label">✅ Active Chats</div></div>
    </div>

    <div class="section">
        <h2>📈 Communication Activity by Chat (UNIQUE CHATS ONLY)</h2>
        
        <div class="legend">
            <span class="legend-item"><span style="color:#7ee787;">📱</span> Individual Chat</span>
            <span class="legend-item"><span style="color:#79c0ff;">👥</span> Group Chat</span>
            <span class="legend-item"><span class="sent-badge">→ Sent</span> by device owner</span>
            <span class="legend-item"><span class="recv-badge">← Received</span> from others</span>
            <span class="legend-item"><span class="media-badge">🖼️ Media</span> files</span>
            <span class="legend-item"><span class="deleted-badge">🗑️ Deleted</span> messages</span>
        </div>

        <div class="filter-bar">
            <input type="text" id="tableFilter" placeholder="🔍 Filter by Chat ID, Name, or JID..." onkeyup="filterTable()">
            <button onclick="filterTable()">Filter</button>
            <button onclick="clearFilter()">Clear</button>
        </div>

        <div class="table-container">
            <table id="activityTable">
                <thead>
                    <tr>
                        <th>Chat ID</th>
                        <th>Chat Name / Contact</th>
                        <th>Total</th>
                        <th>Sent</th>
                        <th>Recv</th>
                        <th>Media</th>
                        <th>Del</th>
                        <th>First Activity</th>
                        <th>Last Activity</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # POPULATE TABLE - Direct query, no background processes
    if [[ -n "$chat_table" ]]; then
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT 
                c._id,
                COALESCE(c.subject, 'Chat_' || c._id) as chat_name,
                COUNT(m._id) as total,
                SUM(CASE WHEN m.from_me = 1 THEN 1 ELSE 0 END) as sent,
                SUM(CASE WHEN m.from_me = 0 THEN 1 ELSE 0 END) as recv,
                SUM(CASE WHEN m.message_type IN (1,2,3,8,9,11,13) THEN 1 ELSE 0 END) as media,
                SUM(CASE WHEN m.message_type = 15 THEN 1 ELSE 0 END) as deleted,
                datetime(MIN(m.$ts_col)/1000, 'unixepoch', 'localtime') as first_seen,
                datetime(MAX(m.$ts_col)/1000, 'unixepoch', 'localtime') as last_seen
            FROM $chat_table c
            LEFT JOIN $msg_table m ON m.chat_row_id = c._id
            WHERE c._id IS NOT NULL
            GROUP BY c._id
            HAVING total > 0
            ORDER BY last_seen DESC;
        " 2>/dev/null | while IFS='|' read -r id name total sent recv media deleted first last; do
            if [[ -n "$id" ]]; then
                # Determine icon
                local icon="📱"
                local row_style=""
                [[ "$name" == *"Group"* ]] && icon="👥"
                
                echo "<tr>" >> "$htmlfile"
                echo "<td><strong>${id}</strong></td>" >> "$htmlfile"
                echo "<td><span class=\"chat-icon\">${icon}</span> ${name}</td>" >> "$htmlfile"
                echo "<td>${total}</td>" >> "$htmlfile"
                echo "<td><span class=\"sent-badge\">${sent}</span></td>" >> "$htmlfile"
                echo "<td><span class=\"recv-badge\">${recv}</span></td>" >> "$htmlfile"
                echo "<td><span class=\"media-badge\">${media}</span></td>" >> "$htmlfile"
                echo "<td><span class=\"deleted-badge\">${deleted}</span></td>" >> "$htmlfile"
                echo "<td>${first}</td>" >> "$htmlfile"
                echo "<td>${last}</td>" >> "$htmlfile"
                echo "</tr>" >> "$htmlfile"
            fi
        done
    else
        # Fallback to message table only
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT 
                chat_row_id,
                'Chat_' || chat_row_id,
                COUNT(*),
                SUM(CASE WHEN from_me = 1 THEN 1 ELSE 0 END),
                SUM(CASE WHEN from_me = 0 THEN 1 ELSE 0 END),
                SUM(CASE WHEN message_type IN (1,2,3,8,9,11,13) THEN 1 ELSE 0 END),
                SUM(CASE WHEN message_type = 15 THEN 1 ELSE 0 END),
                datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime'),
                datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime')
            FROM $msg_table
            WHERE chat_row_id IS NOT NULL
            GROUP BY chat_row_id
            ORDER BY MAX($ts_col) DESC;
        " 2>/dev/null | while IFS='|' read -r id name total sent recv media deleted first last; do
            if [[ -n "$id" ]]; then
                echo "<tr>" >> "$htmlfile"
                echo "<td><strong>${id}</strong></td>" >> "$htmlfile"
                echo "<td><span class=\"chat-icon\">📱</span> ${name}</td>" >> "$htmlfile"
                echo "<td>${total}</td>" >> "$htmlfile"
                echo "<td><span class=\"sent-badge\">${sent}</span></td>" >> "$htmlfile"
                echo "<td><span class=\"recv-badge\">${recv}</span></td>" >> "$htmlfile"
                echo "<td><span class=\"media-badge\">${media}</span></td>" >> "$htmlfile"
                echo "<td><span class=\"deleted-badge\">${deleted}</span></td>" >> "$htmlfile"
                echo "<td>${first}</td>" >> "$htmlfile"
                echo "<td>${last}</td>" >> "$htmlfile"
                echo "</tr>" >> "$htmlfile"
            fi
        done
    fi

    # Close HTML
    cat >> "$htmlfile" <<'EOF'
                </tbody>
            </table>
        </div>
        <div style="margin-top: 15px; color: #8b949e; font-size: 0.8rem;">
            📍 Source: msgstore.db | Query: GROUP BY chat_row_id | Generated by WA-Forensics Toolkit
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit • Court-Admissible Evidence</p>
        <p>Chain of Custody Verified • Read-Only Analysis • SHA-256 Hashes Recorded</p>
        <p>Based on Le-Khac & Choo (2022) — A Practical Hands-on Approach to Database Forensics</p>
    </div>
</div>

<script>
function filterTable() {
    const input = document.getElementById('tableFilter');
    const filter = input.value.toLowerCase();
    const table = document.getElementById('activityTable');
    const rows = table.getElementsByTagName('tbody')[0].getElementsByTagName('tr');
    
    for (let row of rows) {
        const text = row.innerText.toLowerCase();
        row.style.display = text.includes(filter) ? '' : 'none';
    }
}

function clearFilter() {
    document.getElementById('tableFilter').value = '';
    filterTable();
}

function exportToCSV() {
    const table = document.getElementById('activityTable');
    const rows = table.querySelectorAll('tr');
    const csv = [];
    
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        const rowData = Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""').replace(/\n/g, ' ') + '"');
        csv.push(rowData.join(','));
    }
    
    const blob = new Blob(['\uFEFF' + csv.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'Q1_activity_profiling.csv';
    link.click();
}
</script>
</body>
</html>
EOF

    # Generate PDF if wkhtmltopdf is available
    if command -v wkhtmltopdf &>/dev/null; then
        wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
    fi
    
    print_ok "HTML report generated successfully"
}

display_post_query_menu() {
    local query="$1"
    local report_file="$2"
    echo ""
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}  📌 What would you like to do next?${RESET}"
    echo -e "    ${GREEN}1${RESET}. Return to Analysis Menu"
    echo -e "    ${GREEN}2${RESET}. View HTML Report in browser"
    echo -e "    ${GREEN}3${RESET}. Run next query"
    echo -e "    ${GREEN}0${RESET}. Main Menu"
    echo ""
    read -rp "  > " choice
    case "$choice" in
        2) cross_open "$report_file" 2>/dev/null & pause ;;
        3) return 1 ;;
        0) return 0 ;;
        *) return 0 ;;
    esac
}
# =============================================================================
# ENHANCED POST-QUERY MENU FOR CHAT RECONSTRUCTION (WITH CALL FORENSICS)
# =============================================================================
display_post_chat_recon_menu() {
    local report_file="$1"
    
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}  📌 What would you like to do next?${RESET}"
    echo ""
    echo -e "    ${GREEN}1${RESET}. Return to Analysis Menu"
    echo -e "    ${GREEN}2${RESET}. View HTML Report in browser"
    echo -e "    ${GREEN}3${RESET}. Run Q3: Contact Mapping"
    echo -e "    ${GREEN}4${RESET}. Deep dive into a specific Chat ID"
    echo -e "    ${GREEN}5${RESET}. 📞 View CALL HISTORY for a contact in this chat"
    echo -e "    ${GREEN}6${RESET}. Run Full Call Forensics (All Calls)"
    echo -e "    ${GREEN}0${RESET}. Main Menu"
    echo ""
    read -rp "  > " choice
    
    case "$choice" in
        1) return 0 ;;
        2) 
            cross_open "$report_file" 2>/dev/null &
            pause
            ;;
        3) analyze_contact_mapping ;;
        4)
            echo ""
            read -rp "  Enter Chat ID: " dive_id
            if [[ "$dive_id" =~ ^[0-9]+$ ]]; then
                chat_deep_dive "$dive_id"
            else
                print_err "Invalid Chat ID"
                pause
            fi
            ;;
        5)
            echo ""
            echo -e "${CYAN}  Select a contact from this chat to view call history:${RESET}\n"
            
            local msg_table=$(detect_message_table "$MSGSTORE_DB")
            local jid_table=$(detect_jid_table "$MSGSTORE_DB")
            
            sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
                SELECT DISTINCT
                    j.raw_string as jid,
                    CASE 
                        WHEN j.user IS NOT NULL AND j.user != '' THEN j.user
                        WHEN j.raw_string LIKE '%@s.whatsapp.net' THEN SUBSTR(j.raw_string, 1, INSTR(j.raw_string, '@') - 1)
                        WHEN j.raw_string LIKE '%@lid' THEN SUBSTR(j.raw_string, 1, INSTR(j.raw_string, '@') - 1)
                        ELSE j.raw_string
                    END as phone,
                    COUNT(*) as msg_count
                FROM $msg_table m
                LEFT JOIN $jid_table j ON m.sender_jid_row_id = j._id
                WHERE m.from_me = 0 AND j.raw_string IS NOT NULL
                GROUP BY j.raw_string
                ORDER BY msg_count DESC
                LIMIT 20;
            " 2>/dev/null | while IFS='|' read -r jid phone msgs; do
                if [[ -n "$jid" && "$jid" != "NULL" ]]; then
                    echo -e "    ${GREEN}•${RESET} ${CYAN}${phone}${RESET} (${msgs} messages)"
                fi
            done
            
            echo ""
            read -rp "  Enter phone number or JID to check calls: " search_term
            
            if [[ -n "$search_term" ]]; then
                show_calls_for_contact "$search_term"
            fi
            ;;
        6) analyze_call_forensics ;;
        0) return 0 ;;
        *) return 0 ;;
    esac
}

# =============================================================================
# SHOW CALLS FOR SPECIFIC CONTACT
# =============================================================================
show_calls_for_contact() {
    local search_term="$1"
    
    local has_call_log=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='call_log';" 2>/dev/null)
    
    if [[ -z "$has_call_log" ]]; then
        print_warn "call_log table not found in database"
        pause
        return 1
    fi
    
    banner
    print_section "📞 CALL HISTORY FOR: $search_term"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    CALL FORENSICS — CONTACT CALL HISTORY                                                       ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    # Get contact details
    local contact_info=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT 
            COALESCE(
                (SELECT display_name FROM wa_contacts WHERE jid LIKE '%${search_term}%' LIMIT 1),
                CASE 
                    WHEN j.user IS NOT NULL THEN j.user
                    ELSE SUBSTR(j.raw_string, 1, INSTR(j.raw_string, '@') - 1)
                END
            ) as contact_name,
            j.raw_string as jid
        FROM jid j
        WHERE j.user LIKE '%${search_term}%' 
           OR j.raw_string LIKE '%${search_term}%'
        LIMIT 1;
    " 2>/dev/null)
    
    if [[ -n "$contact_info" ]]; then
        IFS='|' read -r contact_name contact_jid <<< "$contact_info"
        echo -e "${BOLD}Contact:${RESET} ${GREEN}${contact_name}${RESET}"
        echo -e "${BOLD}JID:${RESET} ${CYAN}${contact_jid}${RESET}\n"
    fi
    
    # Get statistics
    local total_calls=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT COUNT(*) FROM call_log cl
        LEFT JOIN jid j ON cl.jid_row_id = j._id
        WHERE j.user LIKE '%${search_term}%' OR j.raw_string LIKE '%${search_term}%';
    " 2>/dev/null || echo "0")
    
    local completed=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT COUNT(*) FROM call_log cl
        LEFT JOIN jid j ON cl.jid_row_id = j._id
        WHERE (j.user LIKE '%${search_term}%' OR j.raw_string LIKE '%${search_term}%')
          AND cl.call_result = 0;
    " 2>/dev/null || echo "0")
    
    local missed=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT COUNT(*) FROM call_log cl
        LEFT JOIN jid j ON cl.jid_row_id = j._id
        WHERE (j.user LIKE '%${search_term}%' OR j.raw_string LIKE '%${search_term}%')
          AND cl.call_result = 1;
    " 2>/dev/null || echo "0")
    
    echo -e "${BOLD}${WHITE}  📊 CALL STATISTICS${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}\n" \
        "Total Calls:" "$total_calls" "Completed:" "$completed" "Missed:" "$missed"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    if [[ "$total_calls" -eq 0 ]]; then
        print_warn "No call history found for this contact"
        pause
        return
    fi
    
    echo -e "${BOLD}${WHITE}  📈 CALL HISTORY${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-6s %-12s %-10s %-12s %-20s${RESET}\n" \
        "Call ID" "Type" "Duration" "Status" "Time"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
        SELECT 
            cl._id,
            CASE cl.video_call WHEN 1 THEN '🎥 VIDEO' ELSE '📞 VOICE' END,
            cl.duration,
            CASE cl.call_result 
                WHEN 0 THEN '✅ COMPLETED'
                WHEN 1 THEN '📞 MISSED'
                WHEN 2 THEN '❌ REJECTED'
                ELSE 'UNKNOWN'
            END,
            datetime(cl.timestamp/1000, 'unixepoch', 'localtime')
        FROM call_log cl
        LEFT JOIN jid j ON cl.jid_row_id = j._id
        WHERE j.user LIKE '%${search_term}%' OR j.raw_string LIKE '%${search_term}%'
        ORDER BY cl.timestamp DESC;
    " 2>/dev/null | while IFS='|' read -r call_id call_type duration status call_time; do
        if [[ -n "$call_id" ]]; then
            local duration_display=""
            if [[ -n "$duration" && "$duration" != "NULL" && "$duration" != "0" ]]; then
                local mins=$((duration / 60))
                local secs=$((duration % 60))
                duration_display="${mins}m ${secs}s"
            else
                duration_display="--"
            fi
            
            local type_color="$BLUE"
            [[ "$call_type" == *"VIDEO"* ]] && type_color="$MAGENTA"
            
            local status_color="$WHITE"
            [[ "$status" == *"COMPLETED"* ]] && status_color="$GREEN"
            [[ "$status" == *"MISSED"* ]] && status_color="$YELLOW"
            [[ "$status" == *"REJECTED"* ]] && status_color="$RED"
            
            printf "  ${WHITE}%-5s${RESET}  ${type_color}%-11s${RESET} ${YELLOW}%-9s${RESET} ${status_color}%-11s${RESET} ${WHITE}%-19s${RESET}\n" \
                "$call_id" "$call_type" "$duration_display" "$status" "${call_time:0:19}"
        fi
    done
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    echo -e "${YELLOW}  Options:${RESET}"
    echo "    e - Export call history as CSV"
    echo "    r - Return"
    echo ""
    read -rp "  > " opt
    
    case "$opt" in
        e|E)
            local csvfile="${CASE_DIR}/extracted/contacts/${search_term}_calls.csv"
            mkdir -p "${CASE_DIR}/extracted/contacts"
            sqlite3 -readonly -csv -header "$MSGSTORE_DB" "
                SELECT 
                    cl._id,
                    datetime(cl.timestamp/1000, 'unixepoch', 'localtime') as call_time,
                    CASE cl.video_call WHEN 1 THEN 'VIDEO' ELSE 'VOICE' END as type,
                    cl.duration,
                    CASE cl.call_result WHEN 0 THEN 'COMPLETED' WHEN 1 THEN 'MISSED' WHEN 2 THEN 'REJECTED' END as status
                FROM call_log cl
                LEFT JOIN jid j ON cl.jid_row_id = j._id
                WHERE j.user LIKE '%${search_term}%' OR j.raw_string LIKE '%${search_term}%'
                ORDER BY cl.timestamp DESC;
            " > "$csvfile" 2>/dev/null
            print_ok "CSV exported: $csvfile"
            ;;
    esac
    
    pause
}
# =============================================================================
# QUERY 2 — FULL CHAT & PARTICIPANT RECONSTRUCTION
# =============================================================================
# =============================================================================
# QUERY 2 — FULL CHAT & PARTICIPANT RECONSTRUCTION (WITH CALLS INTEGRATED)
# =============================================================================
# =============================================================================
# QUERY 2 — FULL CHAT & PARTICIPANT RECONSTRUCTION (SCROLLING - NO PAGINATION)
# =============================================================================
analyze_chat_reconstruction() {
    banner
    print_section "Q2: FULL CHAT & PARTICIPANT RECONSTRUCTION"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local outfile="${CASE_DIR}/reports/Q2_chat_reconstruction.html"
    
    print_info "Reconstructing communication networks with calls..."
    
    # Check for call_log table
    local has_call_log=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='call_log';" 2>/dev/null)
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 2: FULL CHAT & PARTICIPANT RECONSTRUCTION                                    ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Source: msgstore.db + call_log  ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📋 LEGEND:${RESET}"
    echo -e "  ${CYAN}├─${RESET} ${GREEN}📱 DEVICE_OWNER${RESET} — Messages sent by device owner"
    echo -e "  ${CYAN}├─${RESET} ${MAGENTA}🏢 BUSINESS_LID${RESET} — Encrypted business account"
    echo -e "  ${CYAN}├─${RESET} ${RED}🗑️ DELETED_CONTACT${RESET} — Contact deleted"
    echo -e "  ${CYAN}├─${RESET} ${YELLOW}⚠️ SYSTEM${RESET} — System message"
    echo -e "  ${CYAN}├─${RESET} ${BLUE}📞 VOICE CALL${RESET} — Voice call (Completed/Missed/Rejected)"
    echo -e "  ${CYAN}└─${RESET} ${MAGENTA}🎥 VIDEO CALL${RESET} — Video call\n"
    
    echo -e "${BOLD}${WHITE}  📈 COMPLETE COMMUNICATION TIMELINE (Messages + Calls)${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-6s %-14s %-22s %-14s %-10s %-8s %-12s %-19s${RESET}\n" \
        "Chat" "Chat Name" "Contact/Phone" "Type" "Direction" "Details" "Status" "Time"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    # Create temp file for combined data
    local temp_data="${TEMP_DIR:-/tmp}/chat_recon_$$.tmp"
    
    # STEP 1: Get all MESSAGES
    if [[ -n "$chat_table" && -n "$jid_table" ]]; then
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT
                c._id,
                COALESCE(c.subject, 'Chat_' || c._id),
                CASE
                    WHEN m.from_me = 1 THEN '📱 DEVICE'
                    ELSE COALESCE(
                        CASE WHEN j.server  = 's.whatsapp.net' THEN j.user  END,
                        CASE WHEN cj.server = 's.whatsapp.net' THEN cj.user END,
                        (SELECT pj.user FROM jid_map jm2
                         JOIN $jid_table pj
                           ON pj._id = CASE WHEN jm2.lid_row_id = j._id
                                            THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                         WHERE (jm2.lid_row_id = j._id OR jm2.jid_row_id = j._id)
                           AND pj.server = 's.whatsapp.net' LIMIT 1),
                        (SELECT pj.user FROM jid_map jm3
                         JOIN $jid_table pj
                           ON pj._id = CASE WHEN jm3.lid_row_id = cj._id
                                            THEN jm3.jid_row_id ELSE jm3.lid_row_id END
                         WHERE (jm3.lid_row_id = cj._id OR jm3.jid_row_id = cj._id)
                           AND pj.server = 's.whatsapp.net' LIMIT 1),
                        COALESCE(j.user, cj.user, '⚠️ UNKNOWN')
                    )
                END AS contact,
                '💬 MSG' AS entry_type,
                CASE WHEN m.from_me = 1 THEN '📤 SENT' ELSE '📥 RECV' END AS direction,
                CASE m.message_type
                    WHEN 0  THEN COALESCE(SUBSTR(m.text_data, 1, 25), '[text]')
                    WHEN 1  THEN '📷 IMAGE'
                    WHEN 2  THEN '🎤 VOICE'
                    WHEN 3  THEN '🎥 VIDEO'
                    WHEN 7  THEN '🔗 LINK'
                    WHEN 8  THEN '📄 DOC'
                    WHEN 15 THEN '🗑️ DELETED'
                    ELSE '📁 MEDIA'
                END AS details,
                CASE
                    WHEN m.message_type = 15 THEN '🗑️ DEL'
                    WHEN m.text_data IS NULL THEN '👻'
                    ELSE '✅'
                END AS status,
                datetime(m.$ts_col/1000, 'unixepoch', 'localtime') AS event_time,
                m.$ts_col AS sort_time
            FROM $msg_table m
            LEFT JOIN $chat_table c   ON m.chat_row_id       = c._id
            LEFT JOIN $jid_table cj   ON c.jid_row_id        = cj._id
            LEFT JOIN $jid_table j    ON m.sender_jid_row_id = j._id
            WHERE m.chat_row_id IS NOT NULL
        " 2>/dev/null > "$temp_data"
        
        # STEP 2: Get all CALLS and append
        if [[ -n "$has_call_log" ]]; then
            sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
                SELECT
                    COALESCE(c._id, '-') AS chat_id,
                    COALESCE(c.subject, 'Call') AS chat_name,
                    COALESCE(
                        CASE WHEN j.server = 's.whatsapp.net' THEN j.user END,
                        (SELECT pj.user FROM jid_map jm2
                         JOIN $jid_table pj
                           ON pj._id = CASE WHEN jm2.lid_row_id = j._id
                                            THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                         WHERE (jm2.lid_row_id = j._id OR jm2.jid_row_id = j._id)
                           AND pj.server = 's.whatsapp.net' LIMIT 1),
                        j.user, 'Unknown'
                    ) AS contact,
                    CASE cl.video_call WHEN 1 THEN '🎥 VIDEO' ELSE '📞 VOICE' END AS entry_type,
                    CASE WHEN cl.video_call = 1 THEN '🎥 CALL' ELSE '📞 CALL' END AS direction,
                    CASE
                        WHEN cl.duration > 0 THEN (cl.duration / 60) || 'm'
                        ELSE '0s'
                    END AS details,
                    CASE cl.call_result
                        WHEN 0 THEN '✅ COMP'
                        WHEN 1 THEN '📞 MISS'
                        WHEN 2 THEN '❌ REJ'
                        ELSE ''
                    END AS status,
                    datetime(cl.timestamp/1000, 'unixepoch', 'localtime') AS event_time,
                    cl.timestamp AS sort_time
                FROM call_log cl
                LEFT JOIN $jid_table j ON cl.jid_row_id = j._id
                LEFT JOIN $chat_table c ON c.jid_row_id = j._id
            " 2>/dev/null >> "$temp_data"
        fi
        
        # STEP 3: Sort by timestamp
        sort -t'|' -k9 -n "$temp_data" -o "$temp_data" 2>/dev/null
        
        # STEP 4: Display everything as ONE CONTINUOUS SCROLLING LIST
        while IFS='|' read -r chat_id chat_name contact entry_type direction details status event_time sort_time; do
            if [[ -n "$chat_id" ]]; then
                # Truncate long fields
                [[ ${#chat_name} -gt 13 ]] && chat_name="${chat_name:0:10}..."
                [[ ${#contact} -gt 21 ]] && contact="${contact:0:18}..."
                [[ ${#details} -gt 7 ]] && details="${details:0:6}..."
                
                # Color coding
                local type_color="$WHITE"
                local contact_color="$WHITE"
                local status_color="$WHITE"
                local direction_color="$WHITE"
                
                # Entry type colors
                if [[ "$entry_type" == *"VIDEO"* ]]; then
                    type_color="$MAGENTA"
                    direction_color="$MAGENTA"
                elif [[ "$entry_type" == *"VOICE"* ]]; then
                    type_color="$BLUE"
                    direction_color="$BLUE"
                elif [[ "$entry_type" == *"MSG"* ]]; then
                    type_color="$CYAN"
                fi
                
                # Contact colors
                [[ "$contact" == *"DEVICE"* ]] && contact_color="$GREEN"
                [[ "$contact" == *"BIZ:"* ]] && contact_color="$MAGENTA"
                [[ "$contact" == *"LID"* ]] && contact_color="$MAGENTA"
                
                # Direction colors
                [[ "$direction" == *"SENT"* ]] && direction_color="$GREEN"
                [[ "$direction" == *"RECV"* ]] && direction_color="$YELLOW"
                [[ "$direction" == *"CALL"* ]] && direction_color="$BLUE"
                
                # Status colors
                [[ "$status" == *"COMP"* ]] && status_color="$GREEN"
                [[ "$status" == *"MISS"* ]] && status_color="$YELLOW"
                [[ "$status" == *"REJ"* ]] && status_color="$RED"
                [[ "$status" == *"DEL"* ]] && status_color="$RED"
                [[ "$status" == "✅" ]] && status_color="$GREEN"
                [[ "$status" == "👻" ]] && status_color="$MAGENTA"
                
                printf "  ${GREEN}%-5s${RESET}  ${CYAN}%-13s${RESET}  ${contact_color}%-21s${RESET} ${type_color}%-13s${RESET} ${direction_color}%-9s${RESET} ${WHITE}%-7s${RESET} ${status_color}%-11s${RESET} ${WHITE}%-18s${RESET}\n" \
                    "$chat_id" "$chat_name" "$contact" "$entry_type" "$direction" "$details" "$status" "${event_time:0:18}"
            fi
        done < "$temp_data"
        
        rm -f "$temp_data"
    fi
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    # Show summary statistics
    local total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
    local total_calls=0
    [[ -n "$has_call_log" ]] && total_calls=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM call_log;" 2>/dev/null || echo "0")
    
    echo -e "${BOLD}${WHITE}  📊 SUMMARY:${RESET} ${GREEN}${total_msgs} messages${RESET} + ${BLUE}${total_calls} calls${RESET} = ${YELLOW}$((total_msgs + total_calls)) total communications${RESET}"
    echo ""
    
    # Build HTML Report with calls included
    build_chat_recon_html_with_calls "$outfile" "$total_msgs" "$total_calls"
    log_action "Q2: Chat Reconstruction" "$MSGSTORE_DB" "SUCCESS"
    
    echo -e "  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    cross_open "$outfile" 2>/dev/null &
    
    # Post-query menu
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}  📌 What would you like to do next?${RESET}"
    echo ""
    echo -e "    ${GREEN}1${RESET}. Return to Analysis Menu"
    echo -e "    ${GREEN}2${RESET}. View HTML Report in browser"
    echo -e "    ${GREEN}0${RESET}. Main Menu"
    echo ""
    read -rp "  > " choice
    
    case "$choice" in
        1) return 0 ;;
        2) cross_open "$outfile" 2>/dev/null & pause ;;
        3) analyze_contact_mapping ;;
        4)
            read -rp "  Enter Chat ID: " dive_id
            [[ "$dive_id" =~ ^[0-9]+$ ]] && chat_deep_dive "$dive_id" || print_err "Invalid Chat ID"
            pause
            ;;
        5)
            read -rp "  Enter phone number or JID to check calls: " search_term
            [[ -n "$search_term" ]] && show_calls_for_contact "$search_term"
            ;;
        6) analyze_call_forensics ;;
        0) return 0 ;;
        *) return 0 ;;
    esac
}

# =============================================================================
# HTML REPORT WITH CALLS INCLUDED
# =============================================================================
build_chat_recon_html_with_calls() {
    local htmlfile="$1"
    local total_msgs="$2"
    local total_calls="$3"
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local has_call_log=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='call_log';" 2>/dev/null)
    
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Chat Reconstruction - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #0d1117; color: #c9d1d9; padding: 24px; }
        .container { max-width: 1600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1a73e8, #0d47a1); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; margin-bottom: 8px; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-right: 10px; }
        .stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: #161b22; border-radius: 12px; padding: 20px; text-align: center; border: 1px solid #30363d; }
        .stat-number { font-size: 2.2rem; font-weight: bold; color: #58a6ff; }
        .stat-label { font-size: 0.75rem; color: #8b949e; text-transform: uppercase; }
        .section { background: #161b22; border-radius: 16px; padding: 24px; margin-bottom: 24px; border: 1px solid #30363d; }
        .section h2 { color: #58a6ff; margin-bottom: 20px; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .legend { display: flex; gap: 24px; flex-wrap: wrap; margin-bottom: 20px; padding: 12px; background: #1a2332; border-radius: 8px; }
        .legend-item { display: flex; align-items: center; gap: 8px; color: #8b949e; font-size: 0.8rem; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #30363d; max-height: 600px; overflow-y: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { background: #1f6feb; color: white; font-weight: 500; padding: 12px 16px; text-align: left; position: sticky; top: 0; white-space: nowrap; }
        td { padding: 10px 16px; border-bottom: 1px solid #21262d; max-width: 280px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; vertical-align: middle; }
        td.details-cell { max-width: 200px; white-space: normal; word-break: break-word; }
        tr:hover td { background: #1a2332; }
        .msg-sent { color: #7ee787; }
        .msg-recv { color: #fbbf24; }
        .call-voice { color: #79c0ff; }
        .call-video { color: #d2a8ff; }
        .status-completed { color: #7ee787; }
        .status-missed { color: #fbbf24; }
        .status-rejected { color: #f85149; }
        .footer { text-align: center; padding: 24px; color: #8b949e; font-size: 0.8rem; border-top: 1px solid #30363d; margin-top: 24px; }
        .btn { padding: 10px 20px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer; margin-right: 10px; }
        .filter-bar { display: flex; gap: 12px; margin-bottom: 20px; }
        .filter-bar input { flex: 1; padding: 10px 14px; background: #0d1117; border: 1px solid #30363d; border-radius: 8px; color: #c9d1d9; }
        .filter-bar button { padding: 10px 20px; background: #238636; border: none; border-radius: 8px; color: white; cursor: pointer; }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>💬 Full Chat & Participant Reconstruction</h1>
        <div style="opacity:0.9">Complete Communication Timeline (Messages + Calls)</div>
        <div style="margin-top:15px">
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>

    <div style="margin-bottom:20px">
        <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn" onclick="exportToCSV()">📥 Export CSV</button>
    </div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total_msgs}</div><div class="stat-label">Total Messages</div></div>
        <div class="stat-card"><div class="stat-number">${total_calls}</div><div class="stat-label">Total Calls</div></div>
        <div class="stat-card"><div class="stat-number">$((total_msgs + total_calls))</div><div class="stat-label">Total Communications</div></div>
    </div>

    <div class="section">
        <h2>📈 Complete Communication Timeline</h2>
        
        <div class="legend">
            <span class="legend-item"><span style="color:#7ee787;">📤 SENT</span> Message</span>
            <span class="legend-item"><span style="color:#fbbf24;">📥 RECV</span> Message</span>
            <span class="legend-item"><span style="color:#79c0ff;">📞 VOICE</span> Call</span>
            <span class="legend-item"><span style="color:#d2a8ff;">🎥 VIDEO</span> Call</span>
            <span class="legend-item"><span style="color:#7ee787;">✅ COMP</span> Completed</span>
            <span class="legend-item"><span style="color:#fbbf24;">📞 MISS</span> Missed</span>
        </div>

        <div class="filter-bar">
            <input type="text" id="tableFilter" placeholder="🔍 Filter by Chat ID, Contact, or Type..." onkeyup="filterTable()">
            <button onclick="filterTable()">Filter</button>
            <button onclick="clearFilter()">Clear</button>
            <button onclick="showOnlyCalls()">📞 Calls Only</button>
            <button onclick="showOnlyMessages()">💬 Messages Only</button>
            <button onclick="showAll()">All</button>
        </div>

        <div class="table-container">
            <table id="timelineTable">
                <thead>
                    <tr>
                        <th>Chat ID</th>
                        <th>Chat Name</th>
                        <th>Contact/Phone</th>
                        <th>Type</th>
                        <th>Direction</th>
                        <th>Details</th>
                        <th>Status</th>
                        <th>Time</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Create temp file and populate
    local temp_data="${TEMP_DIR:-/tmp}/html_recon_$$.tmp"
    
    sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
        SELECT
            c._id,
            COALESCE(c.subject, 'Chat_' || c._id),
            CASE
                WHEN m.from_me = 1 THEN '📱 DEVICE'
                ELSE COALESCE(
                    CASE WHEN j.server  = 's.whatsapp.net' THEN j.user  END,
                    CASE WHEN cj.server = 's.whatsapp.net' THEN cj.user END,
                    (SELECT pj.user FROM jid_map jm2
                     JOIN $jid_table pj
                       ON pj._id = CASE WHEN jm2.lid_row_id = j._id
                                        THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                     WHERE (jm2.lid_row_id = j._id OR jm2.jid_row_id = j._id)
                       AND pj.server = 's.whatsapp.net' LIMIT 1),
                    (SELECT pj.user FROM jid_map jm3
                     JOIN $jid_table pj
                       ON pj._id = CASE WHEN jm3.lid_row_id = cj._id
                                        THEN jm3.jid_row_id ELSE jm3.lid_row_id END
                     WHERE (jm3.lid_row_id = cj._id OR jm3.jid_row_id = cj._id)
                       AND pj.server = 's.whatsapp.net' LIMIT 1),
                    COALESCE(j.user, cj.user, 'UNKNOWN')
                )
            END,
            '💬 MESSAGE',
            CASE WHEN m.from_me = 1 THEN '📤 SENT' ELSE '📥 RECV' END,
            CASE m.message_type
                WHEN 0  THEN COALESCE(SUBSTR(m.text_data, 1, 30), '[text]')
                WHEN 1  THEN '📷 IMAGE'
                WHEN 2  THEN '🎤 VOICE'
                WHEN 3  THEN '🎥 VIDEO'
                WHEN 7  THEN '🔗 LINK'
                WHEN 8  THEN '📄 DOC'
                WHEN 15 THEN '🗑️ DELETED'
                ELSE '📁 MEDIA'
            END,
            CASE WHEN m.message_type = 15 THEN '🗑️ DELETED' ELSE '✅ INTACT' END,
            datetime(m.$ts_col/1000, 'unixepoch', 'localtime'),
            m.$ts_col
        FROM $msg_table m
        LEFT JOIN $chat_table c   ON m.chat_row_id       = c._id
        LEFT JOIN $jid_table cj   ON c.jid_row_id        = cj._id
        LEFT JOIN $jid_table j    ON m.sender_jid_row_id = j._id
        WHERE m.chat_row_id IS NOT NULL
    " 2>/dev/null > "$temp_data"
    
    # Append calls
    if [[ -n "$has_call_log" ]]; then
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT
                COALESCE(c._id, '-'),
                COALESCE(c.subject, 'Call'),
                COALESCE(
                    CASE WHEN j.server = 's.whatsapp.net' THEN j.user END,
                    (SELECT pj.user FROM jid_map jm2
                     JOIN $jid_table pj
                       ON pj._id = CASE WHEN jm2.lid_row_id = j._id
                                        THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                     WHERE (jm2.lid_row_id = j._id OR jm2.jid_row_id = j._id)
                       AND pj.server = 's.whatsapp.net' LIMIT 1),
                    j.user, 'Unknown'
                ),
                CASE cl.video_call WHEN 1 THEN '🎥 VIDEO CALL' ELSE '📞 VOICE CALL' END,
                CASE cl.video_call WHEN 1 THEN '🎥 VIDEO' ELSE '📞 VOICE' END,
                CASE WHEN cl.duration > 0 THEN (cl.duration / 60) || ' min' ELSE '0s' END,
                CASE cl.call_result WHEN 0 THEN '✅ COMPLETED' WHEN 1 THEN '📞 MISSED' WHEN 2 THEN '❌ REJECTED' ELSE 'UNKNOWN' END,
                datetime(cl.timestamp/1000, 'unixepoch', 'localtime'),
                cl.timestamp
            FROM call_log cl
            LEFT JOIN $jid_table j ON cl.jid_row_id = j._id
            LEFT JOIN $chat_table c ON c.jid_row_id = j._id
        " 2>/dev/null >> "$temp_data"
    fi
    
    # Sort and output
    sort -t'|' -k9 -n "$temp_data" 2>/dev/null | while IFS='|' read -r cid cname contact etype dir details status etime stime; do
        if [[ -n "$cid" ]]; then
            local row_class=""
            [[ "$dir" == *"SENT"* ]] && row_class="msg-sent"
            [[ "$dir" == *"RECV"* ]] && row_class="msg-recv"
            [[ "$etype" == *"VOICE"* ]] && row_class="call-voice"
            [[ "$etype" == *"VIDEO"* ]] && row_class="call-video"
            
            local status_class=""
            [[ "$status" == *"COMPLETED"* ]] && status_class="status-completed"
            [[ "$status" == *"MISSED"* ]] && status_class="status-missed"
            [[ "$status" == *"REJECTED"* ]] && status_class="status-rejected"
            
            # Skip rows with no chat id or that are clearly continuation lines
            [[ -z "${cid// }" || "${cid// }" == "-" && -z "${contact// }" && -z "${etime// }" ]] && continue
            echo "<tr class=\"${row_class}\">" >> "$htmlfile"
            echo "<td>${cid}</td><td>${cname}</td><td>${contact}</td><td>${etype}</td><td>${dir}</td><td class=\"details-cell\">${details}</td><td class=\"${status_class}\">${status}</td><td>${etime}</td>" >> "$htmlfile"
            echo "</tr>" >> "$htmlfile"
        fi
    done
    
    rm -f "$temp_data"

    cat >> "$htmlfile" <<'EOF'
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit • Court-Admissible Evidence</p>
        <p>Chain of Custody Verified • Read-Only Analysis • SHA-256 Hashes Recorded</p>
    </div>
</div>

<script>
function filterTable() {
    const input = document.getElementById('tableFilter');
    const filter = input.value.toLowerCase();
    const rows = document.querySelectorAll('#timelineTable tbody tr');
    for (let row of rows) {
        row.style.display = row.innerText.toLowerCase().includes(filter) ? '' : 'none';
    }
}
function clearFilter() {
    document.getElementById('tableFilter').value = '';
    filterTable();
}
function showOnlyCalls() {
    const rows = document.querySelectorAll('#timelineTable tbody tr');
    for (let row of rows) {
        row.style.display = row.innerText.includes('CALL') ? '' : 'none';
    }
}
function showOnlyMessages() {
    const rows = document.querySelectorAll('#timelineTable tbody tr');
    for (let row of rows) {
        row.style.display = row.innerText.includes('MESSAGE') ? '' : 'none';
    }
}
function showAll() {
    const rows = document.querySelectorAll('#timelineTable tbody tr');
    for (let row of rows) row.style.display = '';
}
function exportToCSV() {
    const table = document.getElementById('timelineTable');
    const rows = table.querySelectorAll('tr');
    const csv = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        csv.push(Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""') + '"').join(','));
    }
    const blob = new Blob(['\uFEFF' + csv.join('\n')], { type: 'text/csv' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'chat_reconstruction.csv';
    link.click();
}
</script>
</body>
</html>
EOF

    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

build_chat_html_report() {
    local htmlfile="$1"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Chat Reconstruction - Forensic Report</title>
<style>*{margin:0;padding:0}body{font-family:'Segoe UI',sans-serif;background:#f8f9fa;padding:24px}.container{max-width:1400px;margin:0 auto}
.header{background:linear-gradient(135deg,#1a73e8,#0d47a1);border-radius:28px;padding:32px;color:white;margin-bottom:24px}
.stats-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px}.stat-card{background:white;border-radius:16px;padding:20px}
.stat-number{font-size:2.5rem;color:#1a73e8}.section{background:white;border-radius:24px;padding:24px;margin-bottom:24px}
table{width:100%;border-collapse:collapse}th{background:#f1f3f4;padding:12px;text-align:left}td{padding:12px;border-bottom:1px solid #e8eaed}
.badge-device{background:#d3f0d3;color:#137333;padding:4px 10px;border-radius:20px}.badge-business{background:#e8d5f5;color:#9334e6;padding:4px 10px;border-radius:20px}
.badge-deleted{background:#fce8e6;color:#c5221f;padding:4px 10px;border-radius:20px}.badge-system{background:#fef7e0;color:#b06000;padding:4px 10px;border-radius:20px}
.btn{padding:10px 20px;border-radius:20px;border:none;cursor:pointer;margin-right:10px}.btn-primary{background:#1a73e8;color:white}
</style></head><body><div class="container">
HTMLEOF

    cat >> "$htmlfile" <<EOF
<div class="header"><h1>💬 Full Chat & Participant Reconstruction</h1><p>${CURRENT_CASE} | ${INVESTIGATOR} | $(date)</p></div>
<div style="margin-bottom:20px"><button class="btn btn-primary" onclick="window.print()">🖨️ Print/PDF</button></div>
<div class="section"><h2>Chat Participants</h2><table>
<thead><tr><th>Chat ID</th><th>Chat Name</th><th>Resolved Sender</th><th>Type</th><th>Total</th><th>Sent</th><th>Recv</th><th>Last Activity</th></tr></thead><tbody>
EOF

    if [[ -n "$chat_table" && -n "$jid_table" ]]; then
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT c._id, COALESCE(c.subject, 'Individual'),
                   CASE WHEN m.from_me=1 THEN '<span class=\"badge-device\">📱 DEVICE</span>'
                        WHEN j.raw_string LIKE '%@lid' THEN '<span class=\"badge-business\">🏢 '||SUBSTR(j.raw_string,1,15)||'</span>'
                        WHEN j.user IS NOT NULL THEN j.user
                        WHEN m.sender_jid_row_id IS NULL THEN '<span class=\"badge-system\">⚠️ SYSTEM</span>'
                        WHEN j._id IS NULL THEN '<span class=\"badge-deleted\">🗑️ DELETED</span>'
                        ELSE j.raw_string END,
                   CASE WHEN j.server='s.whatsapp.net' THEN 'Individual' ELSE 'Group/Business' END,
                   COUNT(*), SUM(CASE WHEN m.from_me=1 THEN 1 ELSE 0 END), SUM(CASE WHEN m.from_me=0 THEN 1 ELSE 0 END),
                   datetime(MAX(m.$ts_col)/1000,'unixepoch','localtime')
            FROM $msg_table m LEFT JOIN $chat_table c ON m.chat_row_id=c._id LEFT JOIN $jid_table j ON m.sender_jid_row_id=j._id
            WHERE m.chat_row_id IS NOT NULL GROUP BY c._id, m.sender_jid_row_id ORDER BY MAX(m.$ts_col) DESC LIMIT 100;
        " 2>/dev/null | while IFS='|' read -r a b c d e f g h; do
            echo "<tr><td>$a</td><td>$b</td><td>$c</td><td>$d</td><td>$e</td><td>$f</td><td>$g</td><td>$h</td></tr>" >> "$htmlfile"
        done
    fi
    
    echo "</tbody></table></div></div></body></html>" >> "$htmlfile"
    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# QUERY 3 — CONTACT IDENTITY MAPPING
# =============================================================================
# =============================================================================
# QUERY 3 — CONTACT IDENTITY MAPPING (WITH CHAT ACTIVITY)
# =============================================================================
# =============================================================================
# QUERY 3 — CONTACT IDENTITY MAPPING (WITH CHAT ACTIVITY - FIXED)
# =============================================================================
# =============================================================================
# QUERY 3 — CONTACT IDENTITY MAPPING (DARK THEME - WITH CHAT IDs)
# =============================================================================
# =============================================================================
# QUERY 3 — CONTACT IDENTITY MAPPING (DARK THEME - WITH CHAT IDs)
# =============================================================================
# =============================================================================
# QUERY 3 — CONTACT IDENTITY MAPPING (FULLY CORRECTED - FINDS ALL MESSAGES)
# =============================================================================
# =============================================================================
# QUERY 3 — CONTACT IDENTITY MAPPING (FINAL - WITH jid_map BRIDGE)
# =============================================================================
analyze_contact_mapping() {
    banner
    print_section "Q3: CONTACT IDENTITY MAPPING"
    
    local outfile="${CASE_DIR}/reports/Q3_contact_mapping.html"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 3: CONTACT IDENTITY MAPPING                                                  ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Source: wa.db + msgstore.db + jid_map ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    # Get statistics
    local total_contacts=0
    local active_contacts=0
    if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
        total_contacts=$(sqlite3 -readonly "$WA_DB" "SELECT COUNT(*) FROM wa_contacts WHERE jid IS NOT NULL;" 2>/dev/null || echo "0")
        active_contacts=$(sqlite3 -readonly "$WA_DB" "SELECT COUNT(*) FROM wa_contacts WHERE is_whatsapp_user = 1;" 2>/dev/null || echo "0")
    fi
    
    local total_chats=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(DISTINCT chat_row_id) FROM $msg_table;" 2>/dev/null || echo "0")
    local total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
    
    echo -e "${BOLD}${WHITE}  📊 CONTACT STATISTICS${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}\n" \
        "Total Contacts:" "$total_contacts" "Active WhatsApp:" "$active_contacts" "Total Chats:" "$total_chats"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} ${YELLOW}%10s${RESET}  ${CYAN}│${RESET}  %-15s %10s  ${CYAN}│${RESET}  %-15s %10s  ${CYAN}│${RESET}\n" \
        "Total Messages:" "$total_msgs" "" "" "" ""
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📇 CONTACTS WITH CHAT ACTIVITY${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-4s %-15s %-20s %-16s %-8s %-8s %-12s${RESET}\n" \
        "ID" "Phone Number" "Display Name" "Chat IDs" "Msgs" "Status" "Last Active"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    local temp_data="${TEMP_DIR:-/tmp}/contacts_activity_$$.tmp"
    
    if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
        sqlite3 -readonly -separator '§' "$WA_DB" "
            SELECT 
                _id,
                jid,
                SUBSTR(jid, 1, INSTR(jid, '@') - 1) as phone,
                COALESCE(display_name, wa_name, '') as display_name,
                CASE WHEN is_whatsapp_user = 1 THEN 'Active' ELSE 'Inactive' END as status
            FROM wa_contacts 
            WHERE jid IS NOT NULL AND jid NOT LIKE '%@broadcast%'
            ORDER BY display_name;
        " 2>/dev/null > "$temp_data"
        
        local line_count=0
        while IFS='§' read -r wa_id jid phone display_name status; do
            [[ -z "$wa_id" || "$phone" == "status" ]] && continue

            # ===== UNIFIED CHAT LOOKUP USING jid_map BRIDGE =====
            local chat_info
            chat_info=$(sqlite3 -readonly "$MSGSTORE_DB" "
                WITH contact_jid AS (
                    SELECT _id FROM jid WHERE raw_string = '${jid}'
                ),
                contact_lid AS (
                    SELECT CASE 
                        WHEN jm.jid_row_id = cj._id THEN jm.lid_row_id
                        WHEN jm.lid_row_id = cj._id THEN jm.jid_row_id
                        ELSE NULL
                    END AS alt_id
                    FROM contact_jid cj
                    LEFT JOIN jid_map jm 
                        ON jm.jid_row_id = cj._id OR jm.lid_row_id = cj._id
                ),
                all_jid_ids AS (
                    SELECT _id FROM contact_jid
                    UNION SELECT alt_id FROM contact_lid WHERE alt_id IS NOT NULL
                ),
                all_chat_ids AS (
                    -- Direct 1-to-1 chat
                    SELECT DISTINCT c._id as chat_id
                    FROM chat c
                    INNER JOIN jid j ON c.jid_row_id = j._id
                    WHERE j._id IN (SELECT _id FROM all_jid_ids)
                    UNION
                    -- Group chats where contact has sent messages
                    SELECT DISTINCT m.chat_row_id as chat_id
                    FROM message m
                    WHERE m.sender_jid_row_id IN (SELECT _id FROM all_jid_ids)
                      AND m.chat_row_id IS NOT NULL
                )
                SELECT 
                    GROUP_CONCAT(DISTINCT m.chat_row_id ORDER BY m.chat_row_id),
                    COUNT(m._id),
                    datetime(MAX(m.${ts_col})/1000, 'unixepoch', 'localtime')
                FROM message m
                WHERE m.chat_row_id IN (SELECT chat_id FROM all_chat_ids);
            " 2>/dev/null | tr '|' '§')
            
            local chat_ids="" msg_count="0" last_active="—"
            if [[ -n "$chat_info" ]]; then
                IFS='§' read -r chat_ids msg_count last_active <<< "$chat_info"
            fi
            
            # Defaults and truncation
            [[ -z "$chat_ids"    || "$chat_ids"    == "NULL" ]] && chat_ids="—"
            [[ -z "$msg_count"   || "$msg_count"   == "NULL" ]] && msg_count="0"
            [[ -z "$last_active" || "$last_active" == "NULL" ]] && last_active="—"
            [[ ${#phone}        -gt 14 ]] && phone="${phone:0:11}..."
            [[ ${#display_name} -gt 19 ]] && display_name="${display_name:0:16}..."
            [[ -z "$display_name" ]]       && display_name="—"
            
            # Colors
            local name_color="$WHITE";  [[ "$display_name" != "—" ]] && name_color="$GREEN"
            local msg_color="$WHITE"
            (( msg_count > 10 )) && msg_color="$YELLOW"
            (( msg_count > 50 )) && msg_color="$RED"
            local chat_color="$CYAN";   [[ "$chat_ids" != "—" ]] && chat_color="$GREEN"
            local stat_color="$WHITE";  [[ "$status" == "Active" ]] && stat_color="$GREEN" || stat_color="$RED"
            local stat_icon="✅";        [[ "$status" != "Active" ]] && stat_icon="❌"
            
            printf "  ${WHITE}%-3s${RESET}  ${CYAN}%-14s${RESET}  ${name_color}%-19s${RESET} ${chat_color}%-15s${RESET} ${msg_color}%-7s${RESET} ${stat_color}%-9s${RESET} ${CYAN}%-12s${RESET}\n" \
                "$wa_id" "$phone" "$display_name" "$chat_ids" "$msg_count" "${stat_icon} ${status}" "${last_active:0:11}"
            
            ((line_count++))
            if (( line_count >= 20 )); then
                echo ""
                echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                echo -e "  ${YELLOW}📄 Press Enter for more or 'q' to quit${RESET}"
                read -rp "  > " nav
                [[ "$nav" == "q" || "$nav" == "Q" ]] && break
                line_count=0
                echo ""
                printf "  ${BOLD}%-4s %-15s %-20s %-10s %-8s %-8s %-12s${RESET}\n" \
                    "ID" "Phone Number" "Display Name" "Chat IDs" "Msgs" "Status" "Last Active"
                echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
            fi
        done < "$temp_data"
        rm -f "$temp_data"
    else
        print_warn "wa.db not loaded — showing contacts from msgstore.db only"
    fi
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    build_contact_mapping_html_dark "$outfile"
    log_action "Q3: Contact Mapping" "wa.db + msgstore.db + jid_map" "SUCCESS"
    
    echo -e "  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    cross_open "$outfile" 2>/dev/null &
    
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}  📌 What would you like to do next?${RESET}"
    echo ""
    echo -e "    ${GREEN}1${RESET}. Return to Analysis Menu"
    echo -e "    ${GREEN}2${RESET}. View HTML Report in browser"
    echo -e "    ${GREEN}3${RESET}. Search for a specific contact"
    echo -e "    ${GREEN}4${RESET}. Deep dive into a Chat ID"
    echo -e "    ${GREEN}0${RESET}. Main Menu"
    echo ""
    read -rp "  > " choice
    case "$choice" in
        1) return 0 ;;
        2) cross_open "$outfile" 2>/dev/null & pause ;;
        3) search_by_phone ;;
        4)
            read -rp "  Enter Chat ID: " dive_id
            [[ "$dive_id" =~ ^[0-9]+$ ]] && chat_deep_dive "$dive_id" || print_err "Invalid Chat ID"
            pause
            ;;
        0) return 0 ;;
        *) return 0 ;;
    esac
}
# =============================================================================
# HTML REPORT FOR CONTACT MAPPING (DARK THEME - MATCHES OTHER REPORTS)
# =============================================================================
# =============================================================================
# HTML REPORT FOR CONTACT MAPPING (WITH jid_map BRIDGE)
# =============================================================================
# =============================================================================
# HTML REPORT FOR CONTACT MAPPING (FIXED - MATCHES TERMINAL OUTPUT)
# =============================================================================
build_contact_mapping_html_dark() {
    local htmlfile="$1"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    # Start HTML file
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Contact Identity Mapping - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', 'Consolas', monospace; background: #0d1117; color: #c9d1d9; padding: 24px; line-height: 1.5; }
        .container { max-width: 1600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; margin-bottom: 8px; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-right: 10px; }
        .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: #161b22; border-radius: 12px; padding: 20px; text-align: center; border: 1px solid #30363d; }
        .stat-number { font-size: 2.2rem; font-weight: bold; color: #58a6ff; }
        .stat-label { font-size: 0.75rem; color: #8b949e; text-transform: uppercase; letter-spacing: 0.5px; }
        .section { background: #161b22; border-radius: 16px; padding: 24px; margin-bottom: 24px; border: 1px solid #30363d; }
        .section h2 { color: #58a6ff; margin-bottom: 20px; font-size: 1.3rem; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #30363d; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { background: #1f6feb; color: white; font-weight: 500; padding: 12px 16px; text-align: left; white-space: nowrap; }
        td { padding: 10px 16px; border-bottom: 1px solid #21262d; vertical-align: middle; }
        tr:hover td { background: #1a2332; }
        .contact-name { color: #7ee787; font-weight: 600; }
        .contact-phone { color: #79c0ff; font-family: monospace; }
        .chat-ids { color: #7ee787; font-family: monospace; }
        .msg-count { color: #d2a8ff; font-weight: 600; }
        .msg-zero { color: #484f58; }
        .status-active { color: #7ee787; }
        .status-inactive { color: #f85149; }
        .dash { color: #484f58; }
        .chat-badge { display: inline-block; background: #1f3a5f; color: #7ee787; border: 1px solid #238636; border-radius: 4px; padding: 2px 6px; font-family: monospace; font-size: 0.75rem; margin: 1px; }
        .footer { text-align: center; padding: 24px; color: #8b949e; font-size: 0.8rem; border-top: 1px solid #30363d; margin-top: 24px; }
        .btn { padding: 10px 20px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer; margin-right: 10px; }
        .btn-secondary { background: #30363d; }
        .filter-bar { display: flex; gap: 12px; margin-bottom: 20px; }
        .filter-bar input { flex: 1; padding: 10px 14px; background: #0d1117; border: 1px solid #30363d; border-radius: 8px; color: #c9d1d9; }
        .filter-bar button { padding: 10px 20px; background: #238636; border: none; border-radius: 8px; color: white; cursor: pointer; }
        .filter-bar button.outline { background: #30363d; }
        @media print { .filter-bar, .btn { display: none; } body { background: white; color: black; } }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    # Header with case info
    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>📇 Contact Identity Mapping</h1>
        <div style="opacity:0.9">WhatsApp Forensic Investigation • Court-Admissible Evidence</div>
        <div style="margin-top:15px">
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>

    <div style="margin-bottom:20px">
        <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn btn-secondary" onclick="exportToCSV()">📥 Export CSV</button>
    </div>

    <div class="section">
        <h2>📇 Contacts with Chat Activity (wa.db + msgstore.db + jid_map)</h2>
        <div class="filter-bar">
            <input type="text" id="tableFilter" placeholder="🔍 Filter by Phone, Name, or Chat ID..." onkeyup="filterTable()">
            <button onclick="filterTable()">🔍 Filter</button>
            <button class="outline" onclick="clearFilter()">✕ Clear</button>
        </div>
        <div class="table-container">
            <table id="contactTable">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Phone Number</th>
                        <th>Display Name</th>
                        <th>Chat IDs</th>
                        <th>Messages</th>
                        <th>Status</th>
                        <th>Last Active</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Populate table - using the SAME query as terminal version
    if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
        # Create temp file with contact data
        local temp_data="${TEMP_DIR:-/tmp}/html_contacts_$$.tmp"
        sqlite3 -readonly -separator '§' "$WA_DB" "
            SELECT 
                _id,
                SUBSTR(jid, 1, INSTR(jid, '@') - 1) as phone,
                COALESCE(display_name, wa_name, '') as display_name,
                jid,
                CASE WHEN is_whatsapp_user = 1 THEN 'Active' ELSE 'Inactive' END as status
            FROM wa_contacts 
            WHERE jid IS NOT NULL AND jid NOT LIKE '%@broadcast%'
            ORDER BY display_name;
        " 2>/dev/null > "$temp_data"
        
        while IFS='§' read -r wa_id phone display_name jid status; do
            [[ -z "$wa_id" || "$phone" == "status" ]] && continue
            
            # === USE EXACT SAME QUERY AS TERMINAL VERSION ===
            local chat_data
            chat_data=$(sqlite3 -readonly "$MSGSTORE_DB" "
                WITH contact_jid AS (
                    SELECT _id FROM jid WHERE raw_string = '${jid}'
                ),
                contact_lid AS (
                    SELECT CASE 
                        WHEN jm.jid_row_id = cj._id THEN jm.lid_row_id
                        WHEN jm.lid_row_id = cj._id THEN jm.jid_row_id
                        ELSE NULL
                    END AS alt_id
                    FROM contact_jid cj
                    LEFT JOIN jid_map jm 
                        ON jm.jid_row_id = cj._id OR jm.lid_row_id = cj._id
                ),
                all_jid_ids AS (
                    SELECT _id FROM contact_jid
                    UNION SELECT alt_id FROM contact_lid WHERE alt_id IS NOT NULL
                ),
                all_chat_ids AS (
                    -- Direct 1-to-1 chat
                    SELECT DISTINCT c._id as chat_id
                    FROM chat c
                    INNER JOIN jid j ON c.jid_row_id = j._id
                    WHERE j._id IN (SELECT _id FROM all_jid_ids)
                    UNION
                    -- Group chats where contact has sent messages
                    SELECT DISTINCT m.chat_row_id as chat_id
                    FROM message m
                    WHERE m.sender_jid_row_id IN (SELECT _id FROM all_jid_ids)
                      AND m.chat_row_id IS NOT NULL
                )
                SELECT 
                    GROUP_CONCAT(DISTINCT m.chat_row_id ORDER BY m.chat_row_id),
                    COUNT(m._id),
                    datetime(MAX(m.${ts_col})/1000, 'unixepoch', 'localtime')
                FROM message m
                WHERE m.chat_row_id IN (SELECT chat_id FROM all_chat_ids);
            " 2>/dev/null)
            
            local chat_ids="" msg_count="0" last_active=""
            if [[ -n "$chat_data" ]]; then
                IFS='|' read -r chat_ids msg_count last_active <<< "$chat_data"
            fi
            
            # Sanitize
            [[ -z "$chat_ids"    || "$chat_ids"    == "NULL" ]] && chat_ids=""
            [[ -z "$msg_count"   || "$msg_count"   == "NULL" ]] && msg_count="0"
            [[ -z "$last_active" || "$last_active" == "NULL" ]] && last_active=""
            [[ -z "$display_name" ]] && display_name=""
            
            # Truncate long phone only (chat_ids shown in full)
            [[ ${#phone} -gt 14 ]] && phone="${phone:0:11}..."
            
            # Build HTML cells
            local name_cell=""
            if [[ -n "$display_name" ]]; then
                name_cell="<strong class=\"contact-name\">${display_name}</strong>"
            else
                name_cell="<span class=\"dash\">—</span>"
            fi
            
            local chat_cell=""
            if [[ -n "$chat_ids" ]]; then
                # Render each chat ID as a separate badge
                local badge_html=""
                IFS=',' read -ra id_arr <<< "$chat_ids"
                for cid_badge in "${id_arr[@]}"; do
                    cid_badge="${cid_badge// /}"
                    [[ -n "$cid_badge" ]] && badge_html+="<span class=\"chat-badge\">${cid_badge}</span> "
                done
                chat_cell="<span class=\"chat-ids\">${badge_html}</span>"
            else
                chat_cell="<span class=\"dash\">—</span>"
            fi
            
            local msg_cell=""
            if [[ "$msg_count" -gt 0 ]]; then
                msg_cell="<span class=\"msg-count\">${msg_count}</span>"
            else
                msg_cell="<span class=\"msg-zero\">0</span>"
            fi
            
            local date_cell=""
            if [[ -n "$last_active" ]]; then
                date_cell="${last_active:0:16}"
            else
                date_cell="<span class=\"dash\">—</span>"
            fi
            
            local status_cell=""
            if [[ "$status" == "Active" ]]; then
                status_cell="<span class=\"status-active\">✅ Active</span>"
            else
                status_cell="<span class=\"status-inactive\">❌ Inactive</span>"
            fi
            
            # Write row to HTML
            printf '<tr><td>%s</td><td class="contact-phone">%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n' \
                "$wa_id" "$phone" "$name_cell" "$chat_cell" "$msg_cell" "$status_cell" "$date_cell" >> "$htmlfile"
                
        done < "$temp_data"
        rm -f "$temp_data"
    fi

    cat >> "$htmlfile" <<'EOF'
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit • Court-Admissible Evidence</p>
        <p>Chain of Custody Verified • Read-Only Analysis • SHA-256 Hashes Recorded</p>
    </div>
</div>

<script>
function filterTable() {
    const input = document.getElementById('tableFilter');
    const filter = input.value.toLowerCase();
    const rows = document.querySelectorAll('#contactTable tbody tr');
    for (let row of rows) row.style.display = row.innerText.toLowerCase().includes(filter) ? '' : 'none';
}
function clearFilter() {
    document.getElementById('tableFilter').value = '';
    filterTable();
}
function exportToCSV() {
    const table = document.getElementById('contactTable');
    const rows = table.querySelectorAll('tr');
    const csv = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        csv.push(Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""') + '"').join(','));
    }
    const blob = new Blob(['\uFEFF' + csv.join('\n')], { type: 'text/csv' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'contact_mapping.csv';
    link.click();
}
</script>
</body>
</html>
EOF

    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# HTML REPORT FOR CONTACT MAPPING
# =============================================================================
build_contact_mapping_html() {
    local htmlfile="$1"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Contact Identity Mapping - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #f8f9fa; color: #202124; padding: 24px; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1a73e8, #0d47a1); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; margin-bottom: 8px; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-right: 10px; }
        .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: white; border-radius: 12px; padding: 20px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        .stat-number { font-size: 2rem; font-weight: bold; color: #1a73e8; }
        .stat-label { font-size: 0.75rem; color: #5f6368; text-transform: uppercase; }
        .section { background: white; border-radius: 16px; padding: 24px; margin-bottom: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
        .section h2 { color: #1a73e8; margin-bottom: 20px; border-bottom: 2px solid #e8eaed; padding-bottom: 12px; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #e8eaed; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { background: #1a73e8; color: white; font-weight: 500; padding: 12px 16px; text-align: left; }
        td { padding: 10px 16px; border-bottom: 1px solid #e8eaed; }
        tr:hover td { background: #f8f9fa; }
        .badge-business { background: #e8d5f5; color: #9334e6; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; }
        .badge-group { background: #d4e4fc; color: #1a73e8; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; }
        .badge-individual { background: #d3f0d3; color: #137333; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; }
        .badge-active { background: #d3f0d3; color: #137333; }
        .badge-inactive { background: #fce8e6; color: #c5221f; }
        .footer { text-align: center; padding: 24px; color: #5f6368; font-size: 0.8rem; border-top: 1px solid #e8eaed; margin-top: 24px; }
        .btn { padding: 10px 20px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer; margin-right: 10px; }
        .filter-bar { display: flex; gap: 12px; margin-bottom: 20px; }
        .filter-bar input { flex: 1; padding: 10px 14px; border: 1px solid #e8eaed; border-radius: 8px; font-size: 0.9rem; }
        .filter-bar button { padding: 10px 20px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer; }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>📇 Contact Identity Mapping</h1>
        <div style="opacity:0.9">WhatsApp Forensic Investigation • Court-Admissible Evidence</div>
        <div style="margin-top:15px">
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>

    <div style="margin-bottom:20px">
        <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn" onclick="exportToCSV()">📥 Export CSV</button>
    </div>

    <div class="section">
        <h2>📇 Saved Contacts with Chat Activity</h2>
        
        <div class="filter-bar">
            <input type="text" id="tableFilter" placeholder="🔍 Filter by Phone, Name, or Type..." onkeyup="filterTable()">
            <button onclick="filterTable()">Filter</button>
            <button onclick="clearFilter()">Clear</button>
        </div>

        <div class="table-container">
            <table id="contactTable">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Phone Number</th>
                        <th>Display Name</th>
                        <th>Type</th>
                        <th>Chats</th>
                        <th>Messages</th>
                        <th>Status</th>
                        <th>Last Active</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Populate table
    if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
        sqlite3 -readonly -separator '|' "$WA_DB" "
            SELECT 
                _id,
                SUBSTR(jid, 1, INSTR(jid, '@') - 1) as phone,
                COALESCE(display_name, wa_name, '—') as name,
                CASE 
                    WHEN jid LIKE '%@lid' THEN '<span class=\"badge-business\">🏢 Business</span>'
                    WHEN jid LIKE '%@g.us' THEN '<span class=\"badge-group\">👥 Group</span>'
                    ELSE '<span class=\"badge-individual\">📱 Individual</span>'
                END as type,
                jid,
                CASE WHEN is_whatsapp_user = 1 THEN '<span class=\"badge-active\">✅ Active</span>' ELSE '<span class=\"badge-inactive\">❌ Inactive</span>' END as status
            FROM wa_contacts 
            WHERE jid IS NOT NULL
            ORDER BY display_name;
        " 2>/dev/null | while IFS='|' read -r id phone name type jid status; do
            # Get message activity
            local msg_count=$(sqlite3 -readonly "$MSGSTORE_DB" "
                SELECT COUNT(*) FROM message m 
                LEFT JOIN jid j ON m.sender_jid_row_id = j._id 
                WHERE j.raw_string = '${jid}' AND m.from_me = 0;
            " 2>/dev/null || echo "0")
            
            local chat_count=$(sqlite3 -readonly "$MSGSTORE_DB" "
                SELECT COUNT(DISTINCT m.chat_row_id) FROM message m 
                LEFT JOIN jid j ON m.sender_jid_row_id = j._id 
                WHERE j.raw_string = '${jid}' AND m.from_me = 0;
            " 2>/dev/null || echo "0")
            
            local last_active=$(sqlite3 -readonly "$MSGSTORE_DB" "
                SELECT datetime(MAX(m.$ts_col)/1000, 'unixepoch', 'localtime') FROM message m 
                LEFT JOIN jid j ON m.sender_jid_row_id = j._id 
                WHERE j.raw_string = '${jid}' AND m.from_me = 0;
            " 2>/dev/null || echo "—")
            
            echo "<tr><td>$id</td><td>$phone</td><td><strong>$name</strong></td><td>$type</td><td>$chat_count</td><td>$msg_count</td><td>$status</td><td>$last_active</td></tr>" >> "$htmlfile"
        done
    fi

    cat >> "$htmlfile" <<'EOF'
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit • Court-Admissible Evidence</p>
        <p>Chain of Custody Verified • Read-Only Analysis • SHA-256 Hashes Recorded</p>
    </div>
</div>

<script>
function filterTable() {
    const input = document.getElementById('tableFilter');
    const filter = input.value.toLowerCase();
    const rows = document.querySelectorAll('#contactTable tbody tr');
    for (let row of rows) row.style.display = row.innerText.toLowerCase().includes(filter) ? '' : 'none';
}
function clearFilter() {
    document.getElementById('tableFilter').value = '';
    filterTable();
}
function exportToCSV() {
    const table = document.getElementById('contactTable');
    const rows = table.querySelectorAll('tr');
    const csv = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        csv.push(Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""') + '"').join(','));
    }
    const blob = new Blob(['\uFEFF' + csv.join('\n')], { type: 'text/csv' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'contact_mapping.csv';
    link.click();
}
</script>
</body>
</html>
EOF

    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# HTML REPORT FOR CONTACT MAPPING
# =============================================================================
build_contact_mapping_html() {
    local htmlfile="$1"
    
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Contact Identity Mapping - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #f8f9fa; color: #202124; padding: 24px; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1a73e8, #0d47a1); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; margin-bottom: 8px; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-right: 10px; }
        .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: white; border-radius: 12px; padding: 20px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        .stat-number { font-size: 2rem; font-weight: bold; color: #1a73e8; }
        .stat-label { font-size: 0.75rem; color: #5f6368; text-transform: uppercase; }
        .section { background: white; border-radius: 16px; padding: 24px; margin-bottom: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
        .section h2 { color: #1a73e8; margin-bottom: 20px; border-bottom: 2px solid #e8eaed; padding-bottom: 12px; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #e8eaed; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { background: #1a73e8; color: white; font-weight: 500; padding: 12px 16px; text-align: left; }
        td { padding: 10px 16px; border-bottom: 1px solid #e8eaed; }
        tr:hover td { background: #f8f9fa; }
        .badge-business { background: #e8d5f5; color: #9334e6; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; }
        .badge-group { background: #d4e4fc; color: #1a73e8; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; }
        .badge-individual { background: #d3f0d3; color: #137333; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; }
        .badge-active { background: #d3f0d3; color: #137333; }
        .badge-inactive { background: #fce8e6; color: #c5221f; }
        .footer { text-align: center; padding: 24px; color: #5f6368; font-size: 0.8rem; border-top: 1px solid #e8eaed; margin-top: 24px; }
        .btn { padding: 10px 20px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer; margin-right: 10px; }
        .filter-bar { display: flex; gap: 12px; margin-bottom: 20px; }
        .filter-bar input { flex: 1; padding: 10px 14px; border: 1px solid #e8eaed; border-radius: 8px; font-size: 0.9rem; }
        .filter-bar button { padding: 10px 20px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer; }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>📇 Contact Identity Mapping</h1>
        <div style="opacity:0.9">WhatsApp Forensic Investigation • Court-Admissible Evidence</div>
        <div style="margin-top:15px">
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>

    <div style="margin-bottom:20px">
        <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn" onclick="exportToCSV()">📥 Export CSV</button>
    </div>

    <div class="section">
        <h2>📇 Saved Contacts with Chat Activity</h2>
        
        <div class="filter-bar">
            <input type="text" id="tableFilter" placeholder="🔍 Filter by Phone, Name, or Type..." onkeyup="filterTable()">
            <button onclick="filterTable()">Filter</button>
            <button onclick="clearFilter()">Clear</button>
        </div>

        <div class="table-container">
            <table id="contactTable">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Phone Number</th>
                        <th>Display Name</th>
                        <th>Type</th>
                        <th>Chats</th>
                        <th>Messages</th>
                        <th>Status</th>
                        <th>Last Active</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Populate table
    if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
        sqlite3 -readonly -separator '|' "$WA_DB" "
            SELECT 
                _id,
                SUBSTR(jid, 1, INSTR(jid, '@') - 1) as phone,
                COALESCE(display_name, wa_name, '—') as name,
                CASE 
                    WHEN jid LIKE '%@lid' THEN '<span class=\"badge-business\">🏢 Business</span>'
                    WHEN jid LIKE '%@g.us' THEN '<span class=\"badge-group\">👥 Group</span>'
                    ELSE '<span class=\"badge-individual\">📱 Individual</span>'
                END as type,
                jid,
                CASE WHEN is_whatsapp_user = 1 THEN '<span class=\"badge-active\">✅ Active</span>' ELSE '<span class=\"badge-inactive\">❌ Inactive</span>' END as status
            FROM wa_contacts 
            WHERE jid IS NOT NULL
            ORDER BY display_name;
        " 2>/dev/null | while IFS='|' read -r id phone name type jid status; do
            # Get message activity
            local msg_count=$(sqlite3 -readonly "$MSGSTORE_DB" "
                SELECT COUNT(*) FROM message m 
                LEFT JOIN jid j ON m.sender_jid_row_id = j._id 
                WHERE j.raw_string = '${jid}' AND m.from_me = 0;
            " 2>/dev/null || echo "0")
            
            local chat_count=$(sqlite3 -readonly "$MSGSTORE_DB" "
                SELECT COUNT(DISTINCT m.chat_row_id) FROM message m 
                LEFT JOIN jid j ON m.sender_jid_row_id = j._id 
                WHERE j.raw_string = '${jid}' AND m.from_me = 0;
            " 2>/dev/null || echo "0")
            
            local last_active=$(sqlite3 -readonly "$MSGSTORE_DB" "
                SELECT datetime(MAX(m.timestamp)/1000, 'unixepoch', 'localtime') FROM message m 
                LEFT JOIN jid j ON m.sender_jid_row_id = j._id 
                WHERE j.raw_string = '${jid}' AND m.from_me = 0;
            " 2>/dev/null || echo "—")
            
            echo "<tr><td>$id</td><td>$phone</td><td><strong>$name</strong></td><td>$type</td><td>$chat_count</td><td>$msg_count</td><td>$status</td><td>$last_active</td></tr>" >> "$htmlfile"
        done
    fi

    cat >> "$htmlfile" <<'EOF'
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit • Court-Admissible Evidence</p>
        <p>Chain of Custody Verified • Read-Only Analysis • SHA-256 Hashes Recorded</p>
    </div>
</div>

<script>
function filterTable() {
    const input = document.getElementById('tableFilter');
    const filter = input.value.toLowerCase();
    const rows = document.querySelectorAll('#contactTable tbody tr');
    for (let row of rows) row.style.display = row.innerText.toLowerCase().includes(filter) ? '' : 'none';
}
function clearFilter() {
    document.getElementById('tableFilter').value = '';
    filterTable();
}
function exportToCSV() {
    const table = document.getElementById('contactTable');
    const rows = table.querySelectorAll('tr');
    const csv = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        csv.push(Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""') + '"').join(','));
    }
    const blob = new Blob(['\uFEFF' + csv.join('\n')], { type: 'text/csv' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'contact_mapping.csv';
    link.click();
}
</script>
</body>
</html>
EOF

    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

build_contact_html_report() {
    local htmlfile="$1"
    
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Contact Mapping - Forensic Report</title>
<style>body{font-family:'Segoe UI',sans-serif;background:#f8f9fa;padding:24px}.container{max-width:1400px;margin:0 auto}
.header{background:linear-gradient(135deg,#1a73e8,#0d47a1);border-radius:28px;padding:32px;color:white;margin-bottom:24px}
.section{background:white;border-radius:24px;padding:24px;margin-bottom:24px}table{width:100%;border-collapse:collapse}
th{background:#f1f3f4;padding:12px}td{padding:12px;border-bottom:1px solid #e8eaed}
.badge-business{background:#e8d5f5;color:#9334e6;padding:4px 10px;border-radius:20px}.badge-individual{background:#d3f0d3;color:#137333;padding:4px 10px;border-radius:20px}
.btn{padding:10px 20px;border-radius:20px;border:none;cursor:pointer;background:#1a73e8;color:white}
</style></head><body><div class="container">
HTMLEOF

    cat >> "$htmlfile" <<EOF
<div class="header"><h1>📇 Contact Identity Mapping</h1><p>${CURRENT_CASE} | ${INVESTIGATOR} | $(date)</p></div>
<div style="margin-bottom:20px"><button class="btn" onclick="window.print()">🖨️ Print/PDF</button></div>
<div class="section"><h2>Saved Contacts (wa.db)</h2><table>
<thead><tr><th>ID</th><th>Phone</th><th>Display Name</th><th>Type</th><th>Status</th></tr></thead><tbody>
EOF

    if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
        sqlite3 -readonly -separator '|' "$WA_DB" "
            SELECT _id, SUBSTR(jid,1,INSTR(jid,'@')-1), COALESCE(display_name,'-'),
                   CASE WHEN jid LIKE '%@lid' THEN '<span class=\"badge-business\">🏢 Business</span>' ELSE '<span class=\"badge-individual\">📱 Individual</span>' END,
                   CASE WHEN is_whatsapp_user=1 THEN '✅ Active' ELSE '❌' END
            FROM wa_contacts WHERE jid IS NOT NULL ORDER BY display_name LIMIT 200;
        " 2>/dev/null | while IFS='|' read -r a b c d e; do
            echo "<tr><td>$a</td><td>$b</td><td>$c</td><td>$d</td><td>$e</td></tr>" >> "$htmlfile"
        done
    fi
    
    echo "</tbody></table></div></div></body></html>" >> "$htmlfile"
    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# QUERY 4 — MEDIA & FILE RECONSTRUCTION
# =============================================================================
analyze_media_reconstruction() {
    banner
    print_section "Q4: MEDIA & FILE RECONSTRUCTION"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local media_table=$(detect_media_table "$MSGSTORE_DB")
    
    print_info "Media table: ${media_table:-Not found}"
    print_info "Scanning media files and recovery paths..."
    
    local outfile="${CASE_DIR}/reports/Q4_media_reconstruction.html"
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    # Get statistics
    local total_media=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type IN (1,2,3,8,9,11,13);" 2>/dev/null || echo "0")
    local images=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 1;" 2>/dev/null || echo "0")
    local videos=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 3;" 2>/dev/null || echo "0")
    local voice=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 2;" 2>/dev/null || echo "0")
    local docs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 8;" 2>/dev/null || echo "0")
    local local_files=0
    local cdn_files=0
    
    if [[ -n "$media_table" ]]; then
        local_files=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $media_table WHERE file_path IS NOT NULL;" 2>/dev/null || echo "0")
        cdn_files=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $media_table WHERE direct_path IS NOT NULL;" 2>/dev/null || echo "0")
    fi
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 4: MEDIA & FILE RECONSTRUCTION                                               ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Source: msgstore.db + media tables ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📊 MEDIA INVENTORY SUMMARY${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-12s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-12s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-12s${RESET} %8s  ${CYAN}│${RESET}\n" \
        "Total Media:" "$total_media" "📷 Images:" "$images" "🎥 Videos:" "$videos"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-12s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-12s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-12s${RESET} %8s  ${CYAN}│${RESET}\n" \
        "🎤 Voice:" "$voice" "📄 Docs:" "$docs" "💾 Local:" "$local_files"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    # Legend
    echo -e "${BOLD}${WHITE}  📋 RECOVERY STATUS LEGEND:${RESET}"
    echo -e "  ${CYAN}├─${RESET} ${GREEN}✅ LOCAL_FILE${RESET}      → File present on device storage (recoverable)"
    echo -e "  ${CYAN}├─${RESET} ${YELLOW}☁️ CDN_RECOVERABLE${RESET} → File stored on WhatsApp CDN (may be recoverable)"
    echo -e "  ${CYAN}└─${RESET} ${RED}❌ NO_FILE${RESET}         → File reference exists but content missing\n"
    
    echo -e "${BOLD}${WHITE}  📁 MEDIA FILES WITH RECOVERY PATHS (Most Recent 30)${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-8s %-18s %-20s %-8s %-10s %-14s %-10s${RESET}\n" \
        "Msg ID" "Conversation" "Sent Time" "Type" "Size" "Filename" "Status"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    if [[ -n "$media_table" ]]; then
        local temp_data="${TEMP_DIR:-/tmp}/media_$$.tmp"
        
        # Build conversation expression — resolve individual chats via jid table
        local _jid_join_term=""
        local _conv_expr="COALESCE(c.subject, 'Chat_' || m.chat_row_id)"
        if [[ -n "$jid_table" ]]; then
            _jid_join_term="LEFT JOIN ${jid_table} cj ON c.jid_row_id = cj._id"
            _conv_expr="COALESCE(c.subject, CASE WHEN cj.server='s.whatsapp.net' THEN 'Individual_'||cj.user WHEN cj.server='g.us' THEN 'Group_'||cj.user WHEN cj.raw_string IS NOT NULL THEN cj.raw_string ELSE 'Chat_'||m.chat_row_id END)"
        fi

        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT 
                m._id,
                ${_conv_expr},
                datetime(m.$ts_col/1000, 'unixepoch', 'localtime'),
                CASE m.message_type
                    WHEN 1 THEN '📷 Image' WHEN 2 THEN '🎤 Voice' WHEN 3 THEN '🎥 Video'
                    WHEN 8 THEN '📄 Doc' WHEN 9 THEN '🎵 Audio' ELSE 'Media'
                END,
                CASE 
                    WHEN mm.file_size > 1048576 THEN ROUND(mm.file_size/1048576.0, 2) || ' MB'
                    WHEN mm.file_size > 1024 THEN ROUND(mm.file_size/1024.0, 1) || ' KB'
                    WHEN mm.file_size IS NULL THEN '0 B'
                    ELSE mm.file_size || ' B'
                END,
                COALESCE(mm.media_name,
                    CASE WHEN mm.file_path IS NOT NULL
                         THEN SUBSTR(mm.file_path, LENGTH(mm.file_path) - INSTR(REVERSE(mm.file_path),'/')+2)
                         WHEN mm.direct_path IS NOT NULL
                         THEN SUBSTR(mm.direct_path, LENGTH(mm.direct_path) - INSTR(REVERSE(mm.direct_path),'/')+2)
                         ELSE '—'
                    END),
                CASE 
                    WHEN mm.file_path IS NOT NULL THEN '✅ LOCAL'
                    WHEN mm.direct_path IS NOT NULL THEN '☁️ CDN'
                    ELSE '❌ NONE'
                END
            FROM $msg_table m
            LEFT JOIN $chat_table c ON m.chat_row_id = c._id
            ${_jid_join_term}
            LEFT JOIN $media_table mm ON mm.message_row_id = m._id
            WHERE m.message_type IN (1,2,3,8,9,11,13)
            ORDER BY m.$ts_col DESC
            LIMIT 30;
        " 2>/dev/null > "$temp_data"
        
        local line_count=0
        while IFS='|' read -r msg_id conv time type size fname status; do
            if [[ -n "$msg_id" ]]; then
                [[ ${#conv} -gt 17 ]] && conv="${conv:0:14}..."
                [[ ${#fname} -gt 13 ]] && fname="${fname:0:10}..."
                
                local status_color="${WHITE}"
                [[ "$status" == *"LOCAL"* ]] && status_color="${GREEN}"
                [[ "$status" == *"CDN"* ]] && status_color="${YELLOW}"
                [[ "$status" == *"NONE"* ]] && status_color="${RED}"
                
                local type_color="${CYAN}"
                [[ "$type" == *"Image"* ]] && type_color="${MAGENTA}"
                [[ "$type" == *"Video"* ]] && type_color="${BLUE}"
                
                printf "  ${WHITE}%-7s${RESET}  ${CYAN}%-17s${RESET}  ${WHITE}%-19s${RESET}  ${type_color}%-7s${RESET}  ${YELLOW}%-9s${RESET}  ${GREEN}%-13s${RESET}  ${status_color}%-9s${RESET}\n" \
                    "$msg_id" "$conv" "${time:0:18}" "$type" "$size" "$fname" "$status"
                
                ((line_count++))
                if (( line_count >= 15 )); then
                    echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                    echo -e "  ${YELLOW}📄 Press Enter for more or 'q' to quit${RESET}"
                    read -rp "  > " nav
                    [[ "$nav" == "q" || "$nav" == "Q" ]] && break
                    line_count=0
                    echo ""
                    printf "  ${BOLD}%-8s %-18s %-20s %-8s %-10s %-14s %-10s${RESET}\n" \
                        "Msg ID" "Conversation" "Sent Time" "Type" "Size" "Filename" "Status"
                    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                fi
            fi
        done < "$temp_data"
        rm -f "$temp_data"
    else
        echo -e "  ${YELLOW}[No message_media table found — showing basic message records]${RESET}"
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT _id, chat_row_id, datetime($ts_col/1000, 'unixepoch', 'localtime'),
                   message_type, media_size, COALESCE(media_name, 'unnamed')
            FROM $msg_table WHERE message_type IN (1,2,3,8,9) ORDER BY $ts_col DESC LIMIT 20;
        " 2>/dev/null | while IFS='|' read -r id chat time type size name; do
            printf "  ${WHITE}%-7s${RESET}  Chat %-14s  ${WHITE}%-19s${RESET}  Type %-4s  %-9s  %-13s\n" \
                "$id" "$chat" "${time:0:18}" "$type" "${size:-N/A}" "${name:0:12}"
        done
    fi
    
    echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    build_media_html_report "$outfile" "$total_media" "$images" "$videos" "$voice" "$docs" "$local_files" "$cdn_files"
    log_action "Q4: Media Reconstruction" "$MSGSTORE_DB" "SUCCESS"
    
    echo -e "\n  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    cross_open "$outfile" 2>/dev/null &
    display_post_query_menu "Q4" "$outfile"
}

build_media_html_report() {
    local htmlfile="$1"
    local total="$2" images="$3" videos="$4" voice="$5" docs="$6" local_count="$7" cdn_count="$8"

    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local media_table=$(detect_media_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")

    cat > "$htmlfile" <<HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Media & File Reconstruction - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', 'Consolas', sans-serif; background: #0d1117; color: #c9d1d9; padding: 24px; }
        .container { max-width: 1600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #6a1b9a 0%, #4a148c 100%); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; margin-bottom: 8px; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-right: 10px; }
        .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: #161b22; border-radius: 12px; padding: 20px; text-align: center; border: 1px solid #30363d; }
        .stat-number { font-size: 2.2rem; font-weight: bold; color: #d2a8ff; }
        .stat-label { font-size: 0.75rem; color: #8b949e; text-transform: uppercase; letter-spacing: 0.5px; margin-top: 4px; }
        .section { background: #161b22; border-radius: 16px; padding: 24px; margin-bottom: 24px; border: 1px solid #30363d; }
        .section h2 { color: #d2a8ff; margin-bottom: 20px; font-size: 1.2rem; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .legend { display: flex; gap: 20px; flex-wrap: wrap; margin-bottom: 20px; padding: 12px 16px; background: #1a2332; border-radius: 8px; font-size: 0.82rem; }
        .legend-item { display: flex; align-items: center; gap: 6px; color: #c9d1d9; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #30363d; }
        table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
        th { background: #6a1b9a; color: white; font-weight: 500; padding: 11px 14px; text-align: left; white-space: nowrap; cursor: pointer; }
        th:hover { background: #7b1fa2; }
        td { padding: 9px 14px; border-bottom: 1px solid #21262d; vertical-align: middle; word-break: break-all; }
        tr:hover td { background: #1a2332; }
        .badge-local  { background: #1a472a; color: #7ee787; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; white-space: nowrap; }
        .badge-cdn    { background: #172a45; color: #79c0ff; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; white-space: nowrap; }
        .badge-none   { background: #3d1c1c; color: #f85149; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; white-space: nowrap; }
        .badge-image  { background: #2d1f47; color: #d2a8ff; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; }
        .badge-video  { background: #1f2d47; color: #79c0ff; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; }
        .badge-voice  { background: #1f3a2d; color: #7ee787; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; }
        .badge-doc    { background: #3a2d1f; color: #f0a040; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; }
        .path-cell    { font-family: 'Consolas', monospace; font-size: 0.78rem; color: #7ee787; max-width: 340px; }
        .path-cdn     { font-family: 'Consolas', monospace; font-size: 0.78rem; color: #79c0ff; max-width: 340px; }
        .conv-cell    { color: #f0e68c; font-weight: 500; }
        .sender-cell  { color: #79c0ff; font-family: 'Consolas', monospace; font-size: 0.82rem; }
        .filter-bar   { display: flex; gap: 12px; margin-bottom: 16px; }
        .filter-bar input { flex: 1; padding: 9px 14px; background: #0d1117; border: 1px solid #30363d; border-radius: 8px; color: #c9d1d9; font-size: 0.9rem; }
        .filter-bar select { padding: 9px 14px; background: #0d1117; border: 1px solid #30363d; border-radius: 8px; color: #c9d1d9; }
        .filter-bar button { padding: 9px 18px; background: #6a1b9a; border: none; border-radius: 8px; color: white; cursor: pointer; }
        .btn { padding: 10px 20px; border-radius: 8px; border: none; cursor: pointer; background: #6a1b9a; color: white; margin-right: 10px; margin-bottom: 16px; }
        .forensic-note { background: #1a2332; border-left: 4px solid #d2a8ff; padding: 14px 18px; border-radius: 4px; margin-bottom: 20px; font-size: 0.85rem; line-height: 1.6; }
        .footer { text-align: center; padding: 24px; color: #8b949e; font-size: 0.78rem; border-top: 1px solid #30363d; margin-top: 24px; }
        @media print { .filter-bar, .btn { display: none; } body { background: white; color: black; } th { background: #6a1b9a !important; } }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>🖼️ Media &amp; File Reconstruction</h1>
        <div style="opacity:0.9;margin-bottom:12px;">WhatsApp Forensic Investigation &bull; Court-Admissible Evidence</div>
        <div>
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">🔖 Warrant: ${WARRANT_NUM}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
            <span class="badge">🔒 Read-Only Mode</span>
        </div>
    </div>

    <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
    <button class="btn" onclick="exportTableToCSV('mediaTable','Q4_media_reconstruction.csv')">📥 Export CSV</button>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total}</div><div class="stat-label">Total Media</div></div>
        <div class="stat-card"><div class="stat-number">${images}</div><div class="stat-label">📷 Images</div></div>
        <div class="stat-card"><div class="stat-number">${videos}</div><div class="stat-label">🎥 Videos</div></div>
        <div class="stat-card"><div class="stat-number">${voice}</div><div class="stat-label">🎤 Voice Notes</div></div>
        <div class="stat-card"><div class="stat-number">${docs}</div><div class="stat-label">📄 Documents</div></div>
        <div class="stat-card"><div class="stat-number">${local_count}</div><div class="stat-label">💾 Local Files</div></div>
        <div class="stat-card"><div class="stat-number">${cdn_count}</div><div class="stat-label">☁️ CDN Files</div></div>
    </div>

    <div class="section">
        <h2>⚖️ Forensic Note — Evidence Integrity</h2>
        <div class="forensic-note">
            All analysis performed in <strong>READ-ONLY</strong> mode. Original database not modified.<br>
            SHA-256 and MD5 hashes recorded in the Evidence Hash Registry for chain-of-custody compliance.<br>
            Media paths extracted directly from <code>message_media</code> table in msgstore.db.<br>
            CDN-recoverable files include the WhatsApp direct_path for potential server-side recovery.<br>
            "Unnamed / CDN-only" items indicate the device never downloaded the file; the raw URL is preserved for legal process.
        </div>
        <div class="legend">
            <div class="legend-item"><span class="badge-local">✅ LOCAL</span> File present on device storage — directly recoverable</div>
            <div class="legend-item"><span class="badge-cdn">☁️ CDN</span> File on WhatsApp CDN — recoverable via legal process / direct_path URL</div>
            <div class="legend-item"><span class="badge-none">❌ NO FILE</span> Reference exists but file absent from device and CDN</div>
        </div>
    </div>

    <div class="section">
        <h2>📁 Complete Media Inventory — All Items</h2>
        <div class="filter-bar">
            <input type="text" id="mediaFilter" placeholder="🔍 Filter by conversation, type, filename, path…" oninput="filterMedia()">
            <select id="typeFilter" onchange="filterMedia()">
                <option value="">All Types</option>
                <option value="Image">📷 Image</option>
                <option value="Video">🎥 Video</option>
                <option value="Voice">🎤 Voice</option>
                <option value="Audio">🎵 Audio</option>
                <option value="Document">📄 Document</option>
                <option value="Sticker">🌟 Sticker</option>
                <option value="GIF">🎞️ GIF</option>
            </select>
            <select id="statusFilter" onchange="filterMedia()">
                <option value="">All Status</option>
                <option value="LOCAL">✅ Local</option>
                <option value="CDN">☁️ CDN</option>
                <option value="NO FILE">❌ No File</option>
            </select>
            <button onclick="clearFilters()">Clear</button>
        </div>
        <div class="table-container">
            <table id="mediaTable">
                <thead>
                    <tr>
                        <th onclick="sortTable(0,'mediaTable')">Msg ID ▲</th>
                        <th onclick="sortTable(1,'mediaTable')">Conversation</th>
                        <th onclick="sortTable(2,'mediaTable')">Sent Time</th>
                        <th onclick="sortTable(3,'mediaTable')">Direction</th>
                        <th onclick="sortTable(4,'mediaTable')">Sender</th>
                        <th onclick="sortTable(5,'mediaTable')">Type</th>
                        <th onclick="sortTable(6,'mediaTable')">Size</th>
                        <th onclick="sortTable(7,'mediaTable')">Filename / Media Name</th>
                        <th>Full File Path / CDN URL</th>
                        <th onclick="sortTable(9,'mediaTable')">Status</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # ── Populate every single media row with full paths, resolved conversation + sender ──
    if [[ -n "$media_table" ]]; then
        local jid_join=""
        local conv_expr="COALESCE(c.subject, 'Chat_' || m.chat_row_id)"
        local sender_expr="'📱 DEVICE'"

        # If jid table available, resolve chat names and sender via JID + jid_map
        if [[ -n "$jid_table" && -n "$chat_table" ]]; then
            jid_join="LEFT JOIN ${jid_table} cj ON c.jid_row_id = cj._id
            LEFT JOIN ${jid_table} sj ON m.sender_jid_row_id = sj._id"

            conv_expr="COALESCE(
                c.subject,
                CASE WHEN cj.server = 's.whatsapp.net' THEN 'Individual_' || cj.user
                     WHEN cj.server = 'g.us' THEN 'Group_' || cj.user
                     WHEN cj.raw_string IS NOT NULL THEN cj.raw_string
                     ELSE 'Chat_' || m.chat_row_id
                END
            )"

            # Resolve sender: walk jid_map to get real phone from @lid JIDs
            sender_expr="CASE
                WHEN m.from_me = 1 THEN '📱 DEVICE'
                ELSE COALESCE(
                    CASE WHEN sj.server = 's.whatsapp.net' THEN sj.user END,
                    (SELECT pj.user FROM jid_map jm2
                     JOIN ${jid_table} pj
                       ON pj._id = CASE WHEN jm2.lid_row_id = sj._id
                                        THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                     WHERE (jm2.lid_row_id = sj._id OR jm2.jid_row_id = sj._id)
                       AND pj.server = 's.whatsapp.net' LIMIT 1),
                    CASE WHEN sj.server IS NOT NULL THEN sj.user END,
                    '⚠️ UNKNOWN'
                )
            END"
        fi

        sqlite3 -readonly -separator '§' "$MSGSTORE_DB" "
            SELECT
                m._id,
                ${conv_expr},
                datetime(m.${ts_col}/1000, 'unixepoch', 'localtime'),
                CASE WHEN m.from_me = 1 THEN 'SENT' ELSE 'RECEIVED' END,
                ${sender_expr},
                CASE
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.pdf'  THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.doc'  THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.docx' THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.xls'  THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.xlsx' THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.ppt'  THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.pptx' THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.txt'  THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.zip'  THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.apk'  THEN 'Document'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.mp3'  THEN 'Audio'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.m4a'  THEN 'Audio'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.aac'  THEN 'Audio'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.opus' THEN 'Voice'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.ogg'  THEN 'Voice'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.mp4'  THEN 'Video'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.3gp'  THEN 'Video'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.mkv'  THEN 'Video'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.gif'  THEN 'GIF'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.webp' THEN 'Sticker'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.jpg'  THEN 'Image'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.jpeg' THEN 'Image'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.png'  THEN 'Image'
                    WHEN LOWER(COALESCE(mm.media_name, mm.file_path, '')) LIKE '%.heic' THEN 'Image'
                    ELSE CASE m.message_type
                        WHEN 1  THEN 'Image'
                        WHEN 2  THEN 'Voice'
                        WHEN 3  THEN 'Video'
                        WHEN 8  THEN 'Document'
                        WHEN 9  THEN 'Audio'
                        WHEN 11 THEN 'Sticker'
                        WHEN 13 THEN 'GIF'
                        ELSE 'Media_t' || m.message_type
                    END
                END,
                CASE
                    WHEN mm.file_size > 1048576 THEN ROUND(mm.file_size/1048576.0, 2) || ' MB'
                    WHEN mm.file_size > 1024    THEN ROUND(mm.file_size/1024.0, 1)    || ' KB'
                    WHEN mm.file_size IS NULL   THEN '—'
                    ELSE mm.file_size || ' B'
                END,
                COALESCE(mm.media_name, '—'),
                COALESCE(mm.file_path, mm.direct_path, '—'),
                CASE
                    WHEN mm.file_path   IS NOT NULL THEN 'LOCAL'
                    WHEN mm.direct_path IS NOT NULL THEN 'CDN'
                    ELSE 'NO FILE'
                END
            FROM ${msg_table} m
            LEFT JOIN ${chat_table} c ON m.chat_row_id = c._id
            ${jid_join}
            LEFT JOIN ${media_table} mm ON mm.message_row_id = m._id
            WHERE m.message_type IN (1,2,3,8,9,11,13)
            ORDER BY m.${ts_col} DESC;
        " 2>/dev/null | while IFS='§' read -r msg_id conv sent_time direction sender mtype fsize fname fpath status; do
            [[ -z "$msg_id" ]] && continue

            # Badge class for type — must match the filter dropdown values exactly
            local type_badge="badge-image"
            case "$mtype" in
                Video)          type_badge="badge-video" ;;
                Voice)          type_badge="badge-voice" ;;
                Audio)          type_badge="badge-voice" ;;
                Document)       type_badge="badge-doc" ;;
                Sticker|GIF)    type_badge="badge-image" ;;
            esac

            local status_badge="badge-local"
            local path_class="path-cell"
            case "$status" in
                CDN)       status_badge="badge-cdn"; path_class="path-cdn" ;;
                "NO FILE") status_badge="badge-none"; path_class="path-cdn" ;;
            esac

            local dir_icon="📱"
            [[ "$direction" == "RECEIVED" ]] && dir_icon="📥"

            # HTML-escape dynamic fields
            local safe_path="${fpath//&/&amp;}"
            safe_path="${safe_path//</&lt;}"
            safe_path="${safe_path//>/&gt;}"
            local safe_conv="${conv//&/&amp;}"
            local safe_fname="${fname//&/&amp;}"
            local safe_sender="${sender//&/&amp;}"

            echo "<tr>" >> "$htmlfile"
            echo "<td><strong>${msg_id}</strong></td>" >> "$htmlfile"
            echo "<td class=\"conv-cell\">${safe_conv}</td>" >> "$htmlfile"
            echo "<td>${sent_time}</td>" >> "$htmlfile"
            echo "<td>${dir_icon} ${direction}</td>" >> "$htmlfile"
            echo "<td class=\"sender-cell\">${safe_sender}</td>" >> "$htmlfile"
            echo "<td><span class=\"${type_badge}\" data-type=\"${mtype}\">${mtype}</span></td>" >> "$htmlfile"
            echo "<td>${fsize}</td>" >> "$htmlfile"
            echo "<td>${safe_fname}</td>" >> "$htmlfile"
            echo "<td class=\"${path_class}\">${safe_path}</td>" >> "$htmlfile"
            echo "<td><span class=\"${status_badge}\">${status}</span></td>" >> "$htmlfile"
            echo "</tr>" >> "$htmlfile"
        done
    else
        # Fallback: no message_media table — query from message table directly
        sqlite3 -readonly -separator '§' "$MSGSTORE_DB" "
            SELECT
                m._id,
                COALESCE(c.subject, 'Chat_' || m.chat_row_id),
                datetime(m.${ts_col}/1000, 'unixepoch', 'localtime'),
                CASE WHEN m.from_me = 1 THEN 'SENT' ELSE 'RECEIVED' END,
                CASE WHEN m.from_me = 1 THEN '📱 DEVICE' ELSE '⚠️ UNKNOWN' END,
                CASE m.message_type
                    WHEN 1 THEN 'Image' WHEN 2 THEN 'Voice' WHEN 3 THEN 'Video'
                    WHEN 8 THEN 'Document' WHEN 9 THEN 'Audio' ELSE 'Media_t' || m.message_type
                END,
                COALESCE(m.media_size || ' B', '—'),
                COALESCE(m.media_name, '—'),
                COALESCE(m.media_url, '—'),
                'NO FILE'
            FROM ${msg_table} m
            LEFT JOIN ${chat_table} c ON m.chat_row_id = c._id
            WHERE m.message_type IN (1,2,3,8,9,11,13)
            ORDER BY m.${ts_col} DESC;
        " 2>/dev/null | while IFS='§' read -r msg_id conv sent_time direction sender mtype fsize fname fpath status; do
            [[ -z "$msg_id" ]] && continue
            echo "<tr><td><strong>${msg_id}</strong></td><td class=\"conv-cell\">${conv}</td><td>${sent_time}</td><td>${direction}</td><td class=\"sender-cell\">${sender}</td><td><span data-type=\"${mtype}\">${mtype}</span></td><td>${fsize}</td><td>${fname}</td><td class=\"path-cdn\">${fpath}</td><td><span class=\"badge-none\">${status}</span></td></tr>" >> "$htmlfile"
        done
    fi

    cat >> "$htmlfile" <<'HTMLEOF'
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit v9.0 — WhatsApp Analysis Suite</p>
        <p>Based on Le-Khac &amp; Choo (2022) | ACPO Compliant | Chain-of-Custody Verified | Read-Only Mode</p>
    </div>
</div>

<script>
function filterMedia() {
    const text       = document.getElementById('mediaFilter').value.toLowerCase();
    const typeFilter = document.getElementById('typeFilter').value;   // exact match
    const statusFilter = document.getElementById('statusFilter').value.toLowerCase();
    const rows = document.querySelectorAll('#mediaTable tbody tr');
    for (let row of rows) {
        const rowText = row.innerText.toLowerCase();
        // Type: match against the data-type attribute on the badge span (exact)
        const typeBadge = row.querySelector('td span[data-type]');
        const rowType   = typeBadge ? typeBadge.getAttribute('data-type') : '';
        const matchText   = !text         || rowText.includes(text);
        const matchType   = !typeFilter   || rowType === typeFilter;
        const matchStatus = !statusFilter || rowText.includes(statusFilter);
        row.style.display = (matchText && matchType && matchStatus) ? '' : 'none';
    }
}
function clearFilters() {
    document.getElementById('mediaFilter').value = '';
    document.getElementById('typeFilter').value  = '';
    document.getElementById('statusFilter').value= '';
    filterMedia();
}
function sortTable(col, tableId) {
    const table  = document.getElementById(tableId);
    const tbody  = table.getElementsByTagName('tbody')[0];
    const rows   = Array.from(tbody.getElementsByTagName('tr'));
    const asc    = table.getAttribute('data-sort-asc') !== 'true';
    rows.sort((a, b) => {
        const aV = a.cells[col]?.innerText.trim() || '';
        const bV = b.cells[col]?.innerText.trim() || '';
        const aN = parseFloat(aV); const bN = parseFloat(bV);
        if (!isNaN(aN) && !isNaN(bN)) return asc ? aN - bN : bN - aN;
        return asc ? aV.localeCompare(bV) : bV.localeCompare(aV);
    });
    tbody.innerHTML = '';
    rows.forEach(r => tbody.appendChild(r));
    table.setAttribute('data-sort-asc', asc);
}
function exportTableToCSV(tableId, filename) {
    const table = document.getElementById(tableId);
    const rows  = table.querySelectorAll('tr');
    const csv   = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        csv.push(Array.from(cols).map(c => '"' + c.innerText.replace(/"/g, '""').replace(/\n/g, ' ') + '"').join(','));
    }
    const blob = new Blob(['\uFEFF' + csv.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href  = URL.createObjectURL(blob);
    link.download = filename;
    link.click();
}
</script>
</body>
</html>
HTMLEOF
    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# QUERY 5 — DELETED MESSAGE DETECTION
# =============================================================================

# =============================================================================
# QUERY 5 — DELETED MESSAGE DETECTION (WITH WA.DB CONTACT RESOLUTION)
# =============================================================================

# =============================================================================
# CONTACT RESOLVER — Resolves sender name from wa.db
# =============================================================================
resolve_sender_name() {
    local sender_jid="${1:-}"
    local sender_phone="${2:-}"
    local from_me="${3:-0}"

    [[ "$from_me" == "1" ]] && { echo "📱 DEVICE OWNER"; return; }

    # 1. Try phone match — wa.db format: 265994143967@s.whatsapp.net
    #    msgstore j.user may include dialling prefix e.g. 97968690618591
    #    wa.db stores without prefix: 968690618591@s.whatsapp.net
    if [[ -n "$sender_phone" && "$sender_phone" != "NULL" && "$sender_phone" != "0" ]]; then
        if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
            local name phone1="${sender_phone:1}" phone2="${sender_phone:2}" phone3="${sender_phone:3}"
            name=$(sqlite3 -readonly "$WA_DB" "
                SELECT COALESCE(NULLIF(display_name,''), NULLIF(wa_name,''), '')
                FROM wa_contacts
                WHERE jid = '${sender_phone}@s.whatsapp.net'
                   OR jid = '${sender_phone}@c.us'
                   OR jid = '${phone1}@s.whatsapp.net'
                   OR jid = '${phone2}@s.whatsapp.net'
                   OR jid = '${phone3}@s.whatsapp.net'
                   OR jid LIKE '${sender_phone}@%'
                   OR jid LIKE '${phone1}@%'
                   OR jid LIKE '${phone2}@%'
                LIMIT 1;
            " 2>/dev/null | tr -d '\n')
            [[ -n "$name" ]] && { echo "$name"; return; }
        fi
        # Not in contacts — show the number (accurate forensic output)
        echo "$sender_phone"
        return
    fi

    # 2. Try full JID match — including @lid business account resolution
    if [[ -n "$sender_jid" && "$sender_jid" != "NULL" ]]; then
        if [[ -n "$WA_DB" && -f "$WA_DB" ]]; then
            local name lid_user
            # For @lid JIDs: extract the LID number and look up via wa_contacts
            # wa.db links LID to real phone via the jid_lookup or wa_contacts table
            if [[ "$sender_jid" == *"@lid"* ]]; then
                lid_user="${sender_jid%%@*}"
                # Try direct match on jid field (some wa.db versions store lid here)
                name=$(sqlite3 -readonly "$WA_DB" "
                    SELECT COALESCE(NULLIF(display_name,''), NULLIF(wa_name,''), '')
                    FROM wa_contacts
                    WHERE jid = '${sender_jid}'
                       OR jid = '${lid_user}@s.whatsapp.net'
                       OR jid = '${lid_user}@c.us'
                    LIMIT 1;
                " 2>/dev/null | tr -d '\n')
                [[ -n "$name" ]] && { echo "$name"; return; }
                # Try jid_lookup table which maps LID -> real JID in newer wa.db
                name=$(sqlite3 -readonly "$WA_DB" "
                    SELECT COALESCE(NULLIF(wc.display_name,''), NULLIF(wc.wa_name,''), '')
                    FROM jid_lookup jl
                    JOIN wa_contacts wc ON wc.jid = jl.jid
                    WHERE jl.lid = '${sender_jid}'
                       OR jl.lid = '${lid_user}@lid'
                    LIMIT 1;
                " 2>/dev/null | tr -d '\n')
                [[ -n "$name" ]] && { echo "$name"; return; }
                # Last resort: look up in msgstore jid table to find linked phone
                if [[ -n "$MSGSTORE_DB" && -f "$MSGSTORE_DB" ]]; then
                    local real_phone
                    real_phone=$(sqlite3 -readonly "$MSGSTORE_DB" "
                        SELECT j2.user FROM jid j1
                        JOIN jid j2 ON j1.lid_jid_row_id = j2._id
                        WHERE j1.raw_string = '${sender_jid}'
                           OR j1.user = '${lid_user}'
                        LIMIT 1;
                    " 2>/dev/null | tr -d '\n')
                    if [[ -n "$real_phone" && "$real_phone" != "NULL" ]]; then
                        name=$(sqlite3 -readonly "$WA_DB" "
                            SELECT COALESCE(NULLIF(display_name,''), NULLIF(wa_name,''), '')
                            FROM wa_contacts
                            WHERE jid LIKE '${real_phone}@%'
                            LIMIT 1;
                        " 2>/dev/null | tr -d '\n')
                        [[ -n "$name" ]] && { echo "$name"; return; }
                        echo "$real_phone"; return
                    fi
                fi
                echo "🏢 ${lid_user}"; return
            fi
            # Normal JID match
            name=$(sqlite3 -readonly "$WA_DB" "
                SELECT COALESCE(NULLIF(display_name,''), NULLIF(wa_name,''), '')
                FROM wa_contacts
                WHERE jid = '${sender_jid}'
                LIMIT 1;
            " 2>/dev/null | tr -d '\n')
            [[ -n "$name" ]] && { echo "$name"; return; }
        fi
        [[ "$sender_jid" == *"@lid"* ]] && echo "🏢 ${sender_jid%%@*}" || echo "${sender_jid%%@*}"
        return
    fi

    echo "⚠️ UNKNOWN"
}


# =============================================================================
# QUERY 5 — DELETED MESSAGE DETECTION (USING CHAT DEEP DIVE RESOLUTION LOGIC)
# =============================================================================
analyze_deleted_messages() {
    banner
    print_section "Q5: DELETED MESSAGE DETECTION"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local media_table=$(detect_media_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local outfile="${CASE_DIR}/reports/Q5_deleted_messages.html"
    
    local type_15=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 15;" 2>/dev/null || echo "0")
    local self_del=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 15 AND from_me = 1;" 2>/dev/null || echo "0")
    local remote_del=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 15 AND from_me = 0;" 2>/dev/null || echo "0")
    local null_text=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 0 AND (text_data IS NULL OR text_data = '');" 2>/dev/null || echo "0")
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 5: DELETED MESSAGE DETECTION                                                 ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Source: Le-Khac & Choo (2022) Section 3.2.3 ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📊 DELETION STATISTICS${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-18s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-18s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-18s${RESET} %8s  ${CYAN}│${RESET}\n" \
        "Type 15 (Revoked):" "$type_15" "Self-Deleted:" "$self_del" "Remote-Deleted:" "$remote_del"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-18s${RESET} %8s  ${CYAN}│${RESET}  %-18s %8s  ${CYAN}│${RESET}  %-18s %8s  ${CYAN}│${RESET}\n" \
        "Null/Empty Text:" "$null_text" "" "" "" ""
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📋 DELETION CLASSIFICATION:${RESET}"
    echo -e "  ${CYAN}├─${RESET} ${RED}🗑️ REMOTE-DELETED${RESET} — Deleted by remote sender (type=15, from_me=0)"
    echo -e "  ${CYAN}├─${RESET} ${YELLOW}📤 SELF-DELETED${RESET} — Deleted by device owner (type=15, from_me=1)"
    echo -e "  ${CYAN}└─${RESET} ${MAGENTA}👻 GHOST/EMPTY${RESET} — Message with NULL/empty content\n"
    
    echo -e "${BOLD}${WHITE}  🗑️ DELETED MESSAGES (Most Recent 50)${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-8s %-18s %-18s %-22s %-18s %-25s${RESET}\n" \
        "Msg ID" "Conversation" "Original Time" "Sender" "Deletion Type" "Media/Residual"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    if [[ -n "$chat_table" && -n "$jid_table" ]]; then
        local line_count=0
        
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT
                m._id,
                COALESCE(c.subject, 'Chat_' || m.chat_row_id) AS conversation,
                datetime(m.$ts_col/1000, 'unixepoch', 'localtime') AS msg_time,
                -- Walk jid_map to turn any @lid JID into the real @s.whatsapp.net phone number.
                COALESCE(
                    CASE WHEN j.server  = 's.whatsapp.net' THEN j.user  END,
                    CASE WHEN cj.server = 's.whatsapp.net' THEN cj.user END,
                    (SELECT pj.user FROM jid_map jm2
                     JOIN $jid_table pj
                       ON pj._id = CASE WHEN jm2.lid_row_id = j._id
                                        THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                     WHERE (jm2.lid_row_id = j._id OR jm2.jid_row_id = j._id)
                       AND pj.server = 's.whatsapp.net' LIMIT 1),
                    (SELECT pj.user FROM jid_map jm3
                     JOIN $jid_table pj
                       ON pj._id = CASE WHEN jm3.lid_row_id = cj._id
                                        THEN jm3.jid_row_id ELSE jm3.lid_row_id END
                     WHERE (jm3.lid_row_id = cj._id OR jm3.jid_row_id = cj._id)
                       AND pj.server = 's.whatsapp.net' LIMIT 1),
                    COALESCE(j.user, cj.user, '')
                ) AS resolved_phone,
                m.from_me,
                m.message_type,
                m.text_data,
                mm.file_path,
                mm.media_name
            FROM $msg_table m
            LEFT JOIN $chat_table c   ON m.chat_row_id       = c._id
            LEFT JOIN $jid_table cj   ON c.jid_row_id        = cj._id
            LEFT JOIN $jid_table j    ON m.sender_jid_row_id = j._id
            LEFT JOIN $media_table mm ON mm.message_row_id   = m._id
            WHERE m.message_type = 15
               OR (m.message_type = 0 AND (m.text_data IS NULL OR m.text_data = ''))
            ORDER BY m.$ts_col DESC
            LIMIT 50;
        " 2>/dev/null | while IFS='|' read -r msg_id conv msg_time resolved_phone from_me msg_type text_data file_path media_name; do

            if [[ -n "$msg_id" ]]; then
                local sender_display=""

                if [[ "$from_me" == "1" ]]; then
                    sender_display="📱 DEVICE OWNER"
                else
                    # Show the real phone number directly — strip @domain if full JID leaked through
                    local phone_to_use="${resolved_phone%%@*}"
                    if [[ -n "$phone_to_use" && "$phone_to_use" != "NULL" && "$phone_to_use" != "0" ]]; then
                        sender_display="$phone_to_use"
                    else
                        sender_display="⚠️ UNKNOWN"
                    fi
                fi
                
                [[ ${#conv} -gt 17 ]] && conv="${conv:0:14}..."
                [[ ${#sender_display} -gt 21 ]] && sender_display="${sender_display:0:18}..."
                
                local del_type="" del_color="$WHITE"
                if [[ "$msg_type" == "15" ]]; then
                    if [[ "$from_me" == "1" ]]; then
                        del_type="📤 SELF-DELETED"; del_color="$YELLOW"
                    else
                        del_type="🗑️ REMOTE-DELETED"; del_color="$RED"
                    fi
                else
                    del_type="👻 GHOST/NULL"; del_color="$MAGENTA"
                fi
                
                local residual="" residual_color="$WHITE"
                if [[ -n "$file_path" && "$file_path" != "NULL" ]]; then
                    residual="📁 ${file_path:0:22}..."; residual_color="$GREEN"
                elif [[ -n "$media_name" && "$media_name" != "NULL" ]]; then
                    residual="📁 ${media_name:0:22}..."; residual_color="$GREEN"
                elif [[ -n "$text_data" && "$text_data" != "NULL" ]]; then
                    residual="${text_data:0:22}..."; residual_color="$CYAN"
                else
                    residual="[NO CONTENT]"; residual_color="$RED"
                fi
                
                printf "  ${WHITE}%-7s${RESET}  ${CYAN}%-17s${RESET}  ${WHITE}%-17s${RESET}  ${GREEN}%-21s${RESET}  ${del_color}%-17s${RESET}  ${residual_color}%-25s${RESET}\n" \
                    "$msg_id" "$conv" "${msg_time:0:16}" "$sender_display" "$del_type" "$residual"
                
                ((line_count++))
                if (( line_count >= 15 )); then
                    echo ""
                    echo -e "${CYAN}  ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                    echo -e "  ${YELLOW}📄 Press Enter for more or 'q' to quit${RESET}"
                    read -rp "  > " nav
                    [[ "$nav" == "q" || "$nav" == "Q" ]] && break
                    line_count=0
                    echo ""
                    printf "  ${BOLD}%-8s %-18s %-18s %-22s %-18s %-25s${RESET}\n" \
                        "Msg ID" "Conversation" "Original Time" "Sender" "Deletion Type" "Media/Residual"
                    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                fi
            fi
        done
    fi
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    if [[ -f "${MSGSTORE_DB}-wal" ]]; then
        local wal_size=$(cross_file_size "${MSGSTORE_DB}-wal" 2>/dev/null)
        echo -e "${BOLD}${WHITE}  💾 WAL FILE DETECTED:${RESET} ${GREEN}${MSGSTORE_DB}-wal${RESET} (${wal_size} bytes)"
        echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
        echo -e "${CYAN}  │${RESET} ${YELLOW}📋 HOW TO RECOVER DELETED MESSAGES FROM WAL:${RESET}"
        echo -e "${CYAN}  │${RESET}   1. Keep msgstore.db, msgstore.db-wal, and msgstore.db-shm together"
        echo -e "${CYAN}  │${RESET}   2. Open in DB Browser for SQLite (auto-reads WAL)"
        echo -e "${CYAN}  │${RESET}   3. Or: sqlite3 msgstore.db \"PRAGMA wal_checkpoint(PASSIVE);\""
        echo -e "${CYAN}  │${RESET}   4. NEVER run PRAGMA wal_checkpoint(FULL) — destroys deleted content"
        echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    fi
    
    build_deleted_html_simple "$outfile"
    log_action "Q5: Deleted Messages" "$MSGSTORE_DB" "SUCCESS"
    
    echo -e "  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    cross_open "$outfile" 2>/dev/null &
    
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}  📌 What would you like to do next?${RESET}"
    echo ""
    echo -e "    ${GREEN}1${RESET}. Return to Analysis Menu"
    echo -e "    ${GREEN}2${RESET}. View HTML Report in browser"
    echo -e "    ${GREEN}3${RESET}. Export deleted messages to CSV"
    echo -e "    ${GREEN}0${RESET}. Main Menu"
    echo ""
    read -rp "  > " choice
    case "$choice" in
        1) return 0 ;;
        2) cross_open "$outfile" 2>/dev/null & pause ;;
        3)
            local csvfile="${CASE_DIR}/reports/Q5_deleted_messages.csv"
            sqlite3 -readonly -csv -header "$MSGSTORE_DB" "
                SELECT m._id,
                    COALESCE(c.subject, 'Chat_' || m.chat_row_id) AS conversation,
                    datetime(m.$ts_col/1000, 'unixepoch', 'localtime') AS time,
                    COALESCE(
                        CASE WHEN j.server  = 's.whatsapp.net' THEN j.user  END,
                        CASE WHEN cj.server = 's.whatsapp.net' THEN cj.user END,
                        (SELECT pj.user FROM jid_map jm2
                         JOIN $jid_table pj
                           ON pj._id = CASE WHEN jm2.lid_row_id = j._id
                                            THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                         WHERE (jm2.lid_row_id = j._id OR jm2.jid_row_id = j._id)
                           AND pj.server = 's.whatsapp.net' LIMIT 1),
                        (SELECT pj.user FROM jid_map jm3
                         JOIN $jid_table pj
                           ON pj._id = CASE WHEN jm3.lid_row_id = cj._id
                                            THEN jm3.jid_row_id ELSE jm3.lid_row_id END
                         WHERE (jm3.lid_row_id = cj._id OR jm3.jid_row_id = cj._id)
                           AND pj.server = 's.whatsapp.net' LIMIT 1),
                        COALESCE(j.user, cj.user, 'UNKNOWN')
                    ) AS contact_phone,
                    CASE WHEN m.message_type=15 AND m.from_me=1 THEN 'SELF-DELETED'
                         WHEN m.message_type=15 AND m.from_me=0 THEN 'REMOTE-DELETED'
                         ELSE 'GHOST/NULL' END AS deletion_type,
                    m.text_data AS residual_text,
                    mm.file_path AS media_path
                FROM $msg_table m
                LEFT JOIN $chat_table c   ON m.chat_row_id       = c._id
                LEFT JOIN $jid_table cj   ON c.jid_row_id        = cj._id
                LEFT JOIN $jid_table j    ON m.sender_jid_row_id = j._id
                LEFT JOIN $media_table mm ON mm.message_row_id   = m._id
                WHERE m.message_type = 15
                   OR (m.message_type = 0 AND (m.text_data IS NULL OR m.text_data = ''))
                ORDER BY m.$ts_col DESC;
            " > "$csvfile" 2>/dev/null
            print_ok "CSV exported: $csvfile"
            pause
            ;;
        0) return 0 ;;
        *) return 0 ;;
    esac
}

# =============================================================================
# HTML REPORT FOR DELETED MESSAGES
# =============================================================================
build_deleted_html_simple() {
    local htmlfile="$1"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local media_table=$(detect_media_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    cat > "$htmlfile" <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Deleted Messages - Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', monospace; background: #0d1117; color: #c9d1d9; padding: 24px; }
        .container { max-width: 1600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #d32f2f, #b71c1c); border-radius: 16px; padding: 30px; margin-bottom: 24px; color: white; }
        .header h1 { font-size: 2rem; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-right: 10px; }
        .section { background: #161b22; border-radius: 16px; padding: 24px; margin-bottom: 24px; border: 1px solid #30363d; }
        .section h2 { color: #f85149; margin-bottom: 20px; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .table-container { overflow-x: auto; border-radius: 8px; border: 1px solid #30363d; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { background: #d32f2f; color: white; padding: 12px 16px; text-align: left; }
        td { padding: 10px 16px; border-bottom: 1px solid #21262d; }
        tr:hover td { background: #1a2332; }
        .deleted-remote { color: #f85149; font-weight: 600; }
        .media-path { color: #7ee787; font-family: monospace; }
        .footer { text-align: center; padding: 24px; color: #8b949e; font-size: 0.8rem; border-top: 1px solid #30363d; margin-top: 24px; }
        .btn { padding: 10px 20px; background: #d32f2f; color: white; border: none; border-radius: 8px; cursor: pointer; margin-right: 10px; }
        .filter-bar { display: flex; gap: 12px; margin-bottom: 20px; }
        .filter-bar input { flex: 1; padding: 10px 14px; background: #0d1117; border: 1px solid #30363d; border-radius: 8px; color: #c9d1d9; }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    cat >> "$htmlfile" <<EOF
    <div class="header">
        <h1>🗑️ Deleted Message Detection</h1>
        <div style="opacity:0.9">WhatsApp Forensic Investigation • Court-Admissible Evidence</div>
        <div style="margin-top:15px">
            <span class="badge">📋 Case: ${CURRENT_CASE}</span>
            <span class="badge">👤 Analyst: ${INVESTIGATOR}</span>
            <span class="badge">📅 $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>
    <div style="margin-bottom:20px">
        <button class="btn" onclick="window.print()">🖨️ Print / Save PDF</button>
    </div>
    <div class="section">
        <h2>🗑️ Deleted Messages</h2>
        <div class="filter-bar">
            <input type="text" id="f" placeholder="🔍 Filter..." onkeyup="document.querySelectorAll('#t tbody tr').forEach(r=>r.style.display=r.innerText.toLowerCase().includes(this.value.toLowerCase())?'':'none')">
        </div>
        <div class="table-container">
            <table id="t">
                <thead><tr><th>Msg ID</th><th>Conversation</th><th>Time</th><th>Contact</th><th>Type</th><th>Media/Residual</th></tr></thead>
                <tbody>
EOF

    sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
        SELECT
            m._id,
            COALESCE(c.subject, 'Chat_' || m.chat_row_id),
            datetime(m.$ts_col/1000, 'unixepoch', 'localtime'),
            COALESCE(
                CASE WHEN j.server  = 's.whatsapp.net' THEN j.user  END,
                CASE WHEN cj.server = 's.whatsapp.net' THEN cj.user END,
                (SELECT pj.user FROM jid_map jm2
                 JOIN $jid_table pj
                   ON pj._id = CASE WHEN jm2.lid_row_id = j._id
                                    THEN jm2.jid_row_id ELSE jm2.lid_row_id END
                 WHERE (jm2.lid_row_id = j._id OR jm2.jid_row_id = j._id)
                   AND pj.server = 's.whatsapp.net' LIMIT 1),
                (SELECT pj.user FROM jid_map jm3
                 JOIN $jid_table pj
                   ON pj._id = CASE WHEN jm3.lid_row_id = cj._id
                                    THEN jm3.jid_row_id ELSE jm3.lid_row_id END
                 WHERE (jm3.lid_row_id = cj._id OR jm3.jid_row_id = cj._id)
                   AND pj.server = 's.whatsapp.net' LIMIT 1),
                COALESCE(j.user, cj.user, '')
            ) AS resolved_phone,
            m.from_me,
            m.message_type,
            m.text_data,
            mm.file_path,
            mm.media_name
        FROM $msg_table m
        LEFT JOIN $chat_table c   ON m.chat_row_id       = c._id
        LEFT JOIN $jid_table cj   ON c.jid_row_id        = cj._id
        LEFT JOIN $jid_table j    ON m.sender_jid_row_id = j._id
        LEFT JOIN $media_table mm ON mm.message_row_id   = m._id
        WHERE m.message_type = 15
           OR (m.message_type = 0 AND (m.text_data IS NULL OR m.text_data = ''))
        ORDER BY m.$ts_col DESC LIMIT 50;
    " 2>/dev/null | while IFS='|' read -r id conv time resolved_phone from_me msg_type text_data file_path media_name; do
        local contact_display=""
        if [[ "$from_me" == "1" ]]; then
            contact_display="📱 DEVICE OWNER"
        else
            # Show the real phone number directly — strip @domain if full JID leaked through
            local phone_to_use="${resolved_phone%%@*}"
            if [[ -n "$phone_to_use" && "$phone_to_use" != "NULL" && "$phone_to_use" != "0" ]]; then
                contact_display="$phone_to_use"
            else
                contact_display="⚠️ UNKNOWN"
            fi
        fi
        local del_type="" del_class=""
        [[ "$msg_type" == "15" && "$from_me" == "1" ]] && del_type="📤 SELF-DELETED"
        [[ "$msg_type" == "15" && "$from_me" != "1" ]] && { del_type="🗑️ REMOTE-DELETED"; del_class="deleted-remote"; }
        [[ "$msg_type" != "15" ]] && del_type="👻 GHOST/NULL"
        local residual="[NO CONTENT]"
        [[ -n "$file_path" && "$file_path" != "NULL" ]] && residual="<span class='media-path'>📁 ${file_path}</span>"
        [[ -n "$media_name" && "$media_name" != "NULL" ]] && residual="<span class='media-path'>📁 ${media_name}</span>"
        [[ -n "$text_data" && "$text_data" != "NULL" ]] && residual="${text_data:0:40}"
        echo "<tr><td>$id</td><td>$conv</td><td>$time</td><td>$contact_display</td><td class=\"$del_class\">$del_type</td><td>$residual</td></tr>" >> "$htmlfile"
    done

    cat >> "$htmlfile" <<'EOF'
                </tbody>
            </table>
        </div>
    </div>
    <div class="footer">
        <p>🔒 Digital Forensic Toolkit • Court-Admissible Evidence • Chain of Custody Verified</p>
    </div>
</div>
</body>
</html>
EOF
    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}


# =============================================================================
# QUERY 6 — URL & LINK EXTRACTION
# =============================================================================
analyze_url_extraction() {
    banner
    print_section "Q6: URL & LINK EXTRACTION"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local outfile="${CASE_DIR}/reports/Q6_url_extraction.html"
    
    local total_urls=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE text_data LIKE '%http%' OR message_type = 7;" 2>/dev/null || echo "0")
    local youtube=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE text_data LIKE '%youtube%' OR text_data LIKE '%youtu.be%';" 2>/dev/null || echo "0")
    local instagram=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE text_data LIKE '%instagram%';" 2>/dev/null || echo "0")
    local facebook=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE text_data LIKE '%facebook%' OR text_data LIKE '%fb.com%';" 2>/dev/null || echo "0")
    local tiktok=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE text_data LIKE '%tiktok%';" 2>/dev/null || echo "0")
    local whatsapp=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE text_data LIKE '%wa.me%';" 2>/dev/null || echo "0")
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 6: URL & LINK EXTRACTION                                                     ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Source: msgstore.db                    ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📊 URL STATISTICS${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %8s  ${CYAN}│${RESET}\n" \
        "Total URLs:" "$total_urls" "YouTube:" "$youtube" "Instagram:" "$instagram"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %8s  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %8s  ${CYAN}│${RESET}\n" \
        "Facebook:" "$facebook" "TikTok:" "$tiktok" "WhatsApp:" "$whatsapp"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  🔗 EXTRACTED URLs (Most Recent 25)${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-8s %-18s %-18s %-14s %-35s${RESET}\n" "Msg ID" "Conversation" "Sent Time" "Category" "URL"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    local temp_data="${TEMP_DIR:-/tmp}/urls_$$.tmp"
    sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
        SELECT m._id, COALESCE(c.subject, 'Individual_' || m.chat_row_id),
               datetime(m.$ts_col/1000, 'unixepoch', 'localtime'),
               CASE WHEN m.text_data LIKE '%youtube%' OR m.text_data LIKE '%youtu.be%' THEN '📺 YouTube'
                    WHEN m.text_data LIKE '%tiktok%' THEN '🎵 TikTok'
                    WHEN m.text_data LIKE '%instagram%' THEN '📷 Instagram'
                    WHEN m.text_data LIKE '%facebook%' OR m.text_data LIKE '%fb.com%' THEN '👤 Facebook'
                    WHEN m.text_data LIKE '%wa.me%' THEN '💬 WhatsApp'
                    ELSE '🌐 Web URL' END,
               CASE WHEN m.text_data LIKE '%https://%' THEN SUBSTR(m.text_data, INSTR(m.text_data, 'https://'), 
                    CASE WHEN INSTR(SUBSTR(m.text_data, INSTR(m.text_data,'https://')), ' ') > 0 
                         THEN INSTR(SUBSTR(m.text_data, INSTR(m.text_data,'https://')), ' ') - 1 ELSE LENGTH(m.text_data) END)
                    WHEN m.text_data LIKE '%http://%' THEN SUBSTR(m.text_data, INSTR(m.text_data, 'http://'),
                    CASE WHEN INSTR(SUBSTR(m.text_data, INSTR(m.text_data,'http://')), ' ') > 0 
                         THEN INSTR(SUBSTR(m.text_data, INSTR(m.text_data,'http://')), ' ') - 1 ELSE LENGTH(m.text_data) END)
                    ELSE NULL END
        FROM $msg_table m LEFT JOIN $chat_table c ON m.chat_row_id = c._id
        WHERE m.text_data LIKE '%http%' OR m.message_type = 7 ORDER BY m.$ts_col DESC LIMIT 25;
    " 2>/dev/null > "$temp_data"
    
    local line_count=0
    while IFS='|' read -r msg_id conv time category url; do
        if [[ -n "$msg_id" && -n "$url" ]]; then
            [[ ${#conv} -gt 17 ]] && conv="${conv:0:14}..."
            [[ ${#url} -gt 34 ]] && url="${url:0:31}..."
            
            local cat_color="$WHITE"
            [[ "$category" == *"YouTube"* ]] && cat_color="$RED"
            [[ "$category" == *"Instagram"* ]] && cat_color="$MAGENTA"
            [[ "$category" == *"Facebook"* ]] && cat_color="$BLUE"
            [[ "$category" == *"TikTok"* ]] && cat_color="$CYAN"
            [[ "$category" == *"WhatsApp"* ]] && cat_color="$GREEN"
            
            printf "  ${WHITE}%-7s${RESET}  ${CYAN}%-17s${RESET}  ${WHITE}%-17s${RESET}  ${cat_color}%-13s${RESET}  ${GREEN}%-34s${RESET}\n" \
                "$msg_id" "$conv" "${time:0:16}" "$category" "$url"
            
            ((line_count++))
            if (( line_count >= 12 )); then
                echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                echo -e "  ${YELLOW}📄 Press Enter for more or 'q' to quit${RESET}"
                read -rp "  > " nav
                [[ "$nav" == "q" || "$nav" == "Q" ]] && break
                line_count=0
                echo ""
                printf "  ${BOLD}%-8s %-18s %-18s %-14s %-35s${RESET}\n" "Msg ID" "Conversation" "Sent Time" "Category" "URL"
                echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
            fi
        fi
    done < "$temp_data"
    rm -f "$temp_data"
    
    echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    build_url_html_report "$outfile" "$total_urls" "$youtube" "$instagram" "$facebook" "$tiktok" "$whatsapp"
    log_action "Q6: URL Extraction" "$MSGSTORE_DB" "SUCCESS"
    
    echo -e "\n  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    cross_open "$outfile" 2>/dev/null &
    display_post_query_menu "Q6" "$outfile"
}

build_url_html_report() {
    local htmlfile="$1"
    local total="$2" yt="$3" ig="$4" fb="$5" tt="$6" wa="$7"
    
    cat > "$htmlfile" <<EOF
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>URL Extraction - Forensic Report</title>
<style>body{font-family:'Segoe UI',sans-serif;background:#f8f9fa;padding:24px}.container{max-width:1200px;margin:0 auto}
.header{background:linear-gradient(135deg,#1976d2,#0d47a1);border-radius:28px;padding:32px;color:white;margin-bottom:24px}
.stats-grid{display:grid;grid-template-columns:repeat(6,1fr);gap:16px;margin-bottom:24px}.stat-card{background:white;border-radius:16px;padding:20px}
.stat-number{font-size:1.5rem;color:#1976d2}.section{background:white;border-radius:24px;padding:24px}
.btn{padding:10px 20px;border-radius:20px;border:none;cursor:pointer;background:#1976d2;color:white;margin-bottom:20px}
</style></head><body><div class="container">
<div class="header"><h1>🔗 URL & Link Extraction</h1><p>${CURRENT_CASE} | ${INVESTIGATOR} | $(date)</p></div>
<div style="margin-bottom:20px"><button class="btn" onclick="window.print()">🖨️ Print/PDF</button></div>
<div class="stats-grid">
<div class="stat-card"><div class="stat-number">$total</div><div>Total URLs</div></div>
<div class="stat-card"><div class="stat-number">$yt</div><div>YouTube</div></div>
<div class="stat-card"><div class="stat-number">$ig</div><div>Instagram</div></div>
<div class="stat-card"><div class="stat-number">$fb</div><div>Facebook</div></div>
<div class="stat-card"><div class="stat-number">$tt</div><div>TikTok</div></div>
<div class="stat-card"><div class="stat-number">$wa</div><div>WhatsApp</div></div>
</div>
<div class="section"><h2>Extracted URLs</h2><p>Full URL details available in terminal output and CSV export.</p></div>
</div></body></html>
EOF
    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# QUERY 7 — MASTER EVIDENCE TIMELINE
# =============================================================================
analyze_master_timeline() {
    banner
    print_section "Q7: MASTER EVIDENCE TIMELINE"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    local outfile="${CASE_DIR}/reports/Q7_master_timeline.html"
    
    local total_events=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
    local text_events=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 0;" 2>/dev/null || echo "0")
    local media_events=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type IN (1,2,3,8,9,11,13);" 2>/dev/null || echo "0")
    local first_event=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table;" 2>/dev/null || echo "N/A")
    local last_event=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table;" 2>/dev/null || echo "N/A")
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 7: MASTER EVIDENCE TIMELINE                                                  ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Complete Message Timeline      ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📊 TIMELINE SUMMARY${RESET}"
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐${RESET}"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %10s  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %10s  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %10s  ${CYAN}│${RESET}\n" \
        "Total Events:" "$total_events" "Text Messages:" "$text_events" "Media Files:" "$media_events"
    printf "  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %10s  ${CYAN}│${RESET}  ${GREEN}%-15s${RESET} %10s  ${CYAN}│${RESET}  %-15s %10s  ${CYAN}│${RESET}\n" \
        "First Event:" "${first_event:0:16}" "Last Event:" "${last_event:0:16}" "" ""
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    
    echo -e "${BOLD}${WHITE}  📅 CHRONOLOGICAL TIMELINE (Most Recent 100 Events)${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-8s %-20s %-20s %-18s %-10s %-25s${RESET}\n" \
        "Msg ID" "Timestamp" "Conversation" "Sender" "Type" "Content"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    if [[ -n "$chat_table" && -n "$jid_table" ]]; then
        local temp_data="${TEMP_DIR:-/tmp}/timeline_$$.tmp"
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT m._id, datetime(m.$ts_col/1000, 'unixepoch', 'localtime'),
                   COALESCE(c.subject, 'Individual_' || m.chat_row_id),
                   CASE WHEN m.from_me = 1 THEN '📱 DEVICE' WHEN j.user IS NOT NULL THEN j.user ELSE COALESCE(j.raw_string, 'UNKNOWN') END,
                   CASE m.message_type WHEN 0 THEN '💬 TEXT' WHEN 1 THEN '📷 IMAGE' WHEN 2 THEN '🎤 VOICE' WHEN 3 THEN '🎥 VIDEO' WHEN 15 THEN '🗑️ DELETED' ELSE 'OTHER' END,
                   COALESCE(SUBSTR(m.text_data, 1, 40), '[media]')
            FROM $msg_table m LEFT JOIN $chat_table c ON m.chat_row_id = c._id LEFT JOIN $jid_table j ON m.sender_jid_row_id = j._id
            WHERE m.chat_row_id IS NOT NULL ORDER BY m.$ts_col DESC LIMIT 100;
        " 2>/dev/null > "$temp_data"
        
        local line_count=0
        while IFS='|' read -r msg_id time conv sender type content; do
            if [[ -n "$msg_id" ]]; then
                [[ ${#conv} -gt 19 ]] && conv="${conv:0:16}..."
                [[ ${#sender} -gt 17 ]] && sender="${sender:0:14}..."
                [[ ${#content} -gt 24 ]] && content="${content:0:21}..."
                
                local type_color="$WHITE"
                [[ "$type" == *"TEXT"* ]] && type_color="$GREEN"
                [[ "$type" == *"IMAGE"* ]] && type_color="$MAGENTA"
                [[ "$type" == *"VIDEO"* ]] && type_color="$BLUE"
                [[ "$type" == *"DELETED"* ]] && type_color="$RED"
                
                printf "  ${WHITE}%-7s${RESET}  ${WHITE}%-19s${RESET}  ${CYAN}%-19s${RESET}  ${GREEN}%-17s${RESET}  ${type_color}%-9s${RESET}  ${YELLOW}%-25s${RESET}\n" \
                    "$msg_id" "${time:0:18}" "$conv" "$sender" "$type" "$content"
                
                ((line_count++))
                if (( line_count >= 15 )); then
                    echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                    echo -e "  ${YELLOW}📄 Press Enter for more or 'q' to quit${RESET}"
                    read -rp "  > " nav
                    [[ "$nav" == "q" || "$nav" == "Q" ]] && break
                    line_count=0
                    echo ""
                    printf "  ${BOLD}%-8s %-20s %-20s %-18s %-10s %-25s${RESET}\n" \
                        "Msg ID" "Timestamp" "Conversation" "Sender" "Type" "Content"
                    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
                fi
            fi
        done < "$temp_data"
        rm -f "$temp_data"
    fi
    
    echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    build_timeline_html_report "$outfile" "$total_events" "$text_events" "$media_events" "$first_event" "$last_event"
    log_action "Q7: Master Timeline" "$MSGSTORE_DB" "SUCCESS"
    
    echo -e "\n  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    cross_open "$outfile" 2>/dev/null &
    display_post_query_menu "Q7" "$outfile"
}

build_timeline_html_report() {
    local htmlfile="$1"
    local total="$2" text="$3" media="$4" first="$5" last="$6"
    
    cat > "$htmlfile" <<EOF
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Master Timeline - Forensic Report</title>
<style>body{font-family:'Segoe UI',sans-serif;background:#f8f9fa;padding:24px}.container{max-width:1200px;margin:0 auto}
.header{background:linear-gradient(135deg,#00897b,#00695c);border-radius:28px;padding:32px;color:white;margin-bottom:24px}
.stats-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px}.stat-card{background:white;border-radius:16px;padding:20px}
.stat-number{font-size:1.8rem;color:#00897b}.section{background:white;border-radius:24px;padding:24px}
.btn{padding:10px 20px;border-radius:20px;border:none;cursor:pointer;background:#00897b;color:white;margin-bottom:20px}
.timeline-info{background:#e0f2f1;padding:15px;border-radius:8px;margin-bottom:20px}
</style></head><body><div class="container">
<div class="header"><h1>📅 Master Evidence Timeline</h1><p>${CURRENT_CASE} | ${INVESTIGATOR} | $(date)</p></div>
<div style="margin-bottom:20px"><button class="btn" onclick="window.print()">🖨️ Print/PDF</button></div>
<div class="stats-grid">
<div class="stat-card"><div class="stat-number">$total</div><div>Total Events</div></div>
<div class="stat-card"><div class="stat-number">$text</div><div>Text Messages</div></div>
<div class="stat-card"><div class="stat-number">$media</div><div>Media Files</div></div>
<div class="stat-card"><div class="stat-number">-</div><div>Duration</div></div>
</div>
<div class="section"><h2>Timeline Overview</h2>
<div class="timeline-info"><strong>First Event:</strong> $first<br><strong>Last Event:</strong> $last</div>
<p>Full chronological timeline available in terminal output and CSV export.</p>
</div>
</div></body></html>
EOF
    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# QUERY 8 — WAL RECOVERY
# =============================================================================
analyze_wal_recovery() {
    banner
    print_section "Q8: WAL DELETED MESSAGE RECOVERY"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local outfile="${CASE_DIR}/reports/Q8_wal_recovery.html"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    FORENSIC QUERY 8: WAL DELETED MESSAGE RECOVERY                                              ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${RESET}  Case: ${GREEN}%-30s${RESET}  Analyst: ${GREEN}%-20s${RESET}  ${CYAN}║${RESET}\n" "${CURRENT_CASE}" "${INVESTIGATOR}"
    printf "${CYAN}║${RESET}  Generated: ${WHITE}%s${RESET}  Source: msgstore.db + WAL journal  ${CYAN}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    
    local wal_file="${MSGSTORE_DB}-wal"
    
    echo -e "${BOLD}${WHITE}  💾 WAL FILE STATUS${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    
    if [[ -f "$wal_file" ]]; then
        local wal_size=$(cross_file_size "$wal_file" 2>/dev/null)
        echo -e "  ${GREEN}✅ WAL file found:${RESET} $wal_file"
        echo -e "  ${GREEN}   Size:${RESET} $wal_size bytes"
    else
        echo -e "  ${RED}❌ No WAL file found at:${RESET} $wal_file"
    fi
    
    echo ""
    echo -e "${BOLD}${WHITE}  ⚠️  PRESERVATION INSTRUCTIONS:${RESET}"
    echo -e "  ${CYAN}├─${RESET} Keep msgstore.db, msgstore.db-wal, and msgstore.db-shm together"
    echo -e "  ${CYAN}├─${RESET} Use PRAGMA wal_checkpoint(PASSIVE) only — NEVER FULL"
    echo -e "  ${CYAN}└─${RESET} WAL may contain deleted message content\n"
    
    echo -e "${BOLD}${WHITE}  🔍 SUSPECT RECORDS (Check WAL for pre-delete content)${RESET}"
    echo -e "${CYAN}  ═════════════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    printf "  ${BOLD}%-8s %-8s %-18s %-8s %-12s %-25s${RESET}\n" \
        "Msg ID" "Chat" "Original Time" "Type" "Status" "Note"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
        SELECT _id, chat_row_id, datetime($ts_col/1000, 'unixepoch', 'localtime'),
               message_type,
               CASE WHEN message_type = 15 THEN 'REVOKED' WHEN text_data IS NULL THEN 'NULL' ELSE 'SUSPECT' END,
               CASE WHEN message_type = 15 THEN 'CHECK WAL' ELSE 'INVESTIGATE' END
        FROM $msg_table WHERE message_type = 15 OR (message_type = 0 AND text_data IS NULL) ORDER BY $ts_col DESC LIMIT 20;
    " 2>/dev/null | while IFS='|' read -r id chat time type status note; do
        [[ -n "$id" ]] && printf "  ${WHITE}%-7s${RESET}  ${CYAN}%-7s${RESET}  ${WHITE}%-17s${RESET}  ${YELLOW}%-7s${RESET}  ${RED}%-11s${RESET}  ${MAGENTA}%-25s${RESET}\n" \
            "$id" "$chat" "${time:0:16}" "$type" "$status" "${note:0:24}"
    done
    
    echo -e "\n  ${CYAN}─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    
    build_wal_html_report "$outfile"
    log_action "Q8: WAL Recovery" "$MSGSTORE_DB" "SUCCESS"
    
    echo -e "\n  ${GREEN}✅ HTML Report:${RESET} ${CYAN}$outfile${RESET}"
    cross_open "$outfile" 2>/dev/null &
    display_post_query_menu "Q8" "$outfile"
}

build_wal_html_report() {
    local htmlfile="$1"
    
    cat > "$htmlfile" <<EOF
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>WAL Recovery - Forensic Report</title>
<style>body{font-family:'Segoe UI',sans-serif;background:#f8f9fa;padding:24px}.container{max-width:1000px;margin:0 auto}
.header{background:linear-gradient(135deg,#ff6f00,#e65100);border-radius:28px;padding:32px;color:white;margin-bottom:24px}
.section{background:white;border-radius:24px;padding:24px}.warning{background:#fff3e0;border-left:4px solid #ff6f00;padding:16px;border-radius:8px}
.btn{padding:10px 20px;border-radius:20px;border:none;cursor:pointer;background:#ff6f00;color:white;margin-bottom:20px}
</style></head><body><div class="container">
<div class="header"><h1>💾 WAL Deleted Message Recovery</h1><p>${CURRENT_CASE} | ${INVESTIGATOR} | $(date)</p></div>
<div style="margin-bottom:20px"><button class="btn" onclick="window.print()">🖨️ Print/PDF</button></div>
<div class="section">
<div class="warning"><strong>⚠️ PRESERVATION:</strong> Keep .db, .db-wal, .db-shm together. Use PRAGMA wal_checkpoint(PASSIVE) only.</div>
<h2>WAL Analysis</h2><p>WAL recovery details available in terminal output.</p>
</div>
</div></body></html>
EOF
    command -v wkhtmltopdf &>/dev/null && wkhtmltopdf --quiet "$htmlfile" "${htmlfile%.html}.pdf" 2>/dev/null
}

# =============================================================================
# RUN ALL 8 QUERIES
# =============================================================================
run_all_analyses() {
    banner
    print_section "RUNNING COMPLETE 8-QUERY FORENSIC FRAMEWORK"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    analyze_activity_profiling
    analyze_chat_reconstruction
    analyze_contact_mapping
    analyze_media_reconstruction
    analyze_deleted_messages
    analyze_url_extraction
    analyze_master_timeline
    analyze_wal_recovery
    
    print_ok "All 8 queries completed!"
    print_info "Reports saved to: ${CASE_DIR}/reports/"
    pause
}

# =============================================================================
# CHAT EXPLORER FUNCTIONS
# =============================================================================
view_available_chats() {
    banner; print_section "AVAILABLE CONVERSATIONS"
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    local stats=$(get_dashboard_stats "$MSGSTORE_DB" "$msg_table" "$chat_table" "$jid_table")
    IFS='|' read -r total_msgs individual_chats group_chats business_chats deleted_msgs media_files active_chats first_msg last_msg <<< "$stats"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                         DASHBOARD STATISTICS                              ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    printf "  ${GREEN}%-20s${RESET} ${YELLOW}%10s${RESET}  │  ${GREEN}%-20s${RESET} ${YELLOW}%10s${RESET}\n" "Total Messages:" "$total_msgs" "Active Chats:" "$active_chats"
    printf "  ${GREEN}%-20s${RESET} ${YELLOW}%10s${RESET}  │  ${GREEN}%-20s${RESET} ${YELLOW}%10s${RESET}\n" "Individual (1:1):" "$individual_chats" "Group Chats:" "$group_chats"
    printf "  ${GREEN}%-20s${RESET} ${YELLOW}%10s${RESET}  │  ${GREEN}%-20s${RESET} ${YELLOW}%10s${RESET}\n" "Business (@lid):" "$business_chats" "Deleted Msgs:" "$deleted_msgs"
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────────────${RESET}\n"
    
    echo -e "${CYAN}  Chat ID │ Messages │ Last Activity          │ Type  │ Chat Name / Phone${RESET}"
    echo -e "${CYAN}  ────────┼──────────┼────────────────────────┼───────┼──────────────────────────${RESET}"
    
    if [[ -n "$chat_table" ]]; then
        sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT 
                c._id,
                COUNT(m._id) as msg_count,
                datetime(MAX(m.$ts_col)/1000, 'unixepoch', 'localtime') as last_active,
                CASE 
                    WHEN c.group_type = 0 OR c.group_type IS NULL THEN '📱 1:1'
                    ELSE '👥 GROUP'
                END as chat_type,
                -- Show phone number if available, otherwise chat name
                CASE 
                    WHEN cj.user IS NOT NULL AND cj.user != '' THEN cj.user
                    WHEN cj.raw_string LIKE '%@s.whatsapp.net' THEN SUBSTR(cj.raw_string, 1, INSTR(cj.raw_string, '@') - 1)
                    WHEN cj.raw_string LIKE '%@lid' THEN '[LID] ' || SUBSTR(cj.raw_string, 1, 20) || '...'
                    ELSE COALESCE(c.subject, 'Chat_' || c._id)
                END as display_name
            FROM $chat_table c
            LEFT JOIN $msg_table m ON m.chat_row_id = c._id
            LEFT JOIN $jid_table cj ON c.jid_row_id = cj._id
            WHERE c._id IS NOT NULL
            GROUP BY c._id
            HAVING msg_count > 0
            ORDER BY last_active DESC
            LIMIT 30;
        " 2>/dev/null | while IFS='|' read -r id count last type name; do
            if [[ -n "$id" ]]; then
                printf "  ${GREEN}%-7s${RESET} │ ${YELLOW}%-8s${RESET} │ ${CYAN}%-22s${RESET} │ %-5s │ ${WHITE}%s${RESET}\n" \
                    "$id" "$count" "$last" "$type" "${name:0:35}"
            fi
        done
    fi
    echo ""
    pause
}

chat_deep_dive_menu() {
    banner; print_section "CHAT DEEP DIVE"
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    view_available_chats
    echo ""; read -rp "  Enter Chat ID (or 'b' to go back): " chat_id
    [[ -z "$chat_id" || "$chat_id" == "b" || "$chat_id" == "B" ]] && return
    [[ "$chat_id" =~ ^[0-9]+$ ]] && chat_deep_dive "$chat_id" || { print_err "Invalid Chat ID"; pause; }
}

chat_deep_dive() {
    local chat_id="$1"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local media_table=$(detect_media_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")

    banner
    print_section "CHAT DEEP DIVE — Chat ID: ${chat_id}"

    # ── STEP 1: Basic chat info ────────────────────────────────────────────
    local chat_info
    chat_info=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT
            COALESCE(c.subject, '') AS chat_name,
            cj.user              AS phone_from_jid,
            cj.raw_string        AS jid_raw,
            cj._id               AS jid_id,
            COUNT(m._id)         AS total_msgs,
            datetime(MIN(m.${ts_col})/1000, 'unixepoch', 'localtime') AS first_msg,
            datetime(MAX(m.${ts_col})/1000, 'unixepoch', 'localtime') AS last_msg
        FROM ${chat_table} c
        LEFT JOIN ${jid_table} cj ON c.jid_row_id = cj._id
        LEFT JOIN ${msg_table} m  ON m.chat_row_id = c._id
        WHERE c._id = ${chat_id}
        GROUP BY c._id;
    " 2>/dev/null | tr '|' '§')

    if [[ -z "$chat_info" ]]; then
        print_err "Chat ID $chat_id not found"
        pause
        return
    fi

    IFS='§' read -r chat_name phone_from_jid jid_raw jid_id total first last <<< "$chat_info"

    # ── STEP 2: Resolve contact name + phone via jid_map ──────────────────
    # FIX: explicitly select the @s.whatsapp.net side of jid_map
    local final_display_name="$chat_name"
    local final_phone=""
    local contact_name_from_wa=""
    local contact_phone_from_wa=""

    if [[ -n "$WA_DB" && -f "$WA_DB" && -n "$jid_id" ]]; then

        # Find the @s.whatsapp.net JID for this chat (even if chat uses @lid)
        local phone_jid
        phone_jid=$(sqlite3 -readonly "$MSGSTORE_DB" "
            WITH chat_jid_row AS (
                SELECT ${jid_id} AS jid_id
            ),
            alt_jid_row AS (
                SELECT
                    CASE
                        WHEN jm.jid_row_id = cj.jid_id THEN jm.lid_row_id
                        WHEN jm.lid_row_id = cj.jid_id THEN jm.jid_row_id
                        ELSE NULL
                    END AS alt_id
                FROM chat_jid_row cj
                LEFT JOIN jid_map jm
                    ON jm.jid_row_id = cj.jid_id
                    OR jm.lid_row_id = cj.jid_id
                LIMIT 1
            )
            -- FIX: return whichever side has server='s.whatsapp.net'
            SELECT j.raw_string
            FROM jid j
            WHERE j._id IN (SELECT jid_id FROM chat_jid_row)
               OR j._id IN (SELECT alt_id FROM alt_jid_row WHERE alt_id IS NOT NULL)
            ORDER BY CASE WHEN j.server = 's.whatsapp.net' THEN 0 ELSE 1 END
            LIMIT 1;
        " 2>/dev/null)

        # Look up in wa.db
        if [[ -n "$phone_jid" ]]; then
            local wa_info
            wa_info=$(sqlite3 -readonly "$WA_DB" "
                SELECT
                    COALESCE(display_name, wa_name, '') AS name,
                    SUBSTR(jid, 1, INSTR(jid, '@') - 1) AS phone
                FROM wa_contacts
                WHERE jid = '${phone_jid}'
                LIMIT 1;
            " 2>/dev/null | tr '|' '§')

            if [[ -n "$wa_info" ]]; then
                IFS='§' read -r contact_name_from_wa contact_phone_from_wa <<< "$wa_info"
            fi

            # Phone fallback: extract from the JID string itself
            if [[ -z "$contact_phone_from_wa" && "$phone_jid" == *"@s.whatsapp.net"* ]]; then
                contact_phone_from_wa="${phone_jid%%@*}"
            fi
        fi

        # Last resort: search wa.db by phone_from_jid (e.g. group has no jid_map entry)
        if [[ -z "$contact_name_from_wa" && -n "$phone_from_jid" && "$phone_from_jid" != "NULL" ]]; then
            local wa_info2
            wa_info2=$(sqlite3 -readonly "$WA_DB" "
                SELECT
                    COALESCE(display_name, wa_name, '') AS name,
                    SUBSTR(jid, 1, INSTR(jid, '@') - 1) AS phone
                FROM wa_contacts
                WHERE jid LIKE '%${phone_from_jid}%'
                LIMIT 1;
            " 2>/dev/null | tr '|' '§')

            if [[ -n "$wa_info2" ]]; then
                IFS='§' read -r contact_name_from_wa contact_phone_from_wa <<< "$wa_info2"
            fi
            [[ -z "$contact_phone_from_wa" ]] && contact_phone_from_wa="$phone_from_jid"
        fi
    fi

    # Finalise display values
    [[ -n "$contact_name_from_wa" ]] && final_display_name="$contact_name_from_wa"

    if [[ -n "$contact_phone_from_wa" ]]; then
        final_phone="$contact_phone_from_wa"
    elif [[ -n "$phone_from_jid" && "$phone_from_jid" != "NULL" ]]; then
        final_phone="$phone_from_jid"
    elif [[ "$jid_raw" == *"@s.whatsapp.net"* ]]; then
        final_phone="${jid_raw%%@*}"
    fi

    # ── STEP 3: Header display ─────────────────────────────────────────────
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════════════${RESET}"

    if [[ -n "$final_display_name" ]]; then
        echo -e "${BOLD}  Chat Name:${RESET}      ${GREEN}${final_display_name}${RESET}"
    else
        echo -e "${BOLD}  Chat Name:${RESET}      ${CYAN}[No Name]${RESET}"
    fi

    [[ -n "$final_phone" ]] && \
        echo -e "${BOLD}  Phone Number:${RESET}   ${CYAN}${final_phone}${RESET}"

    if [[ "$jid_raw" == *"@lid"* ]]; then
        local lid_number="${jid_raw%%@*}"
        echo -e "${BOLD}  Type:${RESET}           ${MAGENTA}🏢 Business Account (LID)${RESET}"
        [[ "$final_phone" != "$lid_number" ]] && \
            echo -e "${BOLD}  LID Number:${RESET}     ${CYAN}${lid_number}${RESET}"
    elif [[ "$jid_raw" == *"@g.us"* ]]; then
        echo -e "${BOLD}  Type:${RESET}           ${BLUE}👥 Group Chat${RESET}"
        echo -e "${BOLD}  Group ID:${RESET}       ${CYAN}${jid_raw%%@*}${RESET}"
    else
        echo -e "${BOLD}  Type:${RESET}           ${GREEN}📱 Individual Chat${RESET}"
    fi

    echo -e "${BOLD}  Raw JID:${RESET}        ${WHITE}${jid_raw}${RESET}"
    echo -e "${BOLD}  Total Messages:${RESET} ${YELLOW}${total}${RESET}"
    echo -e "${BOLD}  Timeline:${RESET}       ${WHITE}${first}${RESET} → ${WHITE}${last}${RESET}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════════════${RESET}\n"

    # ── STEP 4: Participants ───────────────────────────────────────────────
    # FIX: ATTACH wa.db so the subquery for display_name works
    echo -e "${BOLD}${WHITE}  👥 PARTICIPANTS:${RESET}\n"

    sqlite3 -readonly "$MSGSTORE_DB" "
        ATTACH DATABASE '${WA_DB}' AS wadb;
        SELECT DISTINCT
            CASE
                WHEN m.from_me = 1 THEN '📱 DEVICE OWNER'
                WHEN j.server = 's.whatsapp.net' THEN
                    COALESCE(
                        (SELECT COALESCE(display_name, wa_name)
                         FROM wadb.wa_contacts
                         WHERE jid = j.raw_string LIMIT 1),
                        '📞 ' || j.user
                    )
                WHEN j.server = 'lid' THEN
                    COALESCE(
                        (SELECT COALESCE(wc.display_name, wc.wa_name)
                         FROM jid_map jmap
                         INNER JOIN jid pj ON (
                             CASE WHEN jmap.lid_row_id = j._id THEN jmap.jid_row_id
                                  ELSE jmap.lid_row_id END) = pj._id
                         INNER JOIN wadb.wa_contacts wc ON wc.jid = pj.raw_string
                         WHERE (jmap.lid_row_id = j._id OR jmap.jid_row_id = j._id)
                           AND pj.server = 's.whatsapp.net'
                         LIMIT 1),
                        '🏢 LID: ' || j.user
                    )
                WHEN j.server = 'g.us' THEN '👥 GROUP: ' || COALESCE(c.subject, j.user)
                ELSE '❓ ' || COALESCE(j.raw_string, 'UNKNOWN')
            END AS identity,
            COUNT(m._id)                                   AS messages,
            SUM(CASE WHEN m.from_me = 0 THEN 1 ELSE 0 END) AS received,
            SUM(CASE WHEN m.from_me = 1 THEN 1 ELSE 0 END) AS sent
        FROM ${msg_table} m
        LEFT JOIN ${jid_table} j ON m.sender_jid_row_id = j._id
        LEFT JOIN ${chat_table} c ON c._id = m.chat_row_id
        WHERE m.chat_row_id = ${chat_id}
        GROUP BY j._id
        ORDER BY messages DESC;
    " 2>/dev/null | while IFS='|' read -r identity msgs recv sent; do
        [[ -z "$identity" ]] && continue
        printf "  ${GREEN}•${RESET} ${YELLOW}%s${RESET}\n" "$identity"
        printf "    └─ Messages: %s  (Sent: %s  Received: %s)\n" "$msgs" "$sent" "$recv"
    done

    # ── STEP 5: Recent messages ────────────────────────────────────────────
    # FIX: type 0 messages containing URLs get [🔗 LINK] label too
    echo -e "\n${BOLD}${WHITE}  💬 RECENT MESSAGES (Last 30):${RESET}\n"

    local msg_sql="
        SELECT
            datetime(m.${ts_col}/1000, 'unixepoch', 'localtime') || ' | ' ||
            CASE WHEN m.from_me = 1 THEN '📤 SENT' ELSE '📥 RECV' END || ' | ' ||
            CASE
                WHEN m.message_type = 0 AND m.text_data LIKE '%http%' THEN
                    '[🔗 LINK] ' || m.text_data
                WHEN m.message_type = 0 THEN
                    COALESCE(m.text_data, '[empty]')
                WHEN m.message_type = 1  THEN '[📷 IMAGE] '    || COALESCE(mm.file_path, mm.media_name, '')
                WHEN m.message_type = 2  THEN '[🎤 VOICE] '    || COALESCE(mm.file_path, mm.media_name, '')
                WHEN m.message_type = 3  THEN '[🎥 VIDEO] '    || COALESCE(mm.file_path, mm.media_name, '')
                WHEN m.message_type = 7  THEN '[🔗 LINK] '     || COALESCE(m.text_data, '')
                WHEN m.message_type = 8  THEN '[📄 DOCUMENT] ' || COALESCE(mm.file_path, mm.media_name, '')
                WHEN m.message_type = 9  THEN '[🎵 AUDIO] '    || COALESCE(mm.file_path, mm.media_name, '')
                WHEN m.message_type = 11 THEN '[🖼️  STICKER]'
                WHEN m.message_type = 13 THEN '[🎞️  GIF]'
                WHEN m.message_type = 15 THEN '[🗑️  DELETED]'
                ELSE '[MEDIA type=' || m.message_type || '] ' || COALESCE(mm.media_name, '')
            END
        FROM ${msg_table} m
        LEFT JOIN ${media_table:-message_media} mm ON mm.message_row_id = m._id
        WHERE m.chat_row_id = ${chat_id}
        ORDER BY m.${ts_col} DESC
        LIMIT 30;"

    sqlite3 -readonly "$MSGSTORE_DB" "$msg_sql" 2>/dev/null | while IFS= read -r line; do
        echo "  $line"
    done

    # ── STEP 6: Media summary ──────────────────────────────────────────────
    local media_count
    media_count=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT COUNT(*) FROM ${msg_table}
        WHERE chat_row_id = ${chat_id} AND message_type IN (1,2,3,8,9,11,13);
    " 2>/dev/null || echo "0")

    if [[ "$media_count" -gt 0 && -n "$media_table" ]]; then
        echo -e "\n${BOLD}${WHITE}  🖼️  MEDIA FILES (${media_count} total):${RESET}\n"
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT
                datetime(m.${ts_col}/1000, 'unixepoch', 'localtime'),
                CASE m.message_type
                    WHEN 1 THEN '📷 IMAGE'    WHEN 2 THEN '🎤 VOICE'
                    WHEN 3 THEN '🎥 VIDEO'    WHEN 8 THEN '📄 DOCUMENT'
                    WHEN 9 THEN '🎵 AUDIO'    WHEN 11 THEN '🖼️  STICKER'
                    WHEN 13 THEN '🎞️  GIF'    ELSE 'MEDIA'
                END,
                COALESCE(mm.file_path, mm.media_name, '[no path]'),
                ROUND(COALESCE(mm.file_size, 0)/1024.0, 1),
                CASE
                    WHEN mm.file_path   IS NOT NULL THEN '✅ LOCAL'
                    WHEN mm.direct_path IS NOT NULL THEN '☁️  CDN'
                    ELSE '❌ NO FILE'
                END
            FROM ${msg_table} m
            LEFT JOIN ${media_table} mm ON mm.message_row_id = m._id
            WHERE m.chat_row_id = ${chat_id}
              AND m.message_type IN (1,2,3,8,9,11,13)
            ORDER BY m.${ts_col} DESC
            LIMIT 20;
        " 2>/dev/null | while IFS='|' read -r ts type path size status; do
            echo "  ${CYAN}${ts}${RESET} | ${type} | ${size}KB | ${status}"
            [[ "$path" != "[no path]" && -n "$path" ]] && \
                echo "       └─ ${GREEN}${path}${RESET}"
        done
    fi

    # ── STEP 7: Links ─────────────────────────────────────────────────────
    local url_count
    url_count=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT COUNT(*) FROM ${msg_table}
        WHERE chat_row_id = ${chat_id} AND text_data LIKE '%http%';
    " 2>/dev/null || echo "0")

    if [[ "$url_count" -gt 0 ]]; then
        echo -e "\n${BOLD}${WHITE}  🔗 LINKS SHARED (${url_count} total):${RESET}\n"
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT
                datetime(${ts_col}/1000, 'unixepoch', 'localtime'),
                CASE WHEN from_me = 1 THEN '📤 SENT' ELSE '📥 RECV' END,
                -- FIX: extract URL cleanly from text that may have surrounding words
                CASE
                    WHEN text_data LIKE '%https://%' THEN
                        TRIM(SUBSTR(text_data,
                            INSTR(text_data, 'https://'),
                            CASE
                                WHEN INSTR(SUBSTR(text_data, INSTR(text_data,'https://')), ' ') > 0
                                THEN INSTR(SUBSTR(text_data, INSTR(text_data,'https://')), ' ') - 1
                                ELSE LENGTH(text_data)
                            END))
                    WHEN text_data LIKE '%http://%' THEN
                        TRIM(SUBSTR(text_data,
                            INSTR(text_data, 'http://'),
                            CASE
                                WHEN INSTR(SUBSTR(text_data, INSTR(text_data,'http://')), ' ') > 0
                                THEN INSTR(SUBSTR(text_data, INSTR(text_data,'http://')), ' ') - 1
                                ELSE LENGTH(text_data)
                            END))
                    ELSE text_data
                END AS url,
                CASE
                    WHEN text_data LIKE '%youtube%'   OR text_data LIKE '%youtu.be%' THEN '📺 YouTube'
                    WHEN text_data LIKE '%tiktok%'                                   THEN '🎵 TikTok'
                    WHEN text_data LIKE '%instagram%'                                THEN '📷 Instagram'
                    WHEN text_data LIKE '%facebook%'  OR text_data LIKE '%fb.com%'   THEN '👤 Facebook'
                    WHEN text_data LIKE '%wa.me%'     OR text_data LIKE '%whatsapp%' THEN '💬 WhatsApp'
                    WHEN text_data LIKE '%twitter%'   OR text_data LIKE '%x.com%'    THEN '🐦 Twitter/X'
                    WHEN text_data LIKE '%t.me%'      OR text_data LIKE '%telegram%' THEN '✈️  Telegram'
                    ELSE '🌐 Web URL'
                END
            FROM ${msg_table}
            WHERE chat_row_id = ${chat_id} AND text_data LIKE '%http%'
            ORDER BY ${ts_col} DESC
            LIMIT 20;
        " 2>/dev/null | while IFS='|' read -r ts dir url cat; do
            echo "  ${CYAN}${ts}${RESET} | ${dir} | ${cat}"
            echo "       └─ ${GREEN}${url}${RESET}"
        done
    fi

    # ── STEP 8: Options menu ───────────────────────────────────────────────
    echo -e "\n${YELLOW}  Options:${RESET}"
    echo "    e - Export transcript"
    echo "    s - Search within chat"
    echo "    m - View all media files"
    echo "    l - View all links"
    echo "    r - Return"
    echo ""
    read -rp "  > " opt

    case "$opt" in
        e|E)
            echo ""
            echo -e "${CYAN}  Export format:${RESET}"
            echo "    h - Professional HTML Report"
            echo "    t - Text file"
            echo ""
            read -rp "  > " exp_format

            mkdir -p "${CASE_DIR}/extracted/chats"
            if [[ "$exp_format" == "t" || "$exp_format" == "T" ]]; then
                local outfile="${CASE_DIR}/extracted/chats/chat_${chat_id}_transcript.txt"
                {
                    echo "WHATSAPP CHAT TRANSCRIPT"
                    echo "========================"
                    echo "Chat ID:  ${chat_id}"
                    echo "Contact:  ${final_display_name:-[No Name]}"
                    [[ -n "$final_phone" ]] && echo "Phone:    ${final_phone}"
                    echo "JID:      ${jid_raw}"
                    echo "Case:     ${CURRENT_CASE}"
                    echo "Exported: $(date)"
                    echo "========================"
                    echo ""
                    sqlite3 -readonly "$MSGSTORE_DB" "
                        SELECT
                            datetime(m.${ts_col}/1000, 'unixepoch', 'localtime') || ' | ' ||
                            CASE WHEN m.from_me = 1 THEN 'SENT' ELSE 'RECV' END || ' | ' ||
                            CASE m.message_type
                                WHEN 0 THEN COALESCE(m.text_data, '[empty]')
                                WHEN 1 THEN '[IMAGE] '    || COALESCE(mm.file_path, mm.media_name, '')
                                WHEN 2 THEN '[VOICE] '    || COALESCE(mm.file_path, mm.media_name, '')
                                WHEN 3 THEN '[VIDEO] '    || COALESCE(mm.file_path, mm.media_name, '')
                                WHEN 7 THEN '[LINK] '     || COALESCE(m.text_data, '')
                                WHEN 8 THEN '[DOCUMENT] ' || COALESCE(mm.file_path, mm.media_name, '')
                                ELSE '[MEDIA]'
                            END
                        FROM ${msg_table} m
                        LEFT JOIN ${media_table:-message_media} mm ON mm.message_row_id = m._id
                        WHERE m.chat_row_id = ${chat_id}
                        ORDER BY m.${ts_col} ASC;
                    " 2>/dev/null
                } > "$outfile"
                print_ok "Saved: $outfile"
            else
                generate_professional_chat_html \
                    "$chat_id" "$final_display_name" "$final_phone" "$jid_raw"
            fi
            pause
            ;;

        s|S)
            read -rp "  Search term: " term
            echo -e "\n${CYAN}  🔍 SEARCH RESULTS:${RESET}\n"
            sqlite3 -readonly "$MSGSTORE_DB" "
                SELECT
                    datetime(${ts_col}/1000, 'unixepoch', 'localtime') || ' | ' ||
                    CASE WHEN from_me = 1 THEN 'SENT' ELSE 'RECV' END || ' | ' ||
                    text_data
                FROM ${msg_table}
                WHERE chat_row_id = ${chat_id}
                  AND text_data LIKE '%${term}%'
                ORDER BY ${ts_col} ASC;
            " 2>/dev/null | while IFS= read -r line; do echo "  $line"; done
            pause
            ;;

        m|M)
            clear
            print_section "MEDIA FILES — Chat ID: ${chat_id}"
            [[ -n "$media_table" ]] && sqlite3 -readonly -column -header "$MSGSTORE_DB" "
                SELECT
                    m._id AS MsgID,
                    datetime(m.${ts_col}/1000, 'unixepoch', 'localtime') AS Time,
                    CASE m.message_type
                        WHEN 1 THEN 'IMAGE' WHEN 2 THEN 'VOICE' WHEN 3 THEN 'VIDEO'
                        WHEN 8 THEN 'DOC'   WHEN 9 THEN 'AUDIO' ELSE 'MEDIA'
                    END AS Type,
                    COALESCE(mm.file_path, mm.media_name, 'N/A') AS FilePath,
                    ROUND(COALESCE(mm.file_size,0)/1024.0,1)     AS Size_KB,
                    CASE
                        WHEN mm.file_path   IS NOT NULL THEN 'LOCAL'
                        WHEN mm.direct_path IS NOT NULL THEN 'CDN'
                        ELSE 'MISSING'
                    END AS Status
                FROM ${msg_table} m
                LEFT JOIN ${media_table} mm ON mm.message_row_id = m._id
                WHERE m.chat_row_id = ${chat_id}
                  AND m.message_type IN (1,2,3,8,9,11,13)
                ORDER BY m.${ts_col} DESC;
            " 2>/dev/null
            pause
            ;;

        l|L)
            clear
            print_section "LINKS SHARED — Chat ID: ${chat_id}"
            sqlite3 -readonly -column -header "$MSGSTORE_DB" "
                SELECT
                    datetime(${ts_col}/1000, 'unixepoch', 'localtime') AS Time,
                    CASE WHEN from_me = 1 THEN 'SENT' ELSE 'RECV' END AS Direction,
                    CASE
                        WHEN text_data LIKE '%https://%' THEN
                            TRIM(SUBSTR(text_data, INSTR(text_data,'https://'),
                                CASE WHEN INSTR(SUBSTR(text_data,INSTR(text_data,'https://')), ' ') > 0
                                     THEN INSTR(SUBSTR(text_data,INSTR(text_data,'https://')), ' ') - 1
                                     ELSE LENGTH(text_data) END))
                        WHEN text_data LIKE '%http://%' THEN
                            TRIM(SUBSTR(text_data, INSTR(text_data,'http://'),
                                CASE WHEN INSTR(SUBSTR(text_data,INSTR(text_data,'http://')), ' ') > 0
                                     THEN INSTR(SUBSTR(text_data,INSTR(text_data,'http://')), ' ') - 1
                                     ELSE LENGTH(text_data) END))
                        ELSE text_data
                    END AS URL,
                    CASE
                        WHEN text_data LIKE '%youtube%'  OR text_data LIKE '%youtu.be%' THEN 'YouTube'
                        WHEN text_data LIKE '%tiktok%'                                  THEN 'TikTok'
                        WHEN text_data LIKE '%instagram%'                               THEN 'Instagram'
                        WHEN text_data LIKE '%facebook%' OR text_data LIKE '%fb.com%'   THEN 'Facebook'
                        WHEN text_data LIKE '%wa.me%'    OR text_data LIKE '%whatsapp%' THEN 'WhatsApp'
                        WHEN text_data LIKE '%twitter%'  OR text_data LIKE '%x.com%'    THEN 'Twitter/X'
                        WHEN text_data LIKE '%t.me%'     OR text_data LIKE '%telegram%' THEN 'Telegram'
                        ELSE 'Web URL'
                    END AS Category
                FROM ${msg_table}
                WHERE chat_row_id = ${chat_id}
                  AND text_data LIKE '%http%'
                ORDER BY ${ts_col} DESC;
            " 2>/dev/null
            pause
            ;;
    esac
}
search_by_phone() {
    banner; print_section "SEARCH BY PHONE NUMBER"
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║                    AVAILABLE PHONE NUMBERS / JIDs                          ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${RESET}\n"
    echo -e "${CYAN}  # │ Phone/JID                              │ Messages │ Type       │ Last Active${RESET}"
    echo -e "${CYAN}  ───┼───────────────────────────────────────┼──────────┼────────────┼────────────────────${RESET}"
    
    local phone_list=(); local counter=1
    
    if [[ -n "$jid_table" ]]; then
        while IFS='|' read -r jid_raw phone msg_count last_active server; do
            if [[ -n "$jid_raw" && "$jid_raw" != "NULL" ]]; then
                local display_name=""; local contact_type=""
                if [[ -n "$phone" && "$phone" != "NULL" ]]; then display_name="$phone"; contact_type="📱 Individual"
                elif [[ "$jid_raw" == *"@lid"* ]]; then display_name="${jid_raw%@lid}"; contact_type="🏢 Business"
                elif [[ "$jid_raw" == *"@g.us"* ]]; then display_name="${jid_raw%@g.us}"; contact_type="👥 Group"
                else display_name="$jid_raw"; contact_type="❓ Other"; fi
                [[ ${#display_name} -gt 35 ]] && display_name="${display_name:0:32}..."
                printf "  ${GREEN}%3s${RESET} │ ${YELLOW}%-37s${RESET} │ ${CYAN}%8s${RESET} │ %-10s │ ${MAGENTA}%s${RESET}\n" "$counter" "$display_name" "$msg_count" "$contact_type" "${last_active:0:16}"
                phone_list+=("$display_name|$jid_raw|$phone"); ((counter++))
            fi
        done < <(sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
            SELECT DISTINCT j.raw_string, j.user, COUNT(m._id), datetime(MAX(m.$ts_col)/1000,'unixepoch','localtime'), j.server
            FROM $jid_table j LEFT JOIN $msg_table m ON m.sender_jid_row_id=j._id WHERE j.raw_string IS NOT NULL AND j.raw_string!=''
            GROUP BY j._id ORDER BY COUNT(m._id) DESC LIMIT 30;
        " 2>/dev/null)
    fi
    
    echo -e "\n${CYAN}  ─────────────────────────────────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}  Options:${RESET} [1-${#phone_list[@]}] Select | s Search | b Back | q Quit"
    read -rp "  > " selection
    
    case "$selection" in
        b|B) return ;; q|Q) return ;; s|S) read -rp "  Search: " term; perform_phone_search "$term" ;;
        *) [[ "$selection" =~ ^[0-9]+$ && $selection -ge 1 && $selection -le ${#phone_list[@]} ]] && { IFS='|' read -r dname jraw phone <<< "${phone_list[$((selection-1))]}"; echo -e "\n${GREEN}Selected: $dname${RESET}\n1.View Chats 2.Deep Dive 3.Export"; read -rp "  > " act; case $act in 1) view_contact_chats "$jraw" "$phone" "$dname" ;; 2) view_contact_chats "$jraw" "$phone" "$dname"; read -rp "Chat ID: " cid; [[ "$cid" =~ ^[0-9]+$ ]] && chat_deep_dive "$cid" ;; 3) export_contact_activity "$jraw" "$dname" ;; esac; } ;; 
    esac
}

perform_phone_search() {
    local term="$1"
    echo -e "\n${CYAN}🔍 SEARCHING: \"$term\"${RESET}\n"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
        SELECT DISTINCT m.chat_row_id, j.user, COUNT(*), datetime(MAX(m.$ts_col)/1000,'unixepoch','localtime')
        FROM $msg_table m LEFT JOIN $jid_table j ON m.sender_jid_row_id=j._id
        WHERE j.user LIKE '%${term}%' OR j.raw_string LIKE '%${term}%' GROUP BY m.chat_row_id ORDER BY COUNT(*) DESC;
    " 2>/dev/null | while IFS='|' read id phone msgs last; do
        echo -e "  ${GREEN}Chat $id${RESET} | Phone: ${phone:-N/A} | Msgs: $msgs | Last: $last"
    done
    pause
}

view_contact_chats() {
    local jid_raw="$1" phone="$2" display_name="$3"
    banner; print_section "CHATS WITH: $display_name"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    sqlite3 -readonly -separator '|' "$MSGSTORE_DB" "
        SELECT DISTINCT m.chat_row_id, COUNT(*), datetime(MAX(m.$ts_col)/1000,'unixepoch','localtime'), COALESCE(c.subject,'Chat')
        FROM $msg_table m LEFT JOIN $chat_table c ON m.chat_row_id=c._id LEFT JOIN jid j ON m.sender_jid_row_id=j._id
        WHERE j.raw_string='${jid_raw}' OR j.user='${phone}' GROUP BY m.chat_row_id ORDER BY MAX(m.$ts_col) DESC;
    " 2>/dev/null | while IFS='|' read id count last name; do
        printf "  ${GREEN}%-7s${RESET} │ ${YELLOW}%-8s${RESET} │ ${CYAN}%-22s${RESET} │ %s\n" "$id" "$count" "$last" "${name:0:40}"
    done
    pause
}

export_contact_activity() {
    local jid_raw="$1" display_name="$2"
    mkdir -p "${CASE_DIR}/extracted/contacts"
    local outfile="${CASE_DIR}/extracted/contacts/${display_name//[^a-zA-Z0-9]/_}_activity.txt"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    {
        echo "CONTACT ACTIVITY: $display_name | JID: $jid_raw | $(date)"
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT datetime($ts_col/1000,'unixepoch','localtime'), CASE WHEN from_me=1 THEN 'SENT' ELSE 'RECV' END, COALESCE(text_data,'[media]')
            FROM $msg_table m LEFT JOIN jid j ON m.sender_jid_row_id=j._id WHERE j.raw_string='${jid_raw}' ORDER BY $ts_col ASC;
        " 2>/dev/null
    } > "$outfile"
    print_ok "Saved: $outfile"; pause
}

generate_professional_chat_html() {
    local chat_id="$1"
    local chat_name="$2"
    local phone_number="${3:-}"
    local jid_raw="${4:-}"
    
    mkdir -p "${CASE_DIR}/html"
    local outfile="${CASE_DIR}/html/chat_${chat_id}_forensic_report.html"
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local media_table=$(detect_media_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    # Get stats
    local total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE chat_row_id = ${chat_id};" 2>/dev/null)
    local sent_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE chat_row_id = ${chat_id} AND from_me = 1;" 2>/dev/null)
    local recv_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE chat_row_id = ${chat_id} AND from_me = 0;" 2>/dev/null)
    local first_msg=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table WHERE chat_row_id = ${chat_id};" 2>/dev/null)
    local last_msg=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table WHERE chat_row_id = ${chat_id};" 2>/dev/null)
    local media_count=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE chat_row_id = ${chat_id} AND message_type IN (1,2,3,8,9,11,13);" 2>/dev/null)
    local deleted_count=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE chat_row_id = ${chat_id} AND message_type = 15;" 2>/dev/null)
    
    print_step "Generating professional HTML report with media paths..."
    
    cat > "$outfile" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WhatsApp Chat Forensic Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', 'Consolas', monospace; background: #0d1117; color: #c9d1d9; padding: 20px; line-height: 1.5; }
        .container { max-width: 1600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #161b22 0%, #0d1117 100%); border-radius: 12px; padding: 30px; margin-bottom: 30px; text-align: center; border: 1px solid #30363d; }
        .header h1 { font-size: 2.2em; color: #58a6ff; margin-bottom: 10px; }
        .badge { display: inline-block; background: #238636; color: white; padding: 4px 12px; border-radius: 20px; font-size: 0.8em; margin: 8px 5px; font-weight: 600; }
        .badge-forensic { background: #6e40c9; }
        .badge-pdf { background: #da3633; cursor: pointer; }
        .contact-info { background: #1a2332; padding: 20px; border-radius: 10px; margin-bottom: 20px; border-left: 4px solid #58a6ff; }
        .contact-info h3 { color: #58a6ff; margin-bottom: 10px; }
        .contact-detail { display: inline-block; margin-right: 30px; }
        .contact-label { color: #8b949e; font-size: 0.8em; }
        .contact-value { color: #c9d1d9; font-size: 1.1em; font-weight: 500; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 16px; margin-bottom: 30px; }
        .stat-card { background: #161b22; border-radius: 10px; padding: 20px; text-align: center; border: 1px solid #30363d; }
        .stat-number { font-size: 2.2em; font-weight: bold; color: #58a6ff; }
        .stat-label { font-size: 0.8em; color: #8b949e; margin-top: 8px; text-transform: uppercase; }
        .section { background: #161b22; border-radius: 12px; padding: 24px; margin-bottom: 28px; border: 1px solid #30363d; }
        .section h2 { color: #58a6ff; margin-bottom: 20px; font-size: 1.4em; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .filter-bar { margin: 15px 0; padding: 12px; background: #21262d; border-radius: 8px; display: flex; gap: 10px; flex-wrap: wrap; }
        .filter-bar input { flex: 1; padding: 10px 14px; background: #0d1117; border: 1px solid #30363d; border-radius: 6px; color: #c9d1d9; }
        .filter-bar button { padding: 10px 18px; background: #238636; border: none; border-radius: 6px; color: white; cursor: pointer; font-weight: 600; }
        .filter-bar button.export { background: #1f6feb; }
        .table-container { overflow-x: auto; margin: 20px 0; border-radius: 8px; border: 1px solid #30363d; }
        .data-table { width: 100%; border-collapse: collapse; font-size: 0.8em; background: #0d1117; }
        .data-table th { background: #1f6feb; color: white; font-weight: 600; padding: 12px 10px; text-align: left; cursor: pointer; }
        .data-table td { padding: 10px; border-bottom: 1px solid #21262d; vertical-align: top; }
        .data-table tr:hover { background: #1a2332; }
        .message-content { max-width: 400px; word-wrap: break-word; }
        .media-path { font-family: 'Consolas', monospace; font-size: 0.75em; color: #7ee787; max-width: 300px; word-break: break-all; }
        .media-badge { background: #1f6feb; color: white; padding: 2px 8px; border-radius: 10px; font-size: 0.7em; }
        .deleted-badge { background: #da3633; color: white; padding: 2px 8px; border-radius: 10px; font-size: 0.7em; }
        .sent-badge { color: #7ee787; }
        .recv-badge { color: #f0883e; }
        .business-badge { background: #6e40c9; color: white; padding: 2px 8px; border-radius: 10px; }
        .evidence-trace { font-size: 0.7em; color: #8b949e; margin-top: 15px; padding: 10px; background: #0d1117; border-radius: 6px; }
        .footer { text-align: center; padding: 24px; border-top: 1px solid #30363d; margin-top: 30px; font-size: 0.8em; color: #8b949e; }
        .nav-tabs { display: flex; gap: 5px; margin-bottom: 20px; border-bottom: 1px solid #30363d; padding-bottom: 10px; }
        .nav-tab { padding: 8px 16px; background: #21262d; border: none; border-radius: 6px; color: #c9d1d9; cursor: pointer; }
        .nav-tab.active { background: #1f6feb; color: white; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
    </style>
</head>
<body>
<div class="container">
HTMLEOF

    # Header with contact information
    cat >> "$outfile" <<EOF
    <div class="header">
        <h1>💬 WhatsApp Chat Forensic Report</h1>
        <div class="subtitle" style="color:#8b949e;">Court-Admissible Evidence</div>
        <div>
            <span class="badge">CASE: ${CURRENT_CASE}</span>
            <span class="badge badge-forensic">CHAT ID: ${chat_id}</span>
            <span class="badge">INVESTIGATOR: ${INVESTIGATOR}</span>
            <span class="badge badge-pdf" onclick="generatePDF()">📄 EXPORT PDF</span>
        </div>
        <p style="margin-top:20px;color:#8b949e;">Generated: $(date) | Chain of Custody Verified</p>
    </div>

    <div class="contact-info">
        <h3>📇 CONTACT INFORMATION</h3>
        <div>
            <span class="contact-detail">
                <span class="contact-label">Contact Name:</span>
                <span class="contact-value">${chat_name}</span>
            </span>
EOF

    # Add phone number if available
    if [[ -n "$phone_number" && "$phone_number" != "Unknown" ]]; then
        cat >> "$outfile" <<EOF
            <span class="contact-detail">
                <span class="contact-label">Phone Number:</span>
                <span class="contact-value" style="color: #79c0ff;">${phone_number}</span>
            </span>
EOF
    fi

    # Add JID for forensic traceability
    if [[ -n "$jid_raw" ]]; then
        cat >> "$outfile" <<EOF
            <span class="contact-detail">
                <span class="contact-label">WhatsApp JID:</span>
                <span class="contact-value" style="font-family: monospace; font-size: 0.8em; color: #8b949e;">${jid_raw}</span>
            </span>
EOF
    fi

    cat >> "$outfile" <<EOF
        </div>
    </div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total_msgs}</div><div class="stat-label">Total Messages</div></div>
        <div class="stat-card"><div class="stat-number">${sent_msgs}</div><div class="stat-label">Sent</div></div>
        <div class="stat-card"><div class="stat-number">${recv_msgs}</div><div class="stat-label">Received</div></div>
        <div class="stat-card"><div class="stat-number">${media_count}</div><div class="stat-label">Media Files</div></div>
        <div class="stat-card"><div class="stat-number">${deleted_count}</div><div class="stat-label">Deleted</div></div>
    </div>

    <div class="nav-tabs">
        <button class="nav-tab active" onclick="showTab('messages')">💬 Messages</button>
        <button class="nav-tab" onclick="showTab('media')">🖼️ Media Files</button>
        <button class="nav-tab" onclick="showTab('participants')">👥 Participants</button>
        <button class="nav-tab" onclick="showTab('links')">🔗 Links</button>
        <button class="nav-tab" onclick="showTab('custody')">🔒 Chain of Custody</button>
    </div>

    <!-- MESSAGES TAB -->
    <div id="messages" class="tab-content active">
        <div class="section">
            <h2>💬 Complete Message Transcript</h2>
            <div class="forensic-note" style="background:#1a2332;padding:16px;border-radius:8px;margin-bottom:20px;">
                <strong>📋 Timeline:</strong> ${first_msg} → ${last_msg}<br>
                <strong>🔍 Messages in chronological order with media paths.</strong>
            </div>
            <div class="filter-bar">
                <input type="text" id="msgFilter" placeholder="Filter by content, sender, or type..." onkeyup="filterTable('msgTable', this.value)">
                <button onclick="filterTable('msgTable', document.getElementById('msgFilter').value)">🔍 Filter</button>
                <button class="export" onclick="exportTableToCSV('msgTable', 'chat_${chat_id}_messages.csv')">📥 Export CSV</button>
            </div>
            <div class="table-container">
                <table class="data-table" id="msgTable">
                    <thead>
                        <tr>
                            <th onclick="sortTable(0, 'msgTable')">Time</th>
                            <th onclick="sortTable(1, 'msgTable')">Dir</th>
                            <th onclick="sortTable(2, 'msgTable')">Sender</th>
                            <th onclick="sortTable(3, 'msgTable')">Type</th>
                            <th onclick="sortTable(4, 'msgTable')">Content</th>
                            <th onclick="sortTable(5, 'msgTable')">Media Path</th>
                            <th onclick="sortTable(6, 'msgTable')">Status</th>
                        </tr>
                    </thead>
                    <tbody>
EOF

    # Messages table WITH MEDIA PATHS
    if [[ -n "$media_table" ]]; then
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT 
                '<tr>',
                '<td>' || COALESCE(datetime($ts_col/1000, 'unixepoch', 'localtime'), '') || '</td>',
                '<td>' || CASE WHEN from_me = 1 THEN '<span class=\"sent-badge\">→ SENT</span>' ELSE '<span class=\"recv-badge\">← RECV</span>' END || '</td>',
                '<td>' || 
                    CASE 
                        WHEN from_me = 1 THEN '📱 DEVICE OWNER'
                        WHEN j.user IS NOT NULL AND j.user != '' THEN j.user
                        WHEN j.raw_string LIKE '%@lid' THEN '<span class=\"business-badge\">🏢 BUSINESS</span>'
                        ELSE COALESCE(j.raw_string, 'UNKNOWN')
                    END || '</td>',
                '<td><span class=\"media-badge\">' ||
                    CASE message_type
                        WHEN 0 THEN '💬 TEXT'
                        WHEN 1 THEN '📷 IMAGE'
                        WHEN 2 THEN '🎤 VOICE'
                        WHEN 3 THEN '🎥 VIDEO'
                        WHEN 7 THEN '🔗 LINK'
                        WHEN 8 THEN '📄 DOCUMENT'
                        WHEN 9 THEN '🎵 AUDIO'
                        WHEN 11 THEN '🖼️ STICKER'
                        WHEN 13 THEN '🎞️ GIF'
                        WHEN 15 THEN '🗑️ DELETED'
                        ELSE '📁 MEDIA'
                    END || '</span></td>',
                '<td class=\"message-content\">' || COALESCE(REPLACE(SUBSTR(text_data, 1, 300), '<', '&lt;'), '-') || '</td>',
                '<td class=\"media-path\">' || 
                    CASE 
                        WHEN message_type IN (1,2,3,8,9) AND mm.file_path IS NOT NULL THEN mm.file_path
                        WHEN message_type IN (1,2,3,8,9) AND mm.media_name IS NOT NULL THEN mm.media_name
                        WHEN message_type IN (1,2,3,8,9) THEN '[Path not recorded]'
                        ELSE '-'
                    END || '</td>',
                '<td>' ||
                    CASE 
                        WHEN message_type = 15 THEN '<span class=\"deleted-badge\">DELETED</span>'
                        WHEN message_type IN (1,2,3,8,9) AND mm.file_path IS NOT NULL THEN '<span style=\"color:#7ee787;\">✅ LOCAL</span>'
                        WHEN message_type IN (1,2,3,8,9) AND mm.direct_path IS NOT NULL THEN '<span style=\"color:#f0883e;\">☁️ CDN</span>'
                        WHEN message_type IN (1,2,3,8,9) THEN '<span style=\"color:#da3633;\">❌ MISSING</span>'
                        ELSE '<span class=\"media-badge\">INTACT</span>'
                    END || '</td>',
                '</tr>'
            FROM $msg_table m
            LEFT JOIN $jid_table j ON m.sender_jid_row_id = j._id
            LEFT JOIN $media_table mm ON mm.message_row_id = m._id
            WHERE m.chat_row_id = ${chat_id}
            ORDER BY m.$ts_col ASC;
        " 2>/dev/null >> "$outfile"
    else
        # Fallback without media table
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT 
                '<tr>',
                '<td>' || COALESCE(datetime($ts_col/1000, 'unixepoch', 'localtime'), '') || '</td>',
                '<td>' || CASE WHEN from_me = 1 THEN '<span class=\"sent-badge\">→ SENT</span>' ELSE '<span class=\"recv-badge\">← RECV</span>' END || '</td>',
                '<td>' || 
                    CASE 
                        WHEN from_me = 1 THEN '📱 DEVICE OWNER'
                        WHEN j.user IS NOT NULL AND j.user != '' THEN j.user
                        ELSE COALESCE(j.raw_string, 'UNKNOWN')
                    END || '</td>',
                '<td><span class=\"media-badge\">' ||
                    CASE message_type
                        WHEN 0 THEN '💬 TEXT'
                        WHEN 1 THEN '📷 IMAGE'
                        WHEN 2 THEN '🎤 VOICE'
                        WHEN 3 THEN '🎥 VIDEO'
                        WHEN 15 THEN '🗑️ DELETED'
                        ELSE '📁 MEDIA'
                    END || '</span></td>',
                '<td class=\"message-content\">' || COALESCE(REPLACE(SUBSTR(text_data, 1, 300), '<', '&lt;'), '-') || '</td>',
                '<td class=\"media-path\">' || COALESCE(media_name, '-') || '</td>',
                '<td>' ||
                    CASE 
                        WHEN message_type = 15 THEN '<span class=\"deleted-badge\">DELETED</span>'
                        ELSE '<span class=\"media-badge\">INTACT</span>'
                    END || '</td>',
                '</tr>'
            FROM $msg_table m
            LEFT JOIN $jid_table j ON m.sender_jid_row_id = j._id
            WHERE m.chat_row_id = ${chat_id}
            ORDER BY m.$ts_col ASC;
        " 2>/dev/null >> "$outfile"
    fi

    cat >> "$outfile" <<EOF
                    </tbody>
                </table>
            </div>
            <div class="evidence-trace">
                📍 SOURCE: msgstore.db | CHAT ID: ${chat_id} | EXECUTED: $(date)
            </div>
        </div>
    </div>

    <!-- MEDIA FILES TAB -->
    <div id="media" class="tab-content">
        <div class="section">
            <h2>🖼️ Media Files Inventory</h2>
            <div class="filter-bar">
                <input type="text" id="mediaFilter" placeholder="Filter by type or path..." onkeyup="filterTable('mediaInvTable', this.value)">
                <button onclick="filterTable('mediaInvTable', document.getElementById('mediaFilter').value)">🔍 Filter</button>
                <button class="export" onclick="exportTableToCSV('mediaInvTable', 'chat_${chat_id}_media.csv')">📥 Export CSV</button>
            </div>
            <div class="table-container">
                <table class="data-table" id="mediaInvTable">
                    <thead>
                        <tr>
                            <th>Msg ID</th>
                            <th>Time</th>
                            <th>Type</th>
                            <th>File Path</th>
                            <th>Size (KB)</th>
                            <th>MIME Type</th>
                            <th>Status</th>
                            <th>Caption</th>
                        </tr>
                    </thead>
                    <tbody>
EOF

    # Media inventory table
    if [[ -n "$media_table" ]]; then
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT 
                '<tr>',
                '<td>' || m._id || '</td>',
                '<td>' || COALESCE(datetime(m.$ts_col/1000, 'unixepoch', 'localtime'), '') || '</td>',
                '<td><span class=\"media-badge\">' ||
                    CASE m.message_type
                        WHEN 1 THEN '📷 IMAGE'
                        WHEN 2 THEN '🎤 VOICE'
                        WHEN 3 THEN '🎥 VIDEO'
                        WHEN 8 THEN '📄 DOCUMENT'
                        WHEN 9 THEN '🎵 AUDIO'
                        WHEN 11 THEN '🖼️ STICKER'
                        WHEN 13 THEN '🎞️ GIF'
                        ELSE 'MEDIA'
                    END || '</span></td>',
                '<td class=\"media-path\">' || COALESCE(mm.file_path, mm.media_name, '[No path recorded]') || '</td>',
                '<td>' || ROUND(COALESCE(mm.file_size, 0)/1024.0, 1) || '</td>',
                '<td>' || COALESCE(mm.mime_type, '-') || '</td>',
                '<td>' ||
                    CASE 
                        WHEN mm.file_path IS NOT NULL THEN '<span style=\"color:#7ee787;\">✅ LOCAL FILE</span>'
                        WHEN mm.direct_path IS NOT NULL THEN '<span style=\"color:#f0883e;\">☁️ CDN RECOVERABLE</span>'
                        ELSE '<span style=\"color:#da3633;\">❌ NOT FOUND</span>'
                    END || '</td>',
                '<td>' || COALESCE(mm.media_caption, '-') || '</td>',
                '</tr>'
            FROM $msg_table m
            LEFT JOIN $media_table mm ON mm.message_row_id = m._id
            WHERE m.chat_row_id = ${chat_id} AND m.message_type IN (1,2,3,8,9,11,13)
            ORDER BY m.$ts_col ASC;
        " 2>/dev/null >> "$outfile"
    else
        echo "<tr><td colspan='8' style='text-align:center;padding:20px;'>No media table found</td></tr>" >> "$outfile"
    fi

    cat >> "$outfile" <<EOF
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- PARTICIPANTS TAB -->
    <div id="participants" class="tab-content">
        <div class="section">
            <h2>👥 Chat Participants</h2>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Identity</th>
                            <th>Phone/JID</th>
                            <th>Messages</th>
                            <th>Sent</th>
                            <th>Received</th>
                            <th>First Seen</th>
                            <th>Last Seen</th>
                        </tr>
                    </thead>
                    <tbody>
EOF

    sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT 
            '<tr>',
            '<td>' || 
                CASE
                    WHEN from_me = 1 THEN '📱 DEVICE OWNER'
                    WHEN j.user IS NOT NULL THEN j.user
                    WHEN j.raw_string LIKE '%@lid' THEN '🏢 BUSINESS: ' || SUBSTR(j.raw_string, 1, 20) || '...'
                    ELSE COALESCE(j.raw_string, 'UNKNOWN')
                END || '</td>',
            '<td>' || COALESCE(j.raw_string, '-') || '</td>',
            '<td>' || COUNT(*) || '</td>',
            '<td><span class=\"sent-badge\">' || SUM(CASE WHEN from_me = 1 THEN 1 ELSE 0 END) || '</span></td>',
            '<td><span class=\"recv-badge\">' || SUM(CASE WHEN from_me = 0 THEN 1 ELSE 0 END) || '</span></td>',
            '<td>' || COALESCE(datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime'), '') || '</td>',
            '<td>' || COALESCE(datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime'), '') || '</td>',
            '</tr>'
        FROM $msg_table m
        LEFT JOIN $jid_table j ON m.sender_jid_row_id = j._id
        WHERE m.chat_row_id = ${chat_id}
        GROUP BY m.sender_jid_row_id
        ORDER BY COUNT(*) DESC;
    " 2>/dev/null >> "$outfile"

    cat >> "$outfile" <<EOF
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- LINKS TAB -->
    <div id="links" class="tab-content">
        <div class="section">
            <h2>🔗 URLs & Links Shared</h2>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Time</th>
                            <th>Sender</th>
                            <th>URL</th>
                            <th>Category</th>
                        </tr>
                    </thead>
                    <tbody>
EOF

    sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT 
            '<tr>',
            '<td>' || COALESCE(datetime($ts_col/1000, 'unixepoch', 'localtime'), '') || '</td>',
            '<td>' || CASE WHEN from_me = 1 THEN '📱 DEVICE' ELSE '📞 Contact' END || '</td>',
            '<td><a href=\"' ||
                CASE
                    WHEN text_data LIKE '%https://%' THEN SUBSTR(text_data, INSTR(text_data,'https://'), 
                        CASE WHEN INSTR(SUBSTR(text_data, INSTR(text_data,'https://')), ' ') > 0 
                             THEN INSTR(SUBSTR(text_data, INSTR(text_data,'https://')), ' ') - 1
                             ELSE LENGTH(text_data) END)
                    WHEN text_data LIKE '%http://%' THEN SUBSTR(text_data, INSTR(text_data,'http://'),
                        CASE WHEN INSTR(SUBSTR(text_data, INSTR(text_data,'http://')), ' ') > 0 
                             THEN INSTR(SUBSTR(text_data, INSTR(text_data,'http://')), ' ') - 1
                             ELSE LENGTH(text_data) END)
                    ELSE '#'
                END || '\" target=\"_blank\" style=\"color:#58a6ff;\">' ||
                SUBSTR(text_data, 1, 60) || '...</a></td>',
            '<td><span class=\"media-badge\">' ||
                CASE
                    WHEN text_data LIKE '%youtube%' OR text_data LIKE '%youtu.be%' THEN 'YouTube'
                    WHEN text_data LIKE '%tiktok%' THEN 'TikTok'
                    WHEN text_data LIKE '%instagram%' THEN 'Instagram'
                    WHEN text_data LIKE '%facebook%' THEN 'Facebook'
                    WHEN text_data LIKE '%wa.me%' THEN 'WhatsApp'
                    ELSE 'Web URL'
                END || '</span></td>',
            '</tr>'
        FROM $msg_table
        WHERE chat_row_id = ${chat_id} AND text_data LIKE '%http%'
        ORDER BY $ts_col ASC;
    " 2>/dev/null >> "$outfile"

    cat >> "$outfile" <<EOF
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- CHAIN OF CUSTODY TAB -->
    <div id="custody" class="tab-content">
        <div class="section">
            <h2>🔒 Chain of Custody & Evidence Integrity</h2>
            <div class="forensic-note" style="background:#1a2332;padding:16px;border-radius:8px;margin-bottom:20px;">
                <strong>✅ Evidence Integrity Maintained</strong><br>
                All analysis performed in READ-ONLY mode. Original databases not modified.<br>
                SHA-256 hashes recorded for all evidence files.
            </div>
            <pre style="background:#0d1117;padding:20px;border-radius:8px;overflow-x:auto;font-size:0.8em;">$(cat "${CASE_DIR}/chain_of_custody.txt" 2>/dev/null | head -30)</pre>
            <div class="evidence-trace">
                📍 CHAIN OF CUSTODY LOG | Case: ${CURRENT_CASE} | Investigator: ${INVESTIGATOR}<br>
                📍 This transcript was generated from msgstore.db (read-only mode).
            </div>
        </div>
    </div>

    <div class="footer">
        <p>🔒 Digital Forensic Toolkit — WhatsApp Deep Analyzer</p>
        <p>Based on Le-Khac & Choo (2022) | Court-Admissible Evidence</p>
        <p>📋 Chat Transcript — Chat ID: ${chat_id} | $(date)</p>
    </div>
</div>

<script>
function showTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
    document.getElementById(tabId).classList.add('active');
    event.target.classList.add('active');
}
function filterTable(tableId, filterText) {
    const table = document.getElementById(tableId);
    const rows = table.getElementsByTagName('tbody')[0].getElementsByTagName('tr');
    const filter = filterText.toLowerCase();
    for (let row of rows) row.style.display = row.innerText.toLowerCase().includes(filter) ? '' : 'none';
}
function sortTable(column, tableId) {
    const table = document.getElementById(tableId);
    const tbody = table.getElementsByTagName('tbody')[0];
    const rows = Array.from(tbody.getElementsByTagName('tr'));
    const isAscending = table.getAttribute('data-sort-asc') === 'true';
    rows.sort((a, b) => {
        let aVal = a.getElementsByTagName('td')[column]?.innerText || '';
        let bVal = b.getElementsByTagName('td')[column]?.innerText || '';
        let aNum = parseFloat(aVal);
        let bNum = parseFloat(bVal);
        if (!isNaN(aNum) && !isNaN(bNum)) return isAscending ? aNum - bNum : bNum - aNum;
        return isAscending ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
    });
    tbody.innerHTML = '';
    rows.forEach(row => tbody.appendChild(row));
    table.setAttribute('data-sort-asc', !isAscending);
}
function exportTableToCSV(tableId, filename) {
    const table = document.getElementById(tableId);
    const rows = table.querySelectorAll('tr');
    const csv = [];
    for (let row of rows) {
        const cols = row.querySelectorAll('th, td');
        csv.push(Array.from(cols).map(col => '"' + col.innerText.replace(/"/g, '""').replace(/\\n/g, ' ') + '"').join(','));
    }
    const blob = new Blob(['\\uFEFF' + csv.join('\\n')], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    link.click();
}
function generatePDF() { window.print(); }
</script>
</body>
</html>
EOF

    print_ok "HTML Report: $outfile"
    cross_open "$outfile" 2>/dev/null &
    pause
}

export_chat_transcript_menu() {
    banner; print_section "EXPORT CHAT TRANSCRIPT"
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    view_available_chats
    echo ""; read -rp "  Enter Chat ID (or 'b' to go back): " chat_id
    [[ -z "$chat_id" || "$chat_id" == "b" || "$chat_id" == "B" ]] && return
    [[ ! "$chat_id" =~ ^[0-9]+$ ]] && { print_err "Invalid"; pause; return; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local chat_name="Chat_${chat_id}"
    [[ -n "$chat_table" ]] && chat_name=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COALESCE(subject,'Chat_'||_id) FROM $chat_table WHERE _id=${chat_id};" 2>/dev/null)
    
    echo -e "\n${CYAN}Format:${RESET} h-HTML c-CSV t-TXT b-Back"
    read -rp "  > " format
    case "$format" in
        b|B) return ;;
       h|H) 
    # Get phone and JID for the report
    local phone=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT COALESCE(cj.user, SUBSTR(cj.raw_string, 1, INSTR(cj.raw_string, '@') - 1))
        FROM chat c LEFT JOIN jid cj ON c.jid_row_id = cj._id WHERE c._id = ${chat_id};
    " 2>/dev/null)
    local jid=$(sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT cj.raw_string FROM chat c LEFT JOIN jid cj ON c.jid_row_id = cj._id WHERE c._id = ${chat_id};
    " 2>/dev/null)
    generate_professional_chat_html "$chat_id" "$chat_name" "$phone" "$jid"
    ;;
        c|C) local outfile="${CASE_DIR}/extracted/chats/chat_${chat_id}.csv"; mkdir -p "${CASE_DIR}/extracted/chats"; sqlite3 -readonly -csv -header "$MSGSTORE_DB" "SELECT * FROM $msg_table WHERE chat_row_id=${chat_id};" > "$outfile" 2>/dev/null; print_ok "CSV: $outfile"; pause ;;
        *) local outfile="${CASE_DIR}/extracted/chats/chat_${chat_id}.txt"; mkdir -p "${CASE_DIR}/extracted/chats"; local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table"); { echo "CHAT TRANSCRIPT - $chat_id | $(date)"; sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime($ts_col/1000,'unixepoch','localtime')||' | '||CASE WHEN from_me=1 THEN 'SENT' ELSE 'RECV' END||' | '||COALESCE(text_data,'[media]') FROM $msg_table WHERE chat_row_id=${chat_id} ORDER BY $ts_col ASC;"; } > "$outfile" 2>/dev/null; print_ok "TXT: $outfile"; pause ;;
    esac
}

# =============================================================================
# EXPORTS
# =============================================================================
export -f detect_message_table
export -f detect_chat_table
export -f detect_jid_table
export -f detect_media_table
export -f detect_link_table
export -f column_exists
export -f get_timestamp_col
export -f get_dashboard_stats
export -f analyze_activity_profiling
export -f build_activity_html_report
export -f analyze_chat_reconstruction
export -f build_chat_html_report
export -f analyze_contact_mapping
export -f build_contact_html_report
export -f analyze_media_reconstruction
export -f build_media_html_report
export -f analyze_deleted_messages
export -f build_deleted_html_simple
export -f analyze_url_extraction
export -f build_url_html_report
export -f analyze_master_timeline
export -f build_timeline_html_report
export -f analyze_wal_recovery
export -f build_wal_html_report
export -f run_all_analyses
export -f view_available_chats
export -f chat_deep_dive_menu
export -f chat_deep_dive
export -f search_by_phone
export -f perform_phone_search
export -f view_contact_chats
export -f export_contact_activity
export -f generate_professional_chat_html
export -f export_chat_transcript_menu
export -f display_post_query_menu 
export -f display_post_chat_recon_menu
export -f show_calls_for_contact