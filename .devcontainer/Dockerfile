# Dockerfile - .NET 10 devcontainer with Claude Code and outbound network sandboxing.
# init-firewall.sh must be in the same directory as this Dockerfile.

ARG TZ=Europe/Kyiv
ARG CLAUDE_CODE_VERSION=latest

# .NET 10 devcontainer images are Ubuntu Noble based.
# Use the runtime-version tag rather than the old 1-10.0-* image-version form.
FROM mcr.microsoft.com/devcontainers/dotnet:10.0-noble

ARG TZ
ARG CLAUDE_CODE_VERSION
ENV TZ=$TZ

USER root

# Firewall tooling + utilities used by init-firewall.sh and Claude Code setup.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bubblewrap \
    socat \
    ripgrep \
    iptables \
    ipset \
    curl \
    jq \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 for Claude Code.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Validate the build arg before interpolating it into the npm package spec.
RUN echo "${CLAUDE_CODE_VERSION}" | grep -qE '^(latest|[0-9A-Za-z._-]+)$' || \
    (echo "ERROR: invalid CLAUDE_CODE_VERSION='${CLAUDE_CODE_VERSION}'" && exit 1) \
    && npm install -g @anthropic-ai/sandbox-runtime "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

COPY NuGet.Claude.Config /opt/claude-dotnet/NuGet.Config
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod 0755 /usr/local/bin/init-firewall.sh \
    && echo "vscode ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/claude-firewall \
    && chmod 0440 /etc/sudoers.d/claude-firewall \
    && mkdir -p /commandhistory /home/vscode/.claude /home/vscode/.nuget/packages /home/vscode/.dotnet /home/vscode/.cache /home/vscode/.local/share/NuGet \
    && chown -R vscode:vscode /commandhistory /home/vscode/.claude /home/vscode/.nuget /home/vscode/.dotnet /home/vscode/.cache /home/vscode/.local

RUN mkdir -p /home/vscode/.cache/claude-dotnet/.nuget/NuGet && cp /opt/claude-dotnet/NuGet.Config /home/vscode/.cache/claude-dotnet/.nuget/NuGet/NuGet.Config && chown -R vscode:vscode /home/vscode/.cache

USER vscode
WORKDIR /workspace
