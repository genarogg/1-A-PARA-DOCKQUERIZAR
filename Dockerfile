FROM debian:bullseye

# Configurar repositorios
RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

ENV DEBIAN_FRONTEND=noninteractive

# Instalar TODO desde paquetes del sistema (sin pip)
RUN apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    libqtgui4 libqt4-network libqt4-opengl libqt4-sql libqt4-sql-psql libqtcore4 libqt4-xml \
    xvfb x11vnc openbox \
    python3 python3-flask python3-flask-cors \
    git wget procps net-tools ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

WORKDIR /app

COPY sysbank /app/sysbank
RUN chmod +x /app/sysbank

RUN mkdir -p /app/instances

ENV DISPLAY=:99
ENV RESOLUTION=1280x720x24
ENV QT_X11_NO_MITSHM=1

COPY start-instance.sh /app/start-instance.sh
COPY instance-manager.py /app/instance-manager.py
RUN chmod +x /app/*.sh /app/*.py

EXPOSE 8080

CMD ["python3", "/app/instance-manager.py"]