#!/bin/bash
set -e

echo "Iniciando servidor X virtual..."
Xvfb :99 -screen 0 ${RESOLUTION} -ac &
XVFB_PID=$!

echo "Esperando a que X esté listo..."
sleep 2

echo "Iniciando gestor de ventanas..."
fluxbox &

echo "Iniciando servidor VNC..."
x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared &
X11VNC_PID=$!

echo "Esperando a que VNC esté listo..."
sleep 2

echo "Iniciando noVNC en el puerto 6080..."
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 &
NOVNC_PID=$!

echo "========================================="
echo "Servicios iniciados correctamente"
echo "========================================="
echo "noVNC disponible en: http://localhost:6080"
echo "VNC directo en: localhost:5900"
echo "========================================="
echo ""

echo "Iniciando aplicación sysbank..."
./sysbank

# Mantener el contenedor vivo si la aplicación termina
tail -f /dev/null