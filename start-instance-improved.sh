#!/bin/bash
set -e

# Parámetros de la instancia
INSTANCE_ID=$1
DISPLAY_NUM=$2
VNC_PORT=$3
NOVNC_PORT=$4

if [ -z "$INSTANCE_ID" ] || [ -z "$DISPLAY_NUM" ] || [ -z "$VNC_PORT" ] || [ -z "$NOVNC_PORT" ]; then
    echo "Error: Faltan parametros"
    echo "Uso: $0 <instance_id> <display_num> <vnc_port> <novnc_port>"
    exit 1
fi

export DISPLAY=:$DISPLAY_NUM
INSTANCE_DIR="/app/instances/$INSTANCE_ID"

echo "========================================="
echo "Iniciando instancia mejorada: $INSTANCE_ID"
echo "Display: $DISPLAY"
echo "VNC Port: $VNC_PORT"
echo "noVNC Port: $NOVNC_PORT"
echo "========================================="

# Crear directorio de la instancia
mkdir -p "$INSTANCE_DIR"
cd "$INSTANCE_DIR"

# Configurar variables de entorno para mejor rendimiento gráfico
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLSL_VERSION_OVERRIDE=330
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export LP_NUM_THREADS=4

# [1/6] Iniciar Xvfb con configuración optimizada
echo "[1/6] Iniciando servidor X optimizado..."
Xvfb $DISPLAY \
    -screen 0 ${RESOLUTION:-1920x1080x24} \
    -ac \
    +extension GLX \
    +extension RANDR \
    +extension RENDER \
    -noreset \
    -dpi 96 \
    -nolisten tcp \
    > "$INSTANCE_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
echo $XVFB_PID > "$INSTANCE_DIR/xvfb.pid"
echo "Xvfb PID: $XVFB_PID"

# Esperar a que X esté listo
echo "Esperando a que X este listo..."
for i in {1..30}; do
    if DISPLAY=$DISPLAY xdpyinfo >/dev/null 2>&1; then
        echo "OK - Servidor X listo despues de $i intentos"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Servidor X no responde despues de 30 segundos"
        cat "$INSTANCE_DIR/xvfb.log"
        exit 1
    fi
    sleep 1
done

# [2/6] Iniciar D-Bus (necesario para XFCE)
echo "[2/6] Iniciando D-Bus..."
dbus-daemon --session --fork --print-address > "$INSTANCE_DIR/dbus.address"
export DBUS_SESSION_BUS_ADDRESS=$(cat "$INSTANCE_DIR/dbus.address")

# [3/6] Iniciar XFCE4 (gestor de ventanas completo)
echo "[3/6] Iniciando entorno XFCE4..."
DISPLAY=$DISPLAY startxfce4 > "$INSTANCE_DIR/xfce4.log" 2>&1 &
XFCE_PID=$!
echo $XFCE_PID > "$INSTANCE_DIR/xfce4.pid"
echo "XFCE4 PID: $XFCE_PID"
sleep 3

# [4/6] Iniciar compositor Picom para efectos visuales suaves
echo "[4/6] Iniciando compositor Picom..."
DISPLAY=$DISPLAY picom \
    --backend glx \
    --vsync \
    --fade-in-step=0.03 \
    --fade-out-step=0.03 \
    --shadow \
    --shadow-opacity=0.5 \
    > "$INSTANCE_DIR/picom.log" 2>&1 &
PICOM_PID=$!
echo $PICOM_PID > "$INSTANCE_DIR/picom.pid"
echo "Picom PID: $PICOM_PID"
sleep 1

# [5/6] Iniciar servidor TigerVNC optimizado
echo "[5/6] Iniciando servidor TigerVNC..."
x0vncserver \
    -display $DISPLAY \
    -rfbport $VNC_PORT \
    -SecurityTypes None \
    -AlwaysShared \
    -AcceptPointerEvents \
    -AcceptKeyEvents \
    -AcceptCutText \
    -SendCutText \
    -MaxCutText=1000000 \
    > "$INSTANCE_DIR/vnc.log" 2>&1 &
VNC_PID=$!
echo $VNC_PID > "$INSTANCE_DIR/vnc.pid"
echo "TigerVNC PID: $VNC_PID"

# Esperar a que VNC esté listo
echo "Esperando a que VNC este listo..."
for i in {1..30}; do
    if netstat -ln 2>/dev/null | grep -q ":$VNC_PORT " || ss -ln 2>/dev/null | grep -q ":$VNC_PORT "; then
        echo "OK - Servidor VNC listo en puerto $VNC_PORT"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: VNC no responde en puerto $VNC_PORT"
        cat "$INSTANCE_DIR/vnc.log"
        exit 1
    fi
    sleep 1
done

# [6/6] Iniciar noVNC
echo "[6/6] Iniciando noVNC..."
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
    echo "OK - noVNC escuchando en puerto $NOVNC_PORT"
else
    echo "ADVERTENCIA: noVNC puede no estar escuchando en puerto $NOVNC_PORT"
    cat "$INSTANCE_DIR/novnc.log"
fi

# [7/7] Iniciar aplicación SysBank
echo "[7/7] Iniciando aplicacion SysBank..."
DISPLAY=$DISPLAY /app/sysbank > "$INSTANCE_DIR/sysbank.log" 2>&1 &
APP_PID=$!
echo $APP_PID > "$INSTANCE_DIR/app.pid"
echo "SysBank PID: $APP_PID"

echo "========================================="
echo "Instancia $INSTANCE_ID iniciada correctamente"
echo "========================================="
echo "PIDs:"
echo "  Xvfb: $XVFB_PID"
echo "  XFCE4: $XFCE_PID"
echo "  Picom: $PICOM_PID"
echo "  TigerVNC: $VNC_PID"
echo "  noVNC: $NOVNC_PID"
echo "  SysBank: $APP_PID"
echo "========================================="
echo "Logs disponibles en: $INSTANCE_DIR/"
echo "  - xvfb.log"
echo "  - xfce4.log"
echo "  - picom.log"
echo "  - vnc.log"
echo "  - novnc.log"
echo "  - sysbank.log"
echo "========================================="

# Mantener el script corriendo y monitorear procesos críticos
while true; do
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "ERROR: Xvfb termino inesperadamente"
        exit 1
    fi
    if ! kill -0 $VNC_PID 2>/dev/null; then
        echo "ERROR: VNC termino inesperadamente"
        exit 1
    fi
    if ! kill -0 $NOVNC_PID 2>/dev/null; then
        echo "ERROR: noVNC termino inesperadamente"
        exit 1
    fi
    sleep 10
done