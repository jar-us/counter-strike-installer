#!/bin/bash
# ==============================================================================
# Counter-Strike 1.6 Server Complete Cleanup Script
# This script removes all traces of CS 1.6 server installation
# ==============================================================================

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo privileges"
   echo "Usage: sudo ./cleanup_cs16_server.sh"
   exit 1
fi

# --- Color codes for better output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Function to print colored messages ---
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[CLEANUP]${NC} $1"
}

# --- Define paths to clean ---
GAME_USER="azureuser"
GAME_USER_HOME="/home/$GAME_USER"
SERVER_DIR="$GAME_USER_HOME/hlds"
STEAM_DIR="$GAME_USER_HOME/steamcmd"
STEAM_HOME="$GAME_USER_HOME/Steam"
STEAM_SDK="$GAME_USER_HOME/.steam"

print_header "Starting Counter-Strike 1.6 Server Complete Cleanup..."

# --- Ask for confirmation ---
echo ""
echo "⚠️  WARNING: This will completely remove all CS 1.6 server files and configurations!"
echo ""
echo "The following will be deleted:"
echo "- CS 1.6 server files: $SERVER_DIR"
echo "- SteamCMD installation: $STEAM_DIR"
echo "- Steam client files: $STEAM_HOME"
echo "- Steam SDK symlinks: $STEAM_SDK"
echo "- Startup scripts: start_server*.sh"
echo "- System service: cs16server.service"
echo "- Firewall rules for CS 1.6"
echo "- Installation logs"
echo ""

read -p "Are you sure you want to proceed? (yes/NO): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_status "Cleanup cancelled by user"
    exit 0
fi

print_header "Proceeding with cleanup..."

# --- STEP 1: STOP AND DISABLE SERVICES ---
print_status "Step 1: Stopping and disabling CS 1.6 server service..."

# Stop systemd service if it exists
if systemctl is-active --quiet cs16server.service 2>/dev/null; then
    print_warning "Stopping cs16server.service..."
    systemctl stop cs16server.service
else
    print_status "cs16server.service is not running"
fi

# Disable systemd service if it exists
if systemctl is-enabled --quiet cs16server.service 2>/dev/null; then
    print_warning "Disabling cs16server.service..."
    systemctl disable cs16server.service
else
    print_status "cs16server.service is not enabled"
fi

# Remove systemd service file
if [ -f /etc/systemd/system/cs16server.service ]; then
    print_warning "Removing systemd service file..."
    rm -f /etc/systemd/system/cs16server.service
    systemctl daemon-reload
    print_status "Systemd service file removed"
else
    print_status "No systemd service file found"
fi

# --- STEP 2: KILL ANY RUNNING SERVER PROCESSES ---
print_status "Step 2: Terminating any running CS 1.6 server processes..."

# Kill any running hlds_linux processes
if pgrep -f "hlds_linux" > /dev/null; then
    print_warning "Killing running hlds_linux processes..."
    pkill -f "hlds_linux" || true
    sleep 2
    # Force kill if still running
    pkill -9 -f "hlds_linux" || true
    print_status "Server processes terminated"
else
    print_status "No running server processes found"
fi

# Kill any screen sessions containing cs16server
if screen -list | grep -q "cs16server"; then
    print_warning "Terminating screen session 'cs16server'..."
    screen -S cs16server -X quit 2>/dev/null || true
    print_status "Screen session terminated"
else
    print_status "No screen session found"
fi

# --- STEP 3: REMOVE SERVER DIRECTORIES ---
print_status "Step 3: Removing CS 1.6 server directories..."

# Remove HLDS server directory
if [ -d "$SERVER_DIR" ]; then
    print_warning "Removing CS 1.6 server directory: $SERVER_DIR"
    rm -rf "$SERVER_DIR"
    print_status "Server directory removed"
else
    print_status "Server directory not found"
fi

# Remove SteamCMD directory
if [ -d "$STEAM_DIR" ]; then
    print_warning "Removing SteamCMD directory: $STEAM_DIR"
    rm -rf "$STEAM_DIR"
    print_status "SteamCMD directory removed"
else
    print_status "SteamCMD directory not found"
fi

# Remove Steam client directory
if [ -d "$STEAM_HOME" ]; then
    print_warning "Removing Steam client directory: $STEAM_HOME"
    rm -rf "$STEAM_HOME"
    print_status "Steam client directory removed"
else
    print_status "Steam client directory not found"
fi

# Remove Steam SDK directory and symlinks
if [ -d "$STEAM_SDK" ]; then
    print_warning "Removing Steam SDK directory: $STEAM_SDK"
    rm -rf "$STEAM_SDK"
    print_status "Steam SDK directory removed"
else
    print_status "Steam SDK directory not found"
fi

# --- STEP 4: REMOVE STARTUP SCRIPTS ---
print_status "Step 4: Removing startup scripts..."

SCRIPTS_TO_REMOVE=(
    "$GAME_USER_HOME/start_server.sh"
    "$GAME_USER_HOME/start_server_screen.sh"
    "$GAME_USER_HOME/fixed_install_hlds.sh"
    "$GAME_USER_HOME/install_cs16_server.sh"
)

