#!/usr/bin/env bash
# Boot opencode's headless server for a PaaS (Hugging Face Spaces / Railway).
set -euo pipefail

# Allow `docker run <image> bash` etc. to override the server for debugging.
# PaaS hosts pass no arguments, so the normal path is unaffected.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

# --- port -------------------------------------------------------------------
# Railway injects $PORT. HF Spaces does not; 7860 must match app_port in README.md.
PORT="${PORT:-7860}"

# --- refuse to run unauthenticated -----------------------------------------
# opencode itself only warns. On a public URL an unauthenticated server means
# anyone can run shell commands and read/write files in this container, so fail
# loudly instead.
if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  cat >&2 <<'MSG'
FATAL: OPENCODE_SERVER_PASSWORD is not set.

  Every route on this server allows shell execution and file access, and basic
  auth is the only thing standing in front of it. Set the secret and redeploy:

    Hugging Face  Settings -> Variables and secrets -> New secret
    Railway       Variables -> New Variable

  Log in as $OPENCODE_SERVER_USERNAME (default "opencode") with that password.
MSG
  exit 1
fi

# --- persistence -----------------------------------------------------------
# opencode keeps sessions, provider credentials and its SQLite DB under the XDG
# dirs (packages/core/src/global.ts), so pointing those at a mounted volume is
# what makes state survive a restart.
#   HF Spaces  persistent storage is mounted at /data (paid add-on)
#   Railway    attach a volume with mount path /data
STATE_ROOT="${OPENCODE_STATE_ROOT:-/data}"

if [ -d "$STATE_ROOT" ] && [ -w "$STATE_ROOT" ]; then
  export XDG_DATA_HOME="$STATE_ROOT/share"
  export XDG_STATE_HOME="$STATE_ROOT/state"
  export XDG_CACHE_HOME="$STATE_ROOT/cache"
  export XDG_CONFIG_HOME="$STATE_ROOT/config"
  WORKSPACE="${OPENCODE_WORKSPACE:-$STATE_ROOT/workspace}"
  mkdir -p "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
  echo "persistence: $STATE_ROOT (sessions, logins and code survive restarts)"
else
  WORKSPACE="${OPENCODE_WORKSPACE:-$HOME/workspace}"
  echo "persistence: NONE — $STATE_ROOT is not a writable mount."
  echo "             Sessions, provider logins and uncommitted code are lost on restart."
  echo "             Push to git before you walk away, or attach a volume at $STATE_ROOT."
fi

mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Volumes and bind mounts routinely carry a different owner than uid 1000,
# which makes git refuse to touch the repo. Trust what we already control.
git config --global --add safe.directory '*' 2>/dev/null || true

# --- extra CORS origins ----------------------------------------------------
# localhost, *.opencode.ai and the desktop app's oc://renderer are allowed out
# of the box (packages/server/src/cors.ts). Only a frontend you host yourself
# on some other domain needs this.
CORS_ARGS=()
if [ -n "${OPENCODE_CORS_ORIGINS:-}" ]; then
  IFS=',' read -ra origins <<<"$OPENCODE_CORS_ORIGINS"
  for origin in "${origins[@]}"; do
    origin="$(echo "$origin" | xargs)"
    [ -n "$origin" ] && CORS_ARGS+=(--cors "$origin")
  done
fi

echo "opencode $(opencode --version) starting on 0.0.0.0:$PORT (workspace: $WORKSPACE)"
exec opencode serve --hostname 0.0.0.0 --port "$PORT" "${CORS_ARGS[@]}"
