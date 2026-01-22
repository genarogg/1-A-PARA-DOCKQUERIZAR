FROM debian:bullseye

# Repositorios
RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

ENV DEBIAN_FRONTEND=noninteractive

# Paquetes OBLIGATORIOS
RUN apt-get update && apt-get install -y --no-install-recommends --allow-unauthenticated \
    libqtgui4 libqt4-network libqt4-opengl libqt4-sql libqt4-sql-psql libqtcore4 libqt4-xml \
    xvfb x11vnc x11-utils x11-xserver-utils \
    python3 python3-flask python3-flask-cors \
    git wget procps net-tools ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Paquetes OPCIONALES para mejor calidad
RUN apt-get update && apt-get install -y --no-install-recommends --allow-unauthenticated \
    xfce4 xfce4-terminal dbus-x11 || true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    mesa-utils libgl1-mesa-dri libgl1-mesa-glx libglu1-mesa || true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    picom compton || true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    fonts-liberation fonts-dejavu fonts-noto fontconfig || true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    tigervnc-standalone-server tigervnc-common || true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    openbox || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

WORKDIR /app

# Crear directorios necesarios
RUN mkdir -p /app/instances /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

# Copiar archivos existentes
COPY sysbank /app/sysbank
COPY instance-manager.py /app/instance-manager.py

