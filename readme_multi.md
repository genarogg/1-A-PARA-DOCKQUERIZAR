# SysBank Multi-Instancia HD

Sistema dockerizado de SysBank con **gráficos mejorados** y soporte para múltiples usuarios simultáneos.

## Características Premium

- **Full HD**: Resolución 1920x1080 nativa
- **XFCE4**: Entorno de escritorio completo (si está disponible)
- **Compositor**: Efectos visuales suaves con Picom/Compton
- **TigerVNC**: Servidor VNC de alta calidad (fallback a x11vnc)
- **Mesa optimizado**: Aceleración gráfica software con LLVM pipe
- **Fuentes mejoradas**: Antialiasing y subpixel rendering
- **Multi-usuario**: Hasta 50 instancias simultáneas e independientes

## Requisitos

- Docker Desktop
- 8GB RAM mínimo (16GB recomendado)
- 4 cores CPU mínimo
- Windows 10/11 o Linux

## Instalación

### Windows

```batch
setup.bat
```

### Linux

```bash
chmod +x setup.sh
./setup.sh
```

### Manual

```bash
docker-compose build --no-cache
docker-compose up -d
```

## Uso

1. Accede a **http://localhost:8080**
2. Cada navegador/pestaña obtiene automáticamente su propia instancia HD
3. Las instancias son completamente independientes

## Personalización

### Cambiar resolución

Edita `docker-compose.yaml`:

```yaml
environment:
  - RESOLUTION=2560x1440x24 # 2K
  # o
  - RESOLUTION=3840x2160x24 # 4K (requiere más recursos)
```

### Ajustar recursos

```yaml
mem_limit: 16g # Más memoria
cpus: 8 # Más CPUs
```

### Cambiar timeout

Edita `instance-manager.py`:

```python
INSTANCE_TIMEOUT = 7200  # 2 horas
```

## API REST

### Ver estadísticas

```
GET http://localhost:8080/api/stats
```

### Listar instancias

```
GET http://localhost:8080/api/instances
```

### Info de instancia

```
GET http://localhost:8080/api/instance/{session_id}
```

### Eliminar instancia

```
DELETE http://localhost:8080/api/instance/{session_id}
```

## Troubleshooting

### Ver logs

```bash
docker logs -f sysbank_multi
```

### Ver logs de una instancia específica

```bash
docker exec -it sysbank_multi ls /app/instances/
docker exec -it sysbank_multi cat /app/instances/sysbank_XXX/sysbank.log
```

### Reiniciar

```bash
docker-compose restart
```

### Limpiar todo

```bash
docker-compose down
docker system prune -a -f
```

## Arquitectura

```
Usuario 1 → http://localhost:8080 → Puerto 6080 → Instancia A (Full HD)
Usuario 2 → http://localhost:8080 → Puerto 6081 → Instancia B (Full HD)
                                ↓
                    Instance Manager (Flask)
                                ↓
        ┌───────────┬───────────┬───────────┐
        ↓           ↓           ↓           ↓
    Display:99  Display:100  Display:101  ...
    XFCE4       XFCE4        XFCE4
    Picom       Picom        Picom
    TigerVNC    TigerVNC     TigerVNC
    noVNC       noVNC        noVNC
    SysBank     SysBank      SysBank
```

## Optimizaciones Aplicadas

### Gráficos

- ✅ Mesa LLVM pipe con 4 threads
- ✅ OpenGL 3.3 emulado
- ✅ Renderizado optimizado con extensiones GLX, RANDR, RENDER
- ✅ Compositor para transiciones suaves
- ✅ Fuentes con antialiasing y hinting

### Rendimiento

- ✅ 4GB shared memory
- ✅ 8GB RAM límite
- ✅ 4 CPU cores
- ✅ VSync desactivado para mejor FPS

### Experiencia

- ✅ Escritorio completo XFCE4
- ✅ Menú de aplicaciones
- ✅ Barra de tareas
- ✅ Efectos de sombra y fade

## Comparación con XLaunch

| Característica | XLaunch  | SysBank Multi-HD  |
| -------------- | -------- | ----------------- |
| Resolución     | Variable | Full HD fija      |
| Multi-usuario  | ❌       | ✅ 50 simultáneos |
| Compositor     | ❌       | ✅ Picom          |
| Escritorio     | Básico   | ✅ XFCE4          |
| Web Access     | ❌       | ✅ noVNC          |
| Auto-gestión   | ❌       | ✅ Automático     |

## Archivos del Proyecto

```
.
├── Dockerfile              # Imagen optimizada
├── docker-compose.yaml     # Configuración de servicios
├── instance-manager.py     # Gestor de instancias (Python)
├── start-instances.sh       # Script de inicio (Bash)
├── setup.bat              # Instalador Windows
├── sysbank                # Ejecutable (tu aplicación)
└── README.md              # Esta documentación
```

## Licencia

MIT

## Soporte

Para problemas:

1. Revisa los logs: `docker logs -f sysbank_multi`
2. Verifica recursos: `docker stats sysbank_multi`
3. Prueba reiniciar: `docker-compose restart`

---

**Versión**: 3.0.0 HD  
**Fecha**: 2026-01-22
