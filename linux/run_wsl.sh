#!/bin/bash
# Script para correr SysBank desde WSL

# Configurar DISPLAY correctamente para WSL2
export DISPLAY=$(grep nameserver /etc/resolv.conf | awk '{print $2}'):0
export LIBGL_ALWAYS_INDIRECT=1

# Permitir que Docker use X server
xhost +local:docker

# Construir imagen si no existe
docker build -t sysbank:qt4 .

# Ejecutar contenedor Qt4
docker run -it -e DISPLAY=$DISPLAY -e QT_X11_NO_MITSHM=1 -v /tmp/.X11-unix:/tmp/.X11-unix sysbank:qt4
