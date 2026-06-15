#!/usr/bin/env bash

set -Eeuo pipefail

USER_NAME=""
HOST_NAME=""
TIMEZONE=""
PUBKEY_FILE=""
SSH_PORT="22"

<<EOF
sudo ./bootstrap-server.sh \
  --user javi \
  --hostname web-prod-01 \
  --timezone America/Bogota \
  --pubkey ~/.ssh/id_ed25519.pub \
  --ssh-port 22
EOF

while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            USER_NAME="$2"
            shift 2
            ;;
        --hostname)
            HOST_NAME="$2"
            shift 2
            ;;
        --timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        --pubkey)
            PUBKEY_FILE="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        *)
            echo "Opción no reconocida: $1"
            exit 1
            ;;
    esac
done

[[ $EUID -eq 0 ]] || {
    echo "Debe ejecutarse como root."
    exit 1
}

[[ -n "$USER_NAME" ]] || usage
[[ -n "$HOST_NAME" ]] || usage
[[ -n "$TIMEZONE" ]] || usage
[[ -n "$PUBKEY_FILE" ]] || usage

[[ -f "$PUBKEY_FILE" ]] || {
    echo "No existe la clave pública: $PUBKEY_FILE"
    exit 1
}

echo "[1/9] Actualizando sistema"

apt update
apt upgrade -y
apt full-upgrade -y
apt autoremove -y

echo "[2/9] Instalando los siguientes paquetes: 
ufw,
fail2ban,
unattended-upgrades,
apt-listchanges"

apt install -y \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges