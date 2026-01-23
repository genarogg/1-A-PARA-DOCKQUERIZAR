FROM debian:buster

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV XDG_RUNTIME_DIR=/tmp/runtime-root

# Debian Buster está archivado, usar repositorios archive
RUN echo "deb http://archive.debian.org/debian buster main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/99no-check-valid-until

RUN apt-get update && apt-get install -y \
    sudo \
    dbus \
    dbus-x11 \
    xvfb \
    x11vnc \
    x11-utils \
    xterm \
    openbox \
    fonts-dejavu \
    net-tools \
    ca-certificates \
    procps \
    wget \
    unzip \
    python3 \
    python3-numpy \
    python3-websockify \
    libqtcore4 \
    libqtgui4 \
    libqt4-network \
    libqt4-sql \
    libqt4-xml \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar noVNC de forma correcta
RUN mkdir -p /opt/novnc && \
    cd /opt && \
    wget -q https://github.com/novnc/noVNC/archive/v1.3.0.zip && \
    unzip -q v1.3.0.zip && \
    mv noVNC-1.3.0/* /opt/novnc/ && \
    rm -rf noVNC-1.3.0 v1.3.0.zip && \
    chmod -R 755 /opt/novnc

RUN useradd -m -s /bin/bash desktop && \
    echo "desktop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copiar el binario sysbank
COPY sysbank /usr/local/bin/sysbank
RUN chmod +x /usr/local/bin/sysbank

# Crear directorio de autostart
RUN mkdir -p /home/desktop/.config/autostart

# Copiar archivo de autostart
COPY sysbank.desktop /home/desktop/.config/autostart/sysbank.desktop

WORKDIR /home/desktop
COPY start.sh /home/desktop/start.sh
RUN chmod +x /home/desktop/start.sh && \
    chown -R desktop:desktop /home/desktop

USER desktop

EXPOSE 6080 5901
CMD ["/home/desktop/start.sh"]