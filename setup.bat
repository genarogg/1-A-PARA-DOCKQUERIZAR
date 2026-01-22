@echo off
echo =========================================================
echo SysBank Multi-Instancia HD - Setup
echo =========================================================
echo.
echo Caracteristicas:
echo  - Full HD (1920x1080)
echo  - Hasta 50 instancias simultaneas
echo  - Graficos mejorados con XFCE4
echo  - Compositor para efectos visuales
echo.
echo =========================================================

if not exist "sysbank" (
    echo [ERROR] No se encuentra el archivo 'sysbank'
    pause
    exit /b 1
)
echo [OK] Ejecutable encontrado

echo.
echo Limpiando contenedores anteriores...
docker-compose down 2>nul
docker rm -f sysbank_multi 2>nul
docker rmi sysbank:qt4-multi-hd 2>nul

echo.
echo =========================================================
echo Construyendo imagen HD (puede tardar varios minutos)...
echo =========================================================
docker-compose build --no-cache

if errorlevel 1 (
    echo.
    echo [ERROR] Fallo la construccion
    pause
    exit /b 1
)

echo.
echo Iniciando sistema...
docker-compose up -d

echo.
echo Esperando inicio...
timeout /t 8 /nobreak >nul

echo.
echo =========================================================
echo            SISTEMA INICIADO CORRECTAMENTE
echo =========================================================
echo.
echo Accede en: http://localhost:8080
echo.
echo Mejoras graficas:
echo   - Resolucion Full HD (1920x1080)
echo   - Entorno XFCE4 completo
echo   - Efectos visuales suaves
echo   - Fuentes optimizadas
echo.
echo Comandos:
echo   Ver logs:    docker logs -f sysbank_multi
echo   Detener:     docker-compose down
echo   Reiniciar:   docker-compose restart
echo.
echo =========================================================
echo.
start http://localhost:8080
echo.
pause