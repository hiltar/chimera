# Chimera Linux

### 1. Preparation
- Download the **latest GNOME** live ISO from: https://repo.chimera-linux.org/live/latest/
- Verify checksum + signature.
- Create bootable USB with Fedora Media Writer.

### 2. Boot and Hardware Testing
1. Boot the USB (disable Secure Boot if needed).
2. In BIOS → Thunderbolt Security → set to **No Security**.
3. Run the Chimera Live ISO and test it.

### 3. Partition the Disk
```
lsblk -f

wipefs -a /dev/nvme0n1

# 1G for EFI
# 4G for swap
# Rest for Linux FS
# Remember to select the type!
cfdisk /dev/nvme0n1

mkfs.fat -F32 -n EFI /dev/nvme0n1p1
mkswap -L swap /dev/nvme0n1p2
mkfs.btrfs -L root -f /dev/nvme0n1p3

mkdir /media/root
mount /dev/nvme0n1p3 /media/root

# Create subvolumes
btrfs subvolume create /media/root/@
btrfs subvolume create /media/root/@home

# Remount with subvolumes
umount /media/root
mount -o subvol=@,noatime,compress=zstd:3 /dev/nvme0n1p3 /media/root
mkdir -p /media/root/home
mount -o subvol=@home,noatime,compress=zstd:3 /dev/nvme0n1p3 /media/root/home

# Mount EFI
mkdir -p /media/root/boot
mount /dev/nvme0n1p1 /media/root/boot
```

### 4. Chimera Installer
`chimera-installer`  

Choose network install.  
Set hostname, timezone, root password.  
Create your user account during the installer.  
Select kernel.  
Install systemd-boot bootloader.  
Install into `/media/root/`

### 5. Post-installation during live
```
# apk operations
apk update
apk add btrfs-progs flatpak ufw wget nano fwupd opendoas bolt bolt-dinit gnome gnome-tweaks gnome-shell-extensions papirus-icon-theme

# Enable important services
dinitctl -o enable networkmanager      # Networking
dinitctl -o enable ufw                 # Firewall
dinitctl -o enable gdm                 # GNOME DE

# Configure doas
echo "permit persist :wheel" > /etc/doas.conf
chmod 640 /etc/doas.conf

# Swap
swapon -L swap

# Exit and reboot
```

### 6. Post-installation after reboot

```
doas apk update && doas apk upgrade

# Firewall
doas ufw default deny incoming
doas ufw default allow outgoing
doas ufw enable
doas ufw status

# CPU microcode
doas apk add ucode-intel

# Flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.brave.Browser
flatpak install flathub org.telegram.desktop
flatpak install flathub com.mattjakeman.ExtensionManager

# fwupd
doas fwupdmgr refresh
doas fwupdmgr get-updates
```

### 7. Optional

```
# Bibata cursor
mkdir -p ~/.local/share/icons
wget https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata.tar.xz
tar -xvf Bibata.tar.xz -C ~/.local/share/icons/
doas tar -xvf Bibata.tar.xz -C /usr/share/icons/

# GNOME extensions
AppIndicator Support
ArcMenu
Dash to Panel
OSD Volume Number

# GNOME settings
dconf load /org/gnome/ < chimera_settings.dconf

# Shell
doas apk add bash
chsh -s /bin/bash
nano ~/.bashrc
PS1='\[\e[38;2;255;0;255m\]\u@\h\[\e[0m\] \[\e[38;5;39m\]\w\[\e[0m\] \$ '
```

### 8. Maintenance
```
# Remove unused kernels
chimera-prunekernels rm all
```
