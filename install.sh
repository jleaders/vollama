#!/bin/bash
# Vollama installer for Linux
# Usage: curl -fsSL https://vollama.dev/install.sh | sudo bash
set -euo pipefail

VOLLAMA_VERSION="${VOLLAMA_VERSION:-latest}"
DOWNLOAD_BASE="https://github.com/jleaders/vollama/releases"

status() { echo ">>> $*"; }
error()  { echo "ERROR: $*" >&2; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
    error "Run as root: curl -fsSL https://vollama.dev/install.sh | sudo bash"
fi

ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [ "$OS" != "linux" ]; then
    error "This installer is for Linux only"
fi

echo ""
echo "  Vollama Installer"
echo "  ================="
echo ""

# Prefer .deb on Debian/Ubuntu systems
if command -v dpkg &>/dev/null; then
    DEB_NAME="vollama_${VOLLAMA_VERSION}_${ARCH}.deb"
    if [ "$VOLLAMA_VERSION" = "latest" ]; then
        URL="$DOWNLOAD_BASE/latest/download/vollama_${ARCH}.deb"
    else
        URL="$DOWNLOAD_BASE/download/${VOLLAMA_VERSION}/${DEB_NAME}"
    fi

    TMPFILE=$(mktemp --suffix=.deb)
    trap "rm -f '$TMPFILE'" EXIT

    status "Downloading vollama .deb package ($ARCH)..."
    if command -v curl &>/dev/null; then
        curl -fSL --progress-bar -o "$TMPFILE" "$URL"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$TMPFILE" "$URL"
    else
        error "curl or wget is required"
    fi

    status "Installing .deb package..."
    dpkg -i "$TMPFILE"

    echo ""
    status "Done! Vollama is running."
    echo ""
    echo "  vollama models              # list available models"
    echo "  vollama run <model>         # load and chat"
    echo "  systemctl status vollama    # service status"
    echo "  sudo apt remove vollama     # uninstall"
    echo ""
else
    # Fallback for non-Debian systems: direct binary install
    URL="$DOWNLOAD_BASE/latest/download/vollama-${OS}-${ARCH}"

    TMPFILE=$(mktemp)
    trap "rm -f '$TMPFILE'" EXIT

    status "Downloading vollama binary ($OS/$ARCH)..."
    if command -v curl &>/dev/null; then
        curl -fSL --progress-bar -o "$TMPFILE" "$URL"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$TMPFILE" "$URL"
    else
        error "curl or wget is required"
    fi

    install -m 755 "$TMPFILE" /usr/local/bin/vollama
    status "Installed /usr/local/bin/vollama"

    # Determine service user (the user who invoked sudo)
    SVCUSER="${SUDO_USER:-$(whoami)}"
    SVCHOME=$(eval echo "~$SVCUSER")
    if [ "$SVCUSER" = "root" ] || [ -z "$SVCHOME" ] || [ ! -d "$SVCHOME" ]; then
        for d in /home/*/; do
            u=$(basename "$d")
            if id "$u" &>/dev/null; then
                SVCUSER="$u"
                SVCHOME="$d"
                break
            fi
        done
    fi

    usermod -aG video "$SVCUSER" 2>/dev/null || true
    getent group render &>/dev/null && usermod -aG render "$SVCUSER" 2>/dev/null || true

    # Ensure user config directories exist
    su - "$SVCUSER" -c 'mkdir -p ~/.config/vollama/recipes ~/.cache/huggingface' 2>/dev/null || true

    # Install systemd unit
    cat > /etc/systemd/system/vollama.service <<'UNIT'
[Unit]
Description=Vollama Model Server
After=network-online.target

[Service]
ExecStart=/usr/local/bin/vollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
UNIT

    # Write user drop-in
    mkdir -p /etc/systemd/system/vollama.service.d
    cat > /etc/systemd/system/vollama.service.d/user.conf <<DROPIN
[Service]
User=$SVCUSER
Environment="HOME=$SVCHOME"
DROPIN

    # Detect backends and write PATH drop-in
    EXTRA_DIRS=""
    for bin in llama-server vllm; do
        p=$(su - "$SVCUSER" -c "command -v $bin 2>/dev/null" 2>/dev/null || true)
        [ -n "$p" ] && EXTRA_DIRS="${EXTRA_DIRS:+$EXTRA_DIRS:}$(dirname "$p")"
    done
    if [ -n "$EXTRA_DIRS" ]; then
        cat > /etc/systemd/system/vollama.service.d/backends.conf <<DROPIN
[Service]
Environment="PATH=$EXTRA_DIRS:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
DROPIN
    fi

    systemctl daemon-reload
    systemctl enable vollama.service
    systemctl restart vollama.service || true

    echo ""
    status "Done! Vollama is running as $SVCUSER."
    echo ""
    echo "  vollama models              # list available models"
    echo "  vollama run <model>         # load and chat"
    echo "  vollama doctor              # check setup"
    echo "  vollama doctor --fix        # fix missing backends"
    echo "  systemctl status vollama    # service status"
    echo ""
fi
