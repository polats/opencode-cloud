# opencode-cloud — one image, two homes (Hugging Face Spaces + Railway).
#
# The port is decided at runtime by entrypoint.sh:
#   * Railway injects $PORT
#   * HF Spaces does not, so we fall back to 7860 (matches app_port in README.md)
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      openssh-client \
      python3 \
      python3-venv \
      ripgrep \
      tar \
      unzip \
    && rm -rf /var/lib/apt/lists/*

# Official Hugging Face CLI, so an agent holding HF_TOKEN can create and push
# repos in one step instead of hand-rolling API calls. Debian marks its Python
# externally-managed (PEP 668), hence the venv rather than a bare pip install.
RUN python3 -m venv /opt/hf-cli \
    && /opt/hf-cli/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/hf-cli/bin/pip install --no-cache-dir "huggingface_hub[cli]" \
    && for bin in hf huggingface-cli; do \
         [ -x "/opt/hf-cli/bin/$bin" ] && ln -sf "/opt/hf-cli/bin/$bin" "/usr/local/bin/$bin"; \
       done \
    && hf version

# Install opencode at BUILD time so cold starts don't re-download the release.
# The official installer hardcodes $HOME/.opencode/bin (it ignores
# OPENCODE_INSTALL_DIR), so move the binary onto the shared PATH afterwards.
# Pin a release with:  --build-arg OPENCODE_VERSION=1.18.18
ARG OPENCODE_VERSION=""
RUN VERSION="${OPENCODE_VERSION}" bash -c 'curl -fsSL https://opencode.ai/install | bash' \
    && mv "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode \
    && chmod 755 /usr/local/bin/opencode \
    && rm -rf "$HOME/.opencode" \
    && opencode --version

# Hugging Face Spaces runs containers as uid 1000. The node images already ship
# a `node` user at uid 1000, so reuse it rather than useradd'ing a colliding one.
ENV HOME=/home/node
ENV PATH=/usr/local/bin:${PATH}

COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
COPY --chown=node:node agents/hf-spaces.md /home/node/agents/hf-spaces.md
RUN chmod +x /home/node/entrypoint.sh \
    && mkdir -p /home/node/workspace \
    && chown -R node:node /home/node

USER node
WORKDIR /home/node/workspace

EXPOSE 7860
ENTRYPOINT ["/home/node/entrypoint.sh"]
