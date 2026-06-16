#!/usr/bin/env bash

set -Eeuo pipefail

# Variables
USER_NAME=""
HOST_NAME=""
TIMEZONE=""
PUBKEY_FILE=""
SSH_PORT="2222"
LOG_DISK=""          # Disco para partición de logs (ej. /dev/sdb)
LOG_SIZE=""          # Tamaño (ej. 10G), si no se especifica se calcula automático

# Función de ayuda
usage() {
    cat <<EOF
Uso: $0 --user USERNAME --hostname HOSTNAME --timezone TIMEZONE --pubkey PUBKEY_FILE [--ssh-port PORT] [--log-disk DISK] [--log-size SIZE]

Opciones:
  --user USERNAME       Nombre del usuario a crear
  --hostname HOSTNAME   Nombre del servidor
  --timezone TIMEZONE   Zona horaria (ej: America/Bogota)
  --pubkey PUBKEY_FILE  Ruta a la llave pública SSH
  --ssh-port PORT       Puerto SSH (por defecto: 2222)
  --log-disk DISK       Disco para crear partición adicional (ej. /dev/sdb)
  --log-size SIZE       Tamaño de la partición (ej. 10G). Por defecto: 10% del espacio libre

Ejemplo:
  $0 --user javi --hostname web-prod-01 --timezone America/Bogota --pubkey ~/.ssh/id_ed25519.pub --ssh-port 2222 --log-disk /dev/sdb --log-size 20G

Características:
  ✓ SSH solo con llave pública (PasswordAuthentication no)
  ✓ Login local con contraseña
  ✓ Sudo con contraseña (seguridad adicional)
  ✓ Root login deshabilitado
  ✓ Firewall UFW activo
  ✓ Fail2Ban activo
  ✓ Swap configurado automáticamente
  ✓ Partición adicional para logs (opcional, sin mover logs existentes)
EOF
    exit 1
}

# Parsear argumentos
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
        --log-disk)
            LOG_DISK="$2"
            shift 2
            ;;
        --log-size)
            LOG_SIZE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "❌ Opción no reconocida: $1"
            usage
            ;;
    esac
done

# Validar que se ejecute como root
[[ $EUID -eq 0 ]] || {
    echo "❌ Debe ejecutarse como root"
    exit 1
}

# Validar parámetros requeridos
[[ -n "$USER_NAME" ]] || { echo "❌ Falta --user"; usage; }
[[ -n "$HOST_NAME" ]] || { echo "❌ Falta --hostname"; usage; }
[[ -n "$TIMEZONE" ]] || { echo "❌ Falta --timezone"; usage; }
[[ -n "$PUBKEY_FILE" ]] || { echo "❌ Falta --pubkey"; usage; }

# Validar que la llave pública exista
[[ -f "$PUBKEY_FILE" ]] || {
    echo "❌ No existe la clave pública: $PUBKEY_FILE"
    exit 1
}

# Validar que sea una llave SSH válida
if ! grep -q "ssh-" "$PUBKEY_FILE"; then
    echo "❌ El archivo $PUBKEY_FILE no parece ser una llave pública SSH válida"
    exit 1
fi

# Mostrar configuración
echo "========================================="
echo "📋 Configuración:"
echo "  Usuario: $USER_NAME"
echo "  Hostname: $HOST_NAME"
echo "  Timezone: $TIMEZONE"
echo "  Clave pública: $PUBKEY_FILE"
echo "  Puerto SSH: $SSH_PORT"
if [[ -n "$LOG_DISK" ]]; then
    echo "  Disco para partición adicional: $LOG_DISK"
    echo "  Tamaño: ${LOG_SIZE:-auto}"
else
    echo "  Partición adicional: No se creará"
fi
echo "========================================="
echo "🔐 Modo: Opción 1"
echo "  ✓ SSH: solo llave pública"
echo "  ✓ Login local: con contraseña"
echo "  ✓ Sudo: con contraseña"
echo "========================================="
echo

# [1/9] Actualizar sistema
echo "📦 [1/9] Actualizando sistema..."
apt update
apt upgrade -y
apt full-upgrade -y
apt autoremove -y

