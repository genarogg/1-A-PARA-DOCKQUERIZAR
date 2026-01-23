@echo off
echo =========================================================
echo SOLUCION DE PROBLEMAS - SYSBANK MULTI-INSTANCIA
echo =========================================================
echo.

echo [PASO 1] Ejecutando diagnostico...
echo.
docker logs --tail 100 sysbank_multi
echo.

echo [PASO 2] Verificando si el contenedor esta corriendo...
docker ps | findstr sysbank_multi
if errorlevel 1 (
    echo ERROR: El contenedor no esta corriendo
    echo Intentando iniciar...
    docker-compose up -d
    timeout /t 10 /nobreak >nul
)

echo.
echo [PASO 3] Verificando permisos y archivos...
docker exec sysbank_multi ls -la /app/
docker exec sysbank_multi ls -la /app/instances/

echo.
echo [PASO 4] Verificando procesos internos...
docker exec sysbank_multi ps aux | findstr python

echo.
echo [PASO 5] Probando creacion manual de instancia...
docker exec sysbank_multi /app/start-instances.sh test_manual 99 5900 6080

echo.
echo =========================================================
echo POSIBLES SOLUCIONES:
echo =========================================================
echo.
echo Si ves errores de "Permission denied":
echo   ^> docker exec sysbank_multi chmod +x /app/start-instances.sh
echo   ^> docker exec sysbank_multi chmod +x /app/sysbank
echo.
echo Si ves "Python module not found":
echo   ^> Reconstruir imagen: docker-compose build --no-cache
echo.
echo Si ves "Port already in use":
echo   ^> docker-compose down
echo   ^> docker-compose up -d
echo.
echo Si ves "Display :99 already in use":
echo   ^> docker exec sysbank_multi pkill Xvfb
echo   ^> docker-compose restart
echo.
echo =========================================================
pause