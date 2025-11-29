#!/bin/bash
# Install OpenVPN, ZeroTier, Vim, and Docker/Podman
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

# Download file using curl or wget
download_file() {
    local url="$1"
    local output="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$output"
    else
        echo "Error: Neither curl nor wget is available."
        return 1
    fi
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

# Interactive: Replace ZeroTier planet file
echo ""
read -rp "Do you want to replace the ZeroTier planet file? (y/n): " REPLACE_PLANET
if [[ "$REPLACE_PLANET" =~ ^[Yy]$ ]]; then
    read -rp "Enter the planet file path or URL: " PLANET_SOURCE
    
    ZEROTIER_DIR="/var/lib/zerotier-one"
    PLANET_FILE="$ZEROTIER_DIR/planet"
    BACKUP_FILE="$ZEROTIER_DIR/planet.backup.$(date +%Y%m%d%H%M%S)"
    
    echo "Stopping ZeroTier service..."
    sudo systemctl stop zerotier-one || true
    
    # Backup original planet file
    if [ -f "$PLANET_FILE" ]; then
        echo "Backing up original planet file to $BACKUP_FILE..."
        sudo cp "$PLANET_FILE" "$BACKUP_FILE"
    fi
    
    # Download or copy planet file
    if [[ "$PLANET_SOURCE" =~ ^https?:// ]]; then
        echo "Downloading planet file from $PLANET_SOURCE..."
        download_file "$PLANET_SOURCE" /tmp/planet.new
        if [ ! -f /tmp/planet.new ]; then
            echo "Error: Failed to download planet file."
            sudo systemctl start zerotier-one
            exit 1
        fi
        sudo mv /tmp/planet.new "$PLANET_FILE"
    else
        if [ ! -f "$PLANET_SOURCE" ] || [ ! -r "$PLANET_SOURCE" ]; then
            echo "Error: Planet file '$PLANET_SOURCE' does not exist or is not readable."
            sudo systemctl start zerotier-one
            exit 1
        fi
        echo "Copying planet file from $PLANET_SOURCE..."
        sudo cp "$PLANET_SOURCE" "$PLANET_FILE"
    fi
    
    echo "Restarting ZeroTier service..."
    sudo systemctl start zerotier-one
    echo "ZeroTier planet file replaced successfully."
fi

# Interactive: Join ZeroTier network
echo ""
read -rp "Do you want to join a ZeroTier network now? (y/n): " JOIN_NETWORK
if [[ "$JOIN_NETWORK" =~ ^[Yy]$ ]]; then
    read -rp "Enter the ZeroTier network ID: " NETWORK_ID
    
    if [ -z "$NETWORK_ID" ]; then
        echo "Warning: Network ID is empty. Skipping network join."
    else
        echo "Joining ZeroTier network $NETWORK_ID..."
        if sudo zerotier-cli join "$NETWORK_ID"; then
            echo ""
            echo "Network status:"
            sudo zerotier-cli listnetworks || echo "Warning: Failed to get network status."
        else
            echo "Error: Failed to join ZeroTier network $NETWORK_ID."
        fi
    fi
fi

# Interactive: Choose container runtime (Docker or Podman)
echo ""
read -rp "Which container runtime do you want to install? (docker/podman): " CONTAINER_RUNTIME
CONTAINER_RUNTIME=$(echo "$CONTAINER_RUNTIME" | tr '[:upper:]' '[:lower:]')
ENABLE_DOCKER=""

if [ "$CONTAINER_RUNTIME" = "podman" ]; then
    echo "=== Installing Podman ==="
    install_packages podman
    echo "Podman installed successfully."
elif [ "$CONTAINER_RUNTIME" = "docker" ]; then
    echo "=== Installing Docker using get.docker.com ==="
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    
    # Interactive: Enable Docker by default?
    echo ""
    read -rp "Do you want to enable Docker to start automatically on boot? (y/n): " ENABLE_DOCKER
    if [[ "$ENABLE_DOCKER" =~ ^[Yy]$ ]]; then
        echo "=== Starting and enabling Docker ==="
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "=== Disabling Docker auto-start ==="
        sudo systemctl stop docker || true
        sudo systemctl disable docker || true
    fi
    
    echo "=== Adding current user to docker group ==="
    # Note: This grants the user root-equivalent privileges since Docker daemon runs as root
    sudo usermod -aG docker "$USER"
    echo "Docker installed successfully."
else
    echo "Invalid choice. Skipping container runtime installation."
fi

echo ""
echo "=== Installation complete! ==="
echo "OpenVPN: installed (auto-start disabled)"
echo "ZeroTier: installed"
echo "Vim: installed"
if [ "$CONTAINER_RUNTIME" = "docker" ]; then
    if [[ "$ENABLE_DOCKER" =~ ^[Yy]$ ]]; then
        echo "Docker: installed and enabled"
    else
        echo "Docker: installed (auto-start disabled)"
    fi
    echo ""
    echo "Note: You may need to log out and back in for docker group changes to take effect."
elif [ "$CONTAINER_RUNTIME" = "podman" ]; then
    echo "Podman: installed"
fi
