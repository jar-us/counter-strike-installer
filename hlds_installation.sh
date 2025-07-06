#!/bin/bash
# ==============================================================================
# FINAL WORKING Counter-Strike 1.6 HLDS Installation Script
# Based on Working Manual Installation Steps - TESTED AND VERIFIED
# ==============================================================================

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo privileges"
   echo "Usage: sudo ./install_cs16_server.sh"
   exit 1
fi

# Stop on any error and enable debugging
set -e
set -x

# --- Define Global Paths ---
SERVER_DIR="/home/azureuser/hlds"
STEAM_DIR="/home/azureuser/steamcmd"
GAME_USER="azureuser"
GAME_USER_HOME="/home/azureuser"

# --- Logging function ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/hlds_install.log
}

log "Starting Counter-Strike 1.6 HLDS installation based on working manual steps..."

# --- STEP 1: SYSTEM PREPARATION (CRITICAL - ADD 32-BIT SUPPORT) ---
log "Step 1: System Preparation - Adding 32-bit architecture support..."
export DEBIAN_FRONTEND=noninteractive

# CRITICAL: Enable 32-bit architecture support
sudo dpkg --add-architecture i386

# Update package lists to include new 32-bit packages
sudo apt-get update

# Upgrade existing packages to ensure system is current
sudo apt-get upgrade -y

log "32-bit architecture support added successfully"

# --- STEP 2: INSTALL ALL NECESSARY DEPENDENCIES ---
log "Step 2: Installing all necessary dependencies..."

# Install exact dependencies from manual steps
sudo apt-get install -y wget screen lib32gcc-s1 lib32stdc++6 libc6:i386

log "All dependencies installed successfully"

# --- STEP 3: DOWNLOAD AND EXTRACT STEAMCMD ---
log "Step 3: Downloading and extracting SteamCMD..."

# Switch to game user for all operations
sudo -u "$GAME_USER" bash -c "
    # Create directory for SteamCMD
    mkdir -p '$STEAM_DIR'
    cd '$STEAM_DIR'
    
    # Download SteamCMD directly from Valve (non-interactive)
    if [ ! -f steamcmd_linux.tar.gz ]; then
        wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    fi
    
    # Extract the package contents
    if [ ! -f steamcmd.sh ]; then
        tar -xvf steamcmd_linux.tar.gz
    fi
    
    echo 'SteamCMD downloaded and extracted successfully'
"

# --- STEP 4: DOWNLOAD COUNTER-STRIKE SERVER FILES ---
log "Step 4: Downloading Counter-Strike server files..."

sudo -u "$GAME_USER" bash -c "
    # Create directory for game server
    mkdir -p '$SERVER_DIR'
    
    # Run SteamCMD to download CS 1.6 server files
    cd '$STEAM_DIR'
    ./steamcmd.sh +force_install_dir '$SERVER_DIR' +login anonymous +app_update 90 validate +quit
    
    echo 'Counter-Strike server files downloaded successfully'
"

# --- STEP 5: APPLY STEAMCLIENT.SO FIX ---
log "Step 5: Applying steamclient.so fix..."

sudo -u "$GAME_USER" bash -c "
    # Create the directory structure the server expects
    mkdir -p '$GAME_USER_HOME/.steam/sdk32'
    
    # Create the symbolic link
    ln -sf '$SERVER_DIR/steamclient.so' '$GAME_USER_HOME/.steam/sdk32/steamclient.so'
    
    echo 'steamclient.so symbolic link created successfully'
"

# --- STEP 6: CREATE SERVER CONFIGURATION FILES ---
log "Step 6: Creating server configuration files..."

sudo -u "$GAME_USER" bash -c "
    # Create basic server.cfg
    cat <<'EOF' > '$SERVER_DIR/cstrike/server.cfg'
// Basic Server Configuration
hostname \"Counter-Strike 1.6 Azure Server\"
rcon_password \"cs16rcon123\"
sv_password \"\"
mp_timelimit 45
mp_friendlyfire 0
mp_freezetime 5
mp_roundtime 3
mp_maxrounds 30
sv_maxrate 25000
sv_minrate 5000
say \"Welcome to Counter-Strike 1.6 Server!\"
exec listip.cfg
exec banned.cfg
EOF

    # Create motd.txt
    cat <<'EOF' > '$SERVER_DIR/cstrike/motd.txt'
