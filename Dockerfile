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
      ripgrep \
      tar \
      unzip \
    && rm -rf /var/lib/apt/lists/*

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
RUN chmod +x /home/node/entrypoint.sh \
    && mkdir -p /home/node/workspace \
    && chown -R node:node /home/node

USER node
WORKDIR /home/node/workspace

EXPOSE 7860
ENTRYPOINT ["/home/node/entrypoint.sh"]
