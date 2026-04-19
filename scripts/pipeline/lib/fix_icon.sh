#!/usr/bin/env bash
# fix_icon.sh — detect and strip alpha channel from AppIcon PNGs
# Usage: fix_icon_check <appiconset_dir>  → exits 0 if clean, 1 if fixed
set -euo pipefail

fix_icon_check() {
    local iconset="$1"
    local fixed=0
    local issues=0

    if [[ ! -d "$iconset" ]]; then
        echo "[icon] ERROR: iconset not found: $iconset"
        return 2
    fi

    while IFS= read -r -d '' png; do
        local has_alpha
        has_alpha=$(sips -g hasAlpha "$png" 2>/dev/null | awk '/hasAlpha/ {print $2}')
        if [[ "$has_alpha" == "yes" ]]; then
            issues=$((issues + 1))
            echo "[icon] alpha detected: $(basename "$png") — stripping"
            # Flatten over white via ImageMagick if available, else sips re-encode JPEG→PNG trick
            local tmp="${png}.noalpha.png"
            # sips cannot directly strip alpha; use a two-step: export to JPEG (drops alpha) then back to PNG
            local tmp_jpg="${png}.tmp.jpg"
            sips -s format jpeg -s formatOptions best "$png" --out "$tmp_jpg" >/dev/null
            sips -s format png "$tmp_jpg" --out "$tmp" >/dev/null
            rm -f "$tmp_jpg"
            mv "$tmp" "$png"
            fixed=$((fixed + 1))
            echo "[icon] fixed: $(basename "$png")"
        fi
    done < <(find "$iconset" -type f -name "*.png" -print0)

    if [[ $issues -eq 0 ]]; then
        echo "[icon] OK — no alpha channel on any icon"
        return 0
    else
        echo "[icon] fixed $fixed/${issues} icons"
        return 1
    fi
}

# Standalone invocation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_icon_check "${1:?usage: fix_icon.sh <AppIcon.appiconset>}"
fi
