#!/bin/bash
set -e

echo "Starting Remote Desktop Setup for Oracle Linux 10..."

# 1. Install EPEL and CRB (Code Ready Builder) - required for many packages
echo "Enabling EPEL and CRB/Powertools..."
# Checking if dnf config-manager exists, install if not
if ! command -v dnf-config-manager &> /dev/null; then
    sudo dnf install -y 'dnf-command(config-manager)'
fi

# Attempt to install EPEL. For OL, it's often in the oracle-epel-release-elX package or just standard epel-release
sudo dnf install -y oracle-epel-release-el9 || sudo dnf install -y epel-release || echo "Warning: EPEL release package not found via standard names."

# Enable CRB (Code Ready Builder) for dependencies
sudo dnf config-manager --set-enabled ol9_codeready_builder || sudo dnf config-manager --set-enabled crb || echo "Warning: Could not explicitly enable CRB/CodeReady."

# Update repolist to ensure we see new packages
sudo dnf makecache

# 2. Install Desktop Environment (XFCE) and X11 Tools
echo "Installing XFCE Desktop and X11 tools..."
# Try to install XFCE group. If not found, might default to GNOME or fail.
sudo dnf groupinstall -y "Xfce" || echo "Warning: Xfce group not found. Attempting 'Server with GUI'..."
if ! rpm -q xfce4-session &> /dev/null; then
    # Fallback to Server with GUI if XFCE failed, though it's heavy
    sudo dnf groupinstall -y "Server with GUI"
fi

# Install Virtual Display (Xvfb) and VNC Server
sudo dnf install -y xorg-x11-server-Xvfb x11vnc

# 3. Setup Dependencies for Web Access
echo "Installing tool dependencies..."
sudo dnf install -y git wget curl python3 which

# 4. Prepare Directories
BASE_DIR="$HOME/remote-desktop"
BIN_DIR="$BASE_DIR/bin"
LIB_DIR="$BASE_DIR/lib"
mkdir -p "$BIN_DIR" "$LIB_DIR"

# 5. Download Cloudflared
if [ ! -f "$BIN_DIR/cloudflared" ]; then
    echo "Downloading Cloudflared..."
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o "$BIN_DIR/cloudflared"
    chmod +x "$BIN_DIR/cloudflared"
fi

# 6. Download noVNC and Websockify
if [ ! -d "$LIB_DIR/noVNC" ]; then
    echo "Cloning noVNC..."
    git clone https://github.com/novnc/noVNC.git "$LIB_DIR/noVNC"
fi

if [ ! -d "$LIB_DIR/noVNC/utils/websockify" ]; then
    echo "Cloning websockify..."
    git clone https://github.com/novnc/websockify "$LIB_DIR/noVNC/utils/websockify"
fi

# 7. Create Startup Script
START_SCRIPT="$BASE_DIR/start_desktop.sh"
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
RESOLUTION="1280x720x24"

echo "------------------------------------------------------------------"
echo "              Antigravity Remote Desktop"
echo "------------------------------------------------------------------"

# Cleanup
pkill -f "Xvfb $DISPLAY_NUM" || true
pkill -f "x11vnc .* $DISPLAY_NUM" || true
pkill -f "novnc_proxy" || true
pkill -f "cloudflared tunnel" || true
pkill -f "xfce4-session" || true

# Password Setup
if [ ! -f "$PASS_FILE" ]; then
    echo "No password found. Generating default password 'antigravity'"
    x11vnc -storepasswd "antigravity" "$PASS_FILE"
fi

# 1. Start Xvfb (Virtual Screen)
echo "🖥️  Starting Virtual Display ($RESOLUTION)..."
Xvfb $DISPLAY_NUM -screen 0 $RESOLUTION > "$LOG_DIR/xvfb.log" 2>&1 &
sleep 2

# 2. Start Desktop Environment
export DISPLAY=$DISPLAY_NUM
echo "🖼️  Starting Desktop Environment..."
if command -v xfce4-session &> /dev/null; then
    xfce4-session > "$LOG_DIR/desktop.log" 2>&1 &
elif command -v gnome-session &> /dev/null; then
    gnome-session > "$LOG_DIR/desktop.log" 2>&1 &
else
    echo "⚠️ No desktop session found! Trying just xterm."
    xterm &
fi

# 3. Start VNC Server
echo "🚀 Starting VNC Server..."
x11vnc -display $DISPLAY_NUM -rfbauth "$PASS_FILE" -forever -shared -bg -o "$LOG_DIR/x11vnc.log"

# 4. Start noVNC
echo "🌐 Starting noVNC..."
"$LIB_DIR/noVNC/utils/novnc_proxy" --vnc localhost:5900 --listen 6080 > "$LOG_DIR/novnc.log" 2>&1 &
NOVNC_PID=$!

# 5. Start Cloudflare Tunnel
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
echo "To start the desktop, run: ~/remote-desktop/start_desktop.sh"
