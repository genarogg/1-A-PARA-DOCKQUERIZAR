FROM debian:buster

# Configurar repositorios archivados
RUN echo "deb http://archive.debian.org/debian buster main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

# Instalar dependencias Qt4, VNC optimizado, aceleración gráfica y herramientas
RUN apt-get -o Acquire::AllowInsecureRepositories=true \
            -o Acquire::AllowDowngradeToInsecureRepositories=true \
            update && \
    apt-get -o Acquire::AllowInsecureRepositories=true \
            -o Acquire::AllowDowngradeToInsecureRepositories=true \
            install -y --allow-unauthenticated \
    # Dependencias Qt4
    libqtgui4 \
    libqt4-network \
    libqt4-opengl \
    libqt4-sql \
    libqt4-sql-psql \
    libqtcore4 \
    libqt4-xml \
    # Servidor X con aceleración
    xvfb \
    xserver-xorg-video-dummy \
    # VNC optimizado con TurboVNC características
    x11vnc \
    # Gestor de ventanas ligero
    openbox \
    # Herramientas de renderizado acelerado
    mesa-utils \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    libglu1-mesa \
    # Fuentes mejoradas
    fonts-liberation \
    fonts-dejavu-core \
    # Utilidades
    supervisor \
    wget \
    python3 \
    python3-pip \
    git \
    procps \
    net-tools \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Instalar noVNC optimizado
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Instalar Flask para el gestor de instancias
RUN pip3 install flask flask-cors requests

WORKDIR /app

# Copiar ejecutable
COPY sysbank /app/sysbank
RUN chmod +x /app/sysbank

# Crear directorios para instancias
RUN mkdir -p /app/instances /var/log/supervisor

# Variables de entorno optimizadas para rendimiento gráfico
ENV DISPLAY=:99
ENV RESOLUTION=1920x1080x24
ENV QT_X11_NO_MITSHM=1
ENV QT_GRAPHICSSYSTEM=native
# Habilitar aceleración OpenGL software (llvmpipe)
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV GALLIUM_DRIVER=llvmpipe
# Optimizaciones de renderizado
ENV QT_XCB_GL_INTEGRATION=xcb_egl

# Script de inicio para una instancia
COPY start-instance.sh /app/start-instance.sh
RUN chmod +x /app/start-instance.sh

# Gestor de instancias con API
COPY instance-manager.py /app/instance-manager.py
RUN chmod +x /app/instance-manager.py

# Configuración de Supervisor para gestión de procesos
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Exponer puertos (el gestor manejará puertos dinámicos)
EXPOSE 8080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]