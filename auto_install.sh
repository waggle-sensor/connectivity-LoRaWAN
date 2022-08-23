# Installation script to install RAK2287 software with dependencies, and conduct RPI system configuration.
# This script is organized by sequenced modules.

# Install dependencies

sudo apt update
sudo apt -y upgrade
sudo apt -y install apt-transport-https python3-pip
sudo pip3 install paho-mqtt pywaggle[all]

# Install RAK software

git clone https://github.com/RAKWireless/rak_common_for_gateway.git ~/Downloads/rak_common_for_gateway
cd ~/Downloads/rak_common_for_gateway
printf '7' | sudo ./install.sh

# Set LoRaWAN to US channel plan

sudo cp /etc/chirpstack-network-server/chirpstack-network-server.us_902_928.toml /etc/chirpstack-network-server/chirpstack-network-server.toml

# Configure RAK to access point

sudo systemctl enable create_ap
sudo echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > /etc/wpa_supplicant/wpa_supplicant.conf

# Set RPI to console login

sudo systemctl --quiet set-default multi-user.target
sudo rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf

# Enable SSH

sudo ssh-keygen -A
sudo update-rc.d ssh enable
sudo invoke-rc.d ssh start

# Enable Serial

sudo sh -c "echo 'enable_uart=1' >> /boot/config.txt"
sudo cp /boot/cmdline.txt /opt/pywaggle/cmdline.bak
sudo sed -i 's/console=serial0,115200 //g' /opt/pywaggle/cmdline.bak
sudo rm /boot/cmdline.txt
sudo mv /opt/pywaggle/cmdline.txt /boot/cmdline.txt

# Configure chirpstack network server

sudo sh -c "echo '[general]\nlog_level=4' >> /etc/chirpstack-network-server/chirpstack-network-server.toml"

# Configure chirpstack application server

sudo sh -c "echo '[general]\nlog_level=4' >> /etc/chirpstack-application-server/chirpstack-application-server.toml"
JWT="$(openssl rand -base64 32)"
sudo sed -i -e "s/verysecret/$JWT/g" /etc/chirpstack-application-server/chirpstack-application-server.toml

# Create Pywaggle plugin

sudo mkdir /var/log/pywaggle
sudo chmod +x /opt/pywaggle/mqtt_plugin.py

# Create pywaggle service

sudo ln -s /opt/pywaggle/mqtt_plugin.service /etc/systemd/system/mqtt_plugin.service
sudo systemctl enable mqtt_plugin
sudo shutdown -r now
