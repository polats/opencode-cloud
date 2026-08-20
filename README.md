---
title: OpenCode Cloud
emoji: 🤖
colorFrom: gray
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
license: mit
---

# opencode-cloud

Run [opencode](https://opencode.ai) — an open source AI coding agent — as a hosted
server you reach from a browser, from the desktop app, or from a local build of the
web app. One Dockerfile, deployable to **Hugging Face Spaces** or **Railway**.

`opencode serve` is not just an API: the server also serves the web UI on its
catch-all route, so opening the deployment URL gives you the full app, same-origin.

---

## Deploy on Hugging Face Spaces

1. **Create a Space** → SDK **Docker**, blank template. Push this repo to it
   (or duplicate an existing Space built from it).
2. **Settings → Variables and secrets** and add:

   | Secret | Required | Notes |
   |---|---|---|
   | `OPENCODE_SERVER_PASSWORD` | **yes** | The container refuses to start without it. This is the only thing protecting a shell. |
   | `OPENCODE_SERVER_USERNAME` | no | Defaults to `opencode`. |
   | `OPENCODE_API_KEY` | pick ≥1 | [opencode zen](https://opencode.ai/zen) curated models |
   | `ANTHROPIC_API_KEY` | pick ≥1 | https://console.anthropic.com |
   | `OPENAI_API_KEY` | pick ≥1 | https://platform.openai.com/api-keys |
   | `GEMINI_API_KEY` | pick ≥1 | https://aistudio.google.com/apikey |

3. Open the Space URL and log in with `opencode` + your password.

Provider keys work as plain env vars — opencode registers any provider whose
models.dev env var is present, no login step needed.

### Persistence

Free Spaces are **ephemeral** and are stopped after ~48h idle. Sessions, provider
logins and any uncommitted code are lost on restart. Two options:

- **Free:** `git clone` your repo into the workspace and push before you walk away.
- **Paid:** enable persistent storage (Settings → Storage). It mounts at `/data`,
  which `entrypoint.sh` detects and uses for the XDG dirs *and* the workspace, so
  state survives restarts. Watch the boot log — it prints which mode it picked.

### Public or private Space?

A **private** Space adds your HF login in front of everything, which is the safer
default for browser use. The catch: HF authenticates private Spaces with an
`Authorization: Bearer hf_…` header, and opencode wants `Authorization: Basic …` —
one header, two claimants. So a private Space works in a browser (HF session
cookie) but a **desktop-app or local-app connection to a private Space will fight
over that header**. Keep the Space public with a long password if you want those.

---

## Deploy on Railway

```bash
railway init                       # or point a service at this GitHub repo
railway variables --set OPENCODE_SERVER_PASSWORD=...
railway up
```

Railway injects `$PORT`, which `entrypoint.sh` uses automatically. Attach a volume
with mount path `/data` for persistence. Details and caveats: [docs/RAILWAY.md](docs/RAILWAY.md).

---

## Keeping the Space in sync with GitHub

`.github/workflows/sync-to-hf-space.yml` builds the image, boots it, checks that
it refuses to start unauthenticated and that it serves an authenticated API and
the web UI — and only then force-pushes `main` to the Space and waits for it to
report `RUNNING`. A broken Dockerfile fails on the runner instead of leaving the
Space stuck in `BUILD_ERROR`.

Configure it under **Settings → Secrets and variables → Actions**:

| Name | Kind | Notes |
|---|---|---|
| `HF_TOKEN` | **secret** | A Hugging Face **write** token. The HF username is derived from it, so it is the only secret needed. |
| `HF_SPACE` | variable | `owner/space-name`. Optional — defaults to this GitHub repo's `owner/name`. A public Space id isn't sensitive, so a variable keeps it readable in logs; a secret of the same name also works. |

GitHub is the source of truth: the sync **force-pushes**, so a commit made only
in the Space's web UI will be discarded. Edit here, not there.

---

## Connecting the desktop app or a local web app

You don't have to use the in-browser UI. In the app, **Settings → Servers → Add**
and enter the deployment URL plus the username/password. The server's CORS
allowlist already covers `localhost`, `*.opencode.ai` and the desktop app's
`oc://renderer` origin, so no extra flags are needed. Only a frontend you host on
your own domain needs `OPENCODE_CORS_ORIGINS=https://your.domain`.

---

## Read this before you deploy

- **This is a remote shell.** Every route allows command execution and file
  read/write in the container. Basic auth over HTTPS is the entire security model,
  so use a long random password, and think twice about what credentials you put in
  the container alongside it.
- **Provider OAuth "login with browser" flows don't work on a remote server.**
  They bind a `http://localhost:<port>/auth/callback` listener *inside* the
  container, so your browser is redirected to your own machine instead. Use API
  keys.
- **CPU only, and modest.** Fine for the agent; you can't run local models.
- **Check the host's terms.** A general-purpose remote shell is not the ML-demo
  use case Spaces are described for; a public one with a weak password is the way
  to get flagged.

---

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | — | **Required.** Basic auth password. |
| `OPENCODE_SERVER_USERNAME` | `opencode` | Basic auth username. |
| `PORT` | `7860` | Listen port. Railway sets this; HF must match `app_port`. |
| `OPENCODE_STATE_ROOT` | `/data` | Where to look for a writable volume. |
| `OPENCODE_WORKSPACE` | `$STATE_ROOT/workspace` or `$HOME/workspace` | Directory to serve. |
| `OPENCODE_CORS_ORIGINS` | — | Comma-separated extra CORS origins. |

Build arg `OPENCODE_VERSION` pins a release (default: latest).

---

MIT. opencode itself is © Anomaly Innovations; this repo is deployment wrapper code.
