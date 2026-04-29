#!/usr/bin/env bash
# =============================================================================
#  DATABASE HANDLER — Acquire, validate, and query evidence databases
# =============================================================================

validate_database() {
    local db_path="$1"
    local label="${2:-database}"
    
    if [[ ! -f "$db_path" ]]; then
        print_err "File not found: $db_path"
        return 1
    fi
    
    local size=$(cross_file_size "$db_path" 2>/dev/null || echo 0)
    if [[ "$size" -eq 0 ]]; then
        print_err "File is empty: $db_path"
        return 1
    fi
    
    # Check SQLite magic bytes
    local magic=$(head -c 16 "$db_path" 2>/dev/null | head -c 15)
    
    if [[ "$magic" != "SQLite format 3" ]]; then
        # Check if encrypted
        local ext="${db_path##*.}"
        if [[ "$ext" =~ ^crypt ]]; then
            print_warn "Encrypted database detected (${ext})."
            return 2  # Return 2 = encrypted
        fi
        print_err "Not a valid SQLite database: $db_path"
        return 1
    fi
    
    # Compute hashes
    local sha256=$(cross_sha256sum "$db_path")
    local md5=$(cross_md5sum "$db_path")
    
    print_ok "Database validated: ${label}"
    print_info "Size: $(cross_human_size "$size")"
    print_info "SHA-256: $sha256"
    print_info "MD5: $md5"
    
    # Record hash
    {
        echo "========================================"
        echo "  EVIDENCE INTEGRITY RECORD"
        echo "========================================"
        echo "  Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Label     : $label"
        echo "  File      : $db_path"
        echo "  Size      : $size bytes"
        echo "  SHA-256   : $sha256"
        echo "  MD5       : $md5"
        echo "  Analyst   : ${INVESTIGATOR}"
        echo "  Session   : ${SESSION_ID}"
        echo "========================================"
        echo ""
    } >> "${CASE_DIR}/evidence/hash_registry.txt"
    
    return 0
}

acquire_database() {
    local src="$1"
    local label="$2"
    local dest="${CASE_DIR}/databases/${label}"
    
    if [[ -f "$dest" ]]; then
        print_warn "Evidence copy already exists: $dest"
        if ! confirm "Overwrite?"; then
            return 0
        fi
        chmod 644 "$dest" 2>/dev/null || true
    fi
    
    cp --preserve=all "$src" "$dest" 2>/dev/null || cp "$src" "$dest"
    chmod 444 "$dest"  # Read-only
    
    print_ok "Evidence acquired: $dest (read-only)"
    log_action "ACQUIRE EVIDENCE" "${src} → ${dest}" "SUCCESS"
    
    # Also copy WAL/SHM if present
    [[ -f "${src}-wal" ]] && cp "${src}-wal" "${CASE_DIR}/databases/${label}-wal" 2>/dev/null
    [[ -f "${src}-shm" ]] && cp "${src}-shm" "${CASE_DIR}/databases/${label}-shm" 2>/dev/null
}

