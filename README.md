# InitSys

System initialization scripts for Linux distributions.

## Available Scripts

### 1. Main Installation Script (`install.sh`)

Comprehensive installation script that includes:
- OpenVPN
- ZeroTier
- Vim, curl, wget
- CLI tools: ripgrep, bat, fzf, fd
- Node Exporter
- Docker/Podman

**One-line execution:**
```bash
curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install.sh | bash
```

**Or download and execute:**
```bash
curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install.sh -o install.sh
bash install.sh
```

### 2. Node Exporter Installation Script (`install-node-exporter.sh`)

Standalone script for one-click Node Exporter installation.

**Features:**
- Automatic detection of system architecture (amd64, arm64, armv7)
- Latest version detection from GitHub releases
- Systemd service installation and configuration
- Optional auto-start on boot
- Support for Ubuntu, Debian, CentOS, Fedora

**One-line execution:**
```bash
curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-node-exporter.sh | bash
```

**Or download and execute:**
```bash
curl -fsSL https://raw.githubusercontent.com/JonasGao/initsys/main/install-node-exporter.sh -o install-node-exporter.sh
bash install-node-exporter.sh
```

**What it does:**
1. Detects your system's package manager (apt/dnf/yum)
2. Ensures curl or wget is installed
3. Asks if you want Node Exporter to auto-start on boot
4. Creates a dedicated system user for Node Exporter
5. Downloads and installs the latest Node Exporter binary
6. Installs the systemd service
7. Optionally starts and enables the service

**After installation:**
- Node Exporter metrics will be available at: `http://localhost:9100/metrics`
- Check status: `systemctl status node_exporter`
- Start manually: `sudo systemctl start node_exporter`
- Enable auto-start: `sudo systemctl enable node_exporter`

## Supported Systems

- Ubuntu
- Debian
- CentOS
- Fedora
- Any Linux distribution with systemd and apt/dnf/yum package managers

## Requirements

- Linux with systemd
- Root or sudo privileges
- Internet connection
- curl or wget (will be installed if not present)

## Files

- `install.sh` - Main comprehensive installation script
- `install-node-exporter.sh` - Standalone Node Exporter installation script
- `node_exporter.service` - Systemd service file for Node Exporter

## License

See repository license.
