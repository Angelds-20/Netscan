#!/bin/bash

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
        [[ "$ip" =~ ^[a-zA-Z0-9.-]+$ ]] && return 0
        return 1
    fi
}

obtener_subred() {
    local dev ip base_ip prefix
    
    dev=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
    if [ -z "$dev" ]; then
        dev=$(ip -o link show | grep 'state UP' | awk -F': ' '{print $2}' | head -n1)
    fi
    
    if [ -n "$dev" ]; then
        ip=$(ip addr show dev "$dev" | grep "inet " | awk '{print $2}' | head -n1)
        if [ -n "$ip" ]; then
            base_ip=$(echo "$ip" | cut -d/ -f1)
            prefix=$(echo "$ip" | cut -d/ -f2)
            echo "$(echo "$base_ip" | cut -d"." -f1-3).0/$prefix"
            return 0
        fi
    fi
    echo "192.168.1.0/24"
}

scan_upnp() {
    echo "[1/3] Buscando UPnP en $1..."
    nmap -sU -Pn -p 1900 --script=upnp-info "$1"
}

scan_cams() {
    echo "[2/3] Buscando puertos de cámaras en $1..."
    nmap -sS -Pn -p 23,80,81,82,554,5000,8000,8080,8554,37777,9000 "$1"
}

check_upnp_mappings() {
    echo "[3/3] Mapeos UPnP activos..."
    if command -v upnpc >/dev/null 2>&1; then
        upnpc -l
    else
        if command -v pacman >/dev/null 2>&1; then
            echo "Error: no se encontró upnpc. Instálalo con: sudo pacman -S miniupnpc"
        elif command -v apt-get >/dev/null 2>&1; then
            echo "Error: no se encontró upnpc. Instálalo con: sudo apt install miniupnpc"
        else
            echo "Error: no se encontró la herramienta upnpc."
        fi
    fi
}

# Main

for cmd in nmap ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: se requiere '$cmd' pero no está instalado."
        exit 1
    fi
done

if [ "$EUID" -ne 0 ]; then
    echo "Error: se requieren privilegios de root para escaneo SYN/UDP."
    echo "Usa: sudo $0 <ip/subred>"
    exit 1
fi

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

logfile="$logdir/scan_$(date +'%Y%m%d_%H%M%S').log"

target="$1"
if [ -z "$target" ]; then
    target=$(obtener_subred)
    echo "Info: usando red local detectada: $target"
fi

if ! validar_ip "$(echo "$target" | cut -d/ -f1)"; then
    echo "Error: IP o Hostname inválido."
    exit 1
fi

{
    echo "Escaneo iniciado en: $target"
    echo "----------------------------------------------------"
    scan_upnp "$target"
    echo "----------------------------------------------------"
    scan_cams "$target"
    echo "----------------------------------------------------"
    check_upnp_mappings
    echo "----------------------------------------------------"
    echo "Escaneo completo."
} | tee "$logfile"

if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER:" "$logfile"
fi

echo "Log guardado en: $logfile"
