#!/usr/bin/env bash
# submit.sh — archive, validate (dry-run by default), self-heal retry, generate notes
# Usage: submit.sh [--live]    # --live actually uploads; default is dry-run (validate-only)
set -uo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$PIPELINE_DIR")")"
cd "$PROJECT_ROOT"

source "$PIPELINE_DIR/lib/ntfy.sh"
source "$PIPELINE_DIR/lib/parse_error.sh"

# Auto-load credentials if .env present (chmod 600, gitignored)
if [[ -f "$PIPELINE_DIR/.env" ]]; then
    set -a; source "$PIPELINE_DIR/.env"; set +a
fi

MODE="dry-run"
[[ "${1:-}" == "--live" ]] && MODE="live"

PLIST="$PROJECT_ROOT/Simone/Info.plist"
ICONSET="$PROJECT_ROOT/Simone/Assets.xcassets/AppIcon.appiconset"
SHOTS_DIR="$PROJECT_ROOT/fastlane/screenshots"
STATE="$PIPELINE_DIR/.pipeline_state"
WORK="$PIPELINE_DIR/.work"
ARCHIVE="$WORK/Simone.xcarchive"
IPA_DIR="$WORK/ipa"
IPA="$IPA_DIR/Simone.ipa"
VALIDATE_LOG="$WORK/validate.log"
VALIDATE_JSON="$WORK/validate.json"

mkdir -p "$WORK" "$IPA_DIR"

