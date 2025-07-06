#!/bin/bash

# --- Configuration ---
RESOURCE_GROUP="MyHldsServerGroup"
LOCATION="eastus"
VM_NAME="MyHldsVm"
ADMIN_USER="azureuser"
VM_SIZE="Standard_B2s"  # Added VM size specification
INSTALL_SCRIPT_URL="https://gist.githubusercontent.com/jar-us/94d63a2155d6dd9a29df139582abf867/raw/8a379ce68570276e18289059402d0a2dc90af85d/install_hlds.sh"

# --- Color codes for better output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# --- Function to check if Azure CLI is installed and logged in ---
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure. Please run 'az login' first."
        exit 1
    fi

    print_status "Azure CLI check passed"
}

# --- Function to check if resource group already exists ---
check_resource_group() {
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group '$RESOURCE_GROUP' already exists. Continuing..."
        return 0
    else
        print_status "Resource group '$RESOURCE_GROUP' does not exist. Will create it."
        return 1
    fi
}

# --- Function to check if VM already exists ---
check_vm_exists() {
    if az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &> /dev/null; then
        print_error "VM '$VM_NAME' already exists in resource group '$RESOURCE_GROUP'"
        print_error "Please choose a different VM name or delete the existing VM"
        exit 1
    fi
}

# --- Function to validate the install script URL ---
validate_script_url() {
    print_status "Validating install script URL..."
    if curl --output /dev/null --silent --head --fail "$INSTALL_SCRIPT_URL"; then
        print_status "Install script URL is accessible"
    else
        print_error "Install script URL is not accessible: $INSTALL_SCRIPT_URL"
        print_error "Please check the URL and ensure it's publicly accessible"
        exit 1
    fi
}

# --- Function to open required ports ---
open_ports() {
    print_status "Opening required ports for Counter-Strike 1.6..."

    # Create Network Security Group
    az network nsg create \
        --resource-group "$RESOURCE_GROUP" \
        --name "${VM_NAME}-nsg" \
        --location "$LOCATION"

    # Open SSH port (22)
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "${VM_NAME}-nsg" \
        --name "SSH" \
        --protocol tcp \
        --priority 1000 \
        --destination-port-range 22 \
        --access allow

    # Open Counter-Strike 1.6 game port (27015)
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "${VM_NAME}-nsg" \
        --name "CS16-Game" \
        --protocol udp \
        --priority 1001 \
        --destination-port-range 27015 \
        --access allow

    # Open RCON port (27015 TCP) - optional but useful
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "${VM_NAME}-nsg" \
        --name "CS16-RCON" \
        --protocol tcp \
        --priority 1002 \
        --destination-port-range 27015 \
        --access allow

    print_status "Network security rules created"
}

# --- Function to wait for VM to be ready ---
wait_for_vm() {
    print_status "Waiting for VM to be fully ready..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if az vm get-instance-view --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query "instanceView.statuses[?code=='PowerState/running']" --output tsv | grep -q "PowerState/running"; then
            print_status "VM is running and ready"
            return 0
        fi

        print_status "Attempt $attempt/$max_attempts: VM not ready yet, waiting 10 seconds..."
        sleep 10
        ((attempt++))
    done

    print_error "VM did not become ready within the expected time"
    return 1
}

# --- Main execution starts here ---
print_status "Starting Counter-Strike 1.6 server deployment..."

# Pre-flight checks
check_azure_cli
validate_script_url

# Check if resources already exist
check_resource_group
check_vm_exists

print_status "Creating Resource Group: $RESOURCE_GROUP"
if ! check_resource_group; then
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    if [ $? -eq 0 ]; then
        print_status "Resource group created successfully"
    else
        print_error "Failed to create resource group"
        exit 1
    fi
fi

# Create network security group first
open_ports

print_status "Creating Virtual Machine: $VM_NAME"
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --image "Ubuntu2204" \
    --admin-username "$ADMIN_USER" \
    --generate-ssh-keys \
    --public-ip-sku Standard \
    --size "$VM_SIZE" \
    --nsg "${VM_NAME}-nsg" \
    --verbose

if [ $? -ne 0 ]; then
    print_error "Failed to create VM"
    exit 1
fi

print_status "VM created successfully"

# Wait for VM to be ready
wait_for_vm

print_status "Skipping installation script for now..."
#print_status "Applying installation script..."
# Enhanced extension settings with better error handling
#az vm extension set \
#    --resource-group "$RESOURCE_GROUP" \
#    --vm-name "$VM_NAME" \
#    --name "CustomScript" \
#    --publisher "Microsoft.Azure.Extensions" \
#    --settings "{\"fileUris\": [\"$INSTALL_SCRIPT_URL\"], \"commandToExecute\": \"chmod +x install_hlds.sh && ./install_hlds.sh\"}" \
#    --protected-settings '{}' \
#    --verbose

#if [ $? -ne 0 ]; then
#    print_error "Failed to apply installation script"
#    exit 1
#fi
#
#print_status "Installation script applied successfully"

# Get the Public IP address
print_status "Retrieving public IP address..."
PUBLIC_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query "publicIps" \
    --output tsv)

if [ -z "$PUBLIC_IP" ]; then
    print_error "Failed to retrieve public IP address"
    exit 1
fi

print_status "Deployment completed successfully!"

echo ""
echo "========================================================"
echo "         VM DEPLOYMENT COMPLETED"
echo "========================================================"
echo "The server installation is running. It might take 5-10 minutes to complete."
echo "Your Server's Public IP Address is: $PUBLIC_IP"
echo "You can connect via SSH: ssh $ADMIN_USER@$PUBLIC_IP"
echo ""
echo "Counter-Strike 1.6 Server Details:"
echo "- Game Port: 27015 (UDP)"
echo "- RCON Port: 27015 (TCP)"
echo "- Server IP: $PUBLIC_IP:27015"
echo ""
echo "To check installation progress, SSH into the VM and run:"
echo "  tail -f /var/log/azure/custom-script/handler.log"
echo "========================================================"

# Optional: Wait for installation to complete
read -p "Do you want to monitor the installation progress? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Monitoring installation progress..."
    print_status "Connecting to VM to check installation status..."

    # Wait a bit for the VM to be SSH-ready
    sleep 30

    ssh -o StrictHostKeyChecking=no "$ADMIN_USER@$PUBLIC_IP" "tail -f /var/log/azure/custom-script/handler.log"
fi