auto_discover_databases() {
    print_step "Scanning for WhatsApp databases..."
    
    local search_paths=(
        "$HOME/WhatsApp/Databases"
        "$HOME/storage/emulated/0/WhatsApp/Databases"
        "/sdcard/WhatsApp/Databases"
        "/data/data/com.whatsapp/databases"
        "$HOME/Downloads"
        "$HOME/Desktop"
        "."
    )
    
    local found_dbs=()
    
    for path in "${search_paths[@]}"; do
        [[ -d "$path" ]] || continue
        while IFS= read -r -d '' f; do
            found_dbs+=("$f")
        done < <(find "$path" -maxdepth 3 \
            \( -name "msgstore.db" -o -name "wa.db" -o -name "msgstore.db.crypt*" \) \
            -print0 2>/dev/null)
    done
    
    if [[ ${#found_dbs[@]} -eq 0 ]]; then
        print_warn "No databases found in standard locations."
        return 1
    fi
    
    print_ok "Found ${#found_dbs[@]} database(s):"
    local i=1
    for db in "${found_dbs[@]}"; do
        echo "  ${i}. $db"
        ((i++))
    done
    
    return 0
}

prompt_database() {
    local label="$1"
    local var_name="$2"
    
    echo ""
    read -rp "  Enter path to ${label} (or press ENTER to skip): " db_input
    
    [[ -z "$db_input" ]] && return 1
    
    db_input="${db_input/#\~/$HOME}"
    
    validate_database "$db_input" "$label"
    local rc=$?
    
    if [[ $rc -eq 1 ]]; then
        log_action "Validate DB" "$db_input" "FAILED"
        return 1
    fi
    
    if [[ $rc -eq 2 ]]; then
        print_warn "Encrypted database detected."
        if confirm "Attempt decryption? (Requires key file)"; then
            if decrypt_database "$db_input" "$label"; then
                return 0
            fi
        fi
        return 1
    fi
    
    acquire_database "$db_input" "$label"
    local dest="${CASE_DIR}/databases/${label}"
    eval "${var_name}='${dest}'"
    
    return 0
}

decrypt_database() {
    local src="$1"
    local label="$2"
    
    print_info "Decryption requires the key file extracted from the device."
    read -rp "  Enter path to key file: " key_file
    
    if [[ ! -f "$key_file" ]]; then
        print_err "Key file not found."
        return 1
    fi
    
    local output="${CASE_DIR}/databases/${label}"
    
    print_step "Attempting decryption using Python helper..."
    
    python3 "${LIB_DIR}/decrypt_helper.py" \
        --keyfile "$key_file" \
        --encrypted "$src" \
        --output "$output" 2>/dev/null
    
    if [[ $? -eq 0 ]] && [[ -f "$output" ]]; then
        chmod 444 "$output"
        print_ok "Decryption successful: $output"
        log_action "DECRYPT DATABASE" "$src" "SUCCESS"
        return 0
    else
        print_err "Decryption failed."
        log_action "DECRYPT DATABASE" "$src" "FAILED"
        return 1
    fi
}

load_databases_interactive() {
    banner
    print_section "LOAD EVIDENCE DATABASES"
    
    echo -e "${YELLOW}  Database Loading Options:${RESET}"
    echo "  1. Auto-discover databases"
    echo "  2. Manually specify paths"
    echo "  3. Use already-loaded databases"
    echo ""
    read -rp "  Select: " choice
    
    case "$choice" in
        1)
            auto_discover_databases
            echo ""
            print_info "Review found databases above and enter paths manually."
            ;;
        2)
            print_step "Loading msgstore.db (chat database)..."
            if ! prompt_database "msgstore.db" MSGSTORE_DB; then
                print_warn "msgstore.db not loaded."
            else
                save_case_state
            fi
            
            print_step "Loading wa.db (contacts database)..."
            if ! prompt_database "wa.db" WA_DB; then
                print_warn "wa.db not loaded."
            else
                save_case_state
            fi
            ;;
        3)
            if [[ -z "$MSGSTORE_DB" ]] && [[ -z "$WA_DB" ]]; then
                print_warn "No databases currently loaded."
            else
                print_ok "Using loaded databases:"
                [[ -n "$MSGSTORE_DB" ]] && print_info "msgstore.db: $MSGSTORE_DB"
                [[ -n "$WA_DB" ]] && print_info "wa.db: $WA_DB"
            fi
            ;;
        *)
            print_warn "Invalid selection."
            ;;
    esac
    
    pause
}

run_query() {
    local db="$1"
    local sql="$2"
    local outfile="$3"
    local format="${4:-csv}"
    
    if [[ ! -f "$db" ]]; then
        print_err "Database not found: $db"
        return 1
    fi
    
    local fmt_flags
    case "$format" in
        csv)    fmt_flags="-csv -header" ;;
        json)   fmt_flags="-json" ;;
        list)   fmt_flags="-separator '|'" ;;
        column) fmt_flags="-column -header" ;;
        *)      fmt_flags="-csv -header" ;;
    esac
    
    eval sqlite3 -readonly $fmt_flags "\"$db\"" "\"$sql\"" > "$outfile" 2>&1
    local rc=$?
    
    if [[ $rc -eq 0 ]]; then
        local rows=$(wc -l < "$outfile")
        log_action "Query Executed" "$db" "SUCCESS — ${rows} rows"
        return 0
    else
        log_action "Query Executed" "$db" "FAILED"
        return 1
    fi
}

