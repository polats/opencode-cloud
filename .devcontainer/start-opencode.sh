#!/usr/bin/env bash
# Boot the opencode server inside a GitHub Codespace.
#
# This exists for one reason: Codespaces secrets are not in postStartCommand's environment.
# They are written to a JSON file and applied to interactive shells, so a server started by
# the lifecycle hook sees none of them — including OPENCODE_SERVER_PASSWORD, without which
# entrypoint.sh correctly refuses to run and the codespace comes up serving nothing.
#
# Sourcing that file first is what makes the codespace behave like the Space and the Railway
# service, where the platform hands the process its variables directly.
set -euo pipefail

SECRETS="/workspaces/.codespaces/shared/user-secrets-envs.json"

if [ -f "$SECRETS" ]; then
  # A flat { "NAME": "value" } object. Exported only if not already set, so a variable given
  # explicitly by devcontainer.json still wins.
  while IFS='=' read -r name value; do
    [ -n "$name" ] || continue
    if [ -z "${!name:-}" ]; then
      export "$name=$value"
    fi
  done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as handle:
    for name, value in json.load(handle).items():
        if isinstance(value, str) and "\n" not in value:
            print(f"{name}={value}")
' "$SECRETS")
  echo "codespaces: loaded secrets from $(basename "$SECRETS")"
else
  echo "codespaces: no secrets file at $SECRETS"
fi

if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  echo "codespaces: OPENCODE_SERVER_PASSWORD is still unset after loading secrets." >&2
  echo "            Set it as a Codespaces secret, not a repository or Actions secret:" >&2
  echo "            gh secret set OPENCODE_SERVER_PASSWORD --app codespaces --repo OWNER/REPO" >&2
fi

# entrypoint.sh only uses the state root if it already exists and is writable, and nothing
# else creates it — so without this every boot reports "persistence: NONE" and sessions and
# logins are silently lost on the next idle stop.
mkdir -p "${OPENCODE_STATE_ROOT:-/workspaces/.opencode-state}" 2>/dev/null || true

exec /home/node/entrypoint.sh
