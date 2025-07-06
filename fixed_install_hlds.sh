#!/bin/bash
# ==============================================================================
# CORRECTED Counter-Strike 1.6 HLDS Installation Script
# Based on Working Manual Installation Steps
# ==============================================================================

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo privileges"
   echo "Usage: sudo ./fixed_install_hlds.sh"
   exit 1
fi

# Stop on any error and enable debugging
set -e
set -x

# --- Define Global Paths ---
SERVER_DIR="/home/azureuser/hlds"
STEAM_DIR="/home/azureuser/steamcmd"
GAME_USER="azureuser"
GAME_USER_HOME="/home/$GAME_USER"

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
    wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    
    # Extract the package contents
    tar -xvf steamcmd_linux.tar.gz
    
    log 'SteamCMD downloaded and extracted successfully'
"

# --- STEP 4: DOWNLOAD COUNTER-STRIKE SERVER FILES ---
log "Step 4: Downloading Counter-Strike server files..."

sudo -u "$GAME_USER" bash -c "
    # Create directory for game server
    mkdir -p '$SERVER_DIR'
    
    # Run SteamCMD to download CS 1.6 server files
    cd '$STEAM_DIR'
    ./steamcmd.sh +force_install_dir '$SERVER_DIR' +login anonymous +app_update 90 validate +quit
    
    log 'Counter-Strike server files downloaded successfully'
"

# --- STEP 5: APPLY STEAMCLIENT.SO FIX ---
log "Step 5: Applying steamclient.so fix..."

sudo -u "$GAME_USER" bash -c "
    # Create the directory structure the server expects
    mkdir -p '$GAME_USER_HOME/.steam/sdk32'
    
    # Create the symbolic link
    ln -sf '$SERVER_DIR/steamclient.so' '$GAME_USER_HOME/.steam/sdk32/steamclient.so'
    
    log 'steamclient.so symbolic link created successfully'
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
    
    log 'Server configuration files created successfully'
"

# --- STEP 7: CREATE THE FINAL WORKING START_SERVER.SH SCRIPT ---
log "Step 7: Creating the final working startup script..."

sudo -u "$GAME_USER" bash -c "
    # Create the exact script from manual steps
    cat <<'EOF' > '$GAME_USER_HOME/start_server.sh'
#!/bin/bash
echo \"Starting Counter-Strike 1.6 Server directly...\"
# Explicitly set the library path to the server directory
export LD_LIBRARY_PATH=~/hlds
# Launch the main executable directly to bypass the hlds_run script
cd ~/hlds && ./hlds_linux -game cstrike +map de_dust2 +maxplayers 16 -insecure -nomaster
EOF

    # Make the script executable
    chmod +x '$GAME_USER_HOME/start_server.sh'
    
    log 'Startup script created and made executable'
"

# --- STEP 8: CREATE SCREEN-BASED LAUNCH SCRIPT ---
log "Step 8: Creating screen-based launch script for background operation..."

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
    
    log 'Screen-based launch script created'
"

# --- STEP 9: CREATE SYSTEMD SERVICE (OPTIONAL) ---
log "Step 9: Creating systemd service for automatic startup..."

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

log "All verification checks passed!"

# --- STEP 12: START THE SERVER ---
log "Step 12: Starting the server..."

# Start the server using screen (non-blocking)
sudo -u "$GAME_USER" bash -c "
    cd '$GAME_USER_HOME'
    ./start_server_screen.sh
"

# Wait a moment for server to start
sleep 5

# Check if server is running
if screen -list | grep -q "cs16server"; then
    log "SUCCESS: Counter-Strike 1.6 server is running in screen session"
else
    log "WARNING: Server may not have started properly"
fi

log "Installation completed successfully!"

# --- FINAL INSTRUCTIONS ---
cat <<EOF

==========================================================
Counter-Strike 1.6 Server Installation Complete!
==========================================================

Based on your working manual installation steps:

Server Details:
- Installation Directory: $SERVER_DIR
- Game Port: 27015 (UDP)
- RCON Port: 27015 (TCP)
- RCON Password: cs16rcon123

Launch Methods:
1. Direct launch: 
   ssh azureuser@[SERVER_IP]
   ./start_server.sh

2. Background launch (recommended):
   ssh azureuser@[SERVER_IP]
   ./start_server_screen.sh

3. System service:
   sudo systemctl start cs16server.service

Server Management:
- Check if running: screen -list
- Attach to server: screen -r cs16server
- Detach from server: Ctrl+A then D
- Stop server: screen -r cs16server, then quit

Configuration Files:
- Server config: $SERVER_DIR/cstrike/server.cfg
- MOTD: $SERVER_DIR/cstrike/motd.txt

Connection Info:
- Server Address: [YOUR_SERVER_IP]:27015
- Console command: connect [YOUR_SERVER_IP]:27015

Current Status:
- Server is running in screen session 'cs16server'
- You can attach to it with: screen -r cs16server

==========================================================
Installation completed using your proven manual steps!
==========================================================
EOF

log "All installation steps completed successfully!"
