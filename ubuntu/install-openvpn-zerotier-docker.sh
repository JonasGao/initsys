#!/bin/bash
# Install OpenVPN, ZeroTier, Vim, and Docker
# Docker is installed using the official get.docker.com script
# OpenVPN auto-start is disabled after installation

set -euo pipefail

echo "=== Installing Vim ==="
sudo apt-get update
sudo apt-get install -y vim

echo "=== Installing OpenVPN ==="
sudo apt-get install -y openvpn

echo "=== Disabling OpenVPN auto-start ==="
sudo systemctl stop openvpn || true
sudo systemctl disable openvpn || true
# Disable any OpenVPN instance services (openvpn@server, openvpn@client, etc.)
for service in $(sudo systemctl list-units 'openvpn@*' --all --no-legend 2>/dev/null | awk '{print $1}'); do
    sudo systemctl stop "$service" || true
    sudo systemctl disable "$service" || true
done

echo "=== Installing ZeroTier ==="
curl -s https://install.zerotier.com -o /tmp/install-zerotier.sh
sudo bash /tmp/install-zerotier.sh
rm /tmp/install-zerotier.sh

echo "=== Installing Docker using get.docker.com ==="
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh
rm /tmp/get-docker.sh

echo "=== Starting and enabling Docker ==="
sudo systemctl start docker
sudo systemctl enable docker

echo "=== Adding current user to docker group ==="
sudo usermod -aG docker "$USER"

echo "=== Installation complete! ==="
echo "OpenVPN: installed (auto-start disabled)"
echo "ZeroTier: installed"
echo "Vim: installed"
echo "Docker: installed and enabled"
echo ""
echo "Note: You may need to log out and back in for docker group changes to take effect."