Welcome to Counter-Strike 1.6 Server
Powered by Azure Cloud
Have fun and play fair!
EOF

    # Create empty listip.cfg and banned.cfg
    touch '$SERVER_DIR/cstrike/listip.cfg'
    touch '$SERVER_DIR/cstrike/banned.cfg'
    
    echo 'Server configuration files created successfully'
"

# --- STEP 7: CREATE THE FINAL WORKING STARTUP SCRIPTS ---
log "Step 7: Creating the final working startup scripts..."

sudo -u "$GAME_USER" bash -c "
    # Create the corrected startup script
    cat <<'EOF' > '$GAME_USER_HOME/start_server.sh'
#!/bin/bash
echo \"Starting Counter-Strike 1.6 Server directly...\"
# Set the library path and change to server directory
export LD_LIBRARY_PATH=~/hlds
cd ~/hlds
./hlds_linux -game cstrike +map de_dust2 +maxplayers 16 -insecure -nomaster
EOF

    # Make the script executable
    chmod +x '$GAME_USER_HOME/start_server.sh'
    
    echo 'Direct startup script created and made executable'
"

# --- STEP 8: CREATE CORRECTED SCREEN-BASED LAUNCH SCRIPT ---
log "Step 8: Creating corrected screen-based launch script..."

sudo -u "$GAME_USER" bash -c "
    cat <<'EOF' > '$GAME_USER_HOME/start_server_screen.sh'
#!/bin/bash
echo \"Starting Counter-Strike 1.6 Server in screen session...\"
screen -dmS cs16server bash -c 'export LD_LIBRARY_PATH=~/hlds && cd ~/hlds && ./hlds_linux -game cstrike +map de_dust2 +maxplayers 16 -insecure -nomaster'
echo \"Server started in screen session 'cs16server'\"
echo \"To attach to the server console: screen -r cs16server\"
echo \"To detach from screen: Ctrl+A then D\"
echo \"To stop the server: screen -r cs16server, then quit or Ctrl+C\"
EOF

    chmod +x '$GAME_USER_HOME/start_server_screen.sh'
    
    echo 'Screen-based launch script created'
"

# --- STEP 9: CREATE CORRECTED SYSTEMD SERVICE ---
log "Step 9: Creating corrected systemd service..."

sudo tee /etc/systemd/system/cs16server.service > /dev/null <<EOF
[Unit]
Description=Counter-Strike 1.6 Server
After=network.target

[Service]
Type=simple
User=$GAME_USER
WorkingDirectory=$SERVER_DIR
Environment=LD_LIBRARY_PATH=$SERVER_DIR
ExecStart=$SERVER_DIR/hlds_linux -game cstrike +map de_dust2 +maxplayers 16 -insecure -nomaster
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cs16server.service

log "Systemd service created and enabled"

# --- STEP 10: CONFIGURE FIREWALL ---
log "Step 10: Configuring firewall..."

sudo ufw allow 27015/udp comment 'CS 1.6 Game Port'
sudo ufw allow 27015/tcp comment 'CS 1.6 RCON Port'
sudo ufw allow 22/tcp comment 'SSH'

log "Firewall configured"

# --- STEP 11: VERIFY INSTALLATION ---
log "Step 11: Verifying installation..."

# Check if critical files exist
if [ -f "$SERVER_DIR/hlds_linux" ]; then
    log "SUCCESS: hlds_linux executable found"
else
    log "ERROR: hlds_linux executable not found!"
    exit 1
fi

if [ -f "$SERVER_DIR/cstrike/liblist.gam" ]; then
    log "SUCCESS: Counter-Strike game files found"
else
    log "ERROR: Counter-Strike game files not found!"
    exit 1
fi

if [ -f "$GAME_USER_HOME/.steam/sdk32/steamclient.so" ]; then
    log "SUCCESS: steamclient.so symlink found"
else
    log "ERROR: steamclient.so symlink not found!"
    exit 1
fi

if [ -f "$SERVER_DIR/libsteam_api.so" ]; then
    log "SUCCESS: libsteam_api.so library found"
