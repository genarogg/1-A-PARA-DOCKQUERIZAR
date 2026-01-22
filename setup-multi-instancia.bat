@echo off
echo =========================================================
echo SysBank Multi-Instancia - Configuracion Automatica
echo =========================================================
echo.
echo Este sistema permite:
echo  - Multiples usuarios simultaneos
echo  - Cada navegador = instancia independiente
echo  - Aceleracion grafica optimizada
echo  - Hasta 50 instancias concurrentes
echo.
echo =========================================================
echo.

REM Verificar ejecutable
if not exist "sysbank" (
    echo [ERROR] No se encuentra el archivo 'sysbank'
    pause
    exit /b 1
)
echo [OK] Ejecutable encontrado

REM Crear archivos necesarios
echo.
echo Creando archivos de configuracion...

REM start-instance.sh
echo Creando start-instance.sh...
(
echo #!/bin/bash
echo set -e
echo.
echo INSTANCE_ID=$1
echo DISPLAY_NUM=$2
echo VNC_PORT=$3
echo NOVNC_PORT=$4
echo.
echo if [ -z "$INSTANCE_ID" ] ^|^| [ -z "$DISPLAY_NUM" ] ^|^| [ -z "$VNC_PORT" ] ^|^| [ -z "$NOVNC_PORT" ]; then
echo     echo "Error: Faltan parametros"
echo     exit 1
echo fi
echo.
echo export DISPLAY=:$DISPLAY_NUM
echo INSTANCE_DIR="/app/instances/$INSTANCE_ID"
echo.
echo echo "========================================="
echo echo "Iniciando instancia: $INSTANCE_ID"
echo echo "========================================="
echo.
echo mkdir -p "$INSTANCE_DIR"
echo cd "$INSTANCE_DIR"
echo.
echo echo "[1/5] Iniciando servidor X..."
echo Xvfb $DISPLAY -screen 0 ${RESOLUTION} -ac +extension GLX +render -noreset -dpi 96 ^> "$INSTANCE_DIR/xvfb.log" 2^>^&1 ^&
echo XVFB_PID=$!
echo echo $XVFB_PID ^> "$INSTANCE_DIR/xvfb.pid"
echo.
echo for i in {1..10}; do
echo     if xdpyinfo -display $DISPLAY ^>^/dev^/null 2^>^&1; then
echo         echo "OK - Servidor X listo"
echo         break
echo     fi
echo     sleep 1
echo done
echo.
echo echo "[2/5] Iniciando gestor de ventanas..."
echo openbox --config-file /dev/null ^> "$INSTANCE_DIR/openbox.log" 2^>^&1 ^&
echo OPENBOX_PID=$!
echo echo $OPENBOX_PID ^> "$INSTANCE_DIR/openbox.pid"
echo sleep 1
echo.
echo echo "[3/5] Iniciando servidor VNC optimizado..."
echo x11vnc -display $DISPLAY -rfbport $VNC_PORT -nopw -listen 0.0.0.0 -xkb -forever -shared -threads -progressive 32 -compresslevel 9 -quality 7 -deferupdate 10 ^> "$INSTANCE_DIR/vnc.log" 2^>^&1 ^&
echo VNC_PID=$!
echo echo $VNC_PID ^> "$INSTANCE_DIR/vnc.pid"
echo.
echo for i in {1..10}; do
echo     if netstat -ln ^| grep -q ":$VNC_PORT "; then
echo         echo "OK - Servidor VNC listo"
echo         break
echo     fi
echo     sleep 1
echo done
echo.
echo echo "[4/5] Iniciando noVNC..."
echo /opt/novnc/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT ^> "$INSTANCE_DIR/novnc.log" 2^>^&1 ^&
echo NOVNC_PID=$!
echo echo $NOVNC_PID ^> "$INSTANCE_DIR/novnc.pid"
echo sleep 2
echo.
echo echo "[5/5] Iniciando aplicacion sysbank..."
echo /app/sysbank ^> "$INSTANCE_DIR/sysbank.log" 2^>^&1 ^&
echo APP_PID=$!
echo echo $APP_PID ^> "$INSTANCE_DIR/app.pid"
echo.
echo echo "========================================="
echo echo "Instancia iniciada correctamente"
echo echo "========================================="
echo.
echo tail -f /dev/null
) > start-instance.sh

echo [OK] start-instance.sh creado

REM Limpiar contenedores anteriores
echo.
echo Limpiando contenedores anteriores...
docker-compose -f docker-compose-multi.yml down 2>nul
docker rm -f sysbank_multi 2>nul

REM Construir imagen
echo.
echo =========================================================
echo Construyendo imagen (esto puede tomar varios minutos)...
echo =========================================================
docker-compose -f docker-compose-multi.yml build --no-cache

REM Iniciar servicios
echo.
echo Iniciando sistema multi-instancia...
docker-compose -f docker-compose-multi.yml up -d

REM Esperar inicio
echo.
echo Esperando a que el sistema este listo...
timeout /t 8 /nobreak >nul

REM Mostrar resultado
echo.
echo =========================================================
echo            SISTEMA INICIADO CORRECTAMENTE
echo =========================================================
echo.
echo Accede al sistema:
echo   http://localhost:8080
echo.
echo Caracteristicas:
echo   - Cada navegador/pestana = instancia independiente
echo   - Hasta 50 usuarios simultaneos
echo   - Graficos optimizados con aceleracion
echo   - Sesiones aisladas (datos no compartidos^)
echo.
echo Comandos utiles:
echo   Ver logs:           docker logs -f sysbank_multi
echo   Ver estadisticas:   docker stats sysbank_multi
echo   Detener:            docker-compose -f docker-compose-multi.yml down
echo   Reiniciar:          docker-compose -f docker-compose-multi.yml restart
echo.
echo =========================================================
echo.
echo Abriendo en el navegador...
start http://localhost:8080
echo.
echo Presiona cualquier tecla para ver los logs...
pause >nul
docker logs -f sysbank_multi