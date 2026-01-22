#!/bin/bash
set -e

# Parámetros de la instancia
INSTANCE_ID=$1
DISPLAY_NUM=$2
VNC_PORT=$3
NOVNC_PORT=$4

if [ -z "$INSTANCE_ID" ] || [ -z "$DISPLAY_NUM" ] || [ -z "$VNC_PORT" ] || [ -z "$NOVNC_PORT" ]; then
    echo "Error: Faltan parámetros"
    echo "Uso: $0 <instance_id> <display_num> <vnc_port> <novnc_port>"
    exit 1
fi

export DISPLAY=:$DISPLAY_NUM
INSTANCE_DIR="/app/instances/$INSTANCE_ID"

echo "========================================="
echo "Iniciando instancia: $INSTANCE_ID"
echo "Display: $DISPLAY"
echo "VNC Port: $VNC_PORT"
echo "noVNC Port: $NOVNC_PORT"
echo "========================================="

# Crear directorio de la instancia
mkdir -p "$INSTANCE_DIR"
cd "$INSTANCE_DIR"

# Iniciar Xvfb con aceleración optimizada
echo "[1/5] Iniciando servidor X virtual optimizado..."
Xvfb $DISPLAY \
    -screen 0 ${RESOLUTION} \
    -ac \
    +extension GLX \
    +render \
    -noreset \
    -dpi 96 \
    > "$INSTANCE_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
echo $XVFB_PID > "$INSTANCE_DIR/xvfb.pid"

# Esperar a que X esté listo
echo "Esperando a que X esté listo..."
for i in {1..10}; do
    if xdpyinfo -display $DISPLAY >/dev/null 2>&1; then
        echo "✓ Servidor X listo"
        break
    fi
    sleep 1
done

# Iniciar gestor de ventanas ligero
echo "[2/5] Iniciando gestor de ventanas..."
openbox --config-file /dev/null > "$INSTANCE_DIR/openbox.log" 2>&1 &
OPENBOX_PID=$!
echo $OPENBOX_PID > "$INSTANCE_DIR/openbox.pid"
sleep 1

# Configurar VNC con compresión y calidad optimizada
echo "[3/5] Iniciando servidor VNC optimizado..."
x11vnc \
    -display $DISPLAY \
    -rfbport $VNC_PORT \
    -nopw \
    -listen 0.0.0.0 \
    -xkb \
    -forever \
    -shared \
    -threads \
    -progressive 32 \
    -compresslevel 9 \
    -quality 7 \
    -deferupdate 10 \
    > "$INSTANCE_DIR/vnc.log" 2>&1 &
VNC_PID=$!
echo $VNC_PID > "$INSTANCE_DIR/vnc.pid"

# Esperar a que VNC esté listo
echo "Esperando a que VNC esté listo..."
for i in {1..10}; do
    if netstat -ln | grep -q ":$VNC_PORT "; then
        echo "✓ Servidor VNC listo"
        break
    fi
    sleep 1
done

# Iniciar noVNC
echo "[4/5] Iniciando noVNC..."
/opt/novnc/utils/novnc_proxy \
    --vnc localhost:$VNC_PORT \
    --listen $NOVNC_PORT \
    > "$INSTANCE_DIR/novnc.log" 2>&1 &
NOVNC_PID=$!
echo $NOVNC_PID > "$INSTANCE_DIR/novnc.pid"

sleep 2

# Iniciar aplicación sysbank
echo "[5/5] Iniciando aplicación sysbank..."
/app/sysbank > "$INSTANCE_DIR/sysbank.log" 2>&1 &
APP_PID=$!
echo $APP_PID > "$INSTANCE_DIR/app.pid"

echo "========================================="
echo "✓ Instancia $INSTANCE_ID iniciada correctamente"
echo "========================================="
echo "PIDs guardados en: $INSTANCE_DIR"
echo "Logs disponibles en: $INSTANCE_DIR/*.log"
echo "========================================="

# Mantener el script corriendo
tail -f /dev/null