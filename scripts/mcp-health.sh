#!/usr/bin/env bash
# mcp-health.sh — Health check for MCP servers (SSE, stdio via mcporter)
set -euo pipefail

# Load config.env if exists
# shellcheck source=/dev/null
CONFIG_FILE="$HOME/.openclaw/workspace/skills/mcp-health/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    set -a  # auto-export
    source "$CONFIG_FILE"
    set +a
fi

# --- Config via env ---
MCP_SERVERS="${MCP_SERVERS:-}"  # comma-separated server names
MCPORTER_CMD="${MCPORTER_CMD:-mcporter}"
CHECK_TIMEOUT="${CHECK_TIMEOUT:-10}"
LOG_FILE="${MCP_HEALTH_LOG:-$HOME/logs/mcp-health.log}"
STATE_FILE="${MCP_HEALTH_STATE:-$HOME/.openclaw-mcp-health-state.json}"
ALERT_COOLDOWN="${ALERT_COOLDOWN:-3600}"  # seconds between repeated alerts for same server
DRY_RUN="${DRY_RUN:-false}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$STATE_FILE")"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --json) OUTPUT_FORMAT=json ;;
    --help|-h)
      echo "Usage: mcp-health.sh [--dry-run] [--json]"
      echo "  Env: MCP_SERVERS=server1,server2"
      exit 0 ;;
  esac
done

[[ -z "$MCP_SERVERS" ]] && { echo '{"status":"error","error":"MCP_SERVERS not set"}'; exit 1; }

# Load state
if [[ -f "$STATE_FILE" ]]; then
  STATE=$(cat "$STATE_FILE")
else
  STATE="{}"
fi

NOW=$(date +%s)
RESULTS="[]"
ALERTS="[]"

IFS=',' read -ra SERVERS <<< "$MCP_SERVERS"
for server in "${SERVERS[@]}"; do
  server=$(echo "$server" | xargs)
  [[ -z "$server" ]] && continue

  # Check server via mcporter
  HEALTHY=false
  ERROR_MSG=""

  if command -v "$MCPORTER_CMD" &>/dev/null; then
    OUTPUT=$(timeout "$CHECK_TIMEOUT" "$MCPORTER_CMD" list "$server" 2>&1) && HEALTHY=true || ERROR_MSG="$OUTPUT"
  else
    # Fallback: try direct HTTP health check if server looks like a URL
    if [[ "$server" =~ ^https?:// ]]; then
      HTTP_CODE=$(timeout "$CHECK_TIMEOUT" curl -s -o /dev/null -w '%{http_code}' "$server/health" 2>/dev/null) || HTTP_CODE="000"
      if [[ "$HTTP_CODE" =~ ^2 ]]; then
        HEALTHY=true
      else
        ERROR_MSG="HTTP $HTTP_CODE"
      fi
    else
      ERROR_MSG="mcporter not found and server is not a URL"
    fi
  fi

  STATUS="healthy"
  $HEALTHY || STATUS="unhealthy"

  RESULT=$(jq -n \
    --arg name "$server" \
    --arg status "$STATUS" \
    --arg error "$ERROR_MSG" \
    '{name:$name, status:$status, error:$error}')
  RESULTS=$(echo "$RESULTS" | jq --argjson r "$RESULT" '. + [$r]')

  # Alert logic with cooldown
  if ! $HEALTHY; then
    LAST_ALERT=$(echo "$STATE" | jq -r --arg s "$server" '.[$s].last_alert // 0')
    ELAPSED=$((NOW - LAST_ALERT))

    if [[ "$ELAPSED" -ge "$ALERT_COOLDOWN" ]]; then
      ALERT=$(jq -n --arg name "$server" --arg error "$ERROR_MSG" '{name:$name, error:$error}')
      ALERTS=$(echo "$ALERTS" | jq --argjson a "$ALERT" '. + [$a]')

      if [[ "$DRY_RUN" != "true" ]]; then
        STATE=$(echo "$STATE" | jq --arg s "$server" --argjson t "$NOW" '.[$s].last_alert = $t')
      fi
      log "ALERT: $server is $STATUS — $ERROR_MSG"
    else
      log "SUPPRESSED: $server still $STATUS (cooldown: $((ALERT_COOLDOWN - ELAPSED))s remaining)"
    fi
  else
    # Clear alert state on recovery
    PREV_STATUS=$(echo "$STATE" | jq -r --arg s "$server" '.[$s].status // "unknown"')
    if [[ "$PREV_STATUS" == "unhealthy" ]]; then
      log "RECOVERED: $server is healthy again"
      ALERT=$(jq -n --arg name "$server" --arg error "recovered" '{name:$name, error:"recovered"}')
      ALERTS=$(echo "$ALERTS" | jq --argjson a "$ALERT" '. + [$a]')
    fi
  fi

  # Update state
  if [[ "$DRY_RUN" != "true" ]]; then
    STATE=$(echo "$STATE" | jq --arg s "$server" --arg st "$STATUS" '.[$s].status = $st')
  fi

  log "CHECK: $server → $STATUS"
done

# Save state
if [[ "$DRY_RUN" != "true" ]]; then
  echo "$STATE" > "$STATE_FILE"
fi

# Output
HEALTHY_COUNT=$(echo "$RESULTS" | jq '[.[] | select(.status=="healthy")] | length')
UNHEALTHY_COUNT=$(echo "$RESULTS" | jq '[.[] | select(.status=="unhealthy")] | length')

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  jq -n \
    --argjson results "$RESULTS" \
    --argjson alerts "$ALERTS" \
    --argjson healthy "$HEALTHY_COUNT" \
    --argjson unhealthy "$UNHEALTHY_COUNT" \
    '{status:"ok", healthy:$healthy, unhealthy:$unhealthy, results:$results, alerts:$alerts}'
else
  if [[ "$UNHEALTHY_COUNT" -gt 0 ]]; then
    echo "🔴 MCP Health: $UNHEALTHY_COUNT server(s) down"
    echo "$RESULTS" | jq -r '.[] | select(.status=="unhealthy") | "  ❌ \(.name): \(.error)"'
  fi
  if [[ "$HEALTHY_COUNT" -gt 0 ]]; then
    echo "✅ MCP Health: $HEALTHY_COUNT server(s) healthy"
    echo "$RESULTS" | jq -r '.[] | select(.status=="healthy") | "  ✓ \(.name)"'
  fi
fi
