# Base image from the expert report recommendation
FROM scottyhardy/docker-wine:latest

# Set environment for 64-bit Windows 10
ENV WINEARCH=win64
ENV WINEPREFIX=/root/.wine

# 1. Install Critical Dependencies (Report Section 4.2)
# corefonts: Text rendering
# gdiplus: Tree drawing
# wininet: Ancestry API calls
# msxml6: Parsing XML responses
RUN winetricks -q corefonts gdiplus wininet msxml6 d3dcompiler_47

# 2. Install VNC and noVNC for desktop access
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    fluxbox \
    && rm -rf /var/lib/apt/lists/*

# Configure noVNC
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Create supervisor config for VNC services
# Create non-root user for running VNC services
RUN useradd -m -s /bin/bash vncuser && \
    mkdir -p /var/log/supervisor /var/run /etc/supervisor/conf.d && \
    chown -R vncuser:vncuser /var/log/supervisor /var/run /usr/share/novnc && \
    chmod 755 /var/log/supervisor /var/run
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 3. The Edge/WebView2 Workaround (Report Section 4.3)
# Note: WebView2 installation skipped - requires manual setup for Ancestry OAuth

# 4. Directory Setup
WORKDIR /root/Documents/RootsMagic

# Set display environment
ENV DISPLAY=:99

# Start VNC services directly
CMD Xvfb :99 -screen 0 1024x768x24 & \
    sleep 2 && \
    DISPLAY=:99 fluxbox & \
    sleep 1 && \
    x11vnc -display :99 -passwd $VNC_PASSWORD -listen localhost -xkb -ncache 10 -ncache_cr & \
        sleep 2 && \
        websockify --web=/usr/share/novnc 8080 localhost:5900 & \
        tail -f /dev/null
