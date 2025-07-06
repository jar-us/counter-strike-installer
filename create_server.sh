#!/bin/bash

# --- Configuration ---
RESOURCE_GROUP="MyHldsServerGroup"
LOCATION="eastus"
VM_NAME="MyHldsVm"
ADMIN_USER="azureuser"
# --- IMPORTANT: Paste the 'Raw' URL from your GitHub Gist here ---
#INSTALL_SCRIPT_URL="https://gist.githubusercontent.com/jar-us/94d63a2155d6dd9a29df139582abf867/raw/8a379ce68570276e18289059402d0a2dc90af85d/install_hlds.sh"

echo "--- Creating Resource Group: $RESOURCE_GROUP ---"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "--- Creating Virtual Machine: $VM_NAME ---"
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --image "Ubuntu2204" \
    --admin-username "$ADMIN_USER" \
    --generate-ssh-keys \
    --public-ip-sku Standard

echo "--- VM created. Skipping installation script for now... ---"
#echo "--- VM created. Applying installation script... ---"
## This extension downloads and runs your script on the new VM
#az vm extension set \
#    --resource-group "$RESOURCE_GROUP" \
#    --vm-name "$VM_NAME" \
#    --name "CustomScript" \
#    --publisher "Microsoft.Azure.Extensions" \
#    --settings "{\"fileUris\": [\"$INSTALL_SCRIPT_URL\"], \"commandToExecute\": \"./install_hlds.sh\"}"

#echo "--- Setup script has been triggered. It will run in the background on the VM. ---"

# --- Show the Public IP address so you can connect ---
PUBLIC_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query "publicIps" \
    --output tsv)

echo ""
echo "========================================================"
echo "         VM DEPLOYMENT INITIATED"
echo "========================================================"
echo "The server installation is running. It might take 5-10 minutes to complete."
echo "Your Server's Public IP Address is: $PUBLIC_IP"
echo "You can connect via SSH: ssh $ADMIN_USER@$PUBLIC_IP"
echo "========================================================"
