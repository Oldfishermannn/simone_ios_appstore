#!/usr/bin/env bash
# fix_shots.sh — validate and auto-resize App Store screenshots
# Usage: fix_shots_check <screenshots_dir>
# Expects subfolders like: iPhone_6.7/, iPhone_6.5/, iPhone_5.5/, iPad_12.9/
#
# Required resolutions (iOS App Store, 2026-04):
#   iPhone 6.9"/6.7"/6.5" display: 1290x2796 portrait (or 2796x1290 landscape)
#   iPhone 5.5" display:           1242x2208 portrait (or 2208x1242 landscape)
#   iPad Pro 13" (6th gen):        2064x2752 portrait (or 2752x2064 landscape)
#   iPad Pro 12.9" (2/3gen):       2048x2732 portrait (or 2732x2048 landscape)
set -euo pipefail

declare -a TARGETS=(
    "iPhone_6.7|1290|2796"
    "iPhone_6.5|1242|2688"
    "iPhone_5.5|1242|2208"
    "iPad_13|2064|2752"
    "iPad_12.9|2048|2732"
)

fix_shots_check() {
    local root="$1"
    local total=0
    local fixed=0
    local issues=0

    if [[ ! -d "$root" ]]; then
        echo "[shots] screenshots dir not present: $root"
        echo "[shots] SKIP — Simone v1.x uses App Store Connect web upload; no local screenshots pipeline"
        return 0
    fi

    for spec in "${TARGETS[@]}"; do
        IFS='|' read -r folder w h <<< "$spec"
        local dir="$root/$folder"
        [[ ! -d "$dir" ]] && continue

        while IFS= read -r -d '' shot; do
            total=$((total + 1))
            local dim
            dim=$(sips -g pixelWidth -g pixelHeight "$shot" 2>/dev/null | awk '/pixel/ {print $2}' | paste -sd 'x' -)
            local actual_w actual_h
            actual_w=$(echo "$dim" | cut -dx -f1)
            actual_h=$(echo "$dim" | cut -dx -f2)

            if [[ "$actual_w" == "$w" && "$actual_h" == "$h" ]]; then
                continue
            fi
            if [[ "$actual_w" == "$h" && "$actual_h" == "$w" ]]; then
                continue  # landscape variant ok
            fi

            issues=$((issues + 1))
            echo "[shots] $folder/$(basename "$shot"): ${dim} != ${w}x${h} — resizing"
            sips -z "$h" "$w" "$shot" >/dev/null
            fixed=$((fixed + 1))
        done < <(find "$dir" -type f \( -name "*.png" -o -name "*.jpg" \) -print0)
    done

    echo "[shots] scanned $total screenshots, fixed $fixed/${issues}"
    [[ $issues -eq 0 ]] && return 0 || return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_shots_check "${1:?usage: fix_shots.sh <screenshots_dir>}"
fi