# [2/9] Instalar paquetes (incluido parted)
echo "📦 [2/9] Instalando paquetes..."
apt install -y \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges \
    git \
    build-essential \
    curl \
    wget \
    vim \
    htop \
    python3 \
    python3-pip \
    parted

# [2.5/9] Crear partición adicional en el disco especificado (sin tocar tabla)
if [[ -n "$LOG_DISK" ]]; then
    echo "💾 [2.5/9] Creando partición adicional en $LOG_DISK..."

    # Verificar que el disco existe
    if [[ ! -b "$LOG_DISK" ]]; then
        echo "❌ El disco $LOG_DISK no existe o no es un bloque"
        exit 1
    fi

    # Verificar que parted está instalado
    if ! command -v parted &>/dev/null; then
        echo "❌ parted no está instalado. Instálelo con: apt install parted"
        exit 1
    fi

    # Obtener espacio libre en el disco (en GB)
    FREE_SPACE=$(parted -s "$LOG_DISK" unit GB print free | grep 'Free Space' | awk '{print $3}' | sed 's/GB//' | head -1)
    if [[ -z "$FREE_SPACE" || "$FREE_SPACE" -lt 5 ]]; then
        echo "❌ No hay suficiente espacio libre en $LOG_DISK (mínimo 5GB). Espacio libre: ${FREE_SPACE:-0}GB"
        exit 1
    fi
    echo "📊 Espacio libre disponible: ${FREE_SPACE}GB"

    # Calcular tamaño si no se especificó
    if [[ -z "$LOG_SIZE" ]]; then
        # Usar 10% del espacio libre, mínimo 5GB, máximo 50GB
        LOG_SIZE_GB=$((FREE_SPACE / 10))
        [[ $LOG_SIZE_GB -lt 5 ]] && LOG_SIZE_GB=5
        [[ $LOG_SIZE_GB -gt 50 ]] && LOG_SIZE_GB=50
        LOG_SIZE="${LOG_SIZE_GB}G"
        echo "📊 Tamaño auto-calculado: $LOG_SIZE"
    else
        # Verificar que el tamaño solicitado no exceda el espacio libre
        REQ_SIZE_GB=$(echo "$LOG_SIZE" | sed 's/[^0-9]//g')
        if [[ -n "$FREE_SPACE" && "$REQ_SIZE_GB" -gt "$FREE_SPACE" ]]; then
            echo "❌ Tamaño solicitado ${LOG_SIZE} excede el espacio libre (${FREE_SPACE}GB)"
            exit 1
        fi
    fi

    # Obtener el inicio del primer espacio libre
    START=$(parted -s "$LOG_DISK" unit GB print free | grep 'Free Space' | head -1 | awk '{print $1}' | sed 's/GB//')
    if [[ -z "$START" ]]; then
        echo "❌ No se encontró espacio libre en $LOG_DISK"
        exit 1
    fi
    echo "📊 Inicio del espacio libre: ${START}GB"

    # Crear partición en el espacio libre (sin modificar tabla existente)
    echo "🔄 Creando partición de tamaño $LOG_SIZE a partir de ${START}GB..."
    parted -s "$LOG_DISK" mkpart primary ext4 "${START}GB" "+${LOG_SIZE}"
    partprobe "$LOG_DISK"
    sleep 2

    # Obtener el nombre de la nueva partición (la última creada)
    NEW_PART=$(lsblk -lpo NAME,TYPE "$LOG_DISK" | grep part | tail -1 | awk '{print $1}')
    if [[ -z "$NEW_PART" ]]; then
        echo "❌ No se pudo detectar la nueva partición"
        exit 1
    fi
    echo "📊 Nueva partición: $NEW_PART"

    # Formatear como ext4
    echo "🔄 Formateando $NEW_PART como ext4..."
    mkfs.ext4 -L "LOG_PART" "$NEW_PART"

    # Mostrar información (sin montar ni mover nada)
    echo "✅ Partición creada y formateada: $NEW_PART ($LOG_SIZE)"
    echo "ℹ️  No se ha montado ni se han movido logs."
    echo "   Para usarla como /var/log, puede hacer:"
    echo "   sudo systemctl stop rsyslog syslog"
    echo "   sudo mount $NEW_PART /var/log"
    echo "   sudo systemctl start rsyslog syslog"
    echo "   (y agregar a /etc/fstab para persistencia)"
