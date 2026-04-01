#!/bin/bash
# Install OpenVPN, ZeroTier, Vim, curl, wget, ripgrep, bat, fzf, fd, delta, Node Exporter, Docker/Podman, and custom CA certificates
# Docker is installed using the official get.docker.com script
# OpenVPN auto-start is disabled after installation
# Node Exporter installation is optional and can be skipped
# Node Exporter auto-start can be enabled or disabled based on user preference
# Node Exporter service file is automatically downloaded if not present locally
# Custom CA certificates can be downloaded and trusted automatically
# Supports: Ubuntu, Debian, CentOS (apt, dnf, yum)
#
# Environment variables:
#   MIRROR_PREFIX - Prefix URL for downloading from GitHub (e.g., "https://mirror.example.com/")
#                   This is prepended to all GitHub raw content and release URLs
#   CONFIG_FILE   - Path to configuration file (default: ~/.initsys.conf)
#                   If file exists, configuration is loaded from it and interactive prompts are skipped
#
# One-line execution:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-openvpn-zerotier-docker.sh | bash
#
# Or download and execute:
#   curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-openvpn-zerotier-docker.sh -o install.sh
#   bash install.sh

set -euo pipefail

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-$HOME/.initsys.conf}"

# Apply mirror prefix to URL if MIRROR_PREFIX is set
apply_mirror() {
    local url="$1"
    if [ -n "${MIRROR_PREFIX:-}" ]; then
        echo "${MIRROR_PREFIX}${url}"
    else
        echo "$url"
    fi
}

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
# Configuration management functions
# ============================================

# Save configuration to file
save_config() {
    local config_file="$1"
    echo "# initsys configuration file" > "$config_file"
    echo "# Generated on $(date)" >> "$config_file"
    echo "" >> "$config_file"
    echo "INSTALL_OPENVPN=$INSTALL_OPENVPN" >> "$config_file"
    echo "REPLACE_PLANET=$REPLACE_PLANET" >> "$config_file"
    echo "PLANET_SOURCE=$PLANET_SOURCE" >> "$config_file"
    echo "JOIN_NETWORK=$JOIN_NETWORK" >> "$config_file"
    echo "NETWORK_ID=$NETWORK_ID" >> "$config_file"
    echo "INSTALL_NODE_EXPORTER=$INSTALL_NODE_EXPORTER" >> "$config_file"
    echo "ENABLE_NODE_EXPORTER=$ENABLE_NODE_EXPORTER" >> "$config_file"
    echo "TRUST_CUSTOM_CA=$TRUST_CUSTOM_CA" >> "$config_file"
    echo "CA_URLS_COUNT=${#CA_URLS[@]}" >> "$config_file"
    local i=0
    for url in "${CA_URLS[@]}"; do
        echo "CA_URL_$i=$url" >> "$config_file"
        i=$((i + 1))
    done
    echo "CONTAINER_RUNTIME=$CONTAINER_RUNTIME" >> "$config_file"
    echo "ENABLE_DOCKER=$ENABLE_DOCKER" >> "$config_file"
    chmod 600 "$config_file"
    echo ""
    echo "Configuration saved to: $config_file"
}

# Load configuration from file
load_config() {
    local config_file="$1"
    # shellcheck source=/dev/null
    source "$config_file"
    # Rebuild CA_URLS array
    CA_URLS=()
    for i in $(seq 0 $((CA_URLS_COUNT - 1))); do
        local var_name="CA_URL_$i"
        CA_URLS+=("${!var_name}")
    done
}

# ============================================
# Phase 1: Collect all user choices
# ============================================

# Initialize variables
INSTALL_OPENVPN=""
REPLACE_PLANET=""
PLANET_SOURCE=""
JOIN_NETWORK=""
NETWORK_ID=""
INSTALL_NODE_EXPORTER=""
ENABLE_NODE_EXPORTER=""
TRUST_CUSTOM_CA=""
CA_URLS=()
CONTAINER_RUNTIME=""
ENABLE_DOCKER=""

# Check if config file exists
if [ -f "$CONFIG_FILE" ]; then
    echo "=== Loading configuration from $CONFIG_FILE ==="
    echo ""
    load_config "$CONFIG_FILE"
    echo "Configuration loaded successfully."
    echo ""
