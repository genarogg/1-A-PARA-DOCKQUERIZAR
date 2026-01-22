FROM debian:buster

# Configurar repositorios archivados
RUN echo "deb http://archive.debian.org/debian buster main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

# Instalar dependencias Qt4, VNC, noVNC y servidor X virtual
RUN apt-get -o Acquire::AllowInsecureRepositories=true \
            -o Acquire::AllowDowngradeToInsecureRepositories=true \
            update && \
    apt-get -o Acquire::AllowInsecureRepositories=true \
            -o Acquire::AllowDowngradeToInsecureRepositories=true \
            install -y --allow-unauthenticated \
    libqtgui4 \
    libqt4-network \
    libqt4-opengl \
    libqt4-sql \
    libqt4-sql-psql \
    libqtcore4 \
    libqt4-xml \
    xvfb \
    x11vnc \
    fluxbox \
    wget \
    python3 \
    python3-numpy \
    git \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Instalar noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

WORKDIR /app

COPY sysbank /app/sysbank
RUN chmod +x /app/sysbank

# Variables de entorno
ENV DISPLAY=:99
ENV RESOLUTION=1280x720x24

# Copiar script de inicio
COPY start-vnc.sh /app/start-vnc.sh
RUN chmod +x /app/start-vnc.sh

EXPOSE 5900 6080

CMD ["/app/start-vnc.sh"]