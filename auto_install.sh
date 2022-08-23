# Installation script to install RAK2287 software with dependencies, and conduct RPI system configuration.
# This script is organized by sequenced modules.

# Change system language to US

sudo sed -i 's/en_GB.UTF-8 UTF-8/# en_GB.UTF-8 UTF-8/g' /etc/locale.gen
sudo sed -i 's/# en_US.UTF-8 utf-8/en_US.UTF-8 utf-8/g' /etc/locale.gen
export LC_ALL=C
export LANG=C
sudo update-locale --no-checks LANG
sudo update-locale --no-checks "LANG=en_US.UTF-8 UTF-8"
sudo dpkg-reconfigure -f noninteractive locales

# Change keyboard layout

sudo sed -i 's/XKBMODEL="pc105"/XKBMODEL="pc104"/g' /etc/default/keyboard
sudo nano /etc/default/keyboard
sudo dpkg-reconfigure -f noninteractive keyboard-configuration
sudo invoke-rc.d keyboard-setup start
sudo setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'
sudo udevadm trigger --subsystem-match=input --action=change

# Change Wifi country

sudo iw reg set US
sudo rfkill unblock wifi
sudo -s
    for filename in /var/lib/systemd/rfkill/*:wlan ; do
        echo 0 > $filename
    done
exit

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
