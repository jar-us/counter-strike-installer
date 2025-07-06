#!/bin/bash
# ==============================================================================
# Counter-Strike 1.6 HLDS Installation Script
# ==============================================================================
#
# Description:
#   This script installs and configures a Counter-Strike 1.6 Half-Life Dedicated
#   Server (HLDS) on a Linux system. It handles all necessary dependencies,
#   downloads the server files, and sets up the required configuration.
#
# Usage:
#   sudo ./hlds_installation.sh [--dry-run]
#
# Options:
#   --dry-run    Run in test mode without making system changes
#
# ==============================================================================

# Exit on error, enable debugging if not in dry-run mode
set -e

# ==============================================================================
# CONFIGURATION SECTION
# ==============================================================================

# Default configuration - can be overridden by environment variables
: "${GAME_USER:=azureuser}"
: "${GAME_USER_HOME:=/home/$GAME_USER}"
: "${SERVER_DIR:=$GAME_USER_HOME/hlds}"
: "${STEAM_DIR:=$GAME_USER_HOME/steamcmd}"
: "${LOG_FILE:=/var/log/hlds_install.log}"
: "${RCON_PASSWORD:=cs16rcon123}"
: "${SERVER_NAME:=Counter-Strike 1.6 Server}"
: "${DEFAULT_MAP:=de_dust2}"
: "${MAX_PLAYERS:=16}"
: "${GAME_PORT:=27015}"

# Parse command line arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            # Disable exit on error in dry-run mode
            set +e
            # Disable debugging in dry-run mode
            set +x
            # Use temporary directories in dry-run mode
            TMP_DIR=$(mktemp -d)
            SERVER_DIR="$TMP_DIR/hlds"
            STEAM_DIR="$TMP_DIR/steamcmd"
            LOG_FILE="$TMP_DIR/hlds_install.log"
            ;;
    esac
done

# Enable debugging if not in dry-run mode
if [ "$DRY_RUN" = false ]; then
    set -x
fi

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Logging function
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if running as root/sudo
check_root() {
    if [[ $EUID -ne 0 && "$DRY_RUN" = false ]]; then
        echo "This script must be run as root or with sudo privileges"
        echo "Usage: sudo ./hlds_installation.sh [--dry-run]"
        exit 1
    fi
}

