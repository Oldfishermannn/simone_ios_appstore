#!/usr/bin/env bash
# bump_build.sh — ensure CFBundleVersion > last submitted
# Usage: bump_build_check <Info.plist> <state_file>
# State file stores last known version.
set -euo pipefail

bump_build_check() {
    local plist="$1"
    local state="$2"

    local current
    current=$(plutil -extract CFBundleVersion raw -o - "$plist" 2>/dev/null || echo "")
    if [[ -z "$current" ]]; then
        echo "[bump] ERROR: CFBundleVersion missing"
        return 2
    fi

    local last=""
    if [[ -f "$state" ]]; then
        last=$(grep '^LAST_BUILD=' "$state" 2>/dev/null | cut -d= -f2 || echo "")
    fi

    echo "[bump] current build: $current   last recorded: ${last:-<none>}"

    # If integer and <= last, bump to last+1
    if [[ -n "$last" && "$current" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]]; then
        if (( current <= last )); then
            local next=$((last + 1))
            echo "[bump] build not incremented ($current <= $last) — bumping to $next"
            plutil -replace CFBundleVersion -string "$next" "$plist"
            echo "LAST_BUILD=$next" > "$state.tmp" && mv "$state.tmp" "$state"
            return 1
        fi
    fi

    # Record current as last
    mkdir -p "$(dirname "$state")"
    echo "LAST_BUILD=$current" > "$state.tmp" && mv "$state.tmp" "$state"
    echo "[bump] OK"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    bump_build_check "${1:?}" "${2:?}"
fi
