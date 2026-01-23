#!/bin/bash
set -e

export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime
mkdir -p $XDG_RUNTIME_DIR

# X virtual
Xvfb :1 -screen 0 1920x1080x24 -ac &
sleep 2

# LXQt (Qt-friendly)
dbus-run-session startlxqt &
sleep 2

# VNC sin cache (IMPORTANTE)
x11vnc \
  -display :1 \
  -nopw \
  -forever \
  -shared \
  -rfbport 5900 \
  -noncache \
  -noxdamage \
  -noscr &

# noVNC
websockify -D 6080 localhost:5900 --web /usr/share/novnc

tail -f /dev/null
