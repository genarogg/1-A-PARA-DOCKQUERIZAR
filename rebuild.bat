@echo off
echo =========================================================
echo Reconstruyendo SysBank Multi-Instancia
echo =========================================================
echo.

echo [1/4] Deteniendo contenedores...
docker-compose down -v

echo.
echo [2/4] Limpiando imagenes antiguas...
docker rmi sysbank:lxde-optimized 2>nul

echo.
echo [3/4] Construyendo nueva imagen (puede tardar 5 minutos)...
docker-compose build --no-cache

if errorlevel 1 (
    echo.
    echo [ERROR] Fallo la construccion
    pause
    exit /b 1
)

echo.
echo [4/4] Iniciando contenedor...
docker-compose up -d

echo.
echo Esperando 15 segundos...
timeout /t 15 /nobreak >nul

echo.
echo =========================================================
echo Verificando logs...
echo =========================================================
docker logs sysbank_multi

echo.
echo =========================================================
echo Sistema listo en: http://localhost:8080
echo =========================================================
echo.
echo Comandos utiles:
echo   Ver logs:    docker logs -f sysbank_multi
echo   Reiniciar:   docker-compose restart
echo   Detener:     docker-compose down
echo.
pause