#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gestor de instancias multi-sesion para SysBank - VERSIÓN MEJORADA
Mejor manejo de errores y diagnóstico
"""

from flask import Flask, render_template_string, jsonify, request, redirect
from flask_cors import CORS
import subprocess
import os
import sys
import time
import uuid
import signal
import json
import socket
from pathlib import Path

app = Flask(__name__)
CORS(app)

# Configuracion
BASE_DISPLAY = 99
BASE_VNC_PORT = 5900
BASE_NOVNC_PORT = 6080
MAX_INSTANCES = 50
INSTANCE_DIR = "/app/instances"
INSTANCE_TIMEOUT = 3600  # 1 hora de inactividad

# Almacenamiento de instancias activas
instances = {}

def log(message, level="INFO"):
    """Log con timestamp"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{level}] {message}", flush=True)

def check_dependencies():
    """Verifica que todas las dependencias estén instaladas"""
    required_cmds = ['xvfb-run', 'x11vnc', 'python3', 'openbox']
    missing = []
    
    for cmd in required_cmds:
        result = subprocess.run(['which', cmd], capture_output=True)
        if result.returncode != 0:
            missing.append(cmd)
    
    if missing:
        log(f"DEPENDENCIAS FALTANTES: {', '.join(missing)}", "ERROR")
        return False
    
    log("Todas las dependencias están instaladas", "OK")
    return True

def check_scripts():
    """Verifica que los scripts necesarios existan y sean ejecutables"""
    scripts = ['/app/start-instances.sh', '/app/sysbank']
    
    for script in scripts:
        if not os.path.exists(script):
            log(f"Script no encontrado: {script}", "ERROR")
            return False
        
        if not os.access(script, os.X_OK):
            log(f"Script sin permisos de ejecución: {script}", "WARN")
            try:
                os.chmod(script, 0o755)
                log(f"Permisos corregidos: {script}", "OK")
            except Exception as e:
                log(f"No se pudieron corregir permisos: {e}", "ERROR")
                return False
    
    log("Scripts verificados correctamente", "OK")
    return True