else
    echo "ℹ️ [2.5/9] Saltando creación de partición para logs (no se especificó --log-disk)"
fi

# [3/9] Crear usuario CON contraseña (Opción 1)
echo "👤 [3/9] Creando usuario $USER_NAME..."

if ! id "$USER_NAME" &>/dev/null; then
    adduser --disabled-password --gecos "" "$USER_NAME"
fi

# Instalar Bun como el usuario
echo "📦 Instalando Bun para $USER_NAME..."
sudo -u "$USER_NAME" bash <<EOF
curl -fsSL https://bun.sh/install | bash
EOF

# Agregar Bun al PATH en .bashrc
echo 'export BUN_INSTALL="$HOME/.bun"' >> /home/$USER_NAME/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /home/$USER_NAME/.bashrc

# Agregar a grupos
usermod -aG sudo "$USER_NAME"
# usermod -aG docker "$USER_NAME"  # Descomentar si se necesita docker

# Generar contraseña temporal
TEMP_PASS=$(openssl rand -base64 32)
echo "$USER_NAME:$TEMP_PASS" | chpasswd

echo "✅ Usuario $USER_NAME creado exitosamente"
echo "🔑 Contraseña temporal: $TEMP_PASS"
echo "⚠️  CAMBIAR esta contraseña en el primer inicio de sesión"
echo ""
echo "📌 Usos de la contraseña:"
echo "   ✅ Login local (consola física)"
echo "   ✅ sudo (requiere autenticación)"
echo "   ❌ SSH (solo llave pública)"

# [4/9] Configurar SSH (solo llave pública)
echo "🔐 [4/9] Configurando SSH (solo llave pública)..."

# Crear directorio .ssh
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"

# Instalar llave pública
install -m 600 -o "$USER_NAME" -g "$USER_NAME" "$PUBKEY_FILE" "/home/$USER_NAME/.ssh/authorized_keys"

# Backup configuración
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# Configurar SSH
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config

# Configurar puerto
if grep -q "^#\?Port " /etc/ssh/sshd_config; then
    sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
fi

# Permitir solo este usuario (seguridad adicional)
if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
    sed -i "s/^AllowUsers.*/AllowUsers $USER_NAME/" /etc/ssh/sshd_config
else
    echo "AllowUsers $USER_NAME" >> /etc/ssh/sshd_config
fi

# Verificar configuración
if sshd -t; then
    echo "✅ Configuración SSH válida"
    systemctl restart ssh
else
    echo "❌ Error en configuración SSH. Revisa /etc/ssh/sshd_config"
    exit 1
fi

# [5/9] Configurar firewall
echo "🔥 [5/9] Configurando firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "✅ Firewall configurado:"
ufw status

# [6/9] Configurar actualizaciones automáticas
echo "🔄 [6/9] Configurando actualizaciones automáticas..."
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# [7/9] Configurar Fail2Ban
echo "🛡️ [7/9] Configurando Fail2Ban..."
cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ${SSH_PORT}
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# [8/9] Configurar timezone
echo "🕐 [8/9] Configurando timezone..."
timedatectl set-timezone "$TIMEZONE"

# [9/9] Configurar hostname y swap
echo "🏷️ [9/9] Configurando hostname..."
hostnamectl set-hostname "$HOST_NAME"

# Configurar Swap
echo "💾 Configurando Swap..."

if swapon -s | grep -q "swapfile"; then
    echo "ℹ️  Ya existe un archivo swap activo"
