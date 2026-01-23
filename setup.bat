@echo off
echo =========================================================
echo SysBank Multi-Instancia LXDE - Setup Optimizado
echo =========================================================
echo.
echo Caracteristicas:
echo  - Full HD (1920x1080)
echo  - Desktop LXDE ligero y rapido
echo  - x11vnc ultra compatible
echo  - Hasta 50 instancias simultaneas
echo  - Optimizado para minimo lag
echo.
echo =========================================================

if not exist "sysbank" (
    echo [ERROR] No se encuentra el archivo 'sysbank'
    echo Coloca el ejecutable 'sysbank' en este directorio
    pause
    exit /b 1
)
echo [OK] Ejecutable encontrado

if not exist "instance-manager.py" (
    echo [ERROR] No se encuentra 'instance-manager.py'
    pause
    exit /b 1
)
echo [OK] Instance manager encontrado

echo.
echo Limpiando contenedores y volumenes antiguos...
docker-compose down -v 2>nul
docker rm -f sysbank_multi 2>nul
docker rmi sysbank:lxde-optimized 2>nul

echo.
echo =========================================================
echo Construyendo imagen optimizada...
echo Esto puede tardar 3-5 minutos la primera vez
echo =========================================================
docker-compose build --no-cache

if errorlevel 1 (
    echo.
    echo [ERROR] Fallo la construccion de la imagen
    echo Verifica que Docker Desktop este ejecutandose
    pause
    exit /b 1
)

echo.
echo Iniciando sistema...
docker-compose up -d

if errorlevel 1 (
    echo.
    echo [ERROR] Fallo al iniciar el contenedor
    pause
    exit /b 1
)

echo.
echo Esperando que el sistema este listo...
timeout /t 10 /nobreak >nul

echo.
echo =========================================================
echo            SISTEMA INICIADO CORRECTAMENTE
echo =========================================================
echo.
echo Acceso web: http://localhost:8080
echo.
echo Caracteristicas:
echo   - Desktop LXDE completo
echo   - Barra de tareas
echo   - Menu de aplicaciones
echo   - Gestor de archivos
echo   - Terminal
echo.
echo Comandos utiles:
echo   Ver logs:           docker logs -f sysbank_multi
echo   Detener:            docker-compose down
echo   Reiniciar:          docker-compose restart
echo   Ver instancias:     docker exec sysbank_multi ls /app/instances
echo.
echo Para mejor rendimiento, usa un cliente VNC nativo:
echo   Windows: TightVNC / RealVNC
echo   Conectar a: localhost:5900
echo.
echo =========================================================
echo.

REM Abrir navegador
start http://localhost:8080

echo Presiona cualquier tecla para ver los logs en tiempo real...
pause >nul
docker logs -f sysbank_multi