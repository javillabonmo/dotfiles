#!/usr/bin/env bash

set -Eeuo pipefail

# Variables
USER_NAME=""
HOST_NAME=""
TIMEZONE=""
PUBKEY_FILE=""
SSH_PORT="2222"

# Función de ayuda
usage() {
    cat <<EOF
Uso: $0 --user USERNAME --hostname HOSTNAME --timezone TIMEZONE --pubkey PUBKEY_FILE [--ssh-port PORT]

Opciones:
  --user USERNAME       Nombre del usuario a crear
  --hostname HOSTNAME   Nombre del servidor
  --timezone TIMEZONE   Zona horaria (ej: America/Bogota)
  --pubkey PUBKEY_FILE  Ruta a la llave pública SSH
  --ssh-port PORT       Puerto SSH (por defecto: 2222)

Ejemplo:
  $0 --user javi --hostname web-prod-01 --timezone America/Bogota --pubkey ~/.ssh/id_ed25519.pub --ssh-port 2222

Características:
  ✓ SSH solo con llave pública (PasswordAuthentication no)
  ✓ Login local con contraseña
  ✓ Sudo con contraseña (seguridad adicional)
  ✓ Root login deshabilitado
  ✓ Firewall UFW activo
  ✓ Fail2Ban activo
  ✓ Swap configurado automáticamente
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

# [2/9] Instalar paquetes
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
    python3-pip

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
echo
echo "⚠️  IMPORTANTE:"
echo "  1. 🔑 Cambia la contraseña temporal: passwd"
echo "  2. 🔐 Prueba SSH en OTRA terminal:"
echo "     ssh -p $SSH_PORT $USER_NAME@$(curl -s ifconfig.me)"
echo "  3. 💾 Guarda la contraseña en un gestor seguro"
echo "  4. ❌ NO cierres esta sesión hasta confirmar acceso"
echo "  5. 📝 Revisa /var/log/auth.log por intentos fallidos"
echo "========================================="