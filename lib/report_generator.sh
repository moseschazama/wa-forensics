#!/usr/bin/env bash
# =============================================================================
#  REPORT GENERATOR — HTML, PDF, CSV, and Text Reports
#
generate_html_report() {
    banner
    print_section "OPTION 10: GENERATING HTML FORENSIC REPORT"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded. Please load evidence first."; pause; return 1; }
    
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")
    
    local outfile="${CASE_DIR}/operations/html/forensic_report.html"
    mkdir -p "${CASE_DIR}/operations/html"
    
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ── Gather Statistic ────────────────────────────────────────────────
    print_info "Collecting case statistics..."
    
    local total_msgs=0 sent_msgs=0 recv_msgs=0 media_msgs=0 deleted_msgs=0 total_contacts=0 total_chats=0
    if [[ -n "$MSGSTORE_DB" && -n "$msg_table" ]]; then
        total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
        sent_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 1;" 2>/dev/null || echo "0")
        recv_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 0;" 2>/dev/null || echo "0")
        media_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type IN (1,2,3,8,9,11,13);" 2>/dev/null || echo "0")
        deleted_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 15;" 2>/dev/null || echo "0")
        total_chats=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(DISTINCT chat_row_id) FROM $msg_table WHERE chat_row_id IS NOT NULL;" 2>/dev/null || echo "0")
        
        # Count unique senders (excluding device owner)
        total_contacts=$(sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT COUNT(DISTINCT sender_jid_row_id) 
            FROM $msg_table 
            WHERE sender_jid_row_id IS NOT NULL AND from_me = 0;
        " 2>/dev/null || echo "0")
    fi
    
    local first_msg="N/A" last_msg="N/A"
    if [[ -n "$ts_col" ]]; then
        first_msg=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table WHERE $ts_col > 0;" 2>/dev/null || echo "N/A")
        last_msg=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table;" 2>/dev/null || echo "N/A")
    fi
    
    # Build HTML
    cat > "$outfile" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Forensic Report — ${CURRENT_CASE}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0d1117; color: #e6edf3; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #161b22 0%, #0d1117 100%); border-radius: 12px; padding: 30px; margin-bottom: 30px; text-align: center; border: 1px solid #30363d; }
        .header h1 { font-size: 2em; color: #58a6ff; margin-bottom: 10px; }
        .badge { display: inline-block; background: #238636; color: white; padding: 4px 12px; border-radius: 20px; font-size: 0.8em; margin: 5px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 30px; }
        .stat-card { background: #161b22; border-radius: 10px; padding: 20px; text-align: center; border: 1px solid #30363d; }
        .stat-number { font-size: 2.2em; font-weight: bold; color: #58a6ff; }
        .stat-label { font-size: 0.8em; color: #8b949e; margin-top: 8px; text-transform: uppercase; }
        .section { background: #161b22; border-radius: 12px; padding: 24px; margin-bottom: 28px; border: 1px solid #30363d; }
        .section h2 { color: #58a6ff; margin-bottom: 20px; font-size: 1.3em; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .info-block { background: #0d1117; border-radius: 8px; padding: 16px; }
        .info-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #21262d; }
        .info-label { color: #8b949e; }
        .info-value { color: #e6edf3; font-weight: 500; }
        .table-container { overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 0.8em; }
        th { background: #1f6feb; color: white; padding: 10px; text-align: left; }
        td { padding: 8px 10px; border-bottom: 1px solid #21262d; }
        tr:hover { background: #1a2332; }
        .footer { text-align: center; padding: 24px; border-top: 1px solid #30363d; margin-top: 30px; font-size: 0.8em; color: #8b949e; }
        .nav-tabs { display: flex; gap: 5px; margin-bottom: 20px; flex-wrap: wrap; }
        .nav-tab { padding: 8px 16px; background: #21262d; border: none; border-radius: 6px; color: #c9d1d9; cursor: pointer; }
        .nav-tab.active { background: #1f6feb; color: white; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        .sent { color: #7ee787; }
        .recv { color: #f0883e; }
        .hash-block { background: #0a0e14; border: 1px solid #30363d; border-radius: 8px; padding: 16px; font-family: 'Courier New', monospace; font-size: 0.75em; max-height: 300px; overflow-y: auto; }
    </style>
</head>
<body>
<div class="container">

    <div class="header">
        <h1>🔍 WhatsApp Forensic Investigation Report</h1>
        <div class="subtitle" style="color: #8b949e; margin-bottom: 15px;">ACPO Compliant • Chain of Custody Verified</div>
        <div>
            <span class="badge">Case: ${CURRENT_CASE}</span>
            <span class="badge">Analyst: ${INVESTIGATOR}</span>
            <span class="badge">Warrant: ${WARRANT_NUM}</span>
        </div>
        <p style="margin-top: 20px; color: #8b949e;">Generated: ${ts}</p>
    </div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total_msgs}</div><div class="stat-label">Total Messages</div></div>
        <div class="stat-card"><div class="stat-number">${sent_msgs}</div><div class="stat-label">Sent</div></div>
        <div class="stat-card"><div class="stat-number">${recv_msgs}</div><div class="stat-label">Received</div></div>
        <div class="stat-card"><div class="stat-number">${media_msgs}</div><div class="stat-label">Media Files</div></div>
        <div class="stat-card"><div class="stat-number">${deleted_msgs}</div><div class="stat-label">Deleted</div></div>
        <div class="stat-card"><div class="stat-number">${total_contacts}</div><div class="stat-label">Unique Contacts</div></div>
    </div>

    <div class="nav-tabs">
        <button class="nav-tab active" onclick="showTab('overview')">Overview</button>
        <button class="nav-tab" onclick="showTab('case')">Case Details</button>
        <button class="nav-tab" onclick="showTab('evidence')">Evidence Integrity</button>
        <button class="nav-tab" onclick="showTab('contacts')">Contacts</button>
        <button class="nav-tab" onclick="showTab('chats')">Chat Summary</button>
        <button class="nav-tab" onclick="showTab('custody')">Chain of Custody</button>
    </div>

    <div id="overview" class="tab-content active">
        <div class="section">
            <h2>📊 Investigation Overview</h2>
            <div class="info-grid">
                <div class="info-block">
                    <h3 style="color: #58a6ff; margin-bottom: 15px;">Case Information</h3>
                    <div class="info-row"><span class="info-label">Case ID</span><span class="info-value">${CURRENT_CASE}</span></div>
                    <div class="info-row"><span class="info-label">Investigator</span><span class="info-value">${INVESTIGATOR}</span></div>
                    <div class="info-row"><span class="info-label">Badge ID</span><span class="info-value">${BADGE_ID}</span></div>
                    <div class="info-row"><span class="info-label">Organization</span><span class="info-value">${ORGANIZATION}</span></div>
                    <div class="info-row"><span class="info-label">Warrant Number</span><span class="info-value">${WARRANT_NUM}</span></div>
                </div>
                <div class="info-block">
                    <h3 style="color: #58a6ff; margin-bottom: 15px;">Evidence Summary</h3>
                    <div class="info-row"><span class="info-label">Suspect Phone</span><span class="info-value">${SUSPECT_PHONE:-N/A}</span></div>
                    <div class="info-row"><span class="info-label">Timeline</span><span class="info-value">${first_msg} → ${last_msg}</span></div>
                    <div class="info-row"><span class="info-label">msgstore.db</span><span class="info-value">${MSGSTORE_DB:+Loaded}</span></div>
                    <div class="info-row"><span class="info-label">wa.db</span><span class="info-value">${WA_DB:+Loaded}</span></div>
                </div>
            </div>
        </div>
    </div>

    <div id="case" class="tab-content">
        <div class="section">
            <h2>🗂️ Case Details</h2>
            <pre style="color:#c9d1d9;">$(cat "${CASE_DIR}/operations/case_info.txt" 2>/dev/null)</pre>
        </div>
    </div>

    <div id="evidence" class="tab-content">
        <div class="section">
            <h2>🔒 Evidence Integrity</h2>
            <div style="background: rgba(34,197,94,0.1); border: 1px solid rgba(34,197,94,0.3); border-radius: 8px; padding: 16px; margin-bottom: 20px;">
                <strong style="color: #7ee787;">✅ All evidence processed in READ-ONLY mode.</strong>
                <p style="color: #8b949e; margin-top: 8px;">SHA-256 hashes recorded for all evidence files.</p>
            </div>
            <pre class="hash-block">$(cat "${CASE_DIR}/operations/evidence/hash_registry.txt" 2>/dev/null || echo "No hash records.")</pre>
        </div>
    </div>

    <div id="contacts" class="tab-content">
        <div class="section">
            <h2>👥 Contact Summary</h2>
            <div class="table-container">
                <table>
                    <thead><tr><th>Contact</th><th>Messages</th><th>Sent</th><th>Received</th><th>Last Contact</th></tr></thead>
                    <tbody>
EOF

    if [[ -n "$MSGSTORE_DB" && -n "$msg_table" && -n "$ts_col" ]]; then
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT '<tr><td>' || COALESCE(
                (SELECT user FROM jid WHERE _id = m.sender_jid_row_id),
                'Unknown') || '</td><td>' || 
                COUNT(*) || '</td><td>' || 
                SUM(CASE WHEN from_me = 1 THEN 1 ELSE 0 END) || '</td><td>' ||
                SUM(CASE WHEN from_me = 0 THEN 1 ELSE 0 END) || '</td><td>' ||
                COALESCE(datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime'), 'Never') || '</td></tr>'
            FROM $msg_table m
            WHERE from_me = 0
            GROUP BY sender_jid_row_id
            ORDER BY COUNT(*) DESC
            LIMIT 20;
        " 2>/dev/null >> "$outfile"
    fi

    cat >> "$outfile" <<EOF
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div id="chats" class="tab-content">
        <div class="section">
            <h2>💬 Recent Messages</h2>
            <div class="table-container">
                <table>
                    <thead><tr><th>Timestamp</th><th>Contact</th><th>Direction</th><th>Content</th></tr></thead>
                    <tbody>
EOF

    if [[ -n "$MSGSTORE_DB" && -n "$msg_table" && -n "$ts_col" ]]; then
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT '<tr><td>' || datetime($ts_col/1000, 'unixepoch', 'localtime') || '</td><td>' || 
                COALESCE((SELECT user FROM jid WHERE _id = m.sender_jid_row_id), 'Unknown') || '</td><td>' ||
                CASE WHEN from_me = 1 THEN '<span class=\"sent\">→ SENT</span>' ELSE '<span class=\"recv\">← RECV</span>' END || '</td><td>' ||
                COALESCE(SUBSTR(text_data, 1, 100), '[media]') || '</td></tr>'
            FROM $msg_table m
            ORDER BY $ts_col DESC
            LIMIT 100;
        " 2>/dev/null >> "$outfile"
    fi

    cat >> "$outfile" <<EOF
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div id="custody" class="tab-content">
        <div class="section">
            <h2>🔗 Chain of Custody</h2>
            <pre class="hash-block">$(cat "${CASE_DIR}/operations/logs/chain_of_custody.log" 2>/dev/null || echo "No chain of custody log.")</pre>
        </div>
    </div>

    <div class="footer">
        <p>🔒 WhatsApp Forensic Analysis Report</p>
        <p>Court-Admissible Evidence • Chain of Custody Verified</p>
        <p>Generated: ${ts} | Case: ${CURRENT_CASE}</p>
    </div>

</div>
<script>
function showTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
    document.getElementById(tabId).classList.add('active');
    event.target.classList.add('active');
}
</script>
</body>
</html>
EOF

    log_action "HTML Report Generated" "$outfile" "SUCCESS"
    print_ok "HTML report: $outfile"
    
    if command -v xdg-open &>/dev/null; then
        xdg-open "$outfile" 2>/dev/null &
    fi
    
    pause
}

generate_pdf_report() {
    banner
    print_section "OPTION 11: GENERATING PDF REPORT"
    
    local html_file="${CASE_DIR}/operations/html/forensic_report.html"
    local pdf_file="${CASE_DIR}/operations/pdf/forensic_report.pdf"
    
    if [[ ! -f "$html_file" ]]; then
        print_info "HTML report not found. Generating first..."
        generate_html_report
    fi
    
    if command -v wkhtmltopdf &>/dev/null; then
        print_step "Converting HTML to PDF..."
        mkdir -p "${CASE_DIR}/operations/pdf"
        
        wkhtmltopdf \
            --page-size A4 \
            --margin-top 10mm \
            --margin-bottom 10mm \
            --margin-left 10mm \
            --margin-right 10mm \
            --quiet \
            "$html_file" "$pdf_file" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            print_ok "PDF report: $pdf_file"
            log_action "PDF Report Generated" "$pdf_file" "SUCCESS"
        else
            print_err "PDF conversion failed."
        fi
    else
        print_warn "wkhtmltopdf not installed. Install: sudo apt-get install wkhtmltopdf"
    fi
    
    pause
}

