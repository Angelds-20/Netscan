# CAMSCAN

Herramienta ligera en Bash para auditoría y escaneo de redes locales, enfocada en la detección de servicios UPnP y puertos de cámaras IP / sistemas CCTV.

## Características

* **Autodetección de red**: Identifica automáticamente la subred local activa en base a tu interfaz y puerta de enlace principal.
* **Escaneo UPnP**: Detecta servicios UPnP activos mediante consultas UDP al puerto 1900.
* **Identificación de cámaras**: Busca puertos TCP comúnmente asociados con cámaras de seguridad (23, 80, 81, 82, 554, 5000, 8000, 8080, 8554, 37777, 9000).
* **Mapeos UPnP**: Muestra mapeos de puertos activos usando `upnpc`.
* **Logging**: Guarda el reporte de cada escaneo en la carpeta `~/camscan/logs/` del usuario original (incluso al ejecutar con `sudo`).

## Dependencias

* `nmap`
* `iproute2` (comando `ip`)
* `miniupnpc` (opcional, para mapeos UPnP)

## Uso

El script requiere ejecutarse con privilegios de administrador para realizar escaneos SYN y UDP (`nmap -sS / -sU`).

Escanear la red local completa de forma automática:
```bash
sudo ./netscan.sh
```

Escanear un host o subred específica:
```bash
sudo ./netscan.sh 192.168.1.50
sudo ./netscan.sh 10.0.0.0/24
```
