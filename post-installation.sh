#!/bin/bash
set -e

# 1. Validate input
USERNAME=$1
if [ -z "$USERNAME" ]; then
    echo "Usage: $0 <your-username>"
    echo "Example: $0 hiltar"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root inside the chroot."
    exit 1
fi

echo "=== Phase 1: System-Wide Configuration (Root) ==="

# Package operations (System-wide)
apk update
apk add btrfs-progs flatpak ufw wget nano fwupd opendoas bolt bolt-dinit gnome gnome-tweaks gnome-shell-extensions papirus-icon-theme ucode-intel bash

# Enable services (Offline mode for chroot)
dinitctl -o enable networkmanager
dinitctl -o enable ufw
dinitctl -o enable gdm

# Configure doas
echo "permit persist :wheel" > /etc/doas.conf
chmod 640 /etc/doas.conf

# Configure UFW (File-based to avoid breaking live kernel)
ufw default deny incoming
ufw default allow outgoing
sed -i 's/^ENABLED=no/ENABLED=yes/' /etc/ufw/ufw.conf

# Flatpak (System-wide installation)
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.brave.Browser
flatpak install -y flathub org.telegram.desktop
flatpak install -y flathub com.mattjakeman.ExtensionManager

# Set user shell
chsh -s /bin/bash "$USERNAME"

echo "=== Phase 2: User-Specific Configuration ==="
# Switch to the actual user to apply dotfiles and local settings
su - "$USERNAME" << 'USER_SCRIPT'
    echo "Applying user settings for $USER..."
    
    # Bibata Cursor (Local User)
    mkdir -p ~/.local/share/icons
    wget -q --show-progress https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata.tar.xz
    tar -xf Bibata.tar.xz -C ~/.local/share/icons/

    # GNOME Settings (dconf requires a D-Bus session)
    wget -q --show-progress -O chimera_settings.dconf https://raw.githubusercontent.com/hiltar/chimera/refs/heads/main/chimera_settings.dconf
    if command -v dbus-run-session &> /dev/null; then
        dbus-run-session dconf load /org/gnome/ < chimera_settings.dconf
    else
        echo "Warning: dbus-run-session not found. You may need to load dconf settings manually after reboot."
    fi

    # Shell Configuration (.bashrc)
    if ! grep -q "PS1=.*255;0;255m" ~/.bashrc 2>/dev/null; then
        echo "PS1='\[\e[38;2;255;0;255m\]\u@\h\[\e[0m\] \[\e[38;5;39m\]\w\[\e[0m\] \$ '" >> ~/.bashrc
    fi
USER_SCRIPT

# Bibata Cursor (System-wide fallback)
if [ -f "/home/$USERNAME/Bibata.tar.xz" ]; then
    tar -xf "/home/$USERNAME/Bibata.tar.xz" -C /usr/share/icons/
fi

echo "==================================================="
echo " Post-Installation Complete!                      "
echo "==================================================="
echo "1. Exit the chroot (type 'exit')."
echo "2. Reboot into your new system."
echo "3. Open 'Extension Manager' to install GNOME extensions."
echo "Note: fwupd will check for hardware updates on your first boot."