# Crear start-instance.sh usando printf (más compatible)
RUN printf '%s\n' \
'#!/bin/bash' \
'set -e' \
'' \
'INSTANCE_ID=$1' \
'DISPLAY_NUM=$2' \
'VNC_PORT=$3' \
'NOVNC_PORT=$4' \
'' \
'if [ -z "$INSTANCE_ID" ] || [ -z "$DISPLAY_NUM" ] || [ -z "$VNC_PORT" ] || [ -z "$NOVNC_PORT" ]; then' \
'    echo "Error: Faltan parametros"' \
'    exit 1' \
'fi' \
'' \
'export DISPLAY=:$DISPLAY_NUM' \
'INSTANCE_DIR="/app/instances/$INSTANCE_ID"' \
'' \
'echo "========================================"' \
'echo "Iniciando instancia HD: $INSTANCE_ID"' \
'echo "Display: $DISPLAY"' \
'echo "Resolucion: ${RESOLUTION:-1920x1080x24}"' \
'echo "========================================"' \
'' \
'mkdir -p "$INSTANCE_DIR"' \
'cd "$INSTANCE_DIR"' \
'' \
'export MESA_GL_VERSION_OVERRIDE=3.3' \
'export MESA_GLSL_VERSION_OVERRIDE=330' \
'export LIBGL_ALWAYS_SOFTWARE=1' \
'export GALLIUM_DRIVER=llvmpipe' \
'export LP_NUM_THREADS=4' \
'' \
'echo "[1/5] Iniciando Xvfb HD..."' \
'Xvfb $DISPLAY -screen 0 ${RESOLUTION:-1920x1080x24} -ac +extension GLX +extension RANDR +extension RENDER +extension COMPOSITE -noreset -dpi 96 > "$INSTANCE_DIR/xvfb.log" 2>&1 &' \
'XVFB_PID=$!' \
'echo $XVFB_PID > "$INSTANCE_DIR/xvfb.pid"' \
'' \
'for i in {1..30}; do' \
'    if DISPLAY=$DISPLAY xdpyinfo >/dev/null 2>&1; then' \
'        echo "OK - Servidor X listo"' \
'        break' \
'    fi' \
'    [ $i -eq 30 ] && echo "ERROR: X timeout" && exit 1' \
'    sleep 1' \
'done' \
'' \
'echo "[2/5] Iniciando gestor de ventanas..."' \
'if command -v startxfce4 >/dev/null 2>&1; then' \
'    echo "Usando XFCE4"' \
'    DISPLAY=$DISPLAY startxfce4 > "$INSTANCE_DIR/wm.log" 2>&1 &' \
'    sleep 3' \
'elif command -v xfce4-session >/dev/null 2>&1; then' \
'    DISPLAY=$DISPLAY xfce4-session > "$INSTANCE_DIR/wm.log" 2>&1 &' \
'    sleep 3' \
'else' \
'    echo "Usando Openbox"' \
'    DISPLAY=$DISPLAY openbox > "$INSTANCE_DIR/wm.log" 2>&1 &' \
'    sleep 1' \
'fi' \
'WM_PID=$!' \
'echo $WM_PID > "$INSTANCE_DIR/wm.pid"' \
'' \
'if command -v picom >/dev/null 2>&1; then' \
'    echo "[3/5] Iniciando Picom..."' \
'    DISPLAY=$DISPLAY picom --backend glx --vsync --fade-in-step=0.03 --fade-out-step=0.03 --shadow > "$INSTANCE_DIR/compositor.log" 2>&1 &' \
'    echo $! > "$INSTANCE_DIR/compositor.pid"' \
'elif command -v compton >/dev/null 2>&1; then' \
'    echo "[3/5] Iniciando Compton..."' \
'    DISPLAY=$DISPLAY compton -b > "$INSTANCE_DIR/compositor.log" 2>&1 &' \
'else' \
'    echo "[3/5] Sin compositor"' \
'fi' \
'' \
'echo "[4/5] Iniciando VNC..."' \
'if command -v x0vncserver >/dev/null 2>&1; then' \
'    echo "Usando TigerVNC"' \
'    x0vncserver -display $DISPLAY -rfbport $VNC_PORT -SecurityTypes None -AlwaysShared > "$INSTANCE_DIR/vnc.log" 2>&1 &' \
'else' \
'    echo "Usando x11vnc"' \
'    x11vnc -display $DISPLAY -rfbport $VNC_PORT -nopw -forever -shared > "$INSTANCE_DIR/vnc.log" 2>&1 &' \
'fi' \
'VNC_PID=$!' \
'echo $VNC_PID > "$INSTANCE_DIR/vnc.pid"' \
'' \
'for i in {1..30}; do' \
'    if netstat -ln 2>/dev/null | grep -q ":$VNC_PORT " || ss -ln 2>/dev/null | grep -q ":$VNC_PORT "; then' \
'        echo "OK - VNC listo"' \
'        break' \
'    fi' \
'    [ $i -eq 30 ] && echo "ERROR: VNC timeout" && exit 1' \
'    sleep 1' \
'done' \
'' \
'echo "[5/5] Iniciando noVNC..."' \
'/opt/novnc/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT > "$INSTANCE_DIR/novnc.log" 2>&1 &' \
'NOVNC_PID=$!' \
'echo $NOVNC_PID > "$INSTANCE_DIR/novnc.pid"' \
'' \
'sleep 3' \
'' \
'if netstat -ln 2>/dev/null | grep -q ":$NOVNC_PORT " || ss -ln 2>/dev/null | grep -q ":$NOVNC_PORT "; then' \
'    echo "OK - noVNC listo en puerto $NOVNC_PORT"' \
'else' \
'    echo "WARN: noVNC posible problema"' \
'fi' \
'' \
'echo "[6/6] Iniciando SysBank..."' \
'DISPLAY=$DISPLAY /app/sysbank > "$INSTANCE_DIR/sysbank.log" 2>&1 &' \
'APP_PID=$!' \
'echo $APP_PID > "$INSTANCE_DIR/app.pid"' \
'' \
'echo "========================================"' \
'echo "Instancia $INSTANCE_ID LISTA"' \
'echo "========================================"' \
'' \
'while true; do' \
'    kill -0 $XVFB_PID 2>/dev/null || exit 1' \
'    kill -0 $VNC_PID 2>/dev/null || exit 1' \
'    kill -0 $NOVNC_PID 2>/dev/null || exit 1' \
'    sleep 10' \
'done' \
> /app/start-instance.sh

# Asegurar permisos ejecutables
RUN chmod +x /app/sysbank /app/start-instance.sh /app/instance-manager.py

# Verificar que el archivo se creó correctamente
RUN ls -lh /app/start-instance.sh && head -5 /app/start-instance.sh

# Fuentes mejoradas
RUN if command -v fc-cache >/dev/null 2>&1; then \
    echo '<?xml version="1.0"?>' > /etc/fonts/local.conf && \
    echo '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">' >> /etc/fonts/local.conf && \
    echo '<fontconfig>' >> /etc/fonts/local.conf && \
    echo '  <match target="font">' >> /etc/fonts/local.conf && \
    echo '    <edit name="antialias" mode="assign"><bool>true</bool></edit>' >> /etc/fonts/local.conf && \
    echo '    <edit name="hinting" mode="assign"><bool>true</bool></edit>' >> /etc/fonts/local.conf && \
    echo '    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>' >> /etc/fonts/local.conf && \
    echo '    <edit name="rgba" mode="assign"><const>rgb</const></edit>' >> /etc/fonts/local.conf && \
    echo '  </match>' >> /etc/fonts/local.conf && \
    echo '</fontconfig>' >> /etc/fonts/local.conf && \
    fc-cache -fv; \
    fi

# Variables optimizadas
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