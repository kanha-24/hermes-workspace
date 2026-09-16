#!/usr/bin/env bash
set -euo pipefail

# Hermes Workspace — free provider setup
#
# Priority:
#   1. Ollama (fully local, no API bill)
#   2. Hermes' official OpenCode Free provider (keyless, subject to upstream limits)
#
# Force a backend with FREE_BACKEND=ollama or FREE_BACKEND=opencode-free.

GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'
log() { printf '%b%s%b\n' "$GREEN" "$*" "$RESET"; }
warn() { printf '%b%s%b\n' "$YELLOW" "$*" "$RESET"; }
die() { printf '%b%s%b\n' "$RED" "$*" "$RESET"; exit 1; }

command -v hermes >/dev/null 2>&1 || die "Hermes Agent is not installed. Install it first."

BACKEND="${FREE_BACKEND:-auto}"

if [[ "$BACKEND" == "auto" ]]; then
  if command -v ollama >/dev/null 2>&1 && curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    BACKEND="ollama"
  else
    BACKEND="opencode-free"
  fi
fi

case "$BACKEND" in
  ollama)
    command -v ollama >/dev/null 2>&1 || die "Ollama is not installed."
    if ! curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      die "Ollama is installed but not running. Start it with: ollama serve"
    fi

    MODEL="${OLLAMA_MODEL:-}"
    if [[ -z "$MODEL" ]]; then
      MODEL="$(curl -fsS http://127.0.0.1:11434/api/tags | python3 -c 'import json,sys; d=json.load(sys.stdin); print((d.get("models") or [{}])[0].get("name", ""))' 2>/dev/null || true)"
    fi
    [[ -n "$MODEL" ]] || die "No Ollama model is installed. Pull a model first, then rerun this script."

    hermes config set model.provider custom
    hermes config set model.default "$MODEL"
    hermes config set model.base_url "http://127.0.0.1:11434/v1"
    hermes config set model.api_key ollama

    log "Free mode configured: local Ollama ($MODEL)"
    warn "Use an Ollama model/server configured for at least 64K context for full Hermes agent/tool use."
    ;;

  opencode-free)
    # Official Hermes provider: keyless, no account/API key required.
    # Do not hardcode a model because the free catalog rotates.
    hermes config set model.provider opencode-free
    hermes config unset model.default >/dev/null 2>&1 || true
    hermes config unset model.base_url >/dev/null 2>&1 || true
    hermes config unset model.api_key >/dev/null 2>&1 || true

    log "Free mode configured: Hermes OpenCode Free (keyless)"
    warn "The upstream free relay can be rate-limited or temporarily unavailable."
    ;;

  *)
    die "Unknown FREE_BACKEND=$BACKEND. Use ollama, opencode-free, or auto."
    ;;
esac

log "Verify with: hermes config get model"
log "Then restart the Hermes gateway."