# Locate API key early — needed by xcodebuild for automatic signing updates
API_KEY_FILE=$(find "$HOME/.appstoreconnect/private_keys" -maxdepth 1 -name 'AuthKey_*.p8' 2>/dev/null | head -1 || true)
XC_AUTH_ARGS=()
if [[ -n "$API_KEY_FILE" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
    XC_AUTH_ARGS=(
        -allowProvisioningUpdates
        -authenticationKeyPath "$API_KEY_FILE"
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    )
fi

# -----------------------------------------------------------------------------
# Stage 1: Preflight
# -----------------------------------------------------------------------------
ntfy "🚀 Submit starting — mode=$MODE"
if ! "$PIPELINE_DIR/preflight.sh"; then
    ntfy "❌ Preflight blocked submit" "high"
    exit 1
fi

# -----------------------------------------------------------------------------
# Stage 2: Archive
# -----------------------------------------------------------------------------
ntfy "📦 Archiving…"
echo ""
echo "=== Archiving ==="
# Clean old archive
rm -rf "$ARCHIVE"

if ! xcodebuild -project "$PROJECT_ROOT/Simone.xcodeproj" \
    -scheme Simone \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    "${XC_AUTH_ARGS[@]}" \
    archive 2>&1 | tee "$WORK/archive.log" | tail -30
then
    ntfy "❌ Archive failed — see $WORK/archive.log" "high"
    exit 2
fi

if [[ ! -d "$ARCHIVE" ]]; then
    ntfy "❌ Archive output missing" "high"
    exit 2
fi
ntfy "✅ Archive built"

# -----------------------------------------------------------------------------
# Stage 3: Export IPA
# -----------------------------------------------------------------------------
echo ""
echo "=== Exporting IPA ==="
EXPORT_OPTS="$WORK/ExportOptions.plist"
cat > "$EXPORT_OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>          <string>app-store-connect</string>
    <key>teamID</key>          <string>9YD5W53S9K</string>
    <key>signingStyle</key>    <string>automatic</string>
    <key>uploadSymbols</key>   <true/>
    <key>uploadBitcode</key>   <false/>
</dict>
</plist>
PLIST

if ! xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$IPA_DIR" \
    -exportOptionsPlist "$EXPORT_OPTS" \
    "${XC_AUTH_ARGS[@]}" 2>&1 | tee "$WORK/export.log" | tail -15
then
    ntfy "❌ Export failed — see $WORK/export.log" "high"
    exit 3
fi

# xcodebuild names it after scheme
IPA=$(find "$IPA_DIR" -name "*.ipa" | head -1)
if [[ -z "$IPA" || ! -f "$IPA" ]]; then
    ntfy "❌ IPA not produced" "high"
    exit 3
fi
ntfy "📦 IPA: $(basename "$IPA") ($(du -h "$IPA" | cut -f1))"

# -----------------------------------------------------------------------------
# Stage 4: Validate with retry + self-heal
# -----------------------------------------------------------------------------
if [[ -z "$API_KEY_FILE" || -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
    ntfy "⚠️  Missing ASC credentials — cannot validate" "high"
    echo "Need ASC_KEY_ID + ASC_ISSUER_ID in scripts/pipeline/.env and a .p8 in ~/.appstoreconnect/private_keys/"
    exit 10
fi

MAX_RETRIES=3
attempt=0
while (( attempt < MAX_RETRIES )); do
    attempt=$((attempt + 1))
    ntfy "🔎 Validation attempt ${attempt}/${MAX_RETRIES}"
    echo ""
    echo "=== altool validate-app (attempt $attempt) ==="

    if xcrun altool --validate-app \
        --file "$IPA" \
        --type ios \
        --apiKey "$ASC_KEY_ID" \
        --apiIssuer "$ASC_ISSUER_ID" \
        --output-format json 2>"$VALIDATE_LOG" > "$VALIDATE_JSON"
    then
        ntfy "✅ Validation passed on attempt ${attempt}"
        break
    fi

    # altool returned non-zero; parse
    echo "[validate] failed — parsing error"
    cat "$VALIDATE_LOG" | tail -20
    # altool JSON may be in stderr for some versions; merge
    if [[ ! -s "$VALIDATE_JSON" ]]; then
        cp "$VALIDATE_LOG" "$VALIDATE_JSON"
    fi

    if (( attempt >= MAX_RETRIES )); then
        ntfy "❌ Validation failed after ${MAX_RETRIES} attempts — giving up" "high"
        echo ""
        echo "=== Final validate.json ==="
        cat "$VALIDATE_JSON"
        exit 4
    fi

    ntfy "🔧 Attempting auto-fix for attempt ${attempt}"
    if ! parse_error "$VALIDATE_JSON" "$PROJECT_ROOT" "$PLIST" "$ICONSET" "$SHOTS_DIR" "$STATE"; then
        ntfy "⚠️  Auto-fix failed or no route — will retry anyway"
    fi

    # Re-archive so fix takes effect
    ntfy "♻️  Re-archiving after auto-fix"
    rm -rf "$ARCHIVE" "$IPA_DIR"/*.ipa
    xcodebuild -project "$PROJECT_ROOT/Simone.xcodeproj" \
        -scheme Simone -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$ARCHIVE" \
        "${XC_AUTH_ARGS[@]}" archive >"$WORK/archive_retry_$attempt.log" 2>&1 \
        || { ntfy "❌ Re-archive failed" "high"; exit 2; }
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportPath "$IPA_DIR" \
        -exportOptionsPlist "$EXPORT_OPTS" \
        "${XC_AUTH_ARGS[@]}" >"$WORK/export_retry_$attempt.log" 2>&1 \
        || { ntfy "❌ Re-export failed" "high"; exit 3; }
    IPA=$(find "$IPA_DIR" -name "*.ipa" | head -1)
done

# -----------------------------------------------------------------------------
# Stage 5: Release notes
# -----------------------------------------------------------------------------
echo ""
echo "=== Release Notes ==="
NOTES="$WORK/release_notes.txt"
"$PIPELINE_DIR/release_notes.sh" > "$NOTES"
cat "$NOTES"
ntfy "📝 Release notes generated ($(wc -l < "$NOTES") lines)"

# -----------------------------------------------------------------------------
# Stage 6: Upload (live only)
# -----------------------------------------------------------------------------
if [[ "$MODE" == "live" ]]; then
    ntfy "📤 Uploading to App Store Connect…"
    if xcrun altool --upload-app --file "$IPA" --type ios \
        --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | tee "$WORK/upload.log"
    then
        ntfy "✅ Upload complete — build processing" "high"
    else
        ntfy "❌ Upload failed — see $WORK/upload.log" "high"
        exit 5
    fi
else
    ntfy "✅ Dry-run complete — would upload $(basename "$IPA") in --live mode"
fi

echo ""
echo "==============================================="
echo " DONE — mode=$MODE"
echo " Artifacts: $WORK"
echo " Notes:     $NOTES"
echo "==============================================="
