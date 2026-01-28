#!/bin/bash
# Install OpenVPN, ZeroTier, Vim, curl, wget, ripgrep, bat, fzf, fd, Node Exporter, and Docker/Podman
# Docker is installed using the official get.docker.com script
# OpenVPN auto-start is disabled after installation
# Node Exporter auto-start can be enabled or disabled based on user preference
# Node Exporter service file is automatically downloaded if not present locally
# Supports: Ubuntu, Debian, CentOS (apt, dnf, yum)
#
# One-line execution:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-openvpn-zerotier-docker.sh | bash
#
# Or download and execute:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-openvpn-zerotier-docker.sh -o install.sh
#   bash install.sh

set -euo pipefail

# Detect if running as root
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

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

# Node Exporter installation
read -rp "Do you want to install Node Exporter? (y/n): " INSTALL_NODE_EXPORTER < /dev/tty
INSTALL_NODE_EXPORTER=$(echo "$INSTALL_NODE_EXPORTER" | tr '[:upper:]' '[:lower:]')

# Node Exporter auto-start (only ask if installing)
ENABLE_NODE_EXPORTER=""
if [[ "$INSTALL_NODE_EXPORTER" =~ ^y$ ]]; then
    read -rp "Do you want to enable Node Exporter to start automatically on boot? (y/n): " ENABLE_NODE_EXPORTER < /dev/tty
    ENABLE_NODE_EXPORTER=$(echo "$ENABLE_NODE_EXPORTER" | tr '[:upper:]' '[:lower:]')
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
echo "curl/wget: will be installed"
echo "CLI tools: ripgrep, bat, fzf, fd will be installed"
if [[ "$INSTALL_NODE_EXPORTER" =~ ^y$ ]]; then
    if [[ "$ENABLE_NODE_EXPORTER" =~ ^y$ ]]; then
        echo "Node Exporter: will be installed (auto-start enabled)"
    else
        echo "Node Exporter: will be installed (auto-start disabled)"
    fi
else
    echo "Node Exporter: will be skipped"
fi
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
            $SUDO apt-get update
            $SUDO apt-get install -y "$@"
            ;;
        dnf)
            $SUDO dnf install -y "$@"
            ;;
        yum)
            $SUDO yum install -y "$@"
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

# Install curl and wget
echo "=== Installing curl and wget ==="
install_packages curl wget

# Install additional CLI tools
echo "=== Installing ripgrep, bat, fzf, and fd ==="
case "$PKG_MANAGER" in
    apt)
        install_packages ripgrep bat fzf fd-find
        # fd-find on Debian/Ubuntu installs as fdfind, create symlink
        if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
            $SUDO ln -sf "$(which fdfind)" /usr/local/bin/fd || true
        fi
        ;;
    dnf|yum)
        install_packages ripgrep bat fzf fd-find
        ;;
esac

# Configure ripgrep alias
echo "=== Configuring ripgrep alias ==="
RG_ALIAS='alias rg="rg"'
BASHRC_FILES=("/etc/bash.bashrc" "/etc/bashrc" "$HOME/.bashrc")
ALIAS_ADDED=false

for bashrc in "${BASHRC_FILES[@]}"; do
    if [ -f "$bashrc" ]; then
        if ! grep -q "alias rg=" "$bashrc" 2>/dev/null; then
            echo "$RG_ALIAS" | $SUDO tee -a "$bashrc" >/dev/null || echo "$RG_ALIAS" >> "$bashrc" 2>/dev/null || true
            ALIAS_ADDED=true
            echo "Added rg alias to $bashrc"
            break
        fi
    fi
done

if [ "$ALIAS_ADDED" = false ]; then
    echo "Note: rg alias not added (ripgrep command is already available as 'rg')"
fi

# Install Node Exporter
if [[ "$INSTALL_NODE_EXPORTER" =~ ^y$ ]]; then
    echo "=== Installing Node Exporter ==="
    
    # Create dedicated system user for Node Exporter
    if ! id -u node_exporter &>/dev/null; then
        echo "Creating system user for Node Exporter..."
        $SUDO useradd --no-create-home --shell /bin/false node_exporter
    fi
    
    # Detect system architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            NODE_EXPORTER_ARCH="amd64"
            ;;
        aarch64|arm64)
            NODE_EXPORTER_ARCH="arm64"
            ;;
        armv7l)
            NODE_EXPORTER_ARCH="armv7"
            ;;
        *)
            echo "Warning: Unsupported architecture $ARCH. Defaulting to amd64."
            NODE_EXPORTER_ARCH="amd64"
            ;;
    esac
    
    # Get latest version of node_exporter
    NODE_EXPORTER_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "$NODE_EXPORTER_VERSION" ]; then
        echo "Warning: Could not detect latest version. Using v1.7.0 as default."
        NODE_EXPORTER_VERSION="1.7.0"
    fi
    
    echo "Installing Node Exporter version $NODE_EXPORTER_VERSION for architecture $NODE_EXPORTER_ARCH..."
    
    # Download and install node_exporter
    NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${NODE_EXPORTER_ARCH}.tar.gz"
    download_file "$NODE_EXPORTER_URL" /tmp/node_exporter.tar.gz
    
    # Extract and install in a subshell to avoid changing working directory
    (
        cd /tmp
        tar xzf node_exporter.tar.gz
        $SUDO mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-${NODE_EXPORTER_ARCH}/node_exporter" /usr/local/bin/
        $SUDO chmod +x /usr/local/bin/node_exporter
    )
    
    # Clean up
    rm -rf /tmp/node_exporter.tar.gz "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${NODE_EXPORTER_ARCH}" || true
    
    # Get the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
    
    # Verify node_exporter binary was installed successfully
    if [ ! -f /usr/local/bin/node_exporter ]; then
        echo "Error: Failed to install Node Exporter binary to /usr/local/bin/node_exporter"
        echo "Skipping systemd service installation."
    else
        echo "Node Exporter binary installed successfully to /usr/local/bin/node_exporter"
        
        # Install systemd service
        SERVICE_FILE_URL="https://raw.githubusercontent.com/JonasGao/initsys/main/node_exporter.service"
        
        if [ -f "$SCRIPT_DIR/node_exporter.service" ]; then
            echo "Installing Node Exporter systemd service from local file..."
            $SUDO cp "$SCRIPT_DIR/node_exporter.service" /etc/systemd/system/
        else
            echo "Local service file not found. Downloading from GitHub..."
            if download_file "$SERVICE_FILE_URL" /tmp/node_exporter.service; then
                echo "Installing Node Exporter systemd service from downloaded file..."
                $SUDO mv /tmp/node_exporter.service /etc/systemd/system/
            else
                echo "Error: Failed to download node_exporter.service from $SERVICE_FILE_URL"
                echo "Skipping systemd service installation."
                echo "You can manually download the service file and install it later."
            fi
        fi
        
        # Only proceed if service file was installed
        if [ -f /etc/systemd/system/node_exporter.service ]; then
            $SUDO systemctl daemon-reload
            
            if [[ "$ENABLE_NODE_EXPORTER" =~ ^y$ ]]; then
                echo "=== Starting and enabling Node Exporter ==="
                if $SUDO systemctl start node_exporter && $SUDO systemctl enable node_exporter; then
                    echo "Node Exporter service started and enabled successfully."
                else
                    echo "Warning: Failed to start or enable Node Exporter service."
                fi
            else
                echo "=== Node Exporter installed but not started ==="
            fi
        fi
    fi
fi

# Install OpenVPN
if [[ "$INSTALL_OPENVPN" =~ ^y$ ]]; then
    echo "=== Installing OpenVPN ==="
    install_packages openvpn

    echo "=== Disabling OpenVPN auto-start ==="
    $SUDO systemctl stop openvpn || true
    $SUDO systemctl disable openvpn || true
    # Disable any OpenVPN instance services (openvpn@server, openvpn@client, etc.)
    for service in $($SUDO systemctl list-units 'openvpn@*' --all --no-legend 2>/dev/null | awk '{print $1}'); do
        $SUDO systemctl stop "$service" || true
        $SUDO systemctl disable "$service" || true
    done
fi

# Install ZeroTier
echo "=== Installing ZeroTier ==="
curl -fsSL https://install.zerotier.com -o /tmp/install-zerotier.sh
$SUDO bash /tmp/install-zerotier.sh
rm /tmp/install-zerotier.sh

