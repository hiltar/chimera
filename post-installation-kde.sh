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
#
# This replaces GNOME/GDM with KDE Plasma/SDDM.
# If your repository uses a different Plasma metapackage, adjust this list.
apk update
apk add btrfs-progs flatpak ufw wget nano fwupd opendoas bolt bolt-dinit \
  plasma-desktop sddm sddm-kcm konsole dolphin ark spectacle discover \
  kate gwenview okular kcalc ksysguard filelight \
  plasma-nm plasma-pa bluedevil \
  plasma-integration kde-gtk-config kde-cli-tools kdeplasma-addons \
  breeze breeze-gtk breeze-icons papirus-icon-theme \
  xdg-desktop-portal xdg-desktop-portal-kde \
  pipewire wireplumber pipewire-pulse \
  upower ucode-amd bash

# Enable services (Offline mode for chroot)
dinitctl -o enable networkmanager
dinitctl -o enable ufw
dinitctl -o enable sddm

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

# GNOME Extension Manager is not used on KDE.
# Use Discover and System Settings after first login instead.

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

# Switch to the actual user to apply dotfiles and local settings.
# This heredoc is quoted so KDE config variables are evaluated as the user,
# not as root.
su - "$USERNAME" << 'USER_SCRIPT'
set -e

CURRENT_USER="$(id -un)"
echo "Applying user settings for ${CURRENT_USER}..."

# --- Cursor theme: Bibata Modern Ice ---
mkdir -p ~/.local/share/icons ~/.config

wget -q --show-progress https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata.tar.xz
tar -xf Bibata.tar.xz -C ~/.local/share/icons/

# Also set Xcursor theme for older X11 applications.
cat > ~/.Xresources << 'XRESOURCES'
Xcursor.theme: Bibata-Modern-Ice
Xcursor.size: 24
XRESOURCES

# --- KDE Plasma configuration ---
# KDE uses kwriteconfig instead of dconf.
if command -v kwriteconfig6 >/dev/null 2>&1; then
    KWC="kwriteconfig6"
elif command -v kwriteconfig5 >/dev/null 2>&1; then
    KWC="kwriteconfig5"
else
    KWC=""
    echo "Warning: kwriteconfig not found. Writing minimal KDE config files directly."
fi

if [ -n "$KWC" ]; then
    # Global KDE appearance: dark Breeze color scheme, Breeze widget style,
    # Papirus icons. This is the closest practical equivalent to:
    #   color-scheme='prefer-dark'
    #   icon-theme='Papirus'
    "$KWC" --file kdeglobals --group General --key ColorScheme BreezeDark
    "$KWC" --file kdeglobals --group General --key widgetStyle Breeze
    "$KWC" --file kdeglobals --group Icons --key Theme Papirus
    "$KWC" --file kdeglobals --group WM --key theme breeze

    # Font rendering, roughly matching GNOME's:
    #   font-antialiasing='rgba'
    #   font-hinting='slight'
    "$KWC" --file kcmfonts --group General --key XftAntialias true
    "$KWC" --file kcmfonts --group General --key XftHintStyle hintslight
    "$KWC" --file kcmfonts --group General --key XftSubPixel rgb

    # Cursor and mouse settings.
    # Matches:
    #   cursor-theme='Bibata-Modern-Ice'
    #   left-handed=true
    #   accel-profile='flat'
    #   speed=0.0
    "$KWC" --file kcminputrc --group Mouse --key cursorTheme Bibata-Modern-Ice
    "$KWC" --file kcminputrc --group Mouse --key LeftHanded true
    "$KWC" --file kcminputrc --group Mouse --key AccelProfile flat
    "$KWC" --file kcminputrc --group Mouse --key MotionAcceleration 0

    # Numlock on login.
    # Matches:
    #   numlock-state=true
    "$KWC" --file ksmserverrc --group General --key numlock 1

    # Keyboard layout.
    # Your GNOME dconf had Finnish as the source and US in MRU.
    # Here we set Finnish as the primary layout. Adjust if you want both.
    "$KWC" --file kxkbrc --group Layout --key LayoutList fi
    "$KWC" --file kxkbrc --group Layout --key LayoutListCount 1
    "$KWC" --file kxkbrc --group Layout --key VariantList ""
    "$KWC" --file kxkbrc --group Layout --key DisplayNames ""
    "$KWC" --file kxkbrc --group Layout --key Options ""
    "$KWC" --file kxkbrc --group Layout --key ResetOldOptions false

    # Touchpad settings, best effort.
    # Matches:
    #   two-finger-scrolling-enabled=true
    #   accel-profile='flat'
    "$KWC" --file kcm_touchpadrc --group touchpad --key TwoFingerScrolling true
    "$KWC" --file kcm_touchpadrc --group touchpad --key AccelProfile flat

    # Workspace / virtual desktops.
    # Matches:
    #   num-workspaces=1
    #   dynamic-workspaces=true
    "$KWC" --file kwinrc --group Desktops --key Number 1
    "$KWC" --file kwinrc --group Desktops --key Rows 1
    "$KWC" --file kwinrc --group Desktops --key Dynamic true

    # Disable hot corners / electric borders.
    # Matches:
    #   enable-hot-corners=false
    for edge in TopLeft Top TopRight Left Right BottomLeft Bottom BottomRight; do
        "$KWC" --file kwinrc --group ElectricBorders --key "$edge" None
    done

    # Enable KDE blur effect as a rough replacement for blur-my-shell.
    # Plasma blur can still be tuned in System Settings.
    "$KWC" --file kwinrc --group Plugins --key blurEnabled true

    # Optional: rough equivalent of GNOME window button layout
    # appmenu:minimize,maximize,close
    #
    # KWin decoration keys can vary by KDE version, so these are left
    # commented out. Uncomment if your KDE version accepts them.
    #
    # "$KWC" --file kwinrc --group org.kde.kwin.Decoration --key ButtonsOnLeft S
    # "$KWC" --file kwinrc --group org.kde.kwin.Decoration --key ButtonsOnRight MXC
