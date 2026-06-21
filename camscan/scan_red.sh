#!/bin/bash

# Escaneo modular de red local: UPnP + cámaras + puertos abiertos
# Con logging automático por fecha y mejoras de robustez

# ---------------------- FUNCIONES ----------------------

# Validar que los octetos de la IP estén entre 0 y 255 o sea un hostname válido
validar_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        for octeto in "${BASH_REMATCH[@]:1}"; do
            if ((octeto > 255)); then
                return 1
            fi
        done
        return 0
    else
        # Permitir nombres de dominio o hosts locales si nmap puede resolverlos
        if [[ "$ip" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            return 0
        fi
        return 1
    fi
}

# Obtiene la subred asociada a la ruta por defecto (interfaz activa principal)
obtener_subred_local() {
    local gateway_dev ip mask prefix
    
    # Encontrar la interfaz de red por defecto
    gateway_dev=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
    
    if [ -z "$gateway_dev" ]; then
        # Fallback si no hay puerta de enlace por defecto (buscar primera interfaz activa)
        gateway_dev=$(ip -o link show | grep 'state UP' | awk -F': ' '{print $2}' | head -n1)
    fi
    
    if [ -n "$gateway_dev" ]; then
        # Obtener IP y máscara en formato CIDR (ej: 192.168.1.15/24)
        ip=$(ip addr show dev "$gateway_dev" | grep "inet " | awk '{print $2}' | head -n1)
        if [ -n "$ip" ]; then
            # Convertir a dirección de red de la subred (ej: 192.168.1.0/24)
            local base_ip prefix
            base_ip=$(echo "$ip" | cut -d/ -f1)
            prefix=$(echo "$ip" | cut -d/ -f2)
            
            # Formatear a .0 y mantener el prefijo original
            echo "$(echo "$base_ip" | cut -d"." -f1-3).0/$prefix"
            return 0
        fi
    fi
    
    # Último recurso por defecto
    echo "192.168.1.0/24"
}

scan_upnp_udp() {
    echo "[1/3] Escaneando UPnP en $1 (UDP puerto 1900)..."
    nmap -sU -Pn -p 1900 --script=upnp-info "$1"
}

scan_camaras() {
    echo "[2/3] Buscando cámaras o servicios sospechosos en $1..."
    # Se añaden puertos comunes: 81, 82, 8000, 8554, 9000
    nmap -sS -Pn -p 23,80,81,82,554,5000,8000,8080,8554,37777,9000 "$1"
}

listar_upnp_mapeos() {
    echo "[3/3] Mapeos UPnP activos..."
    if command -v upnpc >/dev/null 2>&1; then
        upnpc -l
    else
        # Sugerir instalación según el gestor de paquetes detectado
        if command -v pacman >/dev/null 2>&1; then
            echo "Error: No se encontró 'upnpc'. Instálalo con: sudo pacman -S miniupnpc"
        elif command -v apt-get >/dev/null 2>&1; then
            echo "Error: No se encontró 'upnpc'. Instálalo con: sudo apt install miniupnpc"
        elif command -v dnf >/dev/null 2>&1; then
            echo "Error: No se encontró 'upnpc'. Instálalo con: sudo dnf install miniupnpc"
        else
            echo "Error: No se encontró la herramienta 'upnpc' (miniupnpc)."
        fi
    fi
}

# ---------------------- PRINCIPAL ----------------------

# Verificar que las herramientas esenciales estén instaladas
for cmd in nmap ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: El comando '$cmd' es requerido y no está instalado."
        exit 1
    fi
done

# Verificar si se ejecuta con privilegios de root (nmap -sS y -sU lo requieren)
if [ "$EUID" -ne 0 ]; then
    echo "Error: Este script requiere privilegios de Root (sudo) debido al tipo de escaneo de nmap (-sS/-sU)."
    echo "Por favor, ejecútalo como: sudo $0 o con un usuario root."
    exit 1
fi

# Carpeta logs (detecta el usuario real si se ejecuta con sudo para evitar guardar en /root)
if [ -n "$SUDO_USER" ]; then
    real_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    [ -z "$real_home" ] && real_home="/home/$SUDO_USER"
    logdir="$real_home/camscan/logs"
    mkdir -p "$logdir"
    chown -R "$SUDO_USER:" "$logdir"
else
    logdir="$HOME/camscan/logs"
    mkdir -p "$logdir"
fi

# Archivo log con fecha y hora
logfile="$logdir/scan_red_$(date +'%Y%m%d_%H%M%S').log"

# IP o red como argumento
target="$1"

# Si no se pasó argumento, usar red local automáticamente
if [ -z "$target" ]; then
    target=$(obtener_subred_local)
    echo "Info: No se especificó IP o subred. Usando red local: $target"
fi

# Validación del objetivo
if ! validar_ip "$(echo "$target" | cut -d/ -f1)"; then
    echo "Error: IP o Hostname inválido: $target"
    exit 1
fi

# Ejecutar y guardar salida con tee (pantalla + archivo)
{
    echo ""
    echo "Escaneo iniciado en: $target"
    echo "----------------------------------------------------"

    scan_upnp_udp "$target"
    echo "----------------------------------------------------"
    scan_camaras "$target"
    echo "----------------------------------------------------"
    listar_upnp_mapeos

    echo ""
    echo "Escaneo completo."
} | tee "$logfile"

# Ajustar propietario del archivo log si se ejecutó con sudo
if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER:" "$logfile"
fi

echo ""
echo "Resultado guardado en: $logfile"
