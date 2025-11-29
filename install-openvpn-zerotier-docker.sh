#!/bin/bash
# Install OpenVPN, ZeroTier, Vim, and Docker
# Docker is installed using the official get.docker.com script
# OpenVPN auto-start is disabled after installation
# Supports: Ubuntu, Debian, CentOS (apt, dnf, yum)

set -euo pipefail

# Detect package manager
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    else
        echo "unknown"
    fi
}

PKG_MANAGER=$(detect_pkg_manager)

if [ "$PKG_MANAGER" = "unknown" ]; then
    echo "Error: Unsupported package manager. This script supports apt (Ubuntu/Debian), dnf and yum (CentOS/Fedora)."
    exit 1
fi

echo "Detected package manager: $PKG_MANAGER"

# Install packages based on package manager
install_packages() {
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update
            sudo apt-get install -y "$@"
            ;;
        dnf)
            sudo dnf install -y "$@"
            ;;
        yum)
            sudo yum install -y "$@"
            ;;
    esac
}

echo "=== Installing Vim ==="
install_packages vim

echo "=== Installing OpenVPN ==="
install_packages openvpn

echo "=== Disabling OpenVPN auto-start ==="
sudo systemctl stop openvpn || true
sudo systemctl disable openvpn || true
# Disable any OpenVPN instance services (openvpn@server, openvpn@client, etc.)
for service in $(sudo systemctl list-units 'openvpn@*' --all --no-legend 2>/dev/null | awk '{print $1}'); do
    sudo systemctl stop "$service" || true
    sudo systemctl disable "$service" || true
done

echo "=== Installing ZeroTier ==="
curl -fsSL https://install.zerotier.com -o /tmp/install-zerotier.sh
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
# Note: This grants the user root-equivalent privileges since Docker daemon runs as root
sudo usermod -aG docker "$USER"

echo "=== Installation complete! ==="
echo "OpenVPN: installed (auto-start disabled)"
echo "ZeroTier: installed"
echo "Vim: installed"
echo "Docker: installed and enabled"
echo ""
echo "Note: You may need to log out and back in for docker group changes to take effect."
