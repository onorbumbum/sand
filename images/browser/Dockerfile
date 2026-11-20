# Browser Sandbox Image: the developer-ready image plus a real, headed Chromium
# on a virtual display. Agents drive it over CDP at http://127.0.0.1:9222
# (guest-only); people watch and take over through noVNC on guest port 6080,
# which sand publishes on the Host Mac loopback only.
ARG BASE_IMAGE=sand/developer-ready:ubuntu-lts
FROM ${BASE_IMAGE}

USER root
ARG PLAYWRIGHT_VERSION=1.64.1
ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    NODE_PATH=/usr/lib/node_modules \
    SAND_BROWSER_CDP=http://127.0.0.1:9222

# Ubuntu's chromium package is a snap stub that cannot run in a container, so
# Chromium comes from Playwright, which ships amd64 and arm64 Linux builds.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tigervnc-standalone-server \
        x11-xserver-utils \
        novnc \
        python3-websockify \
        openbox \
        xdg-utils \
        fonts-liberation \
        fonts-noto-color-emoji \
        fonts-noto-cjk \
    && npm install -g "playwright@${PLAYWRIGHT_VERSION}" \
    && playwright install --with-deps chromium \
    && chrome="$(find /opt/ms-playwright -type f -name chrome -path '*chrome-linux*' | head -n 1)" \
    && test -x "${chrome}" \
    && ln -s "${chrome}" /usr/local/bin/chromium \
    && chmod -R a+rX /opt/ms-playwright \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

COPY sand-browser-up sand-browser /usr/local/bin/
COPY openbox.xml /etc/sand-browser/openbox.xml
RUN chmod 0755 /usr/local/bin/sand-browser-up /usr/local/bin/sand-browser \
    && ln -s /state/sandbox/Downloads /home/sandbox/Downloads \
    && chown -h sandbox:sandbox /home/sandbox/Downloads

USER sandbox
WORKDIR /workspace
CMD ["/usr/local/bin/sand-browser-up"]
