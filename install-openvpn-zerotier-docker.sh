#!/bin/bash
# Install OpenVPN, ZeroTier, Vim, and Docker/Podman
# Docker is installed using the official get.docker.com script
# OpenVPN auto-start is disabled after installation
# Supports: Ubuntu, Debian, CentOS (apt, dnf, yum)
#
# One-line execution:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-openvpn-zerotier-docker.sh | bash
#
# Or download and execute:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-openvpn-zerotier-docker.sh -o install.sh
#   bash install.sh

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
echo ""

# ============================================
# Phase 1: Collect all user choices
# ============================================

echo "=== Configuration ==="
echo ""

# OpenVPN
read -rp "Do you want to install OpenVPN? (y/n): " INSTALL_OPENVPN < /dev/tty
INSTALL_OPENVPN=$(echo "$INSTALL_OPENVPN" | tr '[:upper:]' '[:lower:]')

# ZeroTier planet file
read -rp "Do you want to replace the ZeroTier planet file? (y/n): " REPLACE_PLANET < /dev/tty
REPLACE_PLANET=$(echo "$REPLACE_PLANET" | tr '[:upper:]' '[:lower:]')
PLANET_SOURCE=""
if [[ "$REPLACE_PLANET" =~ ^y$ ]]; then
    read -rp "Enter the planet file path or URL: " PLANET_SOURCE < /dev/tty
fi

# ZeroTier network
read -rp "Do you want to join a ZeroTier network? (y/n): " JOIN_NETWORK < /dev/tty
JOIN_NETWORK=$(echo "$JOIN_NETWORK" | tr '[:upper:]' '[:lower:]')
NETWORK_ID=""
if [[ "$JOIN_NETWORK" =~ ^y$ ]]; then
    read -rp "Enter the ZeroTier network ID: " NETWORK_ID < /dev/tty
fi

# Container runtime
read -rp "Which container runtime do you want to install? (docker/podman/none): " CONTAINER_RUNTIME < /dev/tty
CONTAINER_RUNTIME=$(echo "$CONTAINER_RUNTIME" | tr '[:upper:]' '[:lower:]')

# Docker auto-start
ENABLE_DOCKER=""
if [ "$CONTAINER_RUNTIME" = "docker" ]; then
    read -rp "Do you want to enable Docker to start automatically on boot? (y/n): " ENABLE_DOCKER < /dev/tty
    ENABLE_DOCKER=$(echo "$ENABLE_DOCKER" | tr '[:upper:]' '[:lower:]')
fi

# ============================================
# Phase 2: Show configuration summary
# ============================================

echo ""
echo "============================================"
echo "=== Configuration Summary ==="
echo "============================================"
echo ""
echo "Package Manager: $PKG_MANAGER"
echo "Vim: will be installed"
if [[ "$INSTALL_OPENVPN" =~ ^y$ ]]; then
    echo "OpenVPN: will be installed (auto-start disabled)"
else
    echo "OpenVPN: will be skipped"
fi
echo "ZeroTier: will be installed"
if [[ "$REPLACE_PLANET" =~ ^y$ ]]; then
    echo "  - Planet file: will be replaced from $PLANET_SOURCE"
else
    echo "  - Planet file: will not be replaced"
fi
if [[ "$JOIN_NETWORK" =~ ^y$ ]] && [ -n "$NETWORK_ID" ]; then
    echo "  - Network: will join $NETWORK_ID"
else
    echo "  - Network: will not join any network"
fi
if [ "$CONTAINER_RUNTIME" = "docker" ]; then
    if [[ "$ENABLE_DOCKER" =~ ^y$ ]]; then
        echo "Container Runtime: Docker (auto-start enabled)"
    else
        echo "Container Runtime: Docker (auto-start disabled)"
    fi
elif [ "$CONTAINER_RUNTIME" = "podman" ]; then
    echo "Container Runtime: Podman"
else
    echo "Container Runtime: none"
fi
echo ""
echo "============================================"
echo ""

# ============================================
# Phase 3: Confirm and proceed
# ============================================

read -rp "Proceed with the installation? (y/n): " CONFIRM < /dev/tty
CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [[ ! "$CONFIRM" =~ ^y$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Starting installation..."
echo ""

# ============================================
# Phase 4: Execute installation
# ============================================

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

# Install Vim
echo "=== Installing Vim ==="
install_packages vim

# Install OpenVPN
if [[ "$INSTALL_OPENVPN" =~ ^y$ ]]; then
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
fi

# Install ZeroTier
echo "=== Installing ZeroTier ==="
curl -fsSL https://install.zerotier.com -o /tmp/install-zerotier.sh
sudo bash /tmp/install-zerotier.sh
rm /tmp/install-zerotier.sh

# Replace ZeroTier planet file
if [[ "$REPLACE_PLANET" =~ ^y$ ]] && [ -n "$PLANET_SOURCE" ]; then
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

# Join ZeroTier network
if [[ "$JOIN_NETWORK" =~ ^y$ ]] && [ -n "$NETWORK_ID" ]; then
    echo "Joining ZeroTier network $NETWORK_ID..."
    if sudo zerotier-cli join "$NETWORK_ID"; then
        echo ""
        echo "Network status:"
        sudo zerotier-cli listnetworks || echo "Warning: Failed to get network status."
    else
        echo "Error: Failed to join ZeroTier network $NETWORK_ID."
    fi
fi

# Install container runtime
if [ "$CONTAINER_RUNTIME" = "podman" ]; then
    echo "=== Installing Podman ==="
    install_packages podman
    echo "Podman installed successfully."
elif [ "$CONTAINER_RUNTIME" = "docker" ]; then
    echo "=== Installing Docker using get.docker.com ==="
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    
    if [[ "$ENABLE_DOCKER" =~ ^y$ ]]; then
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
fi

# ============================================
# Phase 5: Show installation summary
# ============================================

echo ""
echo "============================================"
echo "=== Installation Complete! ==="
echo "============================================"
echo ""
echo "Vim: installed"
if [[ "$INSTALL_OPENVPN" =~ ^y$ ]]; then
    echo "OpenVPN: installed (auto-start disabled)"
else
    echo "OpenVPN: skipped"
fi
echo "ZeroTier: installed"
if [[ "$REPLACE_PLANET" =~ ^y$ ]]; then
    echo "  - Planet file: replaced"
fi
if [[ "$JOIN_NETWORK" =~ ^y$ ]] && [ -n "$NETWORK_ID" ]; then
    echo "  - Network: joined $NETWORK_ID"
fi
if [ "$CONTAINER_RUNTIME" = "docker" ]; then
    if [[ "$ENABLE_DOCKER" =~ ^y$ ]]; then
        echo "Docker: installed and enabled"
    else
        echo "Docker: installed (auto-start disabled)"
    fi
    echo ""
    echo "Note: You may need to log out and back in for docker group changes to take effect."
elif [ "$CONTAINER_RUNTIME" = "podman" ]; then
    echo "Podman: installed"
fi
