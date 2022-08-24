# Installation script to install RAK2287 software with dependencies, and conduct RPI system configuration.
# This script is organized by sequenced modules.

# Change system language to US

sudo sed -i 's/en_GB.UTF-8 UTF-8/# en_GB.UTF-8 UTF-8/g' /etc/locale.gen
sudo sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
export LC_ALL=C
export LANG=C
sudo update-locale --no-checks LANG
sudo update-locale --no-checks "LANG=en_US.UTF-8"
sudo dpkg-reconfigure -f noninteractive locales

# Change keyboard layout

sudo sed -i 's/XKBMODEL="pc105"/XKBMODEL="pc104"/g' /etc/default/keyboard
sudo dpkg-reconfigure -f noninteractive keyboard-configuration
sudo invoke-rc.d keyboard-setup start
sudo setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'
sudo udevadm trigger --subsystem-match=input --action=change

# Change Wifi country

sudo iw reg set US
sudo rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
done
sudo shutdown -r now
