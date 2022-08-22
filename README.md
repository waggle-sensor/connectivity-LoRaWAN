# Completely Manual Build
## Install Operating System
- Download latest Raspi Lite Arm 64 image from: [https://downloads.raspberrypi.org/raspios_lite_arm64/images/](https://downloads.raspberrypi.org/raspios_lite_arm64/images/)
- Determine path to SD Micro and manually build image in BASH:
```
sudo lsblk
sudo dd bs=4M if=/path/to/filename.img of=/path/to/device oflag=sync
// e.g.: sudo dd bs=4M if=/mnt/data/02--PROJECTS/U/University-of-Oregon-Research/11--LORA/2022-04-04-raspios-bullseye-arm64-lite.img of=/dev/sda oflag=sync
```
- Insert SD Micro into RPIv4 and power on device
- Select keyboard layout "Other", then "English (US)", then "English (US)"
- Enter new username: "sagelora", then set a password: "ArgonneNatlLab"
## Configure RPI System
- Reboot RPIv4, plug in ethernet cable, and execute config commands in BASH:
```
sudo shutdown -r now
sudo raspi-config
# This opens a configuration menu
```
### 5 Localisations Options
- Select "L1 Locale", deselect "en_GB.UTF-8 UTF-8", select "en_US.UTF-8 UTF-8", then "en_US.UTF-8"
- Select "L2 Timezone", navigate to "America", then select to appropriate time zone
- Select "L3 Keyboard", select "Generic 140-key PC", then "English (US)", then "The default for the keyboard layout", then "No compose key"
- Select "L4 WLAN Country", select "US United States"
## Install Dependencies
- After reboot, login with "sagelora" credentials
### Debian Dependencies:
- Execute apt commands in BASH, then reboot:
```
sudo apt update
sudo apt upgrade
sudo apt install git apt-transport-https python3-pip
```
### Python Dependencies:
- Execute Python package manager commands in BASH:
```
sudo pip3 install paho-mqtt pywaggle[all]
```
## Install RAK Software
- Download and install RAK software in BASH
```
git clone https://github.com/RAKWireless/rak_common_for_gateway.git ~/Downloads/rak_common_for_gateway
cd ~/Downloads/rak_common_for_gateway
sudo ./install.sh
# This brings up a configuration menu
```
- Enter "7" for "7. RAK7248 no LTE (RAK2287 SPI + raspberry pi)"
## Configure RAK Software
- Execute config command in BASH:
```
sudo gateway-config
# This opens a configuration menu
```
### 2 Setup RAK Gateway Channel Plan
- Select "2 Server is Chirpstack", then "1 ChirpStack Channel-plan configuration", then "11 US_902_928", then server IP "127.0.0.1"
### 5 Configure WIFI
- Select "1 Enable AP Mode/Disable Client Mode"
## Configure RPI System
```
sudo raspi-config
# This opens a configuration menu
```
### 1 System Options
- Select "S5 Boot / Auto Login", then "B1 Console"
### 3 Interface Options
- Select "I2 SSH", verfiy with "Yes"
- Select "I6 Serial Port", then answer "No" to disable login shell accessibility over serial port, then answer "Yes" to enable serial port hardware
### 4 Performance Options
- Select "P2 GPU Memory", then enter "16"

### Finish Configuration
- Select "Finish", DO NOT REBOOT

## Configure Chirpstack
- Edit network server configuration file in BASH:
```
sudo nano /etc/chirpstack-network-server/chirpstack-network-server.toml
```
- Make the following changes inside the file, at location of indicated tags:
```
# Add the following lines immediately after the file header
[general]
log_level=4
```
- Build random secret key and save the output in BASH:
```
openssl rand -base64 32
```
- Edit application server configuration file in BASH:
```
sudo nano /etc/chirpstack-application-server/chirpstack-application-server.toml
```
-Make the following changes inside the file, at location of indicated tags:
```
# Add the following lines immediately after the file header
[general]
log_level=4

[application_server.external_api]
# jwt_secret="verysecret" (the fourth key below the tag)
# The following is an example of a random base64 32-character key
jwt_secret="TWpC5KJuWmoJ+fRWTLynCL/gfjur+TiPpvH5fd3JTmk="
```
## Create Pywaggle Plugin
- Create pywaggle directories and download Python file in BASH:
```
sudo mkdir /var/log/pywaggle
sudo mkdir /opt/pywaggle
sudo wget https://raw.githubusercontent.com/waggle-sensor/summer2022/main/Tsai/plugin/mqtt_plugin.py -P /opt/pywaggle
sudo chmod +x /opt/pywaggle/mqtt_plugin.py
```
- Edit mqtt_plugin.py in BASH:
```
sudo nano /opt/pywaggle/mqtt_plugin.py
```
- Find logging directory near top of file and change:
```
# os.environ["PYWAGGLE_LOG_DIR"] = "/var/log/pywaggle"
```
- Create systemd service file in BASH:
```
sudo nano /opt/pywaggle/mqtt_plugin.service
```
- Copy and paste into service file in BASH:
```
[Unit]
Description=Pywaggle Asynchronous Callback
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
Restart=always
RestartSec=1
ExecStart=/usr/bin/python3 /opt/pywaggle/mqtt_plugin.py

[Install]
WantedBy=multi-user.target
```
- Change permissions to service file and create symbolic link in BASH and enable pywaggle service, then restart system:
```
sudo ln -s /opt/pywaggle/mqtt_plugin.service /etc/systemd/system/mqtt_plugin.service
sudo systemctl enable mqtt_plugin
sudo shutdown -r now
```
## Check installation
- Login with 'sagelora' credentials
```
sudo systemctl status mosquitto
sudo systemctl status postgresql
sudo systemctl status redis-server
sudo systemctl status chirpstack-gateway-bridge
sudo systemctl status chirpstack-network-server
sudo systemctl status chirpstack-application-server
```
