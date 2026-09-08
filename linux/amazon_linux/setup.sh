dnf upgrade
sudo dnf install -y \
    git \
    wget \
    vim \
    htop \
    python3 \
    dnf-automatic
    
#sudo vim /etc/dnf/automatic.conf

curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://bun.sh/install | bash

# Agregar Bun al PATH en .bashrc
echo 'export BUN_INSTALL="$HOME/.bun"' >> "$HOME/.bashrc"
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"

timedatectl set-timezone "America/Bogota"