def check_port_open(host, port, timeout=1):
    """Verifica si un puerto está abierto"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

def get_next_available_ports():
    """Encuentra los siguientes puertos disponibles"""
    used_displays = [inst['display'] for inst in instances.values()]
    used_vnc_ports = [inst['vnc_port'] for inst in instances.values()]
    used_novnc_ports = [inst['novnc_port'] for inst in instances.values()]
    
    for i in range(MAX_INSTANCES):
        display = BASE_DISPLAY + i
        vnc_port = BASE_VNC_PORT + i
        novnc_port = BASE_NOVNC_PORT + i
        
        if display not in used_displays and vnc_port not in used_vnc_ports and novnc_port not in used_novnc_ports:
            # Verificar que el puerto no esté en uso por otro proceso
            if not check_port_open('localhost', vnc_port) and not check_port_open('localhost', novnc_port):
                return display, vnc_port, novnc_port
    
    log("No hay puertos disponibles", "ERROR")
    return None, None, None

def wait_for_port(port, timeout=30, check_interval=0.5):
    """Espera a que un puerto esté disponible"""
    start_time = time.time()
    attempts = 0
    while time.time() - start_time < timeout:
        attempts += 1
        if check_port_open('localhost', port):
            log(f"Puerto {port} disponible después de {attempts} intentos", "OK")
            return True
        time.sleep(check_interval)
    
    log(f"Timeout esperando puerto {port} después de {attempts} intentos", "ERROR")
    return False

def read_log_file(log_path, lines=10):
    """Lee las últimas líneas de un archivo de log"""
    try:
        if os.path.exists(log_path):
            with open(log_path, 'r') as f:
                all_lines = f.readlines()
                return ''.join(all_lines[-lines:])
        return "Log no encontrado"
    except Exception as e:
        return f"Error leyendo log: {e}"

def create_instance(session_id):
    """Crea una nueva instancia de SysBank con mejor manejo de errores"""
    if len(instances) >= MAX_INSTANCES:
        log(f"Límite de instancias alcanzado: {len(instances)}/{MAX_INSTANCES}", "ERROR")
        return None
    
    display, vnc_port, novnc_port = get_next_available_ports()
    if display is None:
        log("No hay puertos disponibles", "ERROR")
        return None
    
    instance_id = f"sysbank_{session_id}"
    instance_path = Path(INSTANCE_DIR) / instance_id
    
    log("="*60)
    log(f"Creando instancia: {instance_id}")
    log(f"   Display: :{display}")
    log(f"   VNC Port: {vnc_port}")
    log(f"   noVNC Port: {novnc_port}")
    log("="*60)
    
    try:
        # Crear directorio de la instancia
        instance_path.mkdir(parents=True, exist_ok=True)
        log(f"Directorio creado: {instance_path}", "OK")
        
        # Verificar que el script de inicio existe y es ejecutable
        if not os.path.exists('/app/start-instances.sh'):
            log("start-instances.sh no encontrado", "ERROR")
            return None
        
        if not os.access('/app/start-instances.sh', os.X_OK):
            log("start-instances.sh sin permisos de ejecución, corrigiendo...", "WARN")
            os.chmod('/app/start-instances.sh', 0o755)
        
        # Iniciar la instancia
        log(f"Ejecutando: /app/start-instances.sh {instance_id} {display} {vnc_port} {novnc_port}")
        
        process = subprocess.Popen([
            '/app/start-instances.sh',
            instance_id,
            str(display),
            str(vnc_port),
            str(novnc_port)
        ], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.STDOUT,  # Combinar stderr con stdout
        text=True,
        bufsize=1)
        
        # Registrar instancia inmediatamente
        instances[session_id] = {
            'id': instance_id,
            'display': display,
            'vnc_port': vnc_port,
            'novnc_port': novnc_port,
            'process': process,
            'created_at': time.time(),
            'last_access': time.time(),
            'status': 'starting'
        }
        
        log(f"Proceso iniciado (PID: {process.pid})", "OK")
        
        # Esperar a que noVNC esté disponible
        log(f"Esperando a que noVNC esté disponible en puerto {novnc_port}...")
        
        if wait_for_port(novnc_port, timeout=45):
            log(f"noVNC listo en puerto {novnc_port}", "OK")
            instances[session_id]['status'] = 'running'
            
            # Mostrar logs de inicio
            log("Logs de inicio:")
            log_files = ['xvfb.log', 'vnc.log', 'novnc.log', 'sysbank.log']
            for log_file in log_files:
                log_path = instance_path / log_file
                if log_path.exists():
                    log(f"\n--- {log_file} (últimas 5 líneas) ---")
                    content = read_log_file(log_path, lines=5)
                    for line in content.split('\n'):
                        if line.strip():
                            log(f"   {line}")
            
            return instances[session_id]
        else:
            log(f"Timeout esperando noVNC en puerto {novnc_port}", "ERROR")
            
            # Mostrar logs de error completos
            log("Logs de diagnóstico:")
            for log_file in ['xvfb.log', 'vnc.log', 'novnc.log', 'sysbank.log']:
                log_path = instance_path / log_file
                log(f"\n--- {log_file} (completo) ---")
                content = read_log_file(log_path, lines=50)
                for line in content.split('\n'):
                    if line.strip():
                        log(f"   {line}")
            
            # Leer output del proceso
            try:
                stdout, _ = process.communicate(timeout=2)
                if stdout:
                    log("\n--- Output del proceso ---")
                    log(stdout)
            except:
                pass
            
            # Limpiar instancia fallida
            instances[session_id]['status'] = 'error'
            stop_instance(session_id)
            return None
            
    except Exception as e:
        log(f"ERROR creando instancia: {e}", "ERROR")
        import traceback
        log(traceback.format_exc(), "ERROR")
        
        if session_id in instances:
            instances[session_id]['status'] = 'error'
            stop_instance(session_id)
        
        return None

def stop_instance(session_id):
    """Detiene una instancia específica"""
    if session_id not in instances:
        return False
    
    instance = instances[session_id]
    instance_path = Path(INSTANCE_DIR) / instance['id']
    
    log(f"Deteniendo instancia: {instance['id']}")
    
    try:
        # Leer PIDs y terminar procesos
        pid_files = ['app.pid', 'novnc.pid', 'vnc.pid', 'wm.pid', 'xvfb.pid']
        for pid_file in pid_files:
            pid_path = instance_path / pid_file
            if pid_path.exists():
                try:
                    with open(pid_path) as f:
                        pid = int(f.read().strip())
                    os.kill(pid, signal.SIGTERM)
                    log(f"   Proceso {pid_file} terminado (PID {pid})", "OK")
                except Exception as e:
                    log(f"   Error terminando {pid_file}: {e}", "WARN")
        
        # Terminar proceso principal
        if instance['process']:
            try:
                instance['process'].terminate()
                instance['process'].wait(timeout=5)
                log("   Proceso principal terminado", "OK")
            except subprocess.TimeoutExpired:
                instance['process'].kill()
                log("   Proceso principal forzado (kill)", "WARN")
        
        del instances[session_id]
        log(f"Instancia {instance['id']} detenida correctamente", "OK")
        return True
        
    except Exception as e:
        log(f"ERROR deteniendo instancia: {e}", "ERROR")
        return False

def cleanup_inactive_instances():
    """Limpia instancias inactivas"""
    current_time = time.time()
    to_remove = []
    
    for session_id, instance in instances.items():
        inactive_time = current_time - instance['last_access']
        if inactive_time > INSTANCE_TIMEOUT:
            to_remove.append(session_id)
    
    for session_id in to_remove:
        log(f"Limpiando instancia inactiva: {session_id}")
        stop_instance(session_id)

# HTML Template (igual que antes, omitido por brevedad)
HTML_TEMPLATE = """[... mismo HTML ...]"""

@app.route('/')
def index():
    """Página principal"""
    session_id = str(uuid.uuid4())
    cleanup_inactive_instances()
    instance = create_instance(session_id)
    
    if instance is None:
        error_msg = """
        <html>
        <head><title>Error - SysBank</title></head>
        <body style="font-family: Arial; padding: 40px; background: #f5f5f5;">
            <div style="max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <h1 style="color: #d32f2f;">❌ Error al crear instancia</h1>
                <p>No se pueden crear más instancias en este momento.</p>
                <h3>Pasos para diagnosticar:</h3>
                <ol>
                    <li>Verifica los logs: <code>docker logs -f sysbank_multi</code></li>
                    <li>Verifica instancias activas: <a href="/api/stats">/api/stats</a></li>
                    <li>Verifica procesos: <code>docker exec sysbank_multi ps aux</code></li>
                </ol>
                <h3>Posibles soluciones:</h3>
                <ul>
                    <li>Reinicia el contenedor: <code>docker-compose restart</code></li>
                    <li>Reconstruye la imagen: <code>docker-compose build --no-cache</code></li>
                    <li>Verifica recursos: <code>docker stats sysbank_multi</code></li>
                </ul>
                <p><a href="/" style="color: #1976d2;">Reintentar</a></p>
            </div>
        </body>
        </html>
        """
        return error_msg, 503
    
    # Usar el HTML_TEMPLATE original aquí
    return "<html><body><h1>Instancia creada correctamente</h1><p>Puerto noVNC: {}</p></body></html>".format(instance['novnc_port'])

@app.route('/api/stats')
def stats():
    return jsonify({
        'active_instances': len(instances),
        'max_instances': MAX_INSTANCES,
        'uptime': time.time(),
        'instances_detail': [{
            'session_id': sid[:8],
            'status': inst['status'],
            'ports': {'vnc': inst['vnc_port'], 'novnc': inst['novnc_port']}
        } for sid, inst in instances.items()]
    })

@app.route('/api/instance/<session_id>')
def get_instance(session_id):
    if session_id in instances:
        instance = instances[session_id]
        instance['last_access'] = time.time()
        return jsonify({
            'status': instance['status'],
            'novnc_port': instance['novnc_port'],
            'vnc_port': instance['vnc_port'],
            'created_at': instance['created_at']
        })
    return jsonify({'status': 'not_found'}), 404

@app.route('/api/instance/<session_id>/heartbeat', methods=['POST'])
def heartbeat(session_id):
    if session_id in instances:
        instances[session_id]['last_access'] = time.time()
        return jsonify({'status': 'ok'})
    return jsonify({'status': 'not_found'}), 404

@app.route('/api/instance/<session_id>', methods=['DELETE'])
def delete_instance(session_id):
    if stop_instance(session_id):
        return jsonify({'status': 'deleted'})
    return jsonify({'status': 'error'}), 500

@app.route('/api/instances')
def list_instances():
    return jsonify({
        'instances': [{
            'id': session_id,
            'status': inst['status'],
            'created_at': inst['created_at'],
            'last_access': inst['last_access'],
            'novnc_port': inst['novnc_port']
        } for session_id, inst in instances.items()]
    })

@app.route('/health')
def health():
    """Endpoint de salud"""
    return jsonify({
        'status': 'healthy',
        'instances': len(instances),
        'dependencies': check_dependencies(),
        'scripts': check_scripts()
    })

if __name__ == '__main__':
    log("="*60)
    log("INICIANDO SYSBANK MULTI-INSTANCIA HD")
    log("="*60)
    
    # Verificaciones iniciales
    if not check_dependencies():
        log("FALLO: Dependencias faltantes", "ERROR")
        sys.exit(1)
    
    if not check_scripts():
        log("FALLO: Problemas con scripts", "ERROR")
        sys.exit(1)
    
    # Limpiar directorio de instancias
    if os.path.exists(INSTANCE_DIR):
        import shutil
        for item in os.listdir(INSTANCE_DIR):
            item_path = os.path.join(INSTANCE_DIR, item)
            try:
                if os.path.isfile(item_path):
                    os.unlink(item_path)
                elif os.path.isdir(item_path):
                    shutil.rmtree(item_path)
            except Exception as e:
                log(f"Error limpiando {item_path}: {e}", "WARN")
    
    os.makedirs(INSTANCE_DIR, exist_ok=True)
    
    log("Accede en: http://localhost:8080")
    log(f"Resolución: 1920x1080 (Full HD)")
    log(f"Máximo de instancias: {MAX_INSTANCES}")
    log("="*60)
    
    app.run(host='0.0.0.0', port=8080, debug=True, threaded=True, use_reloader=False)