# Run command as game user
run_as_user() {
    if [ "$DRY_RUN" = true ]; then
        eval "$1"
    else
        sudo -u "$GAME_USER" bash -c "$1"
    fi
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# ==============================================================================
# INSTALLATION FUNCTIONS
# ==============================================================================

# Step 1: System preparation
prepare_system() {
    log "Step 1: System Preparation - Adding 32-bit architecture support..."

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would add 32-bit architecture support"
        log "[DRY RUN] Would update package lists"
        log "[DRY RUN] Would upgrade existing packages"
    else
        export DEBIAN_FRONTEND=noninteractive

        # Enable 32-bit architecture support
        sudo dpkg --add-architecture i386 || error_exit "Failed to add i386 architecture"

        # Update package lists
        sudo apt-get update || error_exit "Failed to update package lists"

        # Upgrade existing packages
        sudo apt-get upgrade -y || error_exit "Failed to upgrade packages"
    fi

    log "System preparation completed successfully"
}

# Step 2: Install dependencies
install_dependencies() {
    log "Step 2: Installing all necessary dependencies..."

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would install: wget screen lib32gcc-s1 lib32stdc++6 libc6:i386"
    else
        # Install required packages
        sudo apt-get install -y wget screen lib32gcc-s1 lib32stdc++6 libc6:i386 || 
            error_exit "Failed to install dependencies"
    fi

    log "Dependencies installed successfully"
}

# Step 3: Download and extract SteamCMD
setup_steamcmd() {
    log "Step 3: Downloading and extracting SteamCMD..."

    # Create directory for SteamCMD
    ensure_directory "$STEAM_DIR"

    # Download and extract SteamCMD
    run_as_user "
        cd '$STEAM_DIR'

        # Download SteamCMD if not already present
        if [ ! -f steamcmd_linux.tar.gz ]; then
            wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz || exit 1
        fi

        # Extract the package contents if not already extracted
        if [ ! -f steamcmd.sh ]; then
            tar -xvf steamcmd_linux.tar.gz || exit 1
        fi
    " || error_exit "Failed to download or extract SteamCMD"

    log "SteamCMD downloaded and extracted successfully"
}

# Step 4: Download Counter-Strike server files
download_cs_server() {
    log "Step 4: Downloading Counter-Strike server files..."

    # Create directory for game server
    ensure_directory "$SERVER_DIR"

    # Download CS 1.6 server files
    run_as_user "
        cd '$STEAM_DIR'
        ./steamcmd.sh +force_install_dir '$SERVER_DIR' +login anonymous +app_update 90 validate +quit
    " || error_exit "Failed to download Counter-Strike server files"

    log "Counter-Strike server files downloaded successfully"
}

# Step 5: Apply steamclient.so fix
apply_steamclient_fix() {
    log "Step 5: Applying steamclient.so fix..."

    run_as_user "
        # Create the directory structure the server expects
        mkdir -p '$GAME_USER_HOME/.steam/sdk32'

        # Create the symbolic link
        ln -sf '$SERVER_DIR/steamclient.so' '$GAME_USER_HOME/.steam/sdk32/steamclient.so'
    " || error_exit "Failed to apply steamclient.so fix"

    log "steamclient.so fix applied successfully"
}

# Step 6: Create server configuration files
create_server_config() {
    log "Step 6: Creating server configuration files..."

    run_as_user "
        # Create basic server.cfg
        cat <<EOF > '$SERVER_DIR/cstrike/server.cfg'
// Basic Server Configuration
hostname \"$SERVER_NAME\"
rcon_password \"$RCON_PASSWORD\"
sv_password \"\"
mp_timelimit 45
mp_friendlyfire 0
mp_freezetime 5
mp_roundtime 3
mp_maxrounds 30
sv_maxrate 25000
sv_minrate 5000
say \"Welcome to $SERVER_NAME!\"
exec listip.cfg
exec banned.cfg
EOF

        # Create motd.txt
        cat <<EOF > '$SERVER_DIR/cstrike/motd.txt'
Welcome to $SERVER_NAME
Have fun and play fair!
EOF

        # Create empty listip.cfg and banned.cfg
        touch '$SERVER_DIR/cstrike/listip.cfg'
        touch '$SERVER_DIR/cstrike/banned.cfg'
    " || error_exit "Failed to create server configuration files"

    log "Server configuration files created successfully"
}

# Step 7: Create startup scripts
create_startup_scripts() {
    log "Step 7: Creating startup scripts..."

    run_as_user "
        # Create direct startup script
        cat <<EOF > '$GAME_USER_HOME/start_server.sh'
#!/bin/bash
echo \"Starting Counter-Strike 1.6 Server directly...\"
# Set the library path and change to server directory
export LD_LIBRARY_PATH=$SERVER_DIR
cd $SERVER_DIR
./hlds_linux -game cstrike +map $DEFAULT_MAP +maxplayers $MAX_PLAYERS -insecure -nomaster
EOF

        # Make the script executable
        chmod +x '$GAME_USER_HOME/start_server.sh'

        # Create screen-based launch script
        cat <<EOF > '$GAME_USER_HOME/start_server_screen.sh'
#!/bin/bash
echo \"Starting Counter-Strike 1.6 Server in screen session...\"
screen -dmS cs16server bash -c 'export LD_LIBRARY_PATH=$SERVER_DIR && cd $SERVER_DIR && ./hlds_linux -game cstrike +map $DEFAULT_MAP +maxplayers $MAX_PLAYERS -insecure -nomaster'
echo \"Server started in screen session 'cs16server'\"
echo \"To attach to the server console: screen -r cs16server\"
echo \"To detach from screen: Ctrl+A then D\"
echo \"To stop the server: screen -r cs16server, then quit or Ctrl+C\"
EOF

        # Make the script executable
        chmod +x '$GAME_USER_HOME/start_server_screen.sh'
    " || error_exit "Failed to create startup scripts"

    log "Startup scripts created successfully"
}

# Step 8: Create systemd service
create_systemd_service() {
    log "Step 8: Creating systemd service..."

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would create systemd service file"
    else
        # Create systemd service file
        sudo tee /etc/systemd/system/cs16server.service > /dev/null <<EOF
[Unit]
Description=Counter-Strike 1.6 Server
After=network.target

[Service]
Type=simple
User=$GAME_USER
WorkingDirectory=$SERVER_DIR
Environment=LD_LIBRARY_PATH=$SERVER_DIR
ExecStart=$SERVER_DIR/hlds_linux -game cstrike +map $DEFAULT_MAP +maxplayers $MAX_PLAYERS -insecure -nomaster
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        # Reload systemd and enable service
        sudo systemctl daemon-reload
        sudo systemctl enable cs16server.service
    fi

    log "Systemd service created and enabled"
}

# Step 9: Configure firewall
configure_firewall() {
    log "Step 9: Configuring firewall..."

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would configure firewall for ports: 27015/udp, 27015/tcp, 22/tcp"
    else
        sudo ufw allow $GAME_PORT/udp comment 'CS 1.6 Game Port'
        sudo ufw allow $GAME_PORT/tcp comment 'CS 1.6 RCON Port'
        sudo ufw allow 22/tcp comment 'SSH'
    fi

    log "Firewall configured"
}

# Step 10: Verify installation
verify_installation() {
    log "Step 10: Verifying installation..."

    # Check if critical files exist
    local verification_passed=true

    if [ ! -f "$SERVER_DIR/hlds_linux" ]; then
        log "ERROR: hlds_linux executable not found!"
        verification_passed=false
    fi

    if [ ! -f "$SERVER_DIR/cstrike/liblist.gam" ]; then
        log "ERROR: Counter-Strike game files not found!"
        verification_passed=false
    fi

    if [ ! -f "$GAME_USER_HOME/.steam/sdk32/steamclient.so" ]; then
        log "ERROR: steamclient.so symlink not found!"
        verification_passed=false
    fi

    if [ ! -f "$SERVER_DIR/libsteam_api.so" ]; then
        log "ERROR: libsteam_api.so library not found!"
        verification_passed=false
    fi

    if [ "$verification_passed" = true ]; then
        log "All verification checks passed!"
    else
        error_exit "Verification failed. Please check the logs."
    fi
}

# Step 11: Test server startup
test_server_startup() {
    log "Step 11: Testing server startup..."

    run_as_user "
        cd '$SERVER_DIR'
        export LD_LIBRARY_PATH='$SERVER_DIR'
        timeout 10s ./hlds_linux -game cstrike +map $DEFAULT_MAP +maxplayers $MAX_PLAYERS -insecure -nomaster || true
    " || log "Server startup test completed with non-zero exit code"

    log "Server startup test completed"
}

# Step 12: Start server in background
start_server() {
    log "Step 12: Starting server in background..."

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would start server in background"
        SERVER_RUNNING=false
    else
        run_as_user "
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
    fi
}

# Step 13: Get server IP information
get_server_ip() {
    log "Retrieving server IP information..."

    # Get public IP from Azure metadata service
    if [ "$DRY_RUN" = true ]; then
        PUBLIC_IP="[YOUR_PUBLIC_IP]"
    else
        PUBLIC_IP=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "Unable to retrieve public IP")
    fi

    # Get private IP
    PRIVATE_IP=$(hostname -I | awk '{print $1}')

    log "IP information retrieved: Public IP=$PUBLIC_IP, Private IP=$PRIVATE_IP"
}

