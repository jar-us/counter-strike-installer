#!/bin/bash

# --- Configuration ---
RESOURCE_GROUP="MyHldsServerGroup"

echo "!!! WARNING: This will permanently delete the resource group '$RESOURCE_GROUP' and all resources within it. !!!"
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Deletion cancelled."
    exit 1
fi

echo "--- Deleting Resource Group: $RESOURCE_GROUP ---"
# The --yes flag confirms deletion without a second prompt.
# The --no-wait flag lets the command run in the background.
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo "--- Deletion process has started. It may take a few minutes to complete in Azure. ---"
