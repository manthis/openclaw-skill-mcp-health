# openclaw-skill-mcp-health

Health check for MCP servers. Detects down/inaccessible servers with rate-limited alerts.

## Usage

```bash
scripts/mcp-health.sh [--dry-run] [--json]
```

## Configuration (env vars)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MCP_SERVERS` | ✅ | — | Comma-separated server names |
| `MCPORTER_CMD` | | `mcporter` | Path to mcporter CLI |
| `CHECK_TIMEOUT` | | `10` | Timeout per check (seconds) |
| `ALERT_COOLDOWN` | | `3600` | Seconds between repeated alerts |
| `MCP_HEALTH_STATE` | | `~/.openclaw-mcp-health-state.json` | State file |
| `MCP_HEALTH_LOG` | | `~/logs/mcp-health.log` | Log file |

## Features

- Checks via `mcporter list <server>` (primary)
- HTTP health check fallback for URL-based servers
- Alert rate limiting (configurable cooldown)
- Recovery detection and notification
- State persistence

## OpenClaw Integration

```yaml
cron:
  - name: "MCP Health"
    schedule: "*/10 * * * *"
    command: "scripts/mcp-health.sh --json"
    env:
      MCP_SERVERS: "beeper,filesystem"
```
