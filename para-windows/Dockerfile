FROM debian:buster

# Debian 10 (Buster) ha sido movido a archive.debian.org.
# Necesitamos reconfigurar sources.list para apuntar a archive tanto para Buster como para Stretch (QT4).
RUN echo "deb http://archive.debian.org/debian buster main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    # Desactivar validación de tiempo para repositorios archivados
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

# Instalamos las dependencias
RUN apt-get -o Acquire::AllowInsecureRepositories=true \
            -o Acquire::AllowDowngradeToInsecureRepositories=true \
            update && \
    apt-get -o Acquire::AllowInsecureRepositories=true \
            -o Acquire::AllowDowngradeToInsecureRepositories=true \
            install -y --allow-unauthenticated \
    libqtgui4 \
    libqt4-network \
    libqt4-opengl \
    libqt4-sql \
    libqt4-sql-psql \
    libqtcore4 \
    libqt4-xml \
    x11-apps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY sysbank /app/sysbank

RUN chmod +x /app/sysbank

ENV QT_X11_NO_MITSHM=1

CMD ["./sysbank"]
