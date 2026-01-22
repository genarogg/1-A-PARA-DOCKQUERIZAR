#!/usr/bin/env python3
"""
Gestor de instancias multi-sesión para SysBank
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
from pathlib import Path

app = Flask(__name__)
CORS(app)

# Configuración
BASE_DISPLAY = 99
BASE_VNC_PORT = 5900
BASE_NOVNC_PORT = 6080
MAX_INSTANCES = 50
INSTANCE_DIR = "/app/instances"
INSTANCE_TIMEOUT = 3600  # 1 hora de inactividad

# Almacenamiento de instancias activas
instances = {}

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

def create_instance(session_id):
    """Crea una nueva instancia de SysBank"""
    if len(instances) >= MAX_INSTANCES:
        return None
    
    display, vnc_port, novnc_port = get_next_available_ports()
    if display is None:
        return None
    
    instance_id = f"sysbank_{session_id}"
    
    try:
        # Iniciar la instancia
        process = subprocess.Popen([
            '/app/start-instance.sh',
            instance_id,
            str(display),
            str(vnc_port),
            str(novnc_port)
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
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
        
        # Esperar a que la instancia esté lista
        time.sleep(5)
        instances[session_id]['status'] = 'running'
        
        return instances[session_id]
    except Exception as e:
        print(f"Error creando instancia: {e}")
        return None

def stop_instance(session_id):
    """Detiene una instancia específica"""
    if session_id not in instances:
        return False
    
    instance = instances[session_id]
    instance_path = Path(INSTANCE_DIR) / instance['id']
    
    try:
        # Leer PIDs y terminar procesos
        for pid_file in ['app.pid', 'novnc.pid', 'vnc.pid', 'openbox.pid', 'xvfb.pid']:
            pid_path = instance_path / pid_file
            if pid_path.exists():
                try:
                    with open(pid_path) as f:
                        pid = int(f.read().strip())
                    os.kill(pid, signal.SIGTERM)
                except:
                    pass
        
        # Terminar proceso principal
        if instance['process']:
            instance['process'].terminate()
            instance['process'].wait(timeout=5)
        
        del instances[session_id]
        return True
    except Exception as e:
        print(f"Error deteniendo instancia: {e}")
        return False

def cleanup_inactive_instances():
    """Limpia instancias inactivas"""
    current_time = time.time()
    to_remove = []
    
    for session_id, instance in instances.items():
        if current_time - instance['last_access'] > INSTANCE_TIMEOUT:
            to_remove.append(session_id)
    
    for session_id in to_remove:
        print(f"Limpiando instancia inactiva: {session_id}")
        stop_instance(session_id)

# HTML de la interfaz principal
HTML_TEMPLATE = '''
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
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🏦 SysBank Multi-Instancia</h1>
            <p class="subtitle">Cada sesión es completamente independiente</p>
        </header>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value" id="active-instances">-</div>
                <div class="stat-label">Instancias Activas</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="max-instances">{{ max_instances }}</div>
                <div class="stat-label">Máximo Permitido</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="session-time">0:00</div>
                <div class="stat-label">Tiempo de Sesión</div>
            </div>
        </div>
        
        <div id="content">
            <div class="loading">
                <div class="spinner"></div>
                <h2>Iniciando tu instancia personal de SysBank...</h2>
                <p>Esto puede tomar unos segundos</p>
            </div>
        </div>
    </div>
    
    <script>
        const sessionId = '{{ session_id }}';
        let sessionStartTime = Date.now();
        let statusCheckInterval;
        
        function updateSessionTime() {
            const elapsed = Math.floor((Date.now() - sessionStartTime) / 1000);
            const minutes = Math.floor(elapsed / 60);
            const seconds = elapsed % 60;
            document.getElementById('session-time').textContent = 
                `${minutes}:${seconds.toString().padStart(2, '0')}`;
        }
        
        function updateStats() {
            fetch('/api/stats')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('active-instances').textContent = data.active_instances;
                });
        }
        
        function checkInstanceStatus() {
            fetch(`/api/instance/${sessionId}`)
                .then(r => r.json())
                .then(data => {
                    if (data.status === 'running') {
                        clearInterval(statusCheckInterval);
                        loadVNC(data.novnc_port);
                    } else if (data.status === 'error') {
                        showError('Error al iniciar la instancia');
                    }
                })
                .catch(err => {
                    console.error('Error checking status:', err);
                });
        }
        
        function loadVNC(port) {
            const content = document.getElementById('content');
            content.innerHTML = `
                <div class="vnc-container">
                    <div class="vnc-header">
                        <div class="session-info">
                            <strong>Sesión:</strong> ${sessionId.substring(0, 8)}
                        </div>
                        <div>
                            <span class="status-badge">● Activa</span>
                        </div>
                    </div>
                    <iframe src="http://${window.location.hostname}:${port}/vnc.html?autoconnect=true&reconnect=true"></iframe>
                </div>
                <div class="controls">
                    <button class="btn-info" onclick="location.reload()">
                        🔄 Recargar Sesión
                    </button>
                    <button class="btn-danger" onclick="terminateSession()">
                        ✕ Terminar Sesión
                    </button>
                    <button class="btn-primary" onclick="window.open('/', '_blank')">
                        ➕ Nueva Instancia
                    </button>
                </div>
            `;
        }
        
        function showError(message) {
            const content = document.getElementById('content');
            content.innerHTML = `
                <div class="error">
                    <h2>❌ Error</h2>
                    <p>${message}</p>
                    <button class="btn-primary" onclick="location.reload()">
                        Reintentar
                    </button>
                </div>
            `;
        }
        
        function terminateSession() {
            if (confirm('¿Estás seguro de que quieres terminar esta sesión?')) {
                fetch(`/api/instance/${sessionId}`, { method: 'DELETE' })
                    .then(() => {
                        window.close();
                    });
            }
        }
        
        // Iniciar
        statusCheckInterval = setInterval(checkInstanceStatus, 2000);
        checkInstanceStatus();
        
        // Actualizar stats y tiempo cada segundo
        setInterval(() => {
            updateStats();
            updateSessionTime();
        }, 1000);
        
        updateStats();
        
        // Heartbeat para mantener la sesión activa
        setInterval(() => {
            fetch(`/api/instance/${sessionId}/heartbeat`, { method: 'POST' });
        }, 30000);
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    """Página principal - crea nueva instancia para cada visitante"""
    session_id = str(uuid.uuid4())
    
    # Limpiar instancias inactivas
    cleanup_inactive_instances()
    
    # Crear nueva instancia
    instance = create_instance(session_id)
    
    if instance is None:
        return "Error: No se pueden crear más instancias. Intenta más tarde.", 503
    
    return render_template_string(HTML_TEMPLATE, 
                                 session_id=session_id, 
                                 max_instances=MAX_INSTANCES)

@app.route('/api/stats')
def stats():
    """Estadísticas del sistema"""
    return jsonify({
        'active_instances': len(instances),
        'max_instances': MAX_INSTANCES,
        'uptime': time.time()
    })

@app.route('/api/instance/<session_id>')
def get_instance(session_id):
    """Obtiene información de una instancia"""
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
    """Actualiza el último acceso de una instancia"""
    if session_id in instances:
        instances[session_id]['last_access'] = time.time()
        return jsonify({'status': 'ok'})
    return jsonify({'status': 'not_found'}), 404

@app.route('/api/instance/<session_id>', methods=['DELETE'])
def delete_instance(session_id):
    """Elimina una instancia específica"""
    if stop_instance(session_id):
        return jsonify({'status': 'deleted'})
    return jsonify({'status': 'error'}), 500

@app.route('/api/instances')
def list_instances():
    """Lista todas las instancias activas"""
    return jsonify({
        'instances': [{
            'id': session_id,
            'status': inst['status'],
            'created_at': inst['created_at'],
            'last_access': inst['last_access']
        } for session_id, inst in instances.items()]
    })

if __name__ == '__main__':
    # Limpiar instancias antiguas al iniciar
    if os.path.exists(INSTANCE_DIR):
        import shutil
        shutil.rmtree(INSTANCE_DIR)
    os.makedirs(INSTANCE_DIR, exist_ok=True)
    
    # Iniciar servidor
    app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)