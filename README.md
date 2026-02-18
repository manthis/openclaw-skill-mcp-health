# 🏥 openclaw-skill-mcp-health

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-blue)](https://github.com/OpenAgentsInc/openclaw)

Health monitoring for MCP (Model Context Protocol) servers. Detects downtime, rate-limits alerts, tracks recovery.

## Quick Start

```bash
git clone https://github.com/manthis/openclaw-skill-mcp-health.git
cd openclaw-skill-mcp-health

export MCP_SERVERS="server1,server2"
./scripts/mcp-health.sh --dry-run
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_SERVERS` | — | Comma-separated server names |
| `MCPORTER_CMD` | `mcporter` | mcporter CLI path |
| `CHECK_TIMEOUT` | `10` | Timeout per check (s) |
| `ALERT_COOLDOWN` | `3600` | Min seconds between repeated alerts |

> ⚠️ **Security:** Never store tokens or credentials in config files.

## Features

- 🔍 Checks via `mcporter list` or HTTP fallback
- ⏱️ Alert cooldown (no spam)
- 🔄 Recovery detection
- 📊 JSON output
- 💾 State persistence

## Requirements

- `mcporter` CLI (or curl for HTTP-based servers)
- `jq`

## License

MIT
