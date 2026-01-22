FROM debian:bullseye

# Configurar repositorios
RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

ENV DEBIAN_FRONTEND=noninteractive

# Instalar paquetes esenciales primero
RUN apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    # Qt4 (OBLIGATORIO para SysBank)
    libqtgui4 libqt4-network libqt4-opengl libqt4-sql libqt4-sql-psql libqtcore4 libqt4-xml \
    # Servidor X y VNC (OBLIGATORIO)
    xvfb x11vnc x11-utils x11-xserver-utils \
    # Python y Flask (OBLIGATORIO)
    python3 python3-flask python3-flask-cors \
    # Herramientas básicas (OBLIGATORIO)
    git wget procps net-tools ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Instalar paquetes opcionales para mejor experiencia (no críticos)
RUN apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    # Gestor de ventanas mejorado (OPCIONAL)
    xfce4 xfce4-terminal dbus-x11 || true \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    # Aceleración gráfica (OPCIONAL)
    mesa-utils libgl1-mesa-dri libgl1-mesa-glx libglu1-mesa || true \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    # Compositor (OPCIONAL)
    picom compton || true \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    # Fuentes mejoradas (OPCIONAL)
    fonts-liberation fonts-dejavu fonts-noto fontconfig || true \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    # TigerVNC (OPCIONAL, mejor que x11vnc)
    tigervnc-standalone-server tigervnc-common || true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Fallback: instalar openbox si XFCE no está disponible
RUN apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated openbox || true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Instalar noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

WORKDIR /app

# Copiar archivos
COPY sysbank /app/sysbank
COPY start-instance.sh /app/start-instance.sh
COPY instance-manager.py /app/instance-manager.py

# Configuración de fuentes mejoradas (si fontconfig está instalado)
RUN if command -v fc-cache >/dev/null 2>&1; then \
    echo '<?xml version="1.0"?>\n\
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n\
<fontconfig>\n\
  <match target="font">\n\
    <edit name="antialias" mode="assign"><bool>true</bool></edit>\n\
    <edit name="hinting" mode="assign"><bool>true</bool></edit>\n\
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>\n\
    <edit name="rgba" mode="assign"><const>rgb</const></edit>\n\
  </match>\n\
</fontconfig>' > /etc/fonts/local.conf && fc-cache -fv; \
    fi

# Permisos
RUN chmod +x /app/sysbank /app/start-instance.sh /app/instance-manager.py && \
    mkdir -p /app/instances /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

# Variables de entorno optimizadas
ENV DISPLAY=:99 \
    RESOLUTION=1920x1080x24 \
    QT_X11_NO_MITSHM=1 \
    QT_GRAPHICSSYSTEM=native \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    LP_NUM_THREADS=4 \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330

EXPOSE 8080

CMD ["python3", "/app/instance-manager.py"]