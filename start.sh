#!/bin/bash
set -e

echo "=== Iniciando configuración ==="

export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# KDE SIN OPENGL (evita pantalla negra)
export KWIN_COMPOSE=QPainter
export KWIN_OPENGL_INTERFACE=software
export QT_XCB_GL_INTEGRATION=none

# DBus
echo "Iniciando DBus..."
eval "$(dbus-launch --exit-with-session)"

# PRIMERO: Crear el servidor X con Xvfb
echo "Iniciando servidor X virtual (Xvfb)..."
Xvfb :1 -screen 0 1280x800x24 &
XVFB_PID=$!

echo "Esperando a que Xvfb esté listo..."
sleep 3

# Verificar que X está funcionando
echo "Verificando servidor X..."
if xdpyinfo -display :1 > /dev/null 2>&1; then
    echo "✓ Servidor X funcionando correctamente"
else
    echo "✗ Error: Servidor X no está funcionando"
    exit 1
fi

# SEGUNDO: Conectar x11vnc al display existente
echo "Iniciando x11vnc..."
x11vnc \
  -display :1 \
  -nopw \
  -forever \
  -shared \
  -rfbport 5901 \
  -noxdamage \
  -repeat \
  -cursor arrow \
  -bg

echo "Esperando a que x11vnc esté listo..."
sleep 2

# TERCERO: Iniciar KDE Plasma
echo "Iniciando KDE Plasma..."
dbus-run-session startplasma-x11 &

echo "Esperando a que KDE inicie..."
sleep 10

# CUARTO: Iniciar noVNC
echo "Iniciando noVNC en puerto 6080..."
/usr/share/novnc/utils/launch.sh \
  --vnc localhost:5901 \
  --listen 6080 &

echo ""
echo "=== Sistema listo ==="
echo "Accede a: http://localhost:6080/vnc.html"
echo ""

# Mantener el contenedor vivo
tail -f /dev/null