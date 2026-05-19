FROM docker.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        git \
        nodejs \
        npm \
        openssh-client \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        sudo \
        tmux \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash sandbox \
    && printf 'sandbox ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/sandbox \
    && chmod 0440 /etc/sudoers.d/sandbox \
    && mkdir -p /workspace \
    && chown sandbox:sandbox /workspace

USER sandbox
WORKDIR /workspace
CMD ["/bin/bash"]
