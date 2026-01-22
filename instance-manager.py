#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gestor de instancias multi-sesion para SysBank
Cada navegador obtiene su propia instancia aislada
"""

from flask import Flask, render_template_string, jsonify, request, redirect
from flask_cors import CORS
import subprocess
import os
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

def check_port_open(host, port, timeout=1):
    """Verifica si un puerto esta abierto"""
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
            return display, vnc_port, novnc_port
    
    return None, None, None

def wait_for_port(port, timeout=30, check_interval=0.5):
    """Espera a que un puerto este disponible"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        if check_port_open('localhost', port):
            return True
        time.sleep(check_interval)
    return False

def create_instance(session_id):
    """Crea una nueva instancia de SysBank"""
    if len(instances) >= MAX_INSTANCES:
        print("ERROR: Limite de instancias alcanzado: {}/{}".format(len(instances), MAX_INSTANCES))
        return None
    
    display, vnc_port, novnc_port = get_next_available_ports()
    if display is None:
        print("ERROR: No hay puertos disponibles")
        return None
    
    instance_id = "sysbank_{}".format(session_id)
    instance_path = Path(INSTANCE_DIR) / instance_id
    
    print("\n" + "="*60)
    print("Creando instancia: {}".format(instance_id))
    print("   Display: :{}".format(display))
    print("   VNC Port: {}".format(vnc_port))
    print("   noVNC Port: {}".format(novnc_port))
    print("="*60)
    
    try:
        # Crear directorio de la instancia
        instance_path.mkdir(parents=True, exist_ok=True)
        
        # Iniciar la instancia
        process = subprocess.Popen([
            '/app/start-instance.sh',
            instance_id,
            str(display),
            str(vnc_port),
            str(novnc_port)
        ], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE,
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
        
        # Esperar a que noVNC este disponible
        print("Esperando a que noVNC este disponible en puerto {}...".format(novnc_port))
        if wait_for_port(novnc_port, timeout=30):
            print("OK: noVNC listo en puerto {}".format(novnc_port))
            instances[session_id]['status'] = 'running'
            
            # Mostrar logs de inicio
            log_files = ['xvfb.log', 'vnc.log', 'novnc.log', 'sysbank.log']
            for log_file in log_files:
                log_path = instance_path / log_file
                if log_path.exists():
                    print("\nLOG {}:".format(log_file))
                    with open(log_path) as f:
                        lines = f.readlines()
                        for line in lines[-5:]:  # Ultimas 5 lineas
                            print("   {}".format(line.rstrip()))
            
            return instances[session_id]
        else:
            print("ERROR: Timeout esperando noVNC en puerto {}".format(novnc_port))
            
            # Mostrar logs de error
            print("\nLogs de diagnostico:")
            for log_file in ['xvfb.log', 'vnc.log', 'novnc.log']:
                log_path = instance_path / log_file
                if log_path.exists():
                    print("\n--- {} ---".format(log_file))
                    with open(log_path) as f:
                        print(f.read())
            
            # Limpiar instancia fallida
            instances[session_id]['status'] = 'error'
            stop_instance(session_id)
            return None
            
    except Exception as e:
        print("ERROR creando instancia: {}".format(e))
        import traceback
        traceback.print_exc()
        
        if session_id in instances:
            instances[session_id]['status'] = 'error'
            stop_instance(session_id)
        
        return None

def stop_instance(session_id):
    """Detiene una instancia especifica"""
    if session_id not in instances:
        return False
    
    instance = instances[session_id]
    instance_path = Path(INSTANCE_DIR) / instance['id']
    
    print("\nDeteniendo instancia: {}".format(instance['id']))
    
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
                    print("   OK: Terminado proceso {}: PID {}".format(pid_file, pid))
                except Exception as e:
                    print("   WARN: Error terminando {}: {}".format(pid_file, e))
        
        # Terminar proceso principal
        if instance['process']:
            try:
                instance['process'].terminate()
                instance['process'].wait(timeout=5)
                print("   OK: Proceso principal terminado")
            except subprocess.TimeoutExpired:
                instance['process'].kill()
                print("   WARN: Proceso principal forzado (kill)")
        
        del instances[session_id]
        print("OK: Instancia {} detenida correctamente".format(instance['id']))
        return True
        
    except Exception as e:
        print("ERROR deteniendo instancia: {}".format(e))
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
        print("Limpiando instancia inactiva: {}".format(session_id))
        stop_instance(session_id)

# HTML de la interfaz principal
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SysBank - Sistema Multi-Instancia</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        header {
            text-align: center;
            margin-bottom: 30px;
        }
        
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 10px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.2);
        }
        
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            font-size: 0.9em;
            opacity: 0.8;
        }
        
        .vnc-container {
            background: white;
            border-radius: 15px;
            padding: 0;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .vnc-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .session-info {
            font-size: 0.9em;
        }
        
        .status-badge {
            display: inline-block;
            padding: 5px 15px;
            background: #4CAF50;
            border-radius: 20px;
            font-size: 0.85em;
        }
        
        .loading {
            text-align: center;
            padding: 100px 20px;
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        
        .spinner {
            width: 60px;
            height: 60px;
            border: 5px solid rgba(255,255,255,0.3);
            border-top-color: white;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        iframe {
            width: 100%;
            height: calc(100vh - 300px);
            min-height: 600px;
            border: none;
            display: block;
        }
        
        .controls {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 10px;
            padding: 15px;
            margin-top: 20px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        button {
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1em;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        
        .btn-primary {
            background: #4CAF50;
            color: white;
        }
        
        .btn-danger {
            background: #f44336;
            color: white;
        }
        
        .btn-info {
            background: #2196F3;
            color: white;
        }
        
        .error {
            background: rgba(244, 67, 54, 0.2);
            border: 1px solid #f44336;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
        }
        
        .loading-detail {
            font-size: 0.9em;
            opacity: 0.8;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>SysBank Multi-Instancia HD</h1>
            <p class="subtitle">Experiencia grafica mejorada - Cada sesion es independiente</p>
        </header>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value" id="active-instances">-</div>
                <div class="stat-label">Instancias Activas</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="max-instances">{{ max_instances }}</div>
                <div class="stat-label">Maximo Permitido</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="session-time">0:00</div>
                <div class="stat-label">Tiempo de Sesion</div>
            </div>
        </div>
        
        <div id="content">
            <div class="loading">
                <div class="spinner"></div>
                <h2>Iniciando tu instancia HD de SysBank...</h2>
                <p>Esto puede tomar unos segundos</p>
                <p class="loading-detail" id="loading-status">Preparando entorno grafico...</p>
            </div>
        </div>
    </div>
    
    <script>
        var sessionId = '{{ session_id }}';
        var sessionStartTime = Date.now();
        var statusCheckInterval;
        var checkAttempts = 0;
        var maxAttempts = 30;
        
        function updateSessionTime() {
            var elapsed = Math.floor((Date.now() - sessionStartTime) / 1000);
            var minutes = Math.floor(elapsed / 60);
            var seconds = elapsed % 60;
            document.getElementById('session-time').textContent = 
                minutes + ':' + (seconds < 10 ? '0' : '') + seconds;
        }
        
        function updateStats() {
            fetch('/api/stats')
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    document.getElementById('active-instances').textContent = data.active_instances;
                })
                .catch(function(err) { console.error('Error updating stats:', err); });
        }
        
        function updateLoadingStatus(message) {
            var statusEl = document.getElementById('loading-status');
            if (statusEl) {
                statusEl.textContent = message;
            }
        }
        
        function checkInstanceStatus() {
            checkAttempts++;
            updateLoadingStatus('Verificando estado... (intento ' + checkAttempts + '/' + maxAttempts + ')');
            
            fetch('/api/instance/' + sessionId)
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    console.log('Instance status:', data);
                    
                    if (data.status === 'running') {
                        clearInterval(statusCheckInterval);
                        updateLoadingStatus('Instancia lista! Cargando interfaz HD...');
                        setTimeout(function() { loadVNC(data.novnc_port); }, 500);
                    } else if (data.status === 'error') {
                        clearInterval(statusCheckInterval);
                        showError('Error al iniciar la instancia. Verifica los logs: docker logs -f sysbank_multi');
                    } else if (data.status === 'starting') {
                        if (checkAttempts >= maxAttempts) {
                            clearInterval(statusCheckInterval);
                            showError('Timeout: La instancia no inicio despues de ' + (maxAttempts * 2) + ' segundos.');
                        }
                    }
                })
                .catch(function(err) {
                    console.error('Error checking status:', err);
                    if (checkAttempts >= maxAttempts) {
                        clearInterval(statusCheckInterval);
                        showError('No se puede conectar con el servidor. Error: ' + err.message);
                    }
                });
        }
        
        function loadVNC(port) {
            var content = document.getElementById('content');
            content.innerHTML = '<div class="vnc-container">' +
                '<div class="vnc-header">' +
                    '<div class="session-info">' +
                        '<strong>Sesion HD:</strong> ' + sessionId.substring(0, 8) + ' | ' +
                        '<strong>Puerto:</strong> ' + port + ' | ' +
                        '<strong>Resolucion:</strong> 1920x1080' +
                    '</div>' +
                    '<div>' +
                        '<span class="status-badge">Activa</span>' +
                    '</div>' +
                '</div>' +
                '<iframe src="http://' + window.location.hostname + ':' + port + '/vnc.html?autoconnect=true&reconnect=true&resize=scale"></iframe>' +
                '</div>' +
                '<div class="controls">' +
                    '<button class="btn-info" onclick="testConnection(' + port + ')">Probar Conexion</button>' +
                    '<button class="btn-info" onclick="location.reload()">Recargar Sesion</button>' +
                    '<button class="btn-danger" onclick="terminateSession()">Terminar Sesion</button>' +
                    '<button class="btn-primary" onclick="openNewInstance()">Nueva Instancia</button>' +
                '</div>';
        }
        
        function openNewInstance() {
            window.open('/', '_blank');
        }
        
        function testConnection(port) {
            var url = 'http://' + window.location.hostname + ':' + port + '/vnc.html';
            fetch(url)
                .then(function(r) {
                    alert(r.ok ? 'Conexion OK' : 'Error: codigo ' + r.status);
                })
                .catch(function(err) {
                    alert('Error de conexion: ' + err.message);
                });
        }
        
        function showError(message) {
            var content = document.getElementById('content');
            content.innerHTML = '<div class="error">' +
                '<h2>Error</h2>' +
                '<p>' + message + '</p>' +
                '<button class="btn-primary" onclick="location.reload()">Reintentar</button>' +
                '</div>';
        }
        
        function terminateSession() {
            if (confirm('Estas seguro?')) {
                fetch('/api/instance/' + sessionId, { method: 'DELETE' })
                    .then(function() {
                        alert('Sesion terminada');
                        window.close();
                    });
            }
        }
        
        statusCheckInterval = setInterval(checkInstanceStatus, 2000);
        checkInstanceStatus();
        
        setInterval(function() {
            updateStats();
            updateSessionTime();
        }, 1000);
        
        updateStats();
        
        setInterval(function() {
            fetch('/api/instance/' + sessionId + '/heartbeat', { method: 'POST' });
        }, 30000);
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Pagina principal"""
    session_id = str(uuid.uuid4())
    cleanup_inactive_instances()
    instance = create_instance(session_id)
    
    if instance is None:
        return "Error: No se pueden crear mas instancias. Verifica los logs: docker logs -f sysbank_multi", 503
    
    return render_template_string(HTML_TEMPLATE, 
                                 session_id=session_id, 
                                 max_instances=MAX_INSTANCES)

@app.route('/api/stats')
def stats():
    return jsonify({
        'active_instances': len(instances),
        'max_instances': MAX_INSTANCES,
        'uptime': time.time()
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

if __name__ == '__main__':
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
                print("Error limpiando {}: {}".format(item_path, e))
    
    os.makedirs(INSTANCE_DIR, exist_ok=True)
    
    print("=" * 60)
    print("SysBank Multi-Instancia HD iniciado")
    print("=" * 60)
    print("Accede en: http://localhost:8080")
    print("Resolucion: 1920x1080 (Full HD)")
    print("Maximo de instancias: {}".format(MAX_INSTANCES))
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=8080, debug=True, threaded=True)