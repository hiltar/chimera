#!/bin/sh
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

echo "=== Phase 1: System-Wide Configuration ==="

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

# --- PREPARE BASHRC SNIPPET ---
# We create a temp file as root using a quoted heredoc ('BASHRC_SNIPPET').
# This ensures root doesn't accidentally evaluate $? or $exit_code.
cat << 'BASHRC_SNIPPET' > /tmp/bashrc_snippet.sh

# --- Custom Bash Prompt Theme ---
_build_general_prompt() {
    local exit_code=$?
    local reset="\[\e[0m\]"

    local c_user="\[\e[38;2;255;121;198m\]"
    local c_dir="\[\e[38;2;139;233;253m\]"
    local c_time="\[\e[38;5;245m\]"
    local c_prompt="\[\e[38;2;241;250;140m\]"
    local c_error="\[\e[38;2;255;85;85m\]"
    local exit_indicator=""
    
    if [ $exit_code -ne 0 ]; then
        exit_indicator="${c_error}✘ $exit_code ${reset}"
    fi

    PS1="${exit_indicator}${c_time}[\A]${reset} ${c_user}\u@\h${reset} ${c_dir}\w${reset}"$'\n'"${c_prompt}❯${reset} "
}

PROMPT_COMMAND=_build_general_prompt
BASHRC_SNIPPET

# Switch to the actual user to apply dotfiles and local settings
# Note: Using unquoted USER_SCRIPT so $USERNAME evaluates properly
su - "$USERNAME" << USER_SCRIPT
    echo "Applying user settings for $USERNAME..."
    
    # Bibata Cursor (Local User)
    mkdir -p ~/.local/share/icons
    wget -q --show-progress https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata.tar.xz
    tar -xf Bibata.tar.xz -C ~/.local/share/icons/

    # GNOME Settings (dconf requires a D-Bus session)
    wget -q --show-progress -O chimera_settings.dconf https://raw.githubusercontent.com/hiltar/chimera/refs/heads/main/chimera_settings.dconf
    if command -v dbus-run-session > /dev/null 2>&1; then
        dbus-run-session dconf load /org/gnome/ < chimera_settings.dconf
    else
        echo "Warning: dbus-run-session not found. You may need to load dconf settings manually after reboot."
    fi

    # Shell Configuration (.bashrc)
    # Check for the new function name to prevent duplicates
    if ! grep -q "_build_general_prompt" ~/.bashrc 2>/dev/null; then
        cat /tmp/bashrc_snippet.sh >> ~/.bashrc
    fi
USER_SCRIPT

# Clean up the temporary file
rm -f /tmp/bashrc_snippet.sh

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
