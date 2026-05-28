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
cfdisk /dev/nvme0n1
mkfs.fat -F32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -L root -f /dev/nvme0n1p2

mkdir /media/root
mount /dev/nvme0n1p2 /media/root

# Create subvolumes
btrfs subvolume create /media/root/@
btrfs subvolume create /media/root/@home

# Remount with subvolumes
umount /media/root
mount -o subvol=@,noatime,compress=zstd:3 /dev/nvme0n1p2 /media/root
mkdir -p /media/root/home
mount -o subvol=@home,noatime,compress=zstd:3 /dev/nvme0n1p2 /media/root/home

# Mount EFI
mkdir -p /media/root/boot/efi
mount /dev/nvme0n1p1 /media/root/boot/efi
```

### 4. Chimera Installer
`chimera-installer`  

Choose Local install.  
Set hostname, timezone, root password.  
Create your user account during the installer.  

### 5. Post-installation during live
```
# Bind mounts + chroot
mount --types proc /proc /media/root/proc
mount --rbind /sys /media/root/sys
mount --rbind /dev /media/root/dev
mount --rbind /run /media/root/run
# chroot into installed system disk
chroot /media/root /bin/bash

# Update system
apk update && apk upgrade
apk add wget nano doas 

# Enable important services
dinitctl enable bolt                # Thunderbolt dock
dinitctl enable networkmanager      # GNOME default

# Generate fstab
genfstab -U / >> /etc/fstab

# Exit and reboot
exit
umount -n -R /media/root
reboot
```
