#!/usr/bin/env bash

# Strict mode: exit on error, unset variables, and pipeline failures
set -euo pipefail

echo "================================================="
echo "🚀 Starting Debian Server Base Provisioning..."
echo "================================================="

# 1. System Update & Essential Core Utilities
echo "[1/6] Updating packages and installing essential tools..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git apt-transport-https ca-certificates gnupg lsb-release unzip

# Optional / Developer tools prompt
read -p "❓ Do you want to install developer utilities (Zsh, Neovim, tmux, htop)? [y/N]: " install_dev
if [[ "$install_dev" =~ ^[Yy]$ ]]; then
    echo "Installing developer toolset..."
    sudo apt install -y htop tmux zsh neovim
fi

# 2. Kernel Tuning (BBR & IP Forwarding)
echo "[2/6] Network tuning: enabling BBR and IP Forwarding..."
sudo tee /etc/sysctl.d/99-custom-network.conf > /dev/null << 'EOF'
# Allow routing of transit traffic
net.ipv4.ip_forward = 1
# TCP Congestion Control optimization (BBR)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
sudo sysctl --system

# 3. Docker & Docker Compose Installation (Official Repository)
echo "[3/6] Installing Docker Engine..."
if ! command -v docker &> /dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group for non-root execution
    sudo usermod -aG docker $USER
    echo "✅ Docker installed. (Re-login required for group permission changes)"
else
    echo "✅ Docker is already installed, skipping."
fi

# 4. Xray & v2rayA Installation
echo "[4/6] Installing v2rayA and Xray networking core..."
sudo rm -f /etc/apt/keyrings/v2raya.gpg /etc/apt/sources.list.d/v2raya.list
wget -qO- https://apt.v2raya.org/key/public-key.asc | sudo gpg --dearmor -o /etc/apt/keyrings/v2raya.gpg
echo "deb [signed-by=/etc/apt/keyrings/v2raya.gpg] https://v2raya.org v2raya main" | sudo tee /etc/apt/sources.list.d/v2raya.list > /dev/null

sudo apt update
sudo apt remove -y v2ray || true
sudo apt install -y v2raya xray

# 5. Service Autostart Configuration
echo "[5/6] Enabling system services..."
sudo systemctl enable v2raya.service
sudo systemctl start v2raya.service

# 6. Final Status Check
echo "[6/6] Verifying system state..."
echo "-------------------------------------------------"
echo "IP Forwarding: $(sysctl -n net.ipv4.ip_forward)"
echo "TCP Congestion: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "Docker Compose version: $(docker compose version)"
echo "-------------------------------------------------"
echo "🎉 Server successfully provisioned!"
echo "👉 Next step: configure your run 'docker compose up -d'."

