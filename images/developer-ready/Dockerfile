FROM docker.io/library/ubuntu:24.04

ARG PI_CLI_VERSION=0.73.1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        git \
        gnupg \
        openssh-client \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        sudo \
        tmux \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && chmod 0644 /etc/apt/keyrings/nodesource.gpg \
    && printf 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main\n' > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g "@mariozechner/pi-coding-agent@${PI_CLI_VERSION}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash sandbox \
    && printf 'sandbox ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/sandbox \
    && chmod 0440 /etc/sudoers.d/sandbox \
    && mkdir -p /workspace /state/sandbox/.pi /state/sandbox/secrets \
    && chown -R sandbox:sandbox /workspace /state \
    && ln -s /state/sandbox/.pi /home/sandbox/.pi \
    && ln -s /state/sandbox/secrets /home/sandbox/.sand-secrets \
    && chown -h sandbox:sandbox /home/sandbox/.pi /home/sandbox/.sand-secrets

USER sandbox
WORKDIR /workspace
CMD ["/bin/bash"]