extract_schema() {
    local outfile="${CASE_DIR}/reports/schema.txt"
    
    {
        echo "DATABASE SCHEMA"
        echo "==============="
        echo "Generated: $(date)"
        echo ""
        
        if [[ -n "$MSGSTORE_DB" ]]; then
            echo "--- msgstore.db ---"
            sqlite3 -readonly "$MSGSTORE_DB" ".schema" 2>/dev/null
            echo ""
            echo "Tables:"
            sqlite3 -readonly "$MSGSTORE_DB" ".tables" 2>/dev/null
        fi
        
        if [[ -n "$WA_DB" ]]; then
            echo ""
            echo "--- wa.db ---"
            sqlite3 -readonly "$WA_DB" ".schema" 2>/dev/null
            echo ""
            echo "Tables:"
            sqlite3 -readonly "$WA_DB" ".tables" 2>/dev/null
        fi
    } > "$outfile"
    
    print_ok "Schema extracted: $outfile"
}

view_schema() {
    if [[ -f "${CASE_DIR}/reports/schema.txt" ]]; then
        cat "${CASE_DIR}/reports/schema.txt"
    else
        extract_schema
        cat "${CASE_DIR}/reports/schema.txt"
    fi
    pause
}

export_raw_tables() {
    banner
    print_section "EXPORT RAW TABLES"
    
    local db="${MSGSTORE_DB}"
    [[ -z "$db" ]] && { print_err "No database loaded."; pause; return 1; }
    
    local ts=$(date '+%Y%m%d_%H%M%S')
    local export_dir="${CASE_DIR}/extracted/raw_export_${ts}"
    mkdir -p "$export_dir"
    
    local tables=$(sqlite3 -readonly "$db" ".tables" 2>/dev/null | tr ' ' '\n' | grep -v '^$')
    
    for table in $tables; do
        # CSV export
        sqlite3 -readonly -csv -header "$db" "SELECT * FROM \"${table}\";" \
            > "${export_dir}/${table}.csv" 2>/dev/null
        
        # JSON export
        sqlite3 -readonly -json "$db" "SELECT * FROM \"${table}\";" \
            > "${export_dir}/${table}.json" 2>/dev/null
        
        local rows=$(wc -l < "${export_dir}/${table}.csv" 2>/dev/null || echo 0)
        print_ok "Table '${table}': $((rows - 1)) rows → CSV + JSON"
    done
    
    print_ok "Export complete: $export_dir"
    log_action "Export Raw Tables" "$db" "SUCCESS"
    pause
}

database_integrity_check() {
    banner
    print_section "DATABASE INTEGRITY CHECK"
    
    for db in "$MSGSTORE_DB" "$WA_DB"; do
        [[ -z "$db" ]] && continue
        [[ ! -f "$db" ]] && continue
        
        print_step "Checking: $db"
        local result=$(sqlite3 -readonly "$db" "PRAGMA integrity_check;" 2>/dev/null)
        
        if [[ "$result" == "ok" ]]; then
            print_ok "Integrity: OK"
        else
            print_warn "Result: $result"
        fi
        log_action "Integrity Check" "$db" "$result"
    done
    
    pause
}

custom_sql_query() {
    banner
    print_section "CUSTOM SQL QUERY"
    
    [[ -z "$MSGSTORE_DB" ]] && { print_err "No database loaded."; pause; return 1; }
    
    print_warn "SECURITY: Only SELECT statements permitted. Read-only mode active."
    echo ""
    read -rp "  Enter SQL query: " sql
    
    local first_word=$(echo "$sql" | awk '{print toupper($1)}')
    if [[ "$first_word" != "SELECT" && "$first_word" != ".SCHEMA" && "$first_word" != ".TABLES" ]]; then
        print_err "Only SELECT statements permitted."
        pause
        return 1
    fi
    
    local outfile="${CASE_DIR}/extracted/custom_query_$(date '+%Y%m%d%H%M%S').txt"
    
    sqlite3 -readonly -column -header "$MSGSTORE_DB" "$sql" > "$outfile" 2>&1
    
    cat "$outfile"
    log_action "Custom SQL Query" "$MSGSTORE_DB" "SUCCESS"
    print_ok "Output saved: $outfile"
    pause
}