else
    # Calcular tamaño basado en RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    echo "📊 RAM total: ${TOTAL_RAM}MB"
    
    if [ "$TOTAL_RAM" -le 1024 ]; then
        SWAP_SIZE="2G"
    elif [ "$TOTAL_RAM" -le 2048 ]; then
        SWAP_SIZE="4G"
    elif [ "$TOTAL_RAM" -le 4096 ]; then
        SWAP_SIZE="6G"
    else
        SWAP_SIZE="8G"
    fi
    
    echo "📊 Tamaño swap: $SWAP_SIZE"
    
    # Crear archivo swap
    echo "🔄 Creando archivo swap..."
    if fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null; then
        echo "✅ Archivo creado con fallocate"
    else
        echo "⚠️  fallocate falló, usando dd..."
        dd if=/dev/zero of=/swapfile bs=1M count=$(( $(echo "$SWAP_SIZE" | sed 's/[^0-9]//g') * 1024 )) status=progress
    fi
    
    # Configurar permisos
    chmod 600 /swapfile
    echo "✅ Permisos configurados"
    
    # Formatear como swap
    mkswap /swapfile
    echo "✅ Swap formateado"
    
    # Activar
    swapon /swapfile
    echo "✅ Swap activado"
    
    # Persistencia
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
        echo "✅ Persistencia configurada en /etc/fstab"
    fi
    
    # Optimizaciones de kernel
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" >> /etc/sysctl.conf
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
        echo "✅ Optimizaciones de kernel aplicadas"
    fi
    
    echo "✅ Swap configurado exitosamente:"
    swapon -s
    echo
    echo "📊 Memoria después de swap:"
    free -h
fi

# Mostrar resumen final
echo
echo "========================================="
echo "✅ ¡Configuración completada!"
echo "========================================="
echo "📊 Estado del sistema:"
echo "  - Hostname: $(hostnamectl --static)"
echo "  - Timezone: $(timedatectl | grep 'Time zone')"
echo "  - Usuario: $USER_NAME"
echo "  - Puerto SSH: $SSH_PORT"
echo "  - Swap: $(swapon -s | grep -q swapfile && echo 'Activo' || echo 'Inactivo')"
if [[ -n "$LOG_DISK" && -n "$NEW_PART" ]]; then
    echo "  - Partición adicional creada: $NEW_PART ($LOG_SIZE)"
    echo "    (no montada, lista para usar)"
fi
echo
echo "🔑 Credenciales:"
echo "  Usuario: $USER_NAME"
echo "  Contraseña temporal: $TEMP_PASS"
echo "  ⚠️  CAMBIAR en el primer login: passwd"
echo
echo "🔐 Acceso SSH (solo llave pública):"
echo "  ssh -p $SSH_PORT $USER_NAME@$(curl -s ifconfig.me)"
echo
echo "📌 Usos de la contraseña:"
echo "  ✅ Login local (consola física)"
echo "  ✅ sudo (requiere autenticación)"
echo "  ❌ SSH (solo llave pública)"
echo
echo "🛡️ Seguridad activa:"
echo "  ✓ Root login: DESHABILITADO"
echo "  ✓ Password SSH: DESHABILITADO"
echo "  ✓ Firewall: ACTIVO"
echo "  ✓ Fail2Ban: ACTIVO"
echo "  ✓ Solo usuario $USER_NAME permitido en SSH"
if [[ -n "$LOG_DISK" && -n "$NEW_PART" ]]; then
    echo
    echo "💾 Partición adicional para logs:"
    echo "   Disco: $LOG_DISK"
    echo "   Partición: $NEW_PART"
    echo "   Tamaño: $LOG_SIZE"
    echo "   Formato: ext4"
    echo "   Para montarla en /data/logs:"
    echo "     sudo mkdir -p /data/logs"
    echo "     sudo mount $NEW_PART /data/logs"
    echo "     (y agregar a /etc/fstab para persistencia)"
    echo "     sudo blkid $NEW_PART  # para obtener UUID y usar en fstab"
    echo "     sudo vim /etc/fstab  # agregar línea: UUID=xxxx-xxxx /data/logs ext4 defaults 0 2"
    echo "     sudo mount -a  # para probar fstab"
fi
echo
echo "⚠️  IMPORTANTE:"
echo "  1. 🔑 Cambia la contraseña temporal: passwd"
echo "  2. 🔐 Prueba SSH en OTRA terminal:"
echo "     ssh -p $SSH_PORT $USER_NAME@$(curl -s ifconfig.me)"
echo "  3. 💾 Guarda la contraseña en un gestor seguro"
echo "  4. ❌ NO cierres esta sesión hasta confirmar acceso"
echo "  5. 📝 Revisa /var/log/auth.log por intentos fallidos"
echo "========================================="