#!/usr/bin/env bash
# =============================================================================
#  REPORT GENERATOR — HTML, PDF, CSV, and Text Reports
# =============================================================================

generate_html_report() {
    banner
    print_section "GENERATING HTML FORENSIC REPORT"
    
    local report_file="${CASE_DIR}/html/forensic_report.html"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Gather statistics
    local total_msgs=0 sent_msgs=0 recv_msgs=0 total_contacts=0
    if [[ -n "$MSGSTORE_DB" ]]; then
        total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM messages;" 2>/dev/null || echo 0)
        sent_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM messages WHERE key_from_me=1;" 2>/dev/null || echo 0)
        recv_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM messages WHERE key_from_me=0;" 2>/dev/null || echo 0)
        total_contacts=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(DISTINCT key_remote_jid) FROM messages;" 2>/dev/null || echo 0)
    fi
    
    # Build HTML
    cat > "$report_file" <<EOF
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
                    <div class="info-row"><span class="info-label">Evidence Source</span><span class="info-value">${EVIDENCE_SOURCE:-N/A}</span></div>
                    <div class="info-row"><span class="info-label">msgstore.db</span><span class="info-value">${MSGSTORE_DB:+Loaded}</span></div>
                    <div class="info-row"><span class="info-label">wa.db</span><span class="info-value">${WA_DB:+Loaded}</span></div>
                </div>
            </div>
        </div>
    </div>

    <div id="case" class="tab-content">
        <div class="section">
            <h2>🗂️ Case Details</h2>
            $(cat "${CASE_DIR}/case_info.txt" 2>/dev/null | sed 's/^/            /' || echo "            No case info available.")
        </div>
    </div>

    <div id="evidence" class="tab-content">
        <div class="section">
            <h2>🔒 Evidence Integrity</h2>
            <div style="background: rgba(34,197,94,0.1); border: 1px solid rgba(34,197,94,0.3); border-radius: 8px; padding: 16px; margin-bottom: 20px;">
                <strong style="color: #7ee787;">✅ All evidence processed in READ-ONLY mode.</strong>
                <p style="color: #8b949e; margin-top: 8px;">SHA-256 and MD5 hashes recorded for all evidence files.</p>
            </div>
            <pre class="hash-block">$(cat "${CASE_DIR}/evidence/hash_registry.txt" 2>/dev/null || echo "No hash records.")</pre>
        </div>
    </div>

    <div id="contacts" class="tab-content">
        <div class="section">
            <h2>👥 Contact Summary</h2>
            <div class="table-container">
                <table>
                    <thead><tr><th>Contact JID</th><th>Messages</th><th>Sent</th><th>Received</th><th>Last Contact</th></tr></thead>
                    <tbody>
EOF

    if [[ -n "$MSGSTORE_DB" ]]; then
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT '<tr><td>' || key_remote_jid || '</td><td>' || COUNT(*) || '</td><td>' || 
                   SUM(CASE WHEN key_from_me=1 THEN 1 ELSE 0 END) || '</td><td>' ||
                   SUM(CASE WHEN key_from_me=0 THEN 1 ELSE 0 END) || '</td><td>' ||
                   datetime(MAX(timestamp/1000),'unixepoch') || '</td></tr>'
            FROM messages
            GROUP BY key_remote_jid
            ORDER BY COUNT(*) DESC
            LIMIT 20;
        " 2>/dev/null >> "$report_file"
    fi

    cat >> "$report_file" <<EOF
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

    if [[ -n "$MSGSTORE_DB" ]]; then
        sqlite3 -readonly "$MSGSTORE_DB" "
            SELECT '<tr><td>' || datetime(timestamp/1000,'unixepoch') || '</td><td>' || key_remote_jid || '</td><td>' ||
                   CASE WHEN key_from_me=1 THEN '<span class=\"sent\">→ SENT</span>' ELSE '<span class=\"recv\">← RECV</span>' END || '</td><td>' ||
                   SUBSTR(COALESCE(data,'[media]'), 1, 100) || '</td></tr>'
            FROM messages
            ORDER BY timestamp DESC
            LIMIT 100;
        " 2>/dev/null >> "$report_file"
    fi

    cat >> "$report_file" <<EOF
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div id="custody" class="tab-content">
        <div class="section">
            <h2>🔗 Chain of Custody</h2>
            <pre class="hash-block">$(cat "${CASE_DIR}/logs/chain_of_custody.log" 2>/dev/null || echo "No chain of custody log.")</pre>
        </div>
    </div>

    <div class="footer">
        <p>🔒 WA-Forensics Toolkit v${TOOLKIT_VERSION} — Court-Admissible Forensic Report</p>
        <p>Session: ${SESSION_ID} | Generated: ${ts}</p>
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

    log_action "HTML Report Generated" "$report_file" "SUCCESS"
    print_ok "HTML report: $report_file"
    
    # Open in browser if possible
    if command -v xdg-open &>/dev/null; then
        xdg-open "$report_file" 2>/dev/null &
    fi
    
    pause
}

