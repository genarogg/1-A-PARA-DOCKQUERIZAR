#!/bin/bash

echo "=========================================="
echo "DIAGNÓSTICO SYSBANK MULTI-INSTANCIA"
echo "=========================================="
echo ""

echo "[1] Estado del contenedor:"
docker ps -a | grep sysbank_multi
echo ""

echo "[2] Logs recientes del contenedor:"
docker logs --tail 50 sysbank_multi
echo ""

echo "[3] Recursos del contenedor:"
docker stats sysbank_multi --no-stream
echo ""

echo "[4] Procesos dentro del contenedor:"
docker exec sysbank_multi ps aux
echo ""

echo "[5] Verificar directorio de instancias:"
docker exec sysbank_multi ls -la /app/instances/
echo ""

echo "[6] Verificar puertos en uso:"
docker exec sysbank_multi netstat -tulpn | grep -E "590[0-9]|608[0-9]"
echo ""

echo "[7] Verificar dependencias instaladas:"
docker exec sysbank_multi which xvfb-run x11vnc python3
echo ""

echo "[8] Verificar script de inicio:"
docker exec sysbank_multi test -x /app/start-instances.sh && echo "start-instances.sh es ejecutable" || echo "ERROR: start-instances.sh no es ejecutable"
echo ""

echo "[9] Verificar ejecutable sysbank:"
docker exec sysbank_multi test -x /app/sysbank && echo "sysbank es ejecutable" || echo "ERROR: sysbank no es ejecutable"
docker exec sysbank_multi file /app/sysbank
echo ""

echo "[10] Variables de entorno:"
docker exec sysbank_multi env | grep -E "DISPLAY|RESOLUTION|QT_|MESA|GALLIUM"
echo ""

echo "=========================================="
echo "DIAGNÓSTICO COMPLETADO"
echo "=========================================="