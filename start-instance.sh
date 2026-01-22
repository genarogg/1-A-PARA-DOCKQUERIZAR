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

# Función para verificar si un proceso está corriendo
check_process() {
    if ps aux | grep -v grep | grep "$1" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Iniciar Xvfb con aceleración optimizada
echo "[1/5] Iniciando servidor X virtual optimizado..."
Xvfb $DISPLAY \
    -screen 0 ${RESOLUTION:-1280x720x24} \
    -ac \
    +extension GLX \
    +render \
    -noreset \
    > "$INSTANCE_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
echo $XVFB_PID > "$INSTANCE_DIR/xvfb.pid"
echo "Xvfb PID: $XVFB_PID"

# Esperar a que X esté listo con timeout
echo "Esperando a que X esté listo..."
for i in {1..30}; do
    if DISPLAY=$DISPLAY xdpyinfo >/dev/null 2>&1; then
        echo "✓ Servidor X listo después de $i intentos"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ Error: Servidor X no responde después de 30 segundos"
        cat "$INSTANCE_DIR/xvfb.log"
        exit 1
    fi
    sleep 1
done

# Iniciar gestor de ventanas ligero
echo "[2/5] Iniciando gestor de ventanas..."
DISPLAY=$DISPLAY openbox > "$INSTANCE_DIR/openbox.log" 2>&1 &
OPENBOX_PID=$!
echo $OPENBOX_PID > "$INSTANCE_DIR/openbox.pid"
echo "Openbox PID: $OPENBOX_PID"
sleep 2

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
    -noxdamage \
    > "$INSTANCE_DIR/vnc.log" 2>&1 &
VNC_PID=$!
echo $VNC_PID > "$INSTANCE_DIR/vnc.pid"
echo "VNC PID: $VNC_PID"

# Esperar a que VNC esté listo
echo "Esperando a que VNC esté listo..."
for i in {1..30}; do
    if netstat -ln 2>/dev/null | grep -q ":$VNC_PORT " || ss -ln 2>/dev/null | grep -q ":$VNC_PORT "; then
        echo "✓ Servidor VNC listo en puerto $VNC_PORT"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ Error: VNC no responde en puerto $VNC_PORT"
        cat "$INSTANCE_DIR/vnc.log"
        exit 1
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
echo "noVNC PID: $NOVNC_PID"

sleep 3

# Verificar que noVNC está escuchando
if netstat -ln 2>/dev/null | grep -q ":$NOVNC_PORT " || ss -ln 2>/dev/null | grep -q ":$NOVNC_PORT "; then
    echo "✓ noVNC escuchando en puerto $NOVNC_PORT"
else
    echo "✗ Advertencia: noVNC puede no estar escuchando en puerto $NOVNC_PORT"
    cat "$INSTANCE_DIR/novnc.log"
fi

# Iniciar aplicación sysbank
echo "[5/5] Iniciando aplicación sysbank..."
DISPLAY=$DISPLAY /app/sysbank > "$INSTANCE_DIR/sysbank.log" 2>&1 &
APP_PID=$!
echo $APP_PID > "$INSTANCE_DIR/app.pid"
echo "SysBank PID: $APP_PID"

echo "========================================="
echo "✓ Instancia $INSTANCE_ID iniciada correctamente"
echo "========================================="
echo "PIDs:"
echo "  Xvfb: $XVFB_PID"
echo "  Openbox: $OPENBOX_PID"
echo "  VNC: $VNC_PID"
echo "  noVNC: $NOVNC_PID"
echo "  SysBank: $APP_PID"
echo "========================================="
echo "Logs disponibles en: $INSTANCE_DIR/"
echo "  - xvfb.log"
echo "  - vnc.log"
echo "  - novnc.log"
echo "  - sysbank.log"
echo "========================================="

# Mantener el script corriendo y monitorear procesos
while true; do
    # Verificar que los procesos principales están corriendo
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "✗ Error: Xvfb terminó inesperadamente"
        exit 1
    fi
    if ! kill -0 $VNC_PID 2>/dev/null; then
        echo "✗ Error: VNC terminó inesperadamente"
        exit 1
    fi
    if ! kill -0 $NOVNC_PID 2>/dev/null; then
        echo "✗ Error: noVNC terminó inesperadamente"
        exit 1
    fi
    sleep 10
done