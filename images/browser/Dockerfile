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

# The browser: Google Chrome on amd64. Playwright's "Chrome for Testing" loses
# a file activated in its GTK picker (double-click or Enter attaches nothing),
# and shows a testing banner. Google Chrome ships amd64 only, so arm64 keeps
# Playwright's Chromium (Ubuntu's chromium package is a snap stub that cannot
# run in a container). The Playwright library drives either over CDP.
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
        libgtk-3-0t64 \
    && npm install -g "playwright@${PLAYWRIGHT_VERSION}" \
    && if [ "$(dpkg --print-architecture)" = amd64 ]; then \
         install -d -m 0755 /etc/apt/keyrings \
         && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg \
         && printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main\n' > /etc/apt/sources.list.d/google-chrome.list \
         && apt-get update \
         && apt-get install -y --no-install-recommends google-chrome-stable \
         && ln -s /usr/bin/google-chrome /usr/local/bin/chromium; \
       else \
         playwright install --with-deps chromium \
         && chrome="$(find /opt/ms-playwright -type f -name chrome -path '*chrome-linux*' | head -n 1)" \
         && test -x "${chrome}" \
         && ln -s "${chrome}" /usr/local/bin/chromium \
         && chmod -R a+rX /opt/ms-playwright; \
       fi \
    && test -x /usr/local/bin/chromium \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

COPY sand-browser-up sand-browser xdg-open /usr/local/bin/
COPY openbox.xml /etc/sand-browser/openbox.xml
RUN chmod 0755 /usr/local/bin/sand-browser-up /usr/local/bin/sand-browser /usr/local/bin/xdg-open \
    && ln -s /state/sandbox/Downloads /home/sandbox/Downloads \
    && ln -s /state/sandbox/Uploads /home/sandbox/Uploads \
    && chown -h sandbox:sandbox /home/sandbox/Downloads /home/sandbox/Uploads

USER sandbox
WORKDIR /workspace
CMD ["/usr/local/bin/sand-browser-up"]
