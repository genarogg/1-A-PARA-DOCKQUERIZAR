#!/bin/bash
set -e

INSTANCE_ID=$1
DISPLAY_NUM=$2
VNC_PORT=$3
NOVNC_PORT=$4

if [ -z "$INSTANCE_ID" ] || [ -z "$DISPLAY_NUM" ] || [ -z "$VNC_PORT" ] || [ -z "$NOVNC_PORT" ]; then
    echo "ERROR: Missing parameters"
    echo "Usage: $0 <instance_id> <display_num> <vnc_port> <novnc_port>"
    exit 1
fi

export DISPLAY=:$DISPLAY_NUM
INSTANCE_DIR="/app/instances/$INSTANCE_ID"

echo "=========================================="
echo "SysBank LXDE Instance Starting"
echo "ID: $INSTANCE_ID"
echo "Display: $DISPLAY"
echo "VNC Port: $VNC_PORT"
echo "noVNC Port: $NOVNC_PORT"
echo "=========================================="

mkdir -p "$INSTANCE_DIR"
cd "$INSTANCE_DIR"

# Variables de optimización
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLSL_VERSION_OVERRIDE=330
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export LP_NUM_THREADS=8
export QT_X11_NO_MITSHM=1
export QT_GRAPHICSSYSTEM=native
export vblank_mode=0
export __GL_SYNC_TO_VBLANK=0

# Función para verificar si un proceso está corriendo
check_process() {
    kill -0 $1 2>/dev/null
}

# [1/5] Xvfb
echo "[1/5] Starting Xvfb..."
Xvfb $DISPLAY \
    -screen 0 ${RESOLUTION:-1920x1080x24} \
    -ac \
    +extension GLX \
    +extension RANDR \
    +extension RENDER \
    +extension COMPOSITE \
    -noreset \
    -nolisten tcp \
    -dpi 96 \
    -fbdir /tmp \
    > "$INSTANCE_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
echo $XVFB_PID > "$INSTANCE_DIR/xvfb.pid"

# Esperar Xvfb
for i in {1..30}; do
    if DISPLAY=$DISPLAY xdpyinfo >/dev/null 2>&1; then
        echo "✓ Xvfb ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ Xvfb timeout"
        cat "$INSTANCE_DIR/xvfb.log"
        exit 1
    fi
    sleep 0.5
done

# [2/5] Window Manager (Openbox)
echo "[2/5] Starting Openbox..."
DISPLAY=$DISPLAY openbox --config-file /dev/null > "$INSTANCE_DIR/openbox.log" 2>&1 &
WM_PID=$!
echo $WM_PID > "$INSTANCE_DIR/wm.pid"
sleep 1
echo "✓ Openbox ready"

# [3/5] x11vnc
echo "[3/5] Starting x11vnc..."
x11vnc \
    -display $DISPLAY \
    -rfbport $VNC_PORT \
    -forever \
    -shared \
    -nopw \
    -noxrecord \
    -noxfixes \
    -noxdamage \
    -wait 10 \
    -defer 10 \
    -speeds lan \
    -cursor arrow \
    > "$INSTANCE_DIR/vnc.log" 2>&1 &
VNC_PID=$!
echo $VNC_PID > "$INSTANCE_DIR/vnc.pid"

# Verificar VNC
for i in {1..30}; do
    if ss -tuln 2>/dev/null | grep -q ":$VNC_PORT " || netstat -tuln 2>/dev/null | grep -q ":$VNC_PORT "; then
        echo "✓ VNC ready on port $VNC_PORT"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ VNC timeout"
        cat "$INSTANCE_DIR/vnc.log"
        exit 1
    fi
    sleep 0.5
done

# [4/5] noVNC
echo "[4/5] Starting noVNC..."
/opt/novnc/utils/novnc_proxy \
    --vnc localhost:$VNC_PORT \
    --listen $NOVNC_PORT \
    --web /opt/novnc \
    > "$INSTANCE_DIR/novnc.log" 2>&1 &
NOVNC_PID=$!
echo $NOVNC_PID > "$INSTANCE_DIR/novnc.pid"
sleep 2
echo "✓ noVNC ready on port $NOVNC_PORT"

# [5/5] SysBank
echo "[5/5] Starting SysBank..."
DISPLAY=$DISPLAY /app/sysbank > "$INSTANCE_DIR/sysbank.log" 2>&1 &
APP_PID=$!
echo $APP_PID > "$INSTANCE_DIR/app.pid"
echo "✓ SysBank started (PID: $APP_PID)"

echo "=========================================="
echo "✓ Instance ready!"
echo "Access at: http://localhost:$NOVNC_PORT"
echo "=========================================="

# Monitor de procesos
while true; do
    if ! check_process $XVFB_PID; then
        echo "✗ Xvfb died, exiting"
        exit 1
    fi
    if ! check_process $VNC_PID; then
        echo "✗ VNC died, exiting"
        exit 1
    fi
    if ! check_process $NOVNC_PID; then
        echo "✗ noVNC died, exiting"
        exit 1
    fi
    sleep 10
done