FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV XDG_RUNTIME_DIR=/tmp/runtime-root

RUN apt-get update && apt-get install -y \
    sudo \
    dbus dbus-x11 \
    xvfb \
    x11vnc \
    novnc websockify \
    kde-standard \
    plasma-workspace \
    kwin-x11 \
    xterm \
    fonts-dejavu \
    net-tools \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash desktop && \
    echo "desktop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/desktop
COPY start.sh /home/desktop/start.sh
RUN chmod +x /home/desktop/start.sh && \
    chown desktop:desktop /home/desktop/start.sh

USER desktop

EXPOSE 6080 5901
CMD ["/home/desktop/start.sh"]