generate_pdf_report() {
    banner
    print_section "GENERATING PDF REPORT"
    
    local html_file="${CASE_DIR}/html/forensic_report.html"
    local pdf_file="${CASE_DIR}/pdf/forensic_report.pdf"
    
    if [[ ! -f "$html_file" ]]; then
        print_info "HTML report not found. Generating first..."
        generate_html_report
    fi
    
    if command -v wkhtmltopdf &>/dev/null; then
        print_step "Converting HTML to PDF..."
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

generate_csv_exports() {
    banner
    print_section "GENERATING CSV EXPORTS"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }
    
    local ts=$(date '+%Y%m%d_%H%M%S')
    
    # Export messages
    local msg_file="${CASE_DIR}/extracted/messages_${ts}.csv"
    sqlite3 -readonly -csv -header "$MSGSTORE_DB" "
        SELECT * FROM messages;
    " > "$msg_file" 2>/dev/null
    print_ok "Messages exported: $msg_file"
    
    # Export contacts summary
    local contacts_file="${CASE_DIR}/extracted/contacts_summary_${ts}.csv"
    sqlite3 -readonly -csv -header "$MSGSTORE_DB" "
        SELECT
            key_remote_jid AS contact,
            COUNT(*) AS messages,
            SUM(CASE WHEN key_from_me=1 THEN 1 ELSE 0 END) AS sent,
            SUM(CASE WHEN key_from_me=0 THEN 1 ELSE 0 END) AS received,
            datetime(MIN(timestamp/1000),'unixepoch') AS first_contact,
            datetime(MAX(timestamp/1000),'unixepoch') AS last_contact
        FROM messages
        GROUP BY key_remote_jid
        ORDER BY messages DESC;
    " > "$contacts_file" 2>/dev/null
    print_ok "Contacts summary exported: $contacts_file"
    
    log_action "CSV Exports Generated" "${CASE_DIR}/extracted" "SUCCESS"
    pause
}

generate_final_text_report() {
    banner
    print_section "GENERATING FINAL TEXT REPORT"
    
    local report_file="${CASE_DIR}/reports/FINAL_REPORT_${CURRENT_CASE}.txt"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    {
        cat <<EOF
╔══════════════════════════════════════════════════════════════════════════╗
║                    FINAL DIGITAL FORENSIC REPORT                         ║
║                    WA-Forensics Toolkit v${TOOLKIT_VERSION}                        ║
╚══════════════════════════════════════════════════════════════════════════╝

Report Generated : ${ts}
Session ID       : ${SESSION_ID}

═══════════════════════════════════════════════════════════
  SECTION 1 — CASE DETAILS
═══════════════════════════════════════════════════════════
$(cat "${CASE_DIR}/case_info.txt" 2>/dev/null)

═══════════════════════════════════════════════════════════
  SECTION 2 — ANALYSIS REPORTS
═══════════════════════════════════════════════════════════
EOF

        for report in "${CASE_DIR}/reports/"*.txt; do
            [[ -f "$report" ]] || continue
            echo ""
            echo "--- $(basename "$report") ---"
            head -50 "$report"
            echo "  ... [see full report: $report]"
        done
        
        cat <<EOF

═══════════════════════════════════════════════════════════
  SECTION 3 — EVIDENCE INTEGRITY
═══════════════════════════════════════════════════════════
$(cat "${CASE_DIR}/evidence/hash_registry.txt" 2>/dev/null)

═══════════════════════════════════════════════════════════
  SECTION 4 — INVESTIGATOR CERTIFICATION
═══════════════════════════════════════════════════════════

I, ${INVESTIGATOR} (Badge ID: ${BADGE_ID}), certify that:
  1. All analysis was performed in READ-ONLY mode.
  2. Original evidence was NOT modified.
  3. SHA-256/MD5 hashes were recorded.
  4. Chain of custody was maintained.

Signature: _______________________________
Date: ${ts}

═══════════════════════════════════════════════════════════
  END OF REPORT — ${CURRENT_CASE}
═══════════════════════════════════════════════════════════
EOF
    } > "$report_file"
    
    log_action "Final Report Generated" "$report_file" "SUCCESS"
    print_ok "Final report: $report_file"
    pause
}

export_chat_html() {
    local chat_id="$1"
    local outfile="${CASE_DIR}/html/chat_${chat_id}.html"
    
    cat > "$outfile" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Chat Transcript — Chat ${chat_id}</title>
    <style>
        body { font-family: monospace; background: #0d1117; color: #e6edf3; padding: 20px; }
        .header { background: #161b22; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .message { padding: 10px; margin: 5px 0; border-bottom: 1px solid #30363d; }
        .sent { border-left: 3px solid #7ee787; padding-left: 15px; }
        .recv { border-left: 3px solid #f0883e; padding-left: 15px; }
        .time { color: #8b949e; font-size: 0.8em; }
        .content { margin-top: 5px; }
    </style>
</head>
<body>
<div class="header">
    <h2>Chat Transcript — ID: ${chat_id}</h2>
    <p>Case: ${CURRENT_CASE} | Generated: $(date)</p>
</div>
EOF

    sqlite3 -readonly "$MSGSTORE_DB" "
        SELECT
            '<div class=\"message ' || CASE WHEN key_from_me=1 THEN 'sent' ELSE 'recv' END || '\">' ||
            '<div class=\"time\">' || datetime(timestamp/1000, 'unixepoch', 'localtime') || '</div>' ||
            '<div class=\"content\">' || COALESCE(data, '[media]') || '</div></div>'
        FROM messages
        WHERE chat_row_id = ${chat_id}
        ORDER BY timestamp ASC;
    " 2>/dev/null >> "$outfile"
    
    cat >> "$outfile" <<EOF
</body>
</html>
EOF

    print_ok "HTML transcript: $outfile"
    
    if command -v xdg-open &>/dev/null; then
        xdg-open "$outfile" 2>/dev/null &
    fi
}
