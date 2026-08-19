# Deploying on Railway

Railway is the sturdier of the two targets: no port/`app_port` coupling, cheap
volumes, and no always-on/idle-GC surprises. There is no free always-on tier.

## Steps

1. Create a project and point a service at this repo (or `railway init` + `railway up`).
   `railway.json` selects the Dockerfile builder.
2. Set variables:

   ```bash
   railway variables --set OPENCODE_SERVER_PASSWORD="$(openssl rand -base64 24)"
   railway variables --set OPENCODE_API_KEY=...        # and/or ANTHROPIC_API_KEY, etc.
   ```

3. **Attach a volume** with mount path `/data`. Without it, every redeploy wipes
   sessions, provider logins and uncommitted code. `entrypoint.sh` picks `/data`
   up automatically and logs which mode it chose.
4. Generate a domain (Settings → Networking → Generate Domain) and open it.

`$PORT` is injected by Railway and used automatically — do not hardcode a port.

## Do not set a healthcheck path

Every route requires basic auth, so `/api/health` returns `401` to an
unauthenticated prober and Railway would mark the deploy failed. Leave
`healthcheckPath` unset and let Railway consider the service live once the
process is listening.

## Getting your code in

There is no repo in the container. From the app's terminal:

```bash
git clone https://github.com/you/your-repo.git
```

For pushes, add a deploy key or use a PAT. Anything outside `/data` is lost on
redeploy.

## Restarts kill in-flight runs

A redeploy or crash takes the container with it, including any agent run in
progress. Session state survives if it lives on the volume; the interrupted run
does not.