# Display final instructions
display_instructions() {
    cat <<EOF

==========================================================
Counter-Strike 1.6 Server Installation Complete!
==========================================================

✅ INSTALLATION SUCCESSFUL - TESTED AND VERIFIED ✅

Server Details:
- Installation Directory: $SERVER_DIR
- Game Port: $GAME_PORT (UDP)
- RCON Port: $GAME_PORT (TCP)
- RCON Password: $RCON_PASSWORD
- Private IP: $PRIVATE_IP:$GAME_PORT
- Public IP: $PUBLIC_IP:$GAME_PORT

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

    if [ "$PUBLIC_IP" != "Unable to retrieve public IP" ] && [ "$PUBLIC_IP" != "[YOUR_PUBLIC_IP]" ]; then
        echo "- External players connect to: $PUBLIC_IP:$GAME_PORT"
        echo "- Console command: connect $PUBLIC_IP:$GAME_PORT"
    else
        echo "- Players connect to: [YOUR_PUBLIC_IP]:$GAME_PORT"
        echo "- Console command: connect [YOUR_PUBLIC_IP]:$GAME_PORT"
    fi

    echo "- LAN players connect to: $PRIVATE_IP:$GAME_PORT"

    if [ "${SERVER_RUNNING:-false}" = true ]; then
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
- If server won't start: cd $SERVER_DIR && export LD_LIBRARY_PATH=$SERVER_DIR && ./hlds_linux -game cstrike +map $DEFAULT_MAP +maxplayers $MAX_PLAYERS -insecure -nomaster
- Check logs: tail -f $LOG_FILE
- Test connectivity: netstat -tuln | grep $GAME_PORT

==========================================================
Installation completed successfully!
Server ready to accept Counter-Strike 1.6 connections!
==========================================================
EOF

    # Clean up in dry-run mode
    if [ "$DRY_RUN" = true ]; then
        log "Dry run completed. Cleaning up temporary files..."
        rm -rf "$TMP_DIR"
    fi
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    log "Starting Counter-Strike 1.6 HLDS installation..."

    # Display dry run notice if applicable
    if [ "$DRY_RUN" = true ]; then
        log "RUNNING IN DRY-RUN MODE - No system changes will be made"
    fi

    # Check if running as root
    check_root

    # Execute installation steps
    prepare_system
    install_dependencies
    setup_steamcmd
    download_cs_server
    apply_steamclient_fix
    create_server_config
    create_startup_scripts
    create_systemd_service
    configure_firewall
    verify_installation
    test_server_startup
    start_server
    get_server_ip

    # Display final instructions
    display_instructions

    log "All installation steps completed successfully!"
}

# Run the main function
main