else
    # Fallback if kwriteconfig is unavailable.
    # This writes minimal config files directly.
    mkdir -p ~/.config

    cat > ~/.config/kdeglobals << 'KDEGLOBALS'
[General]
ColorScheme=BreezeDark
widgetStyle=Breeze

[Icons]
Theme=Papirus

[WM]
theme=breeze
KDEGLOBALS

    cat > ~/.config/kcmfonts << 'KCMFONTS'
[General]
XftAntialias=true
XftHintStyle=hintslight
XftSubPixel=rgb
KCMFONTS

    cat > ~/.config/kcminputrc << 'KCMINPUT'
[Mouse]
cursorTheme=Bibata-Modern-Ice
LeftHanded=true
AccelProfile=flat
MotionAcceleration=0
KCMINPUT

    cat > ~/.config/ksmserverrc << 'KSMSERVER'
[General]
numlock=1
KSMSERVER

    cat > ~/.config/kxkbrc << 'KXKB'
[Layout]
LayoutList=fi
LayoutListCount=1
VariantList=
DisplayNames=
Options=
ResetOldOptions=false
KXKB

    cat > ~/.config/kwinrc << 'KWINRC'
[Desktops]
Number=1
Rows=1
Dynamic=true

[ElectricBorders]
TopLeft=None
Top=None
TopRight=None
Left=None
Right=None
BottomLeft=None
Bottom=None
BottomRight=None

[Plugins]
blurEnabled=true
KWINRC
fi

# --- GTK application theming ---
# Make GTK3/GTK4 apps follow the KDE/Papirus/Bibata/dark theme.
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

cat > ~/.config/gtk-3.0/settings.ini << 'GTK3'
[Settings]
gtk-theme=Breeze-Dark
gtk-icon-theme=Papirus
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-application-prefer-dark-theme=true
GTK3

cp -f ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini

# --- Shell Configuration (.bashrc) ---
# Check for the new function name to prevent duplicates.
if ! grep -q "_build_general_prompt" ~/.bashrc 2>/dev/null; then
    cat /tmp/bashrc_snippet.sh >> ~/.bashrc
fi
USER_SCRIPT

# Clean up the temporary file
rm -f /tmp/bashrc_snippet.sh

# Resolve user home directory robustly.
USER_HOME=$(getent passwd "$USERNAME" 2>/dev/null | cut -d: -f6)
[ -n "$USER_HOME" ] || USER_HOME="/home/$USERNAME"

# Bibata Cursor (System-wide fallback)
mkdir -p /usr/share/icons
if [ -f "$USER_HOME/Bibata.tar.xz" ]; then
    tar -xf "$USER_HOME/Bibata.tar.xz" -C /usr/share/icons/
fi

echo "==================================================="
echo " Post-Installation Complete!                      "
echo "==================================================="
echo "1. Exit the chroot (type 'exit')."
echo "2. Reboot into your new system."
echo "3. Log in through SDDM and choose Plasma (Wayland or X11)."
echo "4. Open System Settings and Discover to customize KDE Plasma."
echo ""
echo "KDE notes:"
echo "- Pin Dolphin, Konsole, and Brave manually if you want GNOME-style favorites."
echo "- KDE's default panel is the equivalent of Dash to Panel."
echo "- KDE's application menu/widget is the equivalent of Arc Menu."
echo "- Blur can be configured in System Settings > Workspace > Desktop Effects."
echo "Note: fwupd will check for hardware updates on your first boot."
