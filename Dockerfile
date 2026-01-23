FROM debian:bullseye

# Repositorios
RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

ENV DEBIAN_FRONTEND=noninteractive

# Qt4 completo
RUN apt-get update && apt-get install -y --no-install-recommends --allow-unauthenticated \
    libqtgui4 \
    libqt4-network \
    libqt4-opengl \
    libqt4-sql \
    libqt4-sql-psql \
    libqtcore4 \
    libqt4-xml \
    qt4-qtconfig \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# LXDE Desktop
RUN apt-get update && apt-get install -y --no-install-recommends \
    lxde-core \
    lxterminal \
    pcmanfm \
    lxappearance \
    openbox \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Servidor X y VNC
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    x11vnc \
    x11-utils \
    x11-xserver-utils \
    xdotool \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Gráficos OpenGL
RUN apt-get update && apt-get install -y --no-install-recommends \
    mesa-utils \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    libglu1-mesa \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Fuentes
RUN apt-get update && apt-get install -y --no-install-recommends \
    fonts-liberation \
    fonts-dejavu \
    fonts-noto \
    fontconfig \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Python y herramientas
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-flask \
    python3-flask-cors \
    git \
    wget \
    curl \
    procps \
    net-tools \
    iproute2 \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Crear directorio de trabajo
WORKDIR /app

# Crear directorios necesarios
RUN mkdir -p /app/instances /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

# ============================================================
# SECCIÓN CRÍTICA: COPIAR ARCHIVOS
# ============================================================
# Copiar archivos explícitamente a /app/
COPY start-instances.sh /app/start-instances.sh
COPY instance-manager.py /app/instance-manager.py
COPY sysbank /app/sysbank

# Dar permisos de ejecución
RUN chmod +x /app/start-instances.sh && \
    chmod +x /app/instance-manager.py && \
    chmod +x /app/sysbank

# VERIFICACIÓN OBLIGATORIA
RUN echo "========================================" && \
    echo "VERIFICANDO ARCHIVOS COPIADOS" && \
    echo "========================================" && \
    ls -lah /app/ && \
    echo "========================================" && \
    test -f /app/start-instances.sh || (echo "ERROR: start-instances.sh no existe" && exit 1) && \
    test -x /app/start-instances.sh || (echo "ERROR: start-instances.sh no es ejecutable" && exit 1) && \
    test -f /app/instance-manager.py || (echo "ERROR: instance-manager.py no existe" && exit 1) && \
    test -x /app/instance-manager.py || (echo "ERROR: instance-manager.py no es ejecutable" && exit 1) && \
    test -f /app/sysbank || (echo "ERROR: sysbank no existe" && exit 1) && \
    test -x /app/sysbank || (echo "ERROR: sysbank no es ejecutable" && exit 1) && \
    echo "✓ Todos los archivos verificados correctamente" && \
    echo "========================================"
# ============================================================

# Configuración de fuentes
RUN echo '<?xml version="1.0"?>' > /etc/fonts/local.conf && \
    echo '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">' >> /etc/fonts/local.conf && \
    echo '<fontconfig>' >> /etc/fonts/local.conf && \
    echo '  <match target="font">' >> /etc/fonts/local.conf && \
    echo '    <edit name="antialias" mode="assign"><bool>true</bool></edit>' >> /etc/fonts/local.conf && \
    echo '    <edit name="hinting" mode="assign"><bool>true</bool></edit>' >> /etc/fonts/local.conf && \
    echo '    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>' >> /etc/fonts/local.conf && \
    echo '    <edit name="rgba" mode="assign"><const>rgb</const></edit>' >> /etc/fonts/local.conf && \
    echo '  </match>' >> /etc/fonts/local.conf && \
    echo '</fontconfig>' >> /etc/fonts/local.conf && \
    fc-cache -fv

# Variables de entorno
ENV DISPLAY=:99 \
    RESOLUTION=1920x1080x24 \
    QT_X11_NO_MITSHM=1 \
    QT_GRAPHICSSYSTEM=native \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    LP_NUM_THREADS=8 \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330

EXPOSE 8080

# Comando de inicio
CMD ["python3", "/app/instance-manager.py"]