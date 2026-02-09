#!/bin/bash
# One-click installation script for Node Exporter
# Supports: Ubuntu, Debian, CentOS, Fedora (apt, dnf, yum)
#
# One-line execution:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-node-exporter.sh | bash
#
# Or download and execute:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-node-exporter.sh -o install-node-exporter.sh
#   bash install-node-exporter.sh

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
    echo "Downloading $url ..."
    if command -v curl &>/dev/null; then
        curl -L --progress-bar "$url" -o "$output"
    elif command -v wget &>/dev/null; then
        wget --progress=dot:giga "$url" -O "$output"
    else
        echo "Error: Neither curl nor wget is available."
        return 1
    fi
}

# Ensure curl or wget is installed
echo "=== Checking for curl/wget ==="
if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    echo "curl/wget not found. Installing curl..."
    install_packages curl
fi

# Node Exporter auto-start
echo ""
read -rp "Do you want to enable Node Exporter to start automatically on boot? (y/n): " ENABLE_NODE_EXPORTER < /dev/tty
ENABLE_NODE_EXPORTER=$(echo "$ENABLE_NODE_EXPORTER" | tr '[:upper:]' '[:lower:]')

echo ""
echo "============================================"
echo "=== Configuration Summary ==="
echo "============================================"
echo ""
if [[ "$ENABLE_NODE_EXPORTER" =~ ^y$ ]]; then
    echo "Node Exporter: will be installed (auto-start enabled)"
else
    echo "Node Exporter: will be installed (auto-start disabled)"
fi
echo ""
echo "============================================"
echo ""

read -rp "Proceed with the installation? (y/n): " CONFIRM < /dev/tty
CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [[ ! "$CONFIRM" =~ ^y$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Starting installation..."
echo ""

# Install Node Exporter
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

# Get latest version of node_exporter with fallback on failure
get_latest_node_exporter_version() {
    local api_url="https://api.github.com/repos/prometheus/node_exporter/releases/latest"
    local default_version="1.10.2"

    echo "Detecting latest Node Exporter version from GitHub releases..."

    local response
    if ! response=$(curl -fsSL "$api_url" 2>/dev/null); then
        echo "Warning: Failed to query GitHub API for latest node_exporter release. Falling back to v${default_version}."
        echo "$default_version"
        return 0
    fi

    local version
    version=$(printf '%s\n' "$response" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || true)

    if [ -z "$version" ]; then
        echo "Warning: Could not parse latest node_exporter version from GitHub API response. Falling back to v${default_version}."
        echo "$default_version"
    else
        echo "$version"
    fi
}

NODE_EXPORTER_VERSION="$(get_latest_node_exporter_version)"

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
    exit 1
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
            exit 1
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
                echo "You may need to check the service status manually: systemctl status node_exporter"
            fi
        else
            echo "=== Node Exporter installed but not started ==="
        fi
    fi
fi

# ============================================
# Show installation summary
# ============================================

echo ""
echo "============================================"
echo "=== Installation Complete! ==="
echo "============================================"
echo ""
if [[ "$ENABLE_NODE_EXPORTER" =~ ^y$ ]]; then
    echo "Node Exporter: installed and enabled"
    echo ""
    echo "Node Exporter is now running and will start automatically on boot."
    echo "You can check the status with: systemctl status node_exporter"
    echo "Node Exporter metrics are available at: http://localhost:9100/metrics"
else
    echo "Node Exporter: installed (auto-start disabled)"
    echo ""
    echo "To start Node Exporter manually, run: sudo systemctl start node_exporter"
    echo "To enable auto-start, run: sudo systemctl enable node_exporter"
    echo "Node Exporter metrics will be available at: http://localhost:9100/metrics"
fi
echo ""
echo "============================================"
