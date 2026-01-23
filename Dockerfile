FROM debian:buster

ENV DEBIAN_FRONTEND=noninteractive

# 🔧 Fix repos EOL
RUN sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid

# 📦 Instalar todo
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    dbus-x11 \
    lxqt \
    openbox \
    qt4-default \
    novnc \
    websockify \
    xterm \
    ca-certificates \
    && apt-get clean

# 🧠 Usuario no-root (RECOMENDADO)
RUN useradd -m qtuser
USER qtuser
WORKDIR /home/qtuser

COPY start.sh /start.sh
USER root
RUN chmod +x /start.sh
USER qtuser

EXPOSE 5900 6080
CMD ["/start.sh"]
