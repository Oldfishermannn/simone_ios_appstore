#!/usr/bin/env bash
# fix_plist.sh — ensure Info.plist has required privacy + compliance keys
# Usage: fix_plist_check <Info.plist_path> <source_dir>
#
# Strategy: grep source for permission-requiring APIs, then require corresponding key.
# Plus unconditionally require ITSAppUsesNonExemptEncryption (else Apple emails you).
set -euo pipefail

# API pattern → plist key → default message
declare -a API_MAP=(
    'requestRecordPermission|AVAudioRecorder|NSMicrophoneUsageDescription|Simone uses the microphone.'
    'AVCaptureDevice|NSCameraUsageDescription|Simone uses the camera.'
    'CLLocationManager|NSLocationWhenInUseUsageDescription|Simone uses your location.'
    'PHPhotoLibrary|PHPickerViewController|NSPhotoLibraryUsageDescription|Simone accesses your photos.'
    'ATTrackingManager|NSUserTrackingUsageDescription|Simone uses this identifier to improve your experience.'
    'MusicKit|MPMediaLibrary|NSAppleMusicUsageDescription|Simone reads your Apple Music library.'
    'EKEventStore|NSCalendarsUsageDescription|Simone accesses your calendar.'
    'CNContactStore|NSContactsUsageDescription|Simone accesses your contacts.'
    'HKHealthStore|NSHealthShareUsageDescription|Simone reads health data.'
    'CBCentralManager|CBPeripheralManager|NSBluetoothAlwaysUsageDescription|Simone uses Bluetooth.'
    'LAContext|NSFaceIDUsageDescription|Simone uses Face ID to authenticate you.'
)

_plist_has() {
    local plist="$1" key="$2"
    plutil -extract "$key" raw -o - "$plist" >/dev/null 2>&1
}

_plist_set_string() {
    local plist="$1" key="$2" val="$3"
    # -insert fails if key exists; try insert, fall back to replace
    plutil -insert "$key" -string "$val" "$plist" 2>/dev/null \
        || plutil -replace "$key" -string "$val" "$plist"
}

_plist_set_bool() {
    local plist="$1" key="$2" val="$3"
    plutil -insert "$key" -bool "$val" "$plist" 2>/dev/null \
        || plutil -replace "$key" -bool "$val" "$plist"
}

fix_plist_check() {
    local plist="$1"
    local src_dir="$2"
    local issues=0
    local fixed=0

    if [[ ! -f "$plist" ]]; then
        echo "[plist] ERROR: Info.plist not found: $plist"
        return 2
    fi

    # 1) Permission keys driven by source grep
    for row in "${API_MAP[@]}"; do
        local patterns key msg
        # Split on last two | separators (patterns may contain |)
        msg="${row##*|}"
        local rest="${row%|*}"
        key="${rest##*|}"
        patterns="${rest%|*}"

        # If any pattern appears in .swift sources, require the key
        local needed=0
        IFS='|' read -ra pats <<< "$patterns"
        for p in "${pats[@]}"; do
            if grep -rlq --include='*.swift' "$p" "$src_dir" 2>/dev/null; then
                needed=1
                break
            fi
        done

        if [[ $needed -eq 1 ]]; then
            if _plist_has "$plist" "$key"; then
                echo "[plist] OK   $key (required by code)"
            else
                issues=$((issues + 1))
                echo "[plist] MISS $key — inserting default: '$msg'"
                _plist_set_string "$plist" "$key" "$msg"
                fixed=$((fixed + 1))
            fi
        fi
    done

    # 2) Export compliance (unconditional — Simone has no custom crypto)
    if _plist_has "$plist" "ITSAppUsesNonExemptEncryption"; then
        echo "[plist] OK   ITSAppUsesNonExemptEncryption"
    else
        issues=$((issues + 1))
        echo "[plist] MISS ITSAppUsesNonExemptEncryption — setting false (Simone uses only OS TLS)"
        _plist_set_bool "$plist" "ITSAppUsesNonExemptEncryption" false
        fixed=$((fixed + 1))
    fi

    # 3) Bundle metadata sanity
    for required in CFBundleShortVersionString CFBundleVersion CFBundleIdentifier; do
        if ! _plist_has "$plist" "$required"; then
            echo "[plist] FATAL missing $required — cannot auto-fix safely"
            return 2
        fi
    done

    echo "[plist] fixed $fixed/${issues} issues"
    [[ $issues -eq 0 ]] && return 0 || return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_plist_check "${1:?usage: fix_plist.sh <Info.plist> <src_dir>}" "${2:?}"
fi
