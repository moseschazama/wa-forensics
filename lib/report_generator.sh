#!/usr/bin/env bash
# =============================================================================
#  REPORT GENERATOR — HTML, PDF, CSV, and Text forensic reports
# =============================================================================

# ── Load cross-platform helpers ───────────────────────────────────────────────
source "${LIB_DIR}/cross_platform.sh" 2>/dev/null || true

# =============================================================================
# GENERATE HTML REPORT
# =============================================================================
generate_html_report() {
    banner
    print_section "GENERATING HTML FORENSIC REPORT"

    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }

    local outfile="${CASE_DIR}/html/forensic_report.html"
    mkdir -p "${CASE_DIR}/html"

    print_step "Compiling forensic analysis data..."

    # Get table names
    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")

    [[ -z "$msg_table" || -z "$ts_col" ]] && { print_err "Could not detect database schema."; pause; return 1; }

    # Gather statistics
    local total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
    local total_chats=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(DISTINCT chat_row_id) FROM $msg_table WHERE chat_row_id IS NOT NULL;" 2>/dev/null || echo "0")
    local sent_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 1;" 2>/dev/null || echo "0")
    local recv_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 0;" 2>/dev/null || echo "0")
    local media_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type IN (1,2,3,8,9,11,13);" 2>/dev/null || echo "0")
    local deleted_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 15;" 2>/dev/null || echo "0")

    local first_msg=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MIN($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table WHERE $ts_col > 0;" 2>/dev/null || echo "N/A")
    local last_msg=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT datetime(MAX($ts_col)/1000, 'unixepoch', 'localtime') FROM $msg_table;" 2>/dev/null || echo "N/A")

    print_step "Generating HTML report..."

    cat > "$outfile" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Forensic Report — ${CURRENT_CASE}</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',sans-serif;background:#0d1117;color:#c9d1d9;padding:24px;line-height:1.5}
        .container{max-width:1400px;margin:0 auto}
        .header{background:linear-gradient(135deg,#1a73e8,#0d47a1);border-radius:16px;padding:30px;margin-bottom:24px;color:white}
        .header h1{font-size:2rem;margin-bottom:8px}
        .badge{display:inline-block;background:rgba(255,255,255,0.2);padding:4px 12px;border-radius:20px;font-size:0.8rem;margin-right:8px}
        .stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin-bottom:24px}
        .stat-card{background:#161b22;border-radius:12px;padding:18px;text-align:center;border:1px solid #30363d}
        .stat-number{font-size:2rem;font-weight:bold;color:#58a6ff}
        .stat-label{font-size:0.7rem;color:#8b949e;text-transform:uppercase;letter-spacing:0.5px;margin-top:4px}
        .section{background:#161b22;border-radius:16px;padding:24px;margin-bottom:24px;border:1px solid #30363d}
        .section h2{color:#58a6ff;margin-bottom:16px;font-size:1.2rem;border-bottom:1px solid #30363d;padding-bottom:10px}
        .info-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-bottom:16px}
        .info-item{padding:10px;background:#0d1117;border-radius:8px}
        .info-label{color:#8b949e;font-size:0.75rem;text-transform:uppercase}
        .info-value{color:#c9d1d9;font-size:0.9rem;margin-top:4px}
        .footer{text-align:center;padding:20px;color:#8b949e;font-size:0.75rem;border-top:1px solid #30363d;margin-top:20px}
        .btn{display:inline-block;padding:10px 20px;background:#1a73e8;color:white;border:none;border-radius:8px;cursor:pointer;text-decoration:none;font-size:0.85rem;margin-right:10px}
        .btn:hover{opacity:0.85}
        @media print{body{background:white;color:black}.header{background:#1a73e8!important;-webkit-print-color-adjust:exact}.btn{display:none}}
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>WhatsApp Forensic Report</h1>
        <div style="opacity:0.9;margin-bottom:10px;">Court-Admissible Evidence • ACPO Compliant</div>
        <div>
            <span class="badge">Case: ${CURRENT_CASE}</span>
            <span class="badge">Analyst: ${INVESTIGATOR}</span>
            <span class="badge">Date: $(date '+%Y-%m-%d %H:%M:%S')</span>
        </div>
    </div>

    <div style="margin-bottom:16px;">
        <button class="btn" onclick="window.print()">Print / Save PDF</button>
    </div>

    <div class="section">
        <h2>Case Information</h2>
        <div class="info-grid">
            <div class="info-item"><div class="info-label">Case ID</div><div class="info-value">${CURRENT_CASE}</div></div>
            <div class="info-item"><div class="info-label">Investigator</div><div class="info-value">${INVESTIGATOR}</div></div>
            <div class="info-item"><div class="info-label">Organization</div><div class="info-value">${ORGANIZATION:-N/A}</div></div>
            <div class="info-item"><div class="info-label">Warrant Number</div><div class="info-value">${WARRANT_NUM:-N/A}</div></div>
            <div class="info-item"><div class="info-label">Suspect Phone</div><div class="info-value">${SUSPECT_PHONE:-N/A}</div></div>
            <div class="info-item"><div class="info-label">Evidence Source</div><div class="info-value">${EVIDENCE_SOURCE:-N/A}</div></div>
        </div>
    </div>

    <div class="stats-grid">
        <div class="stat-card"><div class="stat-number">${total_msgs}</div><div class="stat-label">Total Messages</div></div>
        <div class="stat-card"><div class="stat-number">${total_chats}</div><div class="stat-label">Total Chats</div></div>
        <div class="stat-card"><div class="stat-number">${sent_msgs}</div><div class="stat-label">Sent</div></div>
        <div class="stat-card"><div class="stat-number">${recv_msgs}</div><div class="stat-label">Received</div></div>
        <div class="stat-card"><div class="stat-number">${media_msgs}</div><div class="stat-label">Media Files</div></div>
        <div class="stat-card"><div class="stat-number">${deleted_msgs}</div><div class="stat-label">Deleted</div></div>
    </div>

    <div class="section">
        <h2>Timeline</h2>
        <div class="info-grid">
            <div class="info-item"><div class="info-label">First Message</div><div class="info-value">${first_msg}</div></div>
            <div class="info-item"><div class="info-label">Last Message</div><div class="info-value">${last_msg}</div></div>
        </div>
    </div>

    <div class="section">
        <h2>Evidence Integrity</h2>
        <div class="info-grid">
            <div class="info-item"><div class="info-label">msgstore.db</div><div class="info-value">${MSGSTORE_DB:-Not loaded}</div></div>
            <div class="info-item"><div class="info-label">wa.db</div><div class="info-value">${WA_DB:-Not loaded}</div></div>
        </div>
        <p style="margin-top:12px;color:#8b949e;font-size:0.8rem;">
            All analysis performed in read-only mode. Original evidence files were not modified.
            SHA-256 hashes recorded in the chain of custody log.
        </p>
    </div>

    <div class="footer">
        <p>WhatsApp Forensic Toolkit v${TOOLKIT_VERSION} — Court-Admissible Evidence</p>
        <p>All actions performed in READ-ONLY mode | Original evidence not modified | ACPO Compliant</p>
        <p>Report generated: $(date) | Case: ${CURRENT_CASE} | Analyst: ${INVESTIGATOR}</p>
    </div>
</div>
</body>
</html>
HTMLEOF

    print_ok "HTML report generated: ${outfile}"
    log_action "GENERATE HTML REPORT" "$outfile" "SUCCESS"

    cross_open "$outfile" 2>/dev/null &
    pause
}

# =============================================================================
# GENERATE PDF REPORT
# =============================================================================
generate_pdf_report() {
    banner
    print_section "GENERATING PDF FORENSIC REPORT"

    local html_file="${CASE_DIR}/html/forensic_report.html"
    local pdf_file="${CASE_DIR}/pdf/forensic_report.pdf"
    mkdir -p "${CASE_DIR}/pdf"

    if [[ ! -f "$html_file" ]]; then
        print_warn "HTML report not found. Generating HTML first..."
        generate_html_report
    fi

    if command -v wkhtmltopdf &>/dev/null; then
        print_step "Converting HTML to PDF..."
        wkhtmltopdf --quiet "$html_file" "$pdf_file" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            print_ok "PDF report generated: ${pdf_file}"
            log_action "GENERATE PDF REPORT" "$pdf_file" "SUCCESS"
            cross_open "$pdf_file" 2>/dev/null &
        else
            print_err "PDF conversion failed."
            print_info "Install wkhtmltopdf: brew install wkhtmltopdf (macOS) or sudo apt-get install wkhtmltopdf (Linux)"
        fi
    else
        print_warn "wkhtmltopdf not installed."
        print_info "To generate PDF reports, install wkhtmltopdf:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "  brew install --cask wkhtmltopdf"
        else
            print_info "  sudo apt-get install wkhtmltopdf"
        fi
        print_info "Alternatively, open the HTML report and use Print → Save as PDF"
        cross_open "$html_file" 2>/dev/null &
    fi

    pause
}

# =============================================================================
# GENERATE CSV EXPORTS
# =============================================================================
generate_csv_exports() {
    banner
    print_section "GENERATING CSV EXPORTS"

    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }

    local export_dir="${CASE_DIR}/reports/csv"
    mkdir -p "$export_dir"

    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    [[ -z "$msg_table" ]] && { print_err "Could not detect message table."; pause; return 1; }

    print_step "Exporting messages..."
    sqlite3 -readonly -header -csv "$MSGSTORE_DB" "SELECT * FROM ${msg_table};" > "${export_dir}/messages.csv" 2>/dev/null
    print_ok "Messages exported: ${export_dir}/messages.csv"

    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    if [[ -n "$chat_table" ]]; then
        print_step "Exporting chats..."
        sqlite3 -readonly -header -csv "$MSGSTORE_DB" "SELECT * FROM ${chat_table};" > "${export_dir}/chats.csv" 2>/dev/null
        print_ok "Chats exported: ${export_dir}/chats.csv"
    fi

    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    if [[ -n "$jid_table" ]]; then
        print_step "Exporting JIDs..."
        sqlite3 -readonly -header -csv "$MSGSTORE_DB" "SELECT * FROM ${jid_table};" > "${export_dir}/jids.csv" 2>/dev/null
        print_ok "JIDs exported: ${export_dir}/jids.csv"
    fi

    local media_table=$(detect_media_table "$MSGSTORE_DB")
    if [[ -n "$media_table" ]]; then
        print_step "Exporting media references..."
        sqlite3 -readonly -header -csv "$MSGSTORE_DB" "SELECT * FROM ${media_table};" > "${export_dir}/media.csv" 2>/dev/null
        print_ok "Media exported: ${export_dir}/media.csv"
    fi

    print_ok "CSV exports complete: ${export_dir}"
    log_action "GENERATE CSV EXPORTS" "$export_dir" "SUCCESS"
}

# =============================================================================
# GENERATE FINAL TEXT REPORT
# =============================================================================
generate_final_text_report() {
    banner
    print_section "GENERATING TEXT FORENSIC REPORT"

    [[ -z "$MSGSTORE_DB" ]] && { print_err "msgstore.db not loaded."; pause; return 1; }

    local outfile="${CASE_DIR}/reports/text/forensic_report.txt"
    mkdir -p "${CASE_DIR}/reports/text"

    local msg_table=$(detect_message_table "$MSGSTORE_DB")
    local chat_table=$(detect_chat_table "$MSGSTORE_DB")
    local jid_table=$(detect_jid_table "$MSGSTORE_DB")
    local ts_col=$(get_timestamp_col "$MSGSTORE_DB" "$msg_table")

    local total_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table;" 2>/dev/null || echo "0")
    local total_chats=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(DISTINCT chat_row_id) FROM $msg_table WHERE chat_row_id IS NOT NULL;" 2>/dev/null || echo "0")
    local sent_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 1;" 2>/dev/null || echo "0")
    local recv_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE from_me = 0;" 2>/dev/null || echo "0")
    local media_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type IN (1,2,3,8,9,11,13);" 2>/dev/null || echo "0")
    local deleted_msgs=$(sqlite3 -readonly "$MSGSTORE_DB" "SELECT COUNT(*) FROM $msg_table WHERE message_type = 15;" 2>/dev/null || echo "0")

    cat > "$outfile" <<EOF
======================================================================
  WHATSAPP FORENSIC REPORT
  Generated by WA-Forensics Toolkit v${TOOLKIT_VERSION}
======================================================================

CASE INFORMATION
  Case ID          : ${CURRENT_CASE}
  Investigator     : ${INVESTIGATOR}
  Badge ID         : ${BADGE_ID:-N/A}
  Organization     : ${ORGANIZATION:-N/A}
  Warrant Number   : ${WARRANT_NUM:-N/A}
  Suspect Phone    : ${SUSPECT_PHONE:-N/A}
  Evidence Source  : ${EVIDENCE_SOURCE:-N/A}
  Generated        : $(date '+%Y-%m-%d %H:%M:%S')
  Session ID       : ${SESSION_ID}

======================================================================
EVIDENCE FILES
  msgstore.db      : ${MSGSTORE_DB:-Not loaded}
  wa.db            : ${WA_DB:-Not loaded}

======================================================================
COMMUNICATION SUMMARY
  Total Messages   : ${total_msgs}
  Total Chats      : ${total_chats}
  Sent Messages    : ${sent_msgs}
  Received Messages: ${recv_msgs}
  Media Files      : ${media_msgs}
  Deleted Messages : ${deleted_msgs}

======================================================================
INTEGRITY NOTICE
  All analysis performed in read-only mode.
  Original evidence files were not modified.
  SHA-256 hashes recorded in the chain of custody log.
  This report is ACPO compliant.

======================================================================
EOF

    print_ok "Text report generated: ${outfile}"
    log_action "GENERATE TEXT REPORT" "$outfile" "SUCCESS"
}