for script in "${SCRIPTS_TO_REMOVE[@]}"; do
    if [ -f "$script" ]; then
        print_warning "Removing script: $(basename $script)"
        rm -f "$script"
    else
        print_status "Script not found: $(basename $script)"
    fi
done

print_status "Startup scripts cleanup completed"

# --- STEP 5: REMOVE FIREWALL RULES ---
print_status "Step 5: Removing firewall rules..."

# Check if ufw is active
if command -v ufw >/dev/null 2>&1; then
    # Remove CS 1.6 specific firewall rules
    print_warning "Removing CS 1.6 firewall rules..."
    
    # Remove UDP rule for game port
    ufw --force delete allow 27015/udp 2>/dev/null || true
    
    # Remove TCP rule for RCON port  
    ufw --force delete allow 27015/tcp 2>/dev/null || true
    
    print_status "Firewall rules removed"
else
    print_status "UFW not installed, skipping firewall cleanup"
fi

# --- STEP 6: CLEAN UP LOGS AND TEMP FILES ---
print_status "Step 6: Cleaning up logs and temporary files..."

# Remove installation logs
LOG_FILES=(
    "/var/log/hlds_install.log"
    "$GAME_USER_HOME/server.log"
    "$GAME_USER_HOME/hlds_install.log"
)

for log_file in "${LOG_FILES[@]}"; do
    if [ -f "$log_file" ]; then
        print_warning "Removing log file: $log_file"
        rm -f "$log_file"
    else
        print_status "Log file not found: $log_file"
    fi
done

# Clean up any remaining SteamCMD cache
if [ -d "/tmp/steam" ]; then
    print_warning "Removing temporary Steam files..."
    rm -rf /tmp/steam* 2>/dev/null || true
fi

print_status "Log cleanup completed"

# --- STEP 7: RESET USER PERMISSIONS ---
print_status "Step 7: Resetting user permissions..."

# Ensure the user's home directory has correct ownership
chown -R "$GAME_USER:$GAME_USER" "$GAME_USER_HOME" 2>/dev/null || true

print_status "User permissions reset"

# --- STEP 8: OPTIONAL - REMOVE 32-BIT PACKAGES ---
print_status "Step 8: Optional cleanup of 32-bit packages..."

echo ""
read -p "Do you want to remove 32-bit packages (lib32gcc-s1, lib32stdc++6, libc6:i386)? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Removing 32-bit packages..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get remove -y lib32gcc-s1 lib32stdc++6 libc6:i386 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    
    # Remove 32-bit architecture if no other 32-bit packages are installed
    if ! dpkg --get-selections | grep -q ":i386"; then
        print_warning "Removing 32-bit architecture support..."
        dpkg --remove-architecture i386 2>/dev/null || true
    fi
    
    print_status "32-bit packages removed"
else
    print_status "Keeping 32-bit packages (recommended for future installations)"
fi

# --- STEP 9: VERIFY CLEANUP ---
print_status "Step 9: Verifying cleanup completion..."

CLEANUP_ISSUES=0

# Check if directories still exist
for dir in "$SERVER_DIR" "$STEAM_DIR" "$STEAM_HOME" "$STEAM_SDK"; do
    if [ -d "$dir" ]; then
        print_error "Directory still exists: $dir"
        ((CLEANUP_ISSUES++))
    fi
done

# Check if scripts still exist
for script in "${SCRIPTS_TO_REMOVE[@]}"; do
    if [ -f "$script" ]; then
        print_error "Script still exists: $script"
        ((CLEANUP_ISSUES++))
    fi
done

# Check if service still exists
if [ -f /etc/systemd/system/cs16server.service ]; then
    print_error "Service file still exists"
    ((CLEANUP_ISSUES++))
fi

# Check if processes are still running
if pgrep -f "hlds_linux" > /dev/null; then
    print_error "Server processes still running"
    ((CLEANUP_ISSUES++))
fi

# --- FINAL REPORT ---
echo ""
echo "=========================================================="
echo "         COUNTER-STRIKE 1.6 CLEANUP COMPLETE"
echo "=========================================================="

if [ $CLEANUP_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ CLEANUP SUCCESSFUL${NC}"
    echo ""
    echo "All CS 1.6 server components have been completely removed:"
    echo "✅ Server files deleted"
    echo "✅ SteamCMD removed"
    echo "✅ Steam client files removed"
    echo "✅ System service removed"
    echo "✅ Startup scripts removed"
    echo "✅ Firewall rules removed"
    echo "✅ Log files cleaned"
    echo "✅ Processes terminated"
    echo ""
    echo "🎯 System is ready for fresh CS 1.6 server installation!"
    echo ""
    echo "To install again, run:"
    echo "   sudo ./install_cs16_server.sh"
else
    echo -e "${YELLOW}⚠️  CLEANUP COMPLETED WITH ISSUES${NC}"
    echo ""
    echo "Found $CLEANUP_ISSUES issue(s) during cleanup."
    echo "Please check the error messages above and manually remove any remaining files."
fi

echo "=========================================================="

print_status "Cleanup script completed!"
