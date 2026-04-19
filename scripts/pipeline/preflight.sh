#!/usr/bin/env bash
# preflight.sh — run all App Store submission pre-checks, auto-fix when possible
# Exits 0 if everything passes (after fixes). Exits >0 only for unfixable blockers.
set -uo pipefail   # not -e: we want to aggregate issues, not die on first

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$PIPELINE_DIR")")"

source "$PIPELINE_DIR/lib/ntfy.sh"
source "$PIPELINE_DIR/lib/fix_icon.sh"
source "$PIPELINE_DIR/lib/fix_shots.sh"
source "$PIPELINE_DIR/lib/fix_plist.sh"
source "$PIPELINE_DIR/lib/bump_build.sh"

PLIST="$PROJECT_ROOT/Simone/Info.plist"
ICONSET="$PROJECT_ROOT/Simone/Assets.xcassets/AppIcon.appiconset"
SRC_DIR="$PROJECT_ROOT/Simone"
SHOTS_DIR="$PROJECT_ROOT/fastlane/screenshots"
STATE="$PIPELINE_DIR/.pipeline_state"

REPORT_JSON="$PIPELINE_DIR/.preflight_report.json"
> "$REPORT_JSON"

declare -a BLOCKERS=()
declare -a FIXED=()
declare -a OK=()

_record() {
    # $1 = status (OK|FIXED|BLOCKER)  $2 = check name  $3 = detail
    case "$1" in
        OK)      OK+=("$2: $3") ;;
        FIXED)   FIXED+=("$2: $3") ;;
        BLOCKER) BLOCKERS+=("$2: $3") ;;
    esac
}

echo "==============================================="
echo " Simone Preflight"
echo " Project: $PROJECT_ROOT"
echo " Notify:  $(ntfy_url)"
echo "==============================================="
ntfy "🚀 Preflight starting ($(basename "$PROJECT_ROOT"))"

# -----------------------------------------------------------------------------
# Check 1: App icon alpha
# -----------------------------------------------------------------------------
echo ""
echo "[1/5] App icon alpha channel"
if fix_icon_check "$ICONSET"; then
    _record OK "icon" "no alpha"
else
    rc=$?
    if [[ $rc -eq 1 ]]; then
        _record FIXED "icon" "alpha stripped"
    else
        _record BLOCKER "icon" "iconset missing or unreadable"
    fi
fi

# -----------------------------------------------------------------------------
# Check 2: Screenshot resolutions
# -----------------------------------------------------------------------------
echo ""
echo "[2/5] Screenshot resolutions"
if fix_shots_check "$SHOTS_DIR"; then
    _record OK "screenshots" "all match / no local screenshots"
else
    _record FIXED "screenshots" "resized out-of-spec images"
fi

# -----------------------------------------------------------------------------
# Check 3: Info.plist privacy + compliance keys
# -----------------------------------------------------------------------------
echo ""
echo "[3/5] Info.plist keys"
if fix_plist_check "$PLIST" "$SRC_DIR"; then
    _record OK "plist" "all required keys present"
else
    rc=$?
    if [[ $rc -eq 1 ]]; then
        _record FIXED "plist" "inserted missing keys"
    else
        _record BLOCKER "plist" "Info.plist malformed or unfixable"
    fi
fi

# -----------------------------------------------------------------------------
# Check 4: Bundle version increment
# -----------------------------------------------------------------------------
echo ""
echo "[4/5] Bundle version increment"
if bump_build_check "$PLIST" "$STATE"; then
    _record OK "version" "build number fresh"
else
    rc=$?
    if [[ $rc -eq 1 ]]; then
        _record FIXED "version" "bumped"
    else
        _record BLOCKER "version" "CFBundleVersion unreadable"
    fi
fi

# -----------------------------------------------------------------------------
# Check 5: Export compliance (already inside fix_plist, but double-check)
# -----------------------------------------------------------------------------
echo ""
echo "[5/5] Export compliance"
if plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$PLIST" >/dev/null 2>&1; then
    _record OK "compliance" "ITSAppUsesNonExemptEncryption set"
else
    _record BLOCKER "compliance" "encryption declaration missing (should have been auto-set)"
fi

# -----------------------------------------------------------------------------
# Bonus: API key presence (non-blocking — submit.sh will re-check)
# -----------------------------------------------------------------------------
echo ""
echo "[bonus] App Store Connect API key"
api_key=$(find "$HOME/.appstoreconnect/private_keys" -maxdepth 1 -name 'AuthKey_*.p8' 2>/dev/null | head -1 || true)
if [[ -n "$api_key" ]]; then
    echo "[apikey] found: $(basename "$api_key")"
    _record OK "apikey" "$(basename "$api_key")"
else
    echo "[apikey] NOT FOUND"
    echo "[apikey] To enable altool upload:"
    echo "  1) App Store Connect → Users & Access → Integrations → Team Keys → Generate"
    echo "  2) mkdir -p ~/.appstoreconnect/private_keys"
    echo "  3) mv ~/Downloads/AuthKey_XXXX.p8 ~/.appstoreconnect/private_keys/"
    echo "  4) export ASC_KEY_ID=XXXX ASC_ISSUER_ID=<uuid>"
    _record FIXED "apikey" "missing (instructions printed)"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "==============================================="
echo " Preflight Summary"
echo "==============================================="
echo "✅ Passed     (${#OK[@]}):"
[[ ${#OK[@]} -gt 0 ]] && printf '   - %s\n' "${OK[@]+"${OK[@]}"}"
echo ""
echo "🔧 Auto-fixed (${#FIXED[@]}):"
[[ ${#FIXED[@]} -gt 0 ]] && printf '   - %s\n' "${FIXED[@]+"${FIXED[@]}"}"
echo ""
echo "❌ Blockers   (${#BLOCKERS[@]}):"
[[ ${#BLOCKERS[@]} -gt 0 ]] && printf '   - %s\n' "${BLOCKERS[@]+"${BLOCKERS[@]}"}"

# JSON report (guard empty arrays under set -u)
_json_arr() {
    local arr=("$@")
    if [[ ${#arr[@]} -eq 0 ]]; then echo "[]"; return; fi
    printf '['; printf '"%s",' "${arr[@]}" | sed 's/,$//'; printf ']'
}
{
    echo '{'
    echo "  \"ok\":       $(_json_arr "${OK[@]+"${OK[@]}"}"),"
    echo "  \"fixed\":    $(_json_arr "${FIXED[@]+"${FIXED[@]}"}"),"
    echo "  \"blockers\": $(_json_arr "${BLOCKERS[@]+"${BLOCKERS[@]}"}")"
    echo '}'
} > "$REPORT_JSON"

if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
    ntfy "❌ Preflight blockers: ${#BLOCKERS[@]}" "high"
    exit 1
fi

if [[ ${#FIXED[@]} -gt 0 ]]; then
    ntfy "🔧 Preflight auto-fixed ${#FIXED[@]} issue(s) — proceeding"
else
    ntfy "✅ Preflight clean"
fi
exit 0
