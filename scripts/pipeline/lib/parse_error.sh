#!/usr/bin/env bash
# parse_error.sh — route altool validation errors to fixers
# Usage: parse_error <validate_json> <project_root> <plist> <iconset> <shots_dir> <state_file>
# Returns: 0 if an auto-fix was applied, 1 if no fix possible, 2 if subagent dispatched
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PIPELINE_DIR/lib/ntfy.sh"
source "$PIPELINE_DIR/lib/fix_icon.sh"
source "$PIPELINE_DIR/lib/fix_shots.sh"
source "$PIPELINE_DIR/lib/fix_plist.sh"
source "$PIPELINE_DIR/lib/bump_build.sh"

parse_error() {
    local json="$1"
    local proj="$2"
    local plist="$3"
    local iconset="$4"
    local shots_dir="$5"
    local state="$6"

    if [[ ! -f "$json" ]]; then
        echo "[parse] no error json at $json"
        return 1
    fi

    # Extract first error code + message
    local code msg
    code=$(jq -r '[.["product-errors"][]?.code, .errors[]?.code] | map(select(. != null)) | .[0] // empty' "$json" 2>/dev/null || echo "")
    msg=$(jq -r '[.["product-errors"][]?.message, .errors[]?.message] | map(select(. != null)) | .[0] // empty' "$json" 2>/dev/null || echo "")

    if [[ -z "$code" && -z "$msg" ]]; then
        echo "[parse] no parseable errors in $json"
        return 1
    fi

    echo "[parse] code=$code msg=$msg"
    ntfy "🔎 Parsing: ${code} — ${msg:0:120}"

    case "$code" in
        ITMS-90717|*"alpha channel"*|*"Invalid Large App Icon"*)
            ntfy "🔧 Auto-fix: strip icon alpha"
            fix_icon_check "$iconset" || true
            return 0
            ;;
        ITMS-90239|*"screenshot"*|*"Invalid Screenshot"*)
            ntfy "🔧 Auto-fix: resize screenshots"
            fix_shots_check "$shots_dir" || true
            return 0
            ;;
        ITMS-90683|*"Missing Purpose String"*|*"Missing required"*key*)
            ntfy "🔧 Auto-fix: patch Info.plist"
            fix_plist_check "$plist" "$(dirname "$plist")" || true
            return 0
            ;;
        ITMS-90060|ITMS-90062|*"already been used"*|*"bundle version"*)
            ntfy "🔧 Auto-fix: bump build number"
            bump_build_check "$plist" "$state" || true
            return 0
            ;;
        *)
            # Unknown error — delegate to Claude subagent
            ntfy "🤖 Unknown ITMS — delegating to Claude subagent"
            claude_subagent_fix "$code" "$msg" "$proj"
            return $?
            ;;
    esac
}

claude_subagent_fix() {
    local code="$1" msg="$2" proj="$3"

    if ! command -v claude >/dev/null 2>&1; then
        echo "[parse] claude CLI not available — cannot dispatch subagent"
        ntfy "⚠️  No claude CLI — cannot self-heal unknown error"
        return 1
    fi

    local prompt
    prompt=$(cat <<EOF
You are an automated iOS submission repair agent. An App Store Connect validation just failed.

Error code: ${code}
Error message: ${msg}
Project root: ${proj}
Info.plist:   ${proj}/Simone/Info.plist

CONSTRAINTS:
- Output ONLY shell commands to fix the issue. No prose, no markdown fences.
- Use plutil, sips, agvtool, or file edits. Nothing destructive.
- If you cannot fix confidently, output exactly: echo "UNFIXABLE"
- All paths must be absolute and quoted.
EOF
)
    local fix_script="/tmp/simone_subagent_fix_$$.sh"
    # Resolve a timeout command: gtimeout (brew coreutils) or timeout (linux), else run without
    local TO=""
    if command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 120"
    elif command -v timeout  >/dev/null 2>&1; then TO="timeout 120"
    fi
    echo "[parse] invoking: claude -p ${TO:+(timeout 120s)}"
    if $TO claude -p "$prompt" > "$fix_script" 2>/tmp/simone_subagent_err.log; then
        if grep -q "UNFIXABLE" "$fix_script"; then
            echo "[parse] subagent said UNFIXABLE"
            ntfy "❌ Subagent: unfixable"
            return 1
        fi
        echo "[parse] subagent proposed:"
        cat "$fix_script" | sed 's/^/   > /'
        ntfy "🤖 Running subagent fix"
        if bash "$fix_script"; then
            return 2
        else
            echo "[parse] subagent fix script exited non-zero"
            return 1
        fi
    else
        echo "[parse] claude -p failed: $(cat /tmp/simone_subagent_err.log)"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_error "$@"
fi
