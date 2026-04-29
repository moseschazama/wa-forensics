#!/usr/bin/env bash
# =============================================================================
#  CROSS-PLATFORM COMPATIBILITY LAYER
#  Provides macOS/Linux compatible versions of common commands
# =============================================================================

# ── SHA-256 Hash ──────────────────────────────────────────────────────────────
# Usage: cross_sha256sum <file>
# Returns SHA-256 hash (just the hash value, no filename)
cross_sha256sum() {
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        echo "ERROR: No SHA-256 tool found" >&2
        return 1
    fi
}

# ── MD5 Hash ──────────────────────────────────────────────────────────────────
# Usage: cross_md5sum <file>
# Returns MD5 hash (just the hash value, no filename)
cross_md5sum() {
    local file="$1"
    if command -v md5sum &>/dev/null; then
        md5sum "$file" | awk '{print $1}'
    elif command -v md5 &>/dev/null; then
        md5 -r "$file" | awk '{print $1}'
    else
        echo "ERROR: No MD5 tool found" >&2
        return 1
    fi
}

# ── File Size ─────────────────────────────────────────────────────────────────
# Usage: cross_file_size <file>
# Returns file size in bytes
cross_file_size() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$file" 2>/dev/null
    else
        stat -c%s "$file" 2>/dev/null
    fi
}

# ── File Modification Date ────────────────────────────────────────────────────
# Usage: cross_file_moddate <file>
# Returns file modification date string
cross_file_moddate() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f %Sm "$file" 2>/dev/null
    else
        stat -c %y "$file" 2>/dev/null | cut -d'.' -f1
    fi
}

# ── Open File/URL ─────────────────────────────────────────────────────────────
# Usage: cross_open <file_or_url>
# Opens file or URL in default application
cross_open() {
    local target="$1"
    if command -v xdg-open &>/dev/null; then
        xdg-open "$target" 2>/dev/null
    elif command -v open &>/dev/null; then
        open "$target" 2>/dev/null
    else
        echo "WARNING: No file opener found. Open manually: $target" >&2
        return 1
    fi
}

# ── Human-Readable File Size ──────────────────────────────────────────────────
# Usage: cross_human_size <bytes>
# Returns human-readable size (e.g., "1.2M", "3.4G")
cross_human_size() {
    local size="$1"
    if command -v numfmt &>/dev/null; then
        numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size} bytes"
    else
        if [[ "$size" -ge 1073741824 ]]; then
            echo "$(echo "$size" | awk '{printf "%.1fG", $1/1073741824}')B"
        elif [[ "$size" -ge 1048576 ]]; then
            echo "$(echo "$size" | awk '{printf "%.1fM", $1/1048576}')B"
        elif [[ "$size" -ge 1024 ]]; then
            echo "$(echo "$size" | awk '{printf "%.1fK", $1/1024}')B"
        else
            echo "${size}B"
        fi
    fi
}

# ── Detect OS Type ────────────────────────────────────────────────────────────
# Returns: "linux", "macos", or "unknown"
cross_detect_os() {
    case "$OSTYPE" in
        linux-gnu*) echo "linux" ;;
        darwin*)    echo "macos" ;;
        *)          echo "unknown" ;;
    esac
}