else
    echo "=== Configuration ==="
    echo ""
    echo "Note: Your choices will be saved to $CONFIG_FILE for future use."
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

    # Custom CA certificates
    read -rp "Do you need to trust custom CA certificates? (y/n): " TRUST_CUSTOM_CA < /dev/tty
    TRUST_CUSTOM_CA=$(echo "$TRUST_CUSTOM_CA" | tr '[:upper:]' '[:lower:]')
    CA_URLS=()
    if [[ "$TRUST_CUSTOM_CA" =~ ^y$ ]]; then
        echo "Enter CA certificate download URLs or local file paths (one per line, empty line to finish):"
        echo "Note: Only HTTPS URLs are allowed for security. HTTP URLs will be rejected."
        while true; do
            read -rp "CA URL: " CA_URL < /dev/tty
            if [ -z "$CA_URL" ]; then
                break
            fi
            # Basic URL validation
            if [[ "$CA_URL" =~ ^https:// ]]; then
                CA_URLS+=("$CA_URL")
            elif [[ "$CA_URL" =~ ^http:// ]]; then
                echo "Warning: Insecure CA URL (http) is not allowed. Please use https:// or provide a local file path."
            elif [ -f "$CA_URL" ]; then
                # Accept local file paths
                CA_URLS+=("$CA_URL")
            else
                echo "Warning: Invalid URL format or file not found. Please enter a valid HTTPS URL or local file path."
            fi
        done

        # Inform user if no URLs were provided
        if [ ${#CA_URLS[@]} -eq 0 ]; then
            echo "No CA certificate URLs provided. Skipping CA certificate installation."
            TRUST_CUSTOM_CA="n"
        fi
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

    # Save configuration to file
    save_config "$CONFIG_FILE"
    echo ""
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
echo "CLI tools: ripgrep, bat, fzf, fd, zoxide, delta will be installed"
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
if [[ "$TRUST_CUSTOM_CA" =~ ^y$ ]] && [ ${#CA_URLS[@]} -gt 0 ]; then
    echo "Custom CA Certificates: will be downloaded and trusted"
    for url in "${CA_URLS[@]}"; do
        echo "  - $url"
    done
else
    echo "Custom CA Certificates: none"
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
    url=$(apply_mirror "$url")
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





# Install additional tools using the independent script
echo "=== Installing additional tools ==="
# Get the path to the additional tools script
ADDITIONAL_TOOLS_SCRIPT="$(dirname "$0")/install-additional-tools.sh"

if [ -f "$ADDITIONAL_TOOLS_SCRIPT" ]; then
    # Use local script if it exists
    echo "Using local additional tools script..."
    # Make the script executable
    chmod +x "$ADDITIONAL_TOOLS_SCRIPT"
    # Run the independent script
    "$ADDITIONAL_TOOLS_SCRIPT"
else
    # Use curl | bash if local script doesn't exist
    echo "Local additional tools script not found. Using remote script..."
    ADD_TOOLS_URL=$(apply_mirror "https://raw.githubusercontent.com/JonasGao/initsys/main/install-additional-tools.sh")
    curl -fsSL "$ADD_TOOLS_URL" | bash
fi

# Install and trust custom CA certificates
if [[ "$TRUST_CUSTOM_CA" =~ ^y$ ]] && [ ${#CA_URLS[@]} -gt 0 ]; then
    echo "=== Installing custom CA certificates ==="
    
    # Determine CA certificate directory based on distro
    case "$PKG_MANAGER" in
        apt)
            CA_CERT_DIR="/usr/local/share/ca-certificates"
            UPDATE_CA_CMD="update-ca-certificates"
            CA_CERT_EXT=".crt"
            ;;
        dnf|yum)
            CA_CERT_DIR="/etc/pki/ca-trust/source/anchors"
            UPDATE_CA_CMD="update-ca-trust"
            CA_CERT_EXT=".crt"
            ;;
        *)
            echo "Error: Unsupported package manager for CA certificate installation."
            echo "Skipping CA certificate installation."
            TRUST_CUSTOM_CA="n"
            ;;
    esac
    
    # Only proceed if package manager is supported
    if [[ "$TRUST_CUSTOM_CA" =~ ^y$ ]]; then
        # Verify update command exists
        if ! command -v "$UPDATE_CA_CMD" &>/dev/null; then
            echo "Warning: $UPDATE_CA_CMD command not found. CA certificates may not be properly trusted."
        fi
        
        # Create directory if it doesn't exist
        $SUDO mkdir -p "$CA_CERT_DIR"
        
        # Download and install each CA certificate
        CA_INDEX=1
        CA_SUCCESS_COUNT=0
        for url in "${CA_URLS[@]}"; do
            CA_FILENAME="custom-ca-${CA_INDEX}${CA_CERT_EXT}"
            CA_TEMP_FILE="$(mktemp "/tmp/${CA_FILENAME}.XXXXXX")"
            
            # Determine how to obtain the CA certificate:
            # - https:// URL: download securely
            # - otherwise: treat as local file path
            OBTAIN_SUCCESS=false
            if [[ "$url" =~ ^https:// ]]; then
                echo "Downloading CA certificate from $url..."
                if download_file "$url" "$CA_TEMP_FILE"; then
                    OBTAIN_SUCCESS=true
                else
                    echo "Warning: Failed to download CA certificate from $url"
                fi
            else
                # Treat as local file path
                if [ -f "$url" ]; then
                    echo "Using local CA certificate file $url..."
                    if cp "$url" "$CA_TEMP_FILE"; then
                        OBTAIN_SUCCESS=true
                    else
                        echo "Warning: Failed to copy CA certificate from $url"
                    fi
                else
                    echo "Warning: CA source is not an existing local file: $url"
                fi
            fi
            
            if [ "$OBTAIN_SUCCESS" = true ]; then
                # Validate certificate: prefer openssl parse check, fall back to marker check
                CERT_VALID=false
                if command -v openssl >/dev/null 2>&1; then
                    if openssl x509 -noout -in "$CA_TEMP_FILE" >/dev/null 2>&1; then
                        CERT_VALID=true
                    else
                        echo "Warning: Obtained file from $url is not a valid X.509 certificate"
                    fi
                else
                    # Fallback basic validation: check if file contains certificate markers
                    if grep -q "BEGIN CERTIFICATE" "$CA_TEMP_FILE" 2>/dev/null; then
                        CERT_VALID=true
                    else
                        echo "Warning: Obtained file from $url does not appear to be a valid certificate"
                    fi
                fi
                
                if [ "$CERT_VALID" = true ]; then
                    echo "Installing CA certificate as ${CA_FILENAME}..."
                    if $SUDO mv "$CA_TEMP_FILE" "${CA_CERT_DIR}/${CA_FILENAME}" && \
                       $SUDO chmod 644 "${CA_CERT_DIR}/${CA_FILENAME}"; then
                        CA_SUCCESS_COUNT=$((CA_SUCCESS_COUNT + 1))
                    else
                        echo "Warning: Failed to install CA certificate ${CA_FILENAME} from $url (mv/chmod failed)"
                        # Attempt to clean up any partially installed file
                        $SUDO rm -f "$CA_TEMP_FILE" "${CA_CERT_DIR}/${CA_FILENAME}" 2>/dev/null || true
                    fi
                else
                    rm -f "$CA_TEMP_FILE"
                fi
            else
                rm -f "$CA_TEMP_FILE" 2>/dev/null || true
            fi
            CA_INDEX=$((CA_INDEX + 1))
        done
        
        # Update CA trust store if certificates were installed
        if [ $CA_SUCCESS_COUNT -gt 0 ]; then
            echo "Updating CA trust store..."
            if $SUDO $UPDATE_CA_CMD; then
                echo "Custom CA certificates installed and trusted successfully ($CA_SUCCESS_COUNT of ${#CA_URLS[@]} certificate(s))."
            else
                echo "Warning: Failed to update CA trust store. Certificates were installed but may not be trusted."
            fi
        else
            echo "No CA certificates were successfully installed."
            TRUST_CUSTOM_CA="n"
        fi
    fi
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
    
    # Get latest version of node_exporter with fallback on failure
    get_latest_node_exporter_version() {
        local api_url="https://api.github.com/repos/prometheus/node_exporter/releases/latest"
        local default_version="1.10.2"

        echo "Detecting latest Node Exporter version from GitHub releases..." >&2

        local response
        if ! response=$(curl -fsSL "$api_url" 2>/dev/null); then
            echo "Warning: Failed to query GitHub API for latest node_exporter release. Falling back to v${default_version}." >&2
            echo "$default_version"
            return 0
        fi

        local version
        version=$(printf '%s\n' "$response" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || true)

        if [ -z "$version" ]; then
            echo "Warning: Could not parse latest node_exporter version from GitHub API response. Falling back to v${default_version}." >&2
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
# Note: ZeroTier install script is not mirrored - always download directly
curl -fsSL "https://install.zerotier.com" -o "/tmp/install-zerotier.sh"
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
        # Note: Docker install script is not mirrored - always download directly
        curl -fsSL "https://get.docker.com" -o "/tmp/get-docker.sh"
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
echo "CLI tools: ripgrep, bat, fzf, fd, zoxide installed"
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
if [[ "$TRUST_CUSTOM_CA" =~ ^y$ ]] && [ ${#CA_URLS[@]} -gt 0 ]; then
    echo "Custom CA Certificates: installed ($CA_SUCCESS_COUNT of ${#CA_URLS[@]} certificate(s)); see earlier log messages for trust store update status."
fi
