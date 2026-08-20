# Hugging Face access

`HF_TOKEN` is present in this container's environment and the official `hf` CLI
is installed, so you can create and manage Hugging Face repos directly.

**Never print, echo, cat or otherwise reveal the value of `HF_TOKEN`.** Pass it
by variable reference only. Session transcripts can be shared, and this token
carries write access to the whole account.

## Who am I

```bash
hf auth whoami
```

The CLI reads `HF_TOKEN` from the environment; there is no login step.

## Create a Space

```bash
hf repo create my-space --repo-type space --space_sdk docker
```

Then populate it. A Docker Space needs, at minimum, a `README.md` whose YAML
front matter declares the SDK and the port your app listens on, plus a
`Dockerfile`:

```markdown
---
title: My Space
emoji: 🚀
colorFrom: gray
colorTo: indigo
sdk: docker
app_port: 7860
---
```

`app_port` must match what the container actually listens on. Hugging Face
exposes exactly one port and routes it through HTTPS on 443 — a Space cannot
serve a second port, and clients must not append a port to the `*.hf.space`
URL.

Upload files with the CLI:

```bash
hf upload <user>/<space> ./local-dir . --repo-type space
```

…or use git, keeping the token out of the stored remote:

```bash
git clone "https://huggingface.co/spaces/<user>/<space>" && cd <space>
# commit files, then:
git push "https://$(hf auth whoami | head -1):${HF_TOKEN}@huggingface.co/spaces/<user>/<space>" HEAD:main
```

## Set Space secrets

Secrets are the only correct place for credentials — never commit them.

```bash
curl -sf -X POST "https://huggingface.co/api/spaces/<user>/<space>/secrets" \
  -H "Authorization: Bearer $HF_TOKEN" -H "Content-Type: application/json" \
  -d '{"key":"SOME_KEY","value":"...","description":"what it is for"}'
```

## Check whether a Space is up

```bash
curl -s "https://huggingface.co/api/spaces/<user>/<space>" | jq '.runtime.stage'
```

`RUNNING` is healthy. `BUILD_ERROR` / `RUNTIME_ERROR` / `CONFIG_ERROR` mean it
failed — read the build logs on the Space page. Free `cpu-basic` Spaces are
ephemeral and are stopped after roughly 48h idle, so anything that must survive
belongs in git or on a persistent-storage mount at `/data`.

## Ask before destroying things

Creating repos is fine. Deleting or renaming an existing repo, changing its
visibility, or overwriting someone else's files is not reversible — confirm with
the user first.
