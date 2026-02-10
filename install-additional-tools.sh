#!/bin/bash
# Install additional tools: Vim, curl, wget, ripgrep, bat, fzf, fd, zoxide, delta
# Supports: Ubuntu, Debian, CentOS (apt, dnf, yum)
# No interactive prompts - automatically installs all tools

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

# Install delta from .deb file
install_delta_deb() {
    echo "=== Installing delta (git-delta) from .deb package ==="
    
    # Detect system architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            DELTA_ARCH="amd64"
            ;;
        aarch64|arm64)
            DELTA_ARCH="arm64"
            ;;
        *)
            echo "Warning: Unsupported architecture $ARCH for delta. Skipping delta installation."
            return 1
            ;;
    esac
    
    # Get latest version of delta with fallback on failure
    get_latest_delta_version() {
        local api_url="https://api.github.com/repos/dandavison/delta/releases/latest"
        local default_version="0.18.2"

        local response
        if ! response=$(curl -fsSL "$api_url" 2>/dev/null); then
            echo "Warning: Failed to query GitHub API for latest delta release. Falling back to v${default_version}."
            echo "$default_version"
            return 0
        fi

        local version
        version=$(printf '%s\n' "$response" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || true)

        if [ -z "$version" ]; then
            echo "Warning: Could not parse latest delta version from GitHub API response. Falling back to v${default_version}."
            echo "$default_version"
        else
            echo "$version"
        fi
    }

    DELTA_VERSION="$(get_latest_delta_version)"
    
    echo "Installing delta version $DELTA_VERSION for architecture $DELTA_ARCH..."
    
    # Download .deb file
    DELTA_DEB_URL="https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${DELTA_ARCH}.deb"
    DELTA_TEMP_DEB=$(mktemp /tmp/delta_XXXXXX.deb)
    
    if download_file "$DELTA_DEB_URL" "$DELTA_TEMP_DEB"; then
        # Install .deb file
        if $SUDO dpkg -i "$DELTA_TEMP_DEB"; then
            echo "Delta installed successfully from .deb package"
            rm -f "$DELTA_TEMP_DEB"
            return 0
        else
            echo "Warning: Failed to install delta .deb package. Trying to fix dependencies..."
            $SUDO apt-get install -f -y
            if $SUDO dpkg -i "$DELTA_TEMP_DEB"; then
                echo "Delta installed successfully after fixing dependencies"
                rm -f "$DELTA_TEMP_DEB"
                return 0
            else
                echo "Warning: Failed to install delta .deb package."
                rm -f "$DELTA_TEMP_DEB"
                return 1
            fi
        fi
    else
        echo "Warning: Failed to download delta .deb file from $DELTA_DEB_URL."
        rm -f "$DELTA_TEMP_DEB"
        return 1
    fi
}

# Install fzf from GitHub release
install_fzf() {
    echo "=== Installing fzf from GitHub release ==="
    
    # Detect system architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            FZF_ARCH="linux_amd64"
            ;;
        aarch64|arm64)
            FZF_ARCH="linux_arm64"
            ;;
        *)
            echo "Warning: Unsupported architecture $ARCH for fzf. Skipping fzf installation."
            return 1
            ;;
    esac
    
    # Get latest version of fzf with fallback on failure
    get_latest_fzf_version() {
        local api_url="https://api.github.com/repos/junegunn/fzf/releases/latest"
        local default_version="0.56.0"

        local response
        if ! response=$(curl -fsSL "$api_url" 2>/dev/null); then
            echo "Warning: Failed to query GitHub API for latest fzf release. Falling back to v${default_version}."
            echo "$default_version"
            return 0
        fi

        local version
        version=$(printf '%s\n' "$response" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || true)

        if [ -z "$version" ]; then
            echo "Warning: Could not parse latest fzf version from GitHub API response. Falling back to v${default_version}."
            echo "$default_version"
        else
            echo "$version"
        fi
    }

    FZF_VERSION="$(get_latest_fzf_version)"
    
    echo "Installing fzf version $FZF_VERSION for architecture $FZF_ARCH..."
    
    # Download fzf
    FZF_URL="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${FZF_ARCH}.tar.gz"
    FZF_TEMP_FILE=$(mktemp /tmp/fzf_XXXXXX.tar.gz)
    
    if download_file "$FZF_URL" "$FZF_TEMP_FILE"; then
        # Extract fzf
        FZF_TEMP_DIR=$(mktemp -d /tmp/fzf_XXXXXX)
        tar xzf "$FZF_TEMP_FILE" -C "$FZF_TEMP_DIR"
        
        # Install fzf
        if $SUDO mv "$FZF_TEMP_DIR/fzf" /usr/local/bin/ && \
           $SUDO chmod +x /usr/local/bin/fzf; then
            echo "fzf installed successfully from GitHub release"
            
            # Install fzf key bindings and completion
            if [ -d "$HOME/.fzf" ]; then
                echo "fzf configuration directory already exists, skipping setup"
            else
                echo "Installing fzf key bindings and completion..."
                # Run fzf's setup script
                if "$FZF_TEMP_DIR/install" --key-bindings --completion --no-update-rc; then
                    echo "fzf key bindings and completion installed successfully"
                else
                    echo "Warning: Failed to install fzf key bindings and completion"
                fi
            fi
            
            # Clean up
            rm -rf "$FZF_TEMP_FILE" "$FZF_TEMP_DIR"
            return 0
        else
            echo "Warning: Failed to install fzf"
            rm -rf "$FZF_TEMP_FILE" "$FZF_TEMP_DIR"
            return 1
        fi
    else
        echo "Warning: Failed to download fzf from $FZF_URL"
        rm -f "$FZF_TEMP_FILE"
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
echo "=== Installing ripgrep, bat, fd, zoxide, and delta ==="
case "$PKG_MANAGER" in
    apt)
        install_packages ripgrep bat fd-find
        # Install delta from .deb file
        install_delta_deb
        # Install zoxide for apt-based systems
        if ! command -v zoxide &>/dev/null; then
            echo "Installing zoxide..."
            curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        fi
        # fd-find on Debian/Ubuntu installs as fdfind, create symlink
        if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
            $SUDO ln -sf "$(which fdfind)" /usr/local/bin/fd || true
        fi
        ;;
    dnf|yum)
        install_packages ripgrep bat fd-find git-delta
        # Install zoxide for dnf/yum-based systems
        if ! command -v zoxide &>/dev/null; then
            echo "Installing zoxide..."
            curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        fi
        ;;
esac

# Install fzf from GitHub release
install_fzf

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

echo ""
echo "============================================"
echo "=== Additional Tools Installation Complete! ==="
echo "============================================"
echo ""
echo "Vim: installed"
echo "curl/wget: installed"
echo "CLI tools: ripgrep, bat, fzf, fd, zoxide installed"
