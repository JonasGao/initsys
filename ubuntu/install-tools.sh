#!/bin/bash
set -euo pipefail

# Detect if running as root
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

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

# Get latest version of delta with fallback on failure
get_latest_delta_version() {
    local api_url="https://api.github.com/repos/dandavison/delta/releases/latest"
    local default_version="0.18.2"

    local response
    if ! response=$(curl -fsSL "$api_url" 2>/dev/null); then
        echo "Warning: Failed to query GitHub API for latest delta release. Falling back to v${default_version}." >&2
        echo "$default_version"
        return 0
    fi

    local version
    version=$(printf '%s\n' "$response" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || true)

    if [ -z "$version" ]; then
        echo "Warning: Could not parse latest delta version from GitHub API response. Falling back to v${default_version}." >&2
        echo "$default_version"
    else
        echo "$version"
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
    
    # Get latest version of delta
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

# Get latest version of fzf with fallback on failure
get_latest_fzf_version() {
    local api_url="https://api.github.com/repos/junegunn/fzf/releases/latest"
    local default_version="0.56.0"

    local response
    if ! response=$(curl -fsSL "$api_url" 2>/dev/null); then
        echo "Warning: Failed to query GitHub API for latest fzf release. Falling back to v${default_version}." >&2
        echo "$default_version"
        return 0
    fi

    local version
    version=$(printf '%s\n' "$response" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || true)

    if [ -z "$version" ]; then
        echo "Warning: Could not parse latest fzf version from GitHub API response. Falling back to v${default_version}." >&2
        echo "$default_version"
    else
        echo "$version"
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
    
    # Get latest version of fzf
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

# Install base packages
echo "=== Installing base packages ==="
$SUDO apt update
$SUDO apt install -y git fd-find bat ripgrep openssh-server openssh-client curl wget

# Install neovim
echo "=== Installing neovim ==="
$SUDO add-apt-repository ppa:neovim-ppa/stable -y
$SUDO apt update
$SUDO apt install -y neovim

# Install fzf from GitHub release
install_fzf

# Install delta
install_delta_deb

# Set up nvim configuration
echo "=== Setting up nvim configuration ==="
mkdir -p "$HOME/.config/"
git clone https://github.com/JonasGao/nvimrc.git $HOME/.config/nvim

# Set up aliases
echo "=== Setting up aliases ==="
printf """alias fd='fdfind'
alias bat='batcat'
alias n='nvim'
alias k='kubectl'
alias h='helm'
""" >"$HOME/.bash_aliases"

# Set up fzf for bash
printf """
# Fzf for bash
eval "\$(fzf --bash)"
""">> "$HOME/.bashrc"

echo ""
echo "============================================"
echo "=== Tools Installation Complete! ==="
echo "============================================"
echo ""
echo "Installed tools:"
echo "- Git"
echo "- fzf (version $FZF_VERSION)"
echo "- fd-find"
echo "- bat"
echo "- ripgrep"
echo "- openssh-server/openssh-client"
echo "- neovim"
echo "- delta (version $DELTA_VERSION)"
echo ""
echo "Aliases set up in $HOME/.bash_aliases"
echo "Fzf configured in $HOME/.bashrc"
echo "nvim configuration installed from JonasGao/nvimrc"
