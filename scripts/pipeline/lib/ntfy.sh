#!/usr/bin/env bash
# ntfy.sh — stage notifications to ntfy.sh topic
# Usage: source this file, then: ntfy "✅ message"
# Env: NTFY_TOPIC (default: simone-pipeline-laoyu-9f2a)
#      NTFY_SERVER (default: https://ntfy.sh)

: "${NTFY_TOPIC:=simone-pipeline-laoyu-9f2a}"
: "${NTFY_SERVER:=https://ntfy.sh}"

ntfy() {
    local msg="$1"
    local priority="${2:-default}"
    # Fire-and-forget; 3s timeout so a dead network doesn't stall the pipeline
    curl -s --max-time 3 \
        -H "Priority: ${priority}" \
        -H "Title: Simone Pipeline" \
        -d "${msg}" \
        "${NTFY_SERVER}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
    echo "[ntfy] ${msg}"
}

ntfy_url() {
    echo "${NTFY_SERVER}/${NTFY_TOPIC}"
}
