# 🏦 SysBank Multi-Instancia

Sistema dockerizado de SysBank con soporte para múltiples usuarios simultáneos, cada uno con su propia instancia independiente.

## 🚀 Características

- **Multi-Usuario**: Hasta 50 instancias simultáneas
- **Aislamiento Total**: Cada navegador obtiene su propia instancia
- **Alta Performance**: Optimizado con aceleración gráfica OpenGL
- **Auto-Gestión**: Las instancias se limpian automáticamente después de 1 hora de inactividad
- **Interfaz Web**: Acceso completo desde el navegador sin instalación

## 📋 Requisitos

- Docker Desktop
- 8GB RAM mínimo (recomendado 16GB para múltiples instancias)
- 4 cores CPU mínimo

## 🛠️ Instalación

### Windows

```batch
setup-multi-instancia.bat
```

### Linux

```bash
chmod +x setup-multi-instancia.sh
./setup-multi-instancia.sh
```

## 🎯 Uso

1. **Accede al sistema**: http://localhost:8080
2. **Cada navegador/pestaña obtiene automáticamente su propia instancia**
3. **Las instancias son completamente independientes** - las acciones en una no afectan a las otras

## 🔧 Arquitectura

```
┌─────────────────────────────────────────┐
│   Navegador 1 (Instancia A)             │
│   http://localhost:8080                 │
│   ↓ puerto 6080                         │
└─────────────────────────────────────────┘
                  │
┌─────────────────────────────────────────┐
│   Navegador 2 (Instancia B)             │
│   http://localhost:8080                 │
│   ↓ puerto 6081                         │
└─────────────────────────────────────────┘
                  │
        ┌─────────▼─────────┐
        │  Instance Manager │
        │   (Flask API)     │
        └─────────┬─────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
┌────────┐  ┌────────┐    ┌────────┐
│ Xvfb:99│  │Xvfb:100│    │Xvfb:101│
│ VNC    │  │ VNC    │... │ VNC    │
│ noVNC  │  │ noVNC  │    │ noVNC  │
│SysBank │  │SysBank │    │SysBank │
└────────┘  └────────┘    └────────┘
```

## 📊 Optimizaciones de Rendimiento

### Gráficas
- **Aceleración OpenGL**: Mesa llvmpipe para renderizado software optimizado
- **Resolución**: 1920x1080 por defecto
- **Compresión VNC**: Nivel 9 con calidad 7
- **Progressive Updates**: Mejora la respuesta en conexiones lentas

### Recursos
- **Memoria compartida**: 4GB para el contenedor
- **Límite de memoria**: 8GB máximo
- **CPU**: 4 cores asignados
- **Timeout**: 1 hora de inactividad antes de limpiar

## 🔌 API REST

El sistema expone una API REST para gestión:

### Estadísticas
```bash
GET /api/stats
```
Respuesta:
```json
{
  "active_instances": 5,
  "max_instances": 50,
  "uptime": 3600.5
}
```

### Información de instancia
```bash
GET /api/instance/{session_id}
```

### Listar todas las instancias
```bash
GET /api/instances
```

### Eliminar instancia
```bash
DELETE /api/instance/{session_id}
```

## 🎨 Personalización

### Cambiar resolución
Edita `docker-compose-multi.yml`:
```yaml
environment:
  - RESOLUTION=1280x720x24  # Cambiar aquí
```

### Cambiar número máximo de instancias
Edita `instance-manager.py`:
```python
MAX_INSTANCES = 100  # Cambiar aquí
```

### Cambiar timeout de inactividad
Edita `instance-manager.py`:
```python
INSTANCE_TIMEOUT = 7200  # 2 horas en segundos
```

## 🐛 Troubleshooting

### Las instancias no inician
```bash
# Ver logs del gestor
docker logs -f sysbank_multi

# Ver logs de una instancia específica
docker exec -it sysbank_multi ls -la /app/instances/
docker exec -it sysbank_multi cat /app/instances/sysbank_XXX/sysbank.log
```

### Problemas de rendimiento
```bash
# Ver uso de recursos
docker stats sysbank_multi

# Si necesitas más recursos, edita docker-compose-multi.yml:
mem_limit: 16g  # Aumentar memoria
cpus: 8         # Aumentar CPUs
```

### Puerto ya en uso
```bash
# Detener todo
docker-compose -f docker-compose-multi.yml down

# Verificar puertos
netstat -ano | findstr "8080"
netstat -ano | findstr "6080"
```

## 📈 Monitoreo

### Ver instancias activas
Accede a: http://localhost:8080/api/instances

### Ver estadísticas en tiempo real
```bash
# Recursos del contenedor
docker stats sysbank_multi

# Logs en vivo
docker logs -f sysbank_multi
```

## 🔒 Seguridad

### Añadir autenticación básica

Edita `instance-manager.py` para añadir:
```python
from flask_httpauth import HTTPBasicAuth

auth = HTTPBasicAuth()

@auth.verify_password
def verify_password(username, password):
    if username == "admin" and password == "tu_password":
        return username
    return None

@app.route('/')
@auth.login_required
def index():
    # ...
```

### Usar HTTPS

Configura un proxy reverso (Nginx/Traefik) o usa certificados SSL:
```bash
# Con certbot
certbot certonly --standalone -d tu-dominio.com
```

## 🤝 Contribuir

Para mejorar el sistema:
1. Fork el repositorio
2. Crea una rama (`git checkout -b feature/mejora`)
3. Commit cambios (`git commit -am 'Añadir mejora'`)
4. Push a la rama (`git push origin feature/mejora`)
5. Crea un Pull Request

## 📝 Licencia

Este proyecto está bajo licencia MIT.

## 🆘 Soporte

Para problemas o preguntas:
- Abre un issue en GitHub
- Revisa los logs: `docker logs -f sysbank_multi`
- Consulta la documentación de Docker

---

**Versión**: 2.0.0  
**Última actualización**: 2026-01-22