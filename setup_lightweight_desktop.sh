#!/bin/bash
set -e

echo "Starting Lightweight Desktop Setup (Openbox)..."

# 1. Disable Heavy GUI (GNOME) to free RAM
echo "Disabling GNOME/GDM on boot..."
sudo systemctl set-default multi-user.target
sudo systemctl stop gdm || true

# 2. Install Openbox, TigerVNC, and basic tools
echo "Installing Openbox and VNC..."
# Enable EPEL 10 for Oracle Linux
sudo dnf install -y oracle-epel-release-el10
# Explicitly enable the repo we found
sudo dnf config-manager --set-enabled ol10_u0_developer_EPEL || true
# CRB is also needed often
sudo dnf config-manager --set-enabled ol10_codeready_builder || sudo dnf config-manager --set-enabled crb || true
sudo dnf makecache

# Install Openbox and VNC
sudo dnf install -y openbox tigervnc-server xorg-x11-server-utils xterm python3 git wget curl

# 3. Setup Dependencies for Web Access (Cloudflare/noVNC)
BASE_DIR="$HOME/remote-desktop"
BIN_DIR="$BASE_DIR/bin"
LIB_DIR="$BASE_DIR/lib"
mkdir -p "$BIN_DIR" "$LIB_DIR"

# Download Cloudflared (if missing)
if [ ! -f "$BIN_DIR/cloudflared" ]; then
    echo "Downloading Cloudflared..."
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o "$BIN_DIR/cloudflared"
    chmod +x "$BIN_DIR/cloudflared"
fi

# Clone noVNC (if missing)
if [ ! -d "$LIB_DIR/noVNC" ]; then
    echo "Cloning noVNC..."
    git clone https://github.com/novnc/noVNC.git "$LIB_DIR/noVNC"
fi
if [ ! -d "$LIB_DIR/noVNC/utils/websockify" ]; then
    git clone https://github.com/novnc/websockify "$LIB_DIR/noVNC/utils/websockify"
fi

# 4. Create Startup Script
START_SCRIPT="$BASE_DIR/start_lightweight.sh"
echo "Creating start script at $START_SCRIPT..."

cat > "$START_SCRIPT" << 'EOF'
#!/bin/bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$BASE_DIR/bin"
LIB_DIR="$BASE_DIR/lib"
PASS_FILE="$BASE_DIR/vnc.pass"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

# Config
DISPLAY_NUM=":1"
RESOLUTION="1280x720"

echo "------------------------------------------------------------------"
echo "              Antigravity Lightweight Desktop (Openbox)"
echo "------------------------------------------------------------------"

# Cleanup
pkill -f "Xvnc $DISPLAY_NUM" || true
pkill -f "novnc_proxy" || true
pkill -f "cloudflared tunnel" || true
pkill -f "openbox" || true
rm -f /tmp/.X11-unix/X${DISPLAY_NUM:1}

# Password Setup
if [ ! -f "$PASS_FILE" ]; then
    echo "No password found. Generating default password 'antigravity'"
    # TigerVNC `vncpasswd -f` reads from stdin and writes to stdout.
    echo "antigravity" | vncpasswd -f > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
fi

# 1. Start TigerVNC (which handles X server)
echo "🚀 Starting TigerVNC Server (Openbox)..."
# Create xstartup if needed
mkdir -p $HOME/.vnc
cat > $HOME/.vnc/xstartup << 'VNCSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec openbox-session &
VNCSTART
chmod +x $HOME/.vnc/xstartup

# Launch Xvnc directly
Xvnc $DISPLAY_NUM -geometry $RESOLUTION -rfbauth "$PASS_FILE" -rfbport 5901 &
XVNC_PID=$!
sleep 2

# 2. Start noVNC
echo "🌐 Starting noVNC..."
"$LIB_DIR/noVNC/utils/novnc_proxy" --vnc localhost:5901 --listen 6080 > "$LOG_DIR/novnc.log" 2>&1 &
NOVNC_PID=$!

# 3. Start Cloudflare Tunnel
echo "🚇 Starting Tunnel..."
"$BIN_DIR/cloudflared" tunnel --url http://localhost:6080 > "$LOG_DIR/tunnel.log" 2>&1 &
TUNNEL_PID=$!

echo "⏳ Waiting for tunnel URL..."
sleep 8
URL=$(grep -o 'https://.*\.trycloudflare\.com' "$LOG_DIR/tunnel.log" | head -n 1)

if [ -z "$URL" ]; then
    echo "⚠️ Tunnel URL not found yet. Check logs/tunnel.log"
else
    echo "=========================================="
    echo "ACCESS URL: $URL/vnc.html"
    echo "PASSWORD:   antigravity"
    echo "=========================================="
fi

# Keep script running
wait $NOVNC_PID
EOF

chmod +x "$START_SCRIPT"

echo "✅ Setup script completed."
echo "To start the desktop, run: ~/remote-desktop/start_lightweight.sh"
