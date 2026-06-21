# Netscan

Script en Bash para escanear redes locales de forma rápida. Identifica dispositivos con UPnP activo y puertos comunes de cámaras de seguridad (CCTV).

## Requisitos
* `nmap`
* `ip` (iproute2)
* `miniupnpc` (opcional, para ver mapeos UPnP con el comando `upnpc`)

El script necesita permisos de root (`sudo`) para poder realizar los escaneos SYN y UDP (`nmap -sS` / `-sU`).

## Uso

Dale permisos de ejecución si aún no los tiene:
```bash
chmod +x camscan/netscan.sh
```

Ejecuta el script:
```bash
# Escaneo automático de la subred local actual
sudo ./camscan/netscan.sh

# Escanear un host o rango específico
sudo ./camscan/netscan.sh 192.168.1.100
sudo ./camscan/netscan.sh 192.168.1.0/24
```

## Logs
Los resultados se guardan automáticamente en tu carpeta personal en `~/camscan/logs/` (con propiedad de tu usuario regular, no de root).