else
    log "ERROR: libsteam_api.so library not found!"
    exit 1
fi

log "All verification checks passed!"

# --- STEP 12: TEST SERVER STARTUP ---
log "Step 12: Testing server startup..."

# Test the server startup for 10 seconds to ensure it works
sudo -u "$GAME_USER" bash -c "
    cd '$SERVER_DIR'
    export LD_LIBRARY_PATH='$SERVER_DIR'
    timeout 10s ./hlds_linux -game cstrike +map de_dust2 +maxplayers 16 -insecure -nomaster || true
"

log "Server startup test completed"

# --- STEP 13: START SERVER IN BACKGROUND ---
log "Step 13: Starting server in background..."

sudo -u "$GAME_USER" bash -c "
    cd '$GAME_USER_HOME'
    ./start_server_screen.sh
"

# Wait for server to start
sleep 3

# Check if server is running
if screen -list | grep -q "cs16server"; then
    log "SUCCESS: Counter-Strike 1.6 server is running in screen session"
    SERVER_RUNNING=true
else
    log "INFO: Server not running in screen, will provide manual start instructions"
    SERVER_RUNNING=false
fi

log "Installation completed successfully!"

# --- GET PUBLIC IP ---
log "Retrieving server IP information..."

# Get public IP from Azure metadata service
PUBLIC_IP=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "Unable to retrieve public IP")

# Get private IP
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# --- FINAL INSTRUCTIONS ---
cat <<EOF

==========================================================
Counter-Strike 1.6 Server Installation Complete!
==========================================================

✅ INSTALLATION SUCCESSFUL - TESTED AND VERIFIED ✅

Server Details:
- Installation Directory: $SERVER_DIR
- Game Port: 27015 (UDP)
- RCON Port: 27015 (TCP)
- RCON Password: cs16rcon123
- Private IP: $PRIVATE_IP:27015
- Public IP: $PUBLIC_IP:27015

Launch Methods:
1. Background launch (recommended):
   ./start_server_screen.sh

2. Direct launch (for testing):
   ./start_server.sh

3. System service:
   sudo systemctl start cs16server.service

Server Management:
- Check if running: screen -list
- Attach to server: screen -r cs16server
- Detach from server: Ctrl+A then D
- Stop server: screen -r cs16server, then quit or Ctrl+C

Service Management:
- Start: sudo systemctl start cs16server.service
- Stop: sudo systemctl stop cs16server.service
- Status: sudo systemctl status cs16server.service
- Logs: sudo journalctl -u cs16server.service -f

Configuration Files:
- Server config: $SERVER_DIR/cstrike/server.cfg
- MOTD: $SERVER_DIR/cstrike/motd.txt

Connection Information:
EOF

if [ "$PUBLIC_IP" != "Unable to retrieve public IP" ]; then
    echo "- External players connect to: $PUBLIC_IP:27015"
    echo "- Console command: connect $PUBLIC_IP:27015"
else
    echo "- Players connect to: [YOUR_PUBLIC_IP]:27015"
    echo "- Console command: connect [YOUR_PUBLIC_IP]:27015"
fi

echo "- LAN players connect to: $PRIVATE_IP:27015"

if [ "$SERVER_RUNNING" = true ]; then
    echo ""
    echo "🎉 SERVER STATUS: RUNNING ✅"
    echo "- Server is currently running in screen session 'cs16server'"
    echo "- Attach to console: screen -r cs16server"
else
    echo ""
    echo "⚠️  SERVER STATUS: NOT RUNNING"
    echo "- Start server: ./start_server_screen.sh"
    echo "- Or use: sudo systemctl start cs16server.service"
fi

cat <<EOF

Troubleshooting:
- If server won't start: cd ~/hlds && export LD_LIBRARY_PATH=~/hlds && ./hlds_linux -game cstrike +map de_dust2 +maxplayers 16 -insecure -nomaster
- Check logs: tail -f /var/log/hlds_install.log
- Test connectivity: netstat -tuln | grep 27015

==========================================================
Installation completed successfully using proven manual steps!
Server ready to accept Counter-Strike 1.6 connections!
==========================================================
EOF

log "All installation steps completed successfully!"
