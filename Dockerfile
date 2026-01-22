FROM debian:bullseye

# Configurar repositorios
RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias Qt4 y herramientas necesarias
RUN apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    libqtgui4 libqt4-network libqt4-opengl libqt4-sql libqt4-sql-psql libqtcore4 libqt4-xml \
    xvfb x11vnc openbox x11-utils \
    python3 python3-flask python3-flask-cors \
    git wget procps net-tools ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Instalar noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

WORKDIR /app

# Copiar ejecutable y scripts
COPY sysbank /app/sysbank
COPY start-instance.sh /app/start-instance.sh
COPY instance-manager.py /app/instance-manager.py

# Dar permisos
RUN chmod +x /app/sysbank && \
    chmod +x /app/start-instance.sh && \
    chmod +x /app/instance-manager.py && \
    mkdir -p /app/instances

# Variables de entorno
ENV DISPLAY=:99
ENV RESOLUTION=1280x720x24
ENV QT_X11_NO_MITSHM=1

EXPOSE 8080

CMD ["python3", "/app/instance-manager.py"]