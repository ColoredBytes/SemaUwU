#!/usr/bin/env bash
# Author: Joshua Ross
# Github: https://github.com/ColoredBytes
# Purpose: semaphore install script.

# Variables
HOST_IP=$(hostname -I | cut -d' ' -f1) # Get the IP address of the host machine
TMP=$(mktemp -d) # Create TMP directory
LOG_FILE="$TMP/errors.log"
LATEST=$(curl -s "https://api.github.com/repos/semaphoreui/semaphore/releases/latest" | jq -r '.assets[] | select(.name | endswith("_linux_amd64.deb")) | .browser_download_url')

# Systemd Variables
SERVICE_URL="https://raw.githubusercontent.com/ColoredBytes/SemaUwU/main/assets/files/semaphore.service"
DEST_DIR="/etc/systemd/system"
SERVICE_FILE="semaphore.service"

# Commands
exec > >(tee -a ${LOG_FILE})
exec 2> >(tee -a ${LOG_FILE} >&2)

error_exit() {
    echo "$1" 1>&2
    echo "An error occurred. Please check the log file at ${LOG_FILE} for more details."
    exit 1
}

systemd_config() {
  sudo systemctl daemon-reload || error_exit "Failed to reload systemd daemon"
  sudo systemctl enable "$SERVICE_FILE" || error_exit "Failed to enable semaphore service"
  sudo systemctl start "$SERVICE_FILE" || error_exit "Failed to start semaphore service"
  sudo systemctl status "$SERVICE_FILE" || error_exit "Failed to start semaphore service"
}

# Create User
sudo adduser --system --group --home /home/semaphore semaphore || error_exit "Failed to create semaphore user"

# Download semaphore deb package to TMP
wget -O $TMP/semaphore.deb $LATEST || error_exit "Failed to download the latest semaphore .deb package"
if [ ! -f "$TMP/semaphore.deb" ]; then
  error_exit "Could not download latest .deb package!"
fi

# Install/update semaphore deb package
echo "Installing Ansible & Semaphore..."
sudo apt install -y ansible || error_exit "Failed to install Ansible"
sudo apt install -y $TMP/semaphore.deb || error_exit "Failed to install Semaphore .deb package"

# Setup Semaphore
semaphore setup || error_exit "Failed to setup Semaphore"

# Make semaphore a home
sudo mkdir /etc/semaphore || error_exit "Failed to create /etc/semaphore directory"
sudo mv config.json /etc/semaphore/ || error_exit "Failed to move config.json to /etc/semaphore"
sudo chown -R semaphore:semaphore /etc/semaphore || error_exit "Failed to set permissions for /etc/semaphore"

# Make systemd service
sudo curl -o "$DEST_DIR/$SERVICE_FILE" "$SERVICE_URL" || error_exit "Failed to download systemd service file"

# Do the needful to enable it correctly 
systemd_config

# Job's Done
echo "Semaphore has been successfully installed. It should be accessible at http://${HOST_IP}:3000"