# Replace ZeroTier planet file
if [[ "$REPLACE_PLANET" =~ ^y$ ]] && [ -n "$PLANET_SOURCE" ]; then
    ZEROTIER_DIR="/var/lib/zerotier-one"
    PLANET_FILE="$ZEROTIER_DIR/planet"
    BACKUP_FILE="$ZEROTIER_DIR/planet.backup.$(date +%Y%m%d%H%M%S)"
    
    echo "Stopping ZeroTier service..."
    $SUDO systemctl stop zerotier-one || true
    
    # Backup original planet file
    if [ -f "$PLANET_FILE" ]; then
        echo "Backing up original planet file to $BACKUP_FILE..."
        $SUDO cp "$PLANET_FILE" "$BACKUP_FILE"
    fi
    
    # Download or copy planet file
    if [[ "$PLANET_SOURCE" =~ ^https?:// ]]; then
        echo "Downloading planet file from $PLANET_SOURCE..."
        download_file "$PLANET_SOURCE" /tmp/planet.new
        if [ ! -f /tmp/planet.new ]; then
            echo "Error: Failed to download planet file."
            $SUDO systemctl start zerotier-one
            exit 1
        fi
        $SUDO mv /tmp/planet.new "$PLANET_FILE"
    else
        if [ ! -f "$PLANET_SOURCE" ] || [ ! -r "$PLANET_SOURCE" ]; then
            echo "Error: Planet file '$PLANET_SOURCE' does not exist or is not readable."
            $SUDO systemctl start zerotier-one
            exit 1
        fi
        echo "Copying planet file from $PLANET_SOURCE..."
        $SUDO cp "$PLANET_SOURCE" "$PLANET_FILE"
    fi
    
    echo "Restarting ZeroTier service..."
    $SUDO systemctl start zerotier-one
    echo "ZeroTier planet file replaced successfully."
fi

# Join ZeroTier network
if [[ "$JOIN_NETWORK" =~ ^y$ ]] && [ -n "$NETWORK_ID" ]; then
    echo "Waiting for ZeroTier service to be ready..."
    sleep 3
    echo "Joining ZeroTier network $NETWORK_ID..."
    if $SUDO zerotier-cli join "$NETWORK_ID"; then
        echo ""
        echo "Network status:"
        $SUDO zerotier-cli listnetworks || echo "Warning: Failed to get network status."
    else
        echo "Error: Failed to join ZeroTier network $NETWORK_ID."
    fi
fi

# Install container runtime
if [ "$CONTAINER_RUNTIME" = "podman" ]; then
    echo "=== Installing Podman ==="
    if command -v podman &>/dev/null; then
        echo "Podman is already installed. Skipping installation."
        podman --version
    else
        install_packages podman
        echo "Podman installed successfully."
    fi
elif [ "$CONTAINER_RUNTIME" = "docker" ]; then
    echo "=== Installing Docker using get.docker.com ==="
    DOCKER_ALREADY_INSTALLED=false
    if command -v docker &>/dev/null; then
        echo "Docker is already installed. Skipping installation."
        docker --version
        DOCKER_ALREADY_INSTALLED=true
    else
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        $SUDO sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
    fi
    
    if [[ "$ENABLE_DOCKER" =~ ^y$ ]]; then
        echo "=== Starting and enabling Docker ==="
        $SUDO systemctl start docker
        $SUDO systemctl enable docker
    else
        echo "=== Disabling Docker auto-start ==="
        $SUDO systemctl stop docker || true
        $SUDO systemctl disable docker || true
    fi
    
    echo "=== Adding current user to docker group ==="
    # Note: This grants the user root-equivalent privileges since Docker daemon runs as root
    $SUDO usermod -aG docker "$USER"
    
    if [ "$DOCKER_ALREADY_INSTALLED" = true ]; then
        echo "Docker setup complete."
    else
        echo "Docker installed successfully."
    fi
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
echo "curl/wget: installed"
echo "CLI tools: ripgrep, bat, fzf, fd installed"
if [[ "$INSTALL_NODE_EXPORTER" =~ ^y$ ]]; then
    if [[ "$ENABLE_NODE_EXPORTER" =~ ^y$ ]]; then
        echo "Node Exporter: installed and enabled"
    else
        echo "Node Exporter: installed (auto-start disabled)"
    fi
else
    echo "Node Exporter: skipped"
fi
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
