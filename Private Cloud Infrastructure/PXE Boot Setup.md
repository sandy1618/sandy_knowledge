---
title: PXE Boot Setup Guide
tags: [pxe, network-boot, tftp, bootloader, deployment]
created: 2025-11-24
---

# PXE Boot Setup Guide

Complete guide to setting up PXE (Preboot Execution Environment) boot infrastructure for network-based OS deployment.

## 🎯 What is PXE Boot?

**PXE (Preboot Execution Environment)** allows computers to boot from a network server instead of local storage. It's the foundation for:
- Automated OS installation
- Diskless workstations
- Network-based recovery tools
- Mass deployment systems

### How PXE Boot Works

```
1. Client PC Powers On
   ↓
2. BIOS/UEFI initiates PXE boot
   ↓
3. Client broadcasts DHCP request
   ↓
4. DHCP server responds with:
   - IP address for client
   - TFTP server address
   - Boot filename
   ↓
5. Client downloads boot file from TFTP server
   ↓
6. Boot file loads network boot menu/installer
   ↓
7. User selects OS to install
   ↓
8. Client downloads and boots selected OS
```

## 🔧 Components Required

### Software Components
1. **DHCP Server** - Assigns IPs and boot parameters
2. **TFTP Server** - Serves boot files (bootloader, kernel)
3. **HTTP/FTP/NFS Server** - Serves OS installation files
4. **PXE Boot Loader** - PXELINUX, GRUB, or iPXE
5. **Boot Menu** - Interface for OS selection

### Network Requirements
- Gigabit Ethernet (recommended for fast deployment)
- DHCP-enabled network
- Server with sufficient storage for OS images

## 🚀 Installation Methods

## Method 1: Simple PXE Server (Best for Learning)

### Step 1: Install Required Packages

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install TFTP server, DHCP server, and HTTP server
sudo apt install -y dnsmasq apache2 pxelinux syslinux-common
```

### Step 2: Configure dnsmasq (Combined DHCP/TFTP)

```bash
# Stop and disable systemd-resolved (conflicts with dnsmasq)
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Remove symlink
sudo rm /etc/resolv.conf

# Create new resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Backup original dnsmasq config
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup

# Edit dnsmasq configuration
sudo nano /etc/dnsmasq.conf
```

**dnsmasq configuration for PXE:**

```conf
# Interface to listen on
interface=eno1
bind-interfaces

# DHCP settings
dhcp-range=192.168.1.100,192.168.1.200,12h

# Gateway
dhcp-option=3,192.168.1.1

# DNS servers
dhcp-option=6,8.8.8.8,8.8.4.4

# TFTP settings
enable-tftp
tftp-root=/var/lib/tftpboot

# PXE settings for BIOS
dhcp-match=set:bios,option:client-arch,0
dhcp-boot=tag:bios,pxelinux.0

# PXE settings for UEFI (64-bit)
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-boot=tag:efi-x86_64,bootx64.efi

# TFTP server address (your server IP)
dhcp-option=66,192.168.1.10

# Logging
log-dhcp
log-queries
```

### Step 3: Set Up TFTP Directory Structure

```bash
# Create TFTP root directory
sudo mkdir -p /var/lib/tftpboot
sudo mkdir -p /var/lib/tftpboot/pxelinux.cfg
sudo mkdir -p /var/lib/tftpboot/ubuntu
sudo mkdir -p /var/lib/tftpboot/images

# Set permissions
sudo chmod -R 755 /var/lib/tftpboot
```

### Step 4: Copy Boot Files

```bash
# Copy PXELINUX files
sudo cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/
sudo cp /usr/lib/syslinux/modules/bios/*.c32 /var/lib/tftpboot/

# For UEFI support
sudo apt install -y grub-efi-amd64-bin
sudo cp /usr/lib/grub/x86_64-efi/monolithic/grubnetx64.efi.signed /var/lib/tftpboot/bootx64.efi
```

### Step 5: Create PXE Boot Menu

```bash
# Create default boot menu
sudo nano /var/lib/tftpboot/pxelinux.cfg/default
```

**Basic boot menu configuration:**

```
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300
ONTIMEOUT local

MENU TITLE PXE Boot Menu
MENU INCLUDE pxelinux.cfg/pxe.conf

LABEL local
    MENU LABEL ^1) Boot from local drive
    MENU DEFAULT
    LOCALBOOT 0

LABEL ubuntu-live
    MENU LABEL ^2) Ubuntu 22.04 Live
    KERNEL ubuntu/vmlinuz
    APPEND initrd=ubuntu/initrd boot=casper netboot=nfs nfsroot=192.168.1.10:/var/lib/tftpboot/ubuntu

LABEL memtest
    MENU LABEL ^3) Memory Test
    KERNEL memtest

LABEL rescue
    MENU LABEL ^4) Rescue Mode
    KERNEL ubuntu/vmlinuz
    APPEND initrd=ubuntu/initrd rescue
```

### Step 6: Style the Boot Menu (Optional)

```bash
# Create menu styling file
sudo nano /var/lib/tftpboot/pxelinux.cfg/pxe.conf
```

```
MENU COLOR screen       37;40      #80ffffff #00000000 std
MENU COLOR border       30;44      #40000000 #00000000 std
MENU COLOR title        1;36;44    #c00090f0 #00000000 std
MENU COLOR unsel        37;44      #90ffffff #00000000 std
MENU COLOR hotkey       1;37;44    #ffffffff #00000000 std
MENU COLOR sel          7;37;40    #e0000000 #20ff8000 all
MENU COLOR hotsel       1;7;37;40  #e0400000 #20ff8000 all
MENU COLOR scrollbar    30;44      #40000000 #00000000 std
```

### Step 7: Start Services

```bash
# Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# Check status
sudo systemctl status dnsmasq

# Check if TFTP is listening
sudo netstat -tulnp | grep :69
```

## Method 2: Using FOG Project (Recommended)

FOG Project includes complete PXE setup automatically. See **[[FOG Project Setup]]** for detailed instructions.

Quick install:
```bash
# Download FOG installer
git clone https://github.com/FOGProject/fogproject.git
cd fogproject/bin
sudo ./installfog.sh

# Follow the installer prompts
# FOG will configure PXE, TFTP, DHCP automatically
```

## 📥 Adding OS Images to PXE Menu

### Adding Ubuntu Live ISO

**Step 1: Download Ubuntu ISO**
```bash
cd /tmp
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso
```

**Step 2: Extract Boot Files**
```bash
# Mount ISO
sudo mkdir /mnt/ubuntu-iso
sudo mount -o loop ubuntu-22.04.3-live-server-amd64.iso /mnt/ubuntu-iso

# Copy kernel and initrd
sudo cp /mnt/ubuntu-iso/casper/vmlinuz /var/lib/tftpboot/ubuntu/
sudo cp /mnt/ubuntu-iso/casper/initrd /var/lib/tftpboot/ubuntu/

# Copy entire ISO for installation
sudo mkdir -p /var/www/html/ubuntu
sudo cp -r /mnt/ubuntu-iso/* /var/www/html/ubuntu/

# Unmount
sudo umount /mnt/ubuntu-iso
```

**Step 3: Add to Boot Menu**
```bash
sudo nano /var/lib/tftpboot/pxelinux.cfg/default
```

Add entry:
```
LABEL ubuntu-installer
    MENU LABEL ^5) Install Ubuntu 22.04
    KERNEL ubuntu/vmlinuz
    APPEND initrd=ubuntu/initrd ip=dhcp url=http://192.168.1.10/ubuntu/ubuntu-22.04.3-live-server-amd64.iso autoinstall
```

### Adding Windows Installation (Advanced)

Windows PXE boot requires additional configuration:

**Requirements:**
- Windows ADK (Assessment and Deployment Kit)
- WinPE (Windows Preinstallation Environment)
- wimboot (for iPXE)

**High-level steps:**
1. Create WinPE image
2. Extract Windows installation files
3. Configure boot parameters
4. Add to PXE menu

*Detailed Windows PXE guide: [[Windows PXE Deployment]]*

### Adding Clonezilla for Imaging

```bash
# Download Clonezilla
cd /tmp
wget https://downloads.sourceforge.net/project/clonezilla/clonezilla_live_stable/3.1.0-22/clonezilla-live-3.1.0-22-amd64.iso

# Mount and extract
sudo mkdir /mnt/clonezilla
sudo mount -o loop clonezilla-live-3.1.0-22-amd64.iso /mnt/clonezilla

# Copy files
sudo mkdir /var/lib/tftpboot/clonezilla
sudo cp /mnt/clonezilla/live/vmlinuz /var/lib/tftpboot/clonezilla/
sudo cp /mnt/clonezilla/live/initrd.img /var/lib/tftpboot/clonezilla/
sudo cp /mnt/clonezilla/live/filesystem.squashfs /var/lib/tftpboot/clonezilla/

# Unmount
sudo umount /mnt/clonezilla
```

Add to menu:
```
LABEL clonezilla
    MENU LABEL ^6) Clonezilla (Disk Imaging)
    KERNEL clonezilla/vmlinuz
    APPEND initrd=clonezilla/initrd.img boot=live config noswap nolocales edd=on nomodeset ocs_live_run="ocs-live-general" ocs_live_extra_param="" ocs_live_batch="no" vga=788 ip=frommedia fetch=tftp://192.168.1.10/clonezilla/filesystem.squashfs
```

## 🔧 UEFI Boot Configuration

### Setting Up GRUB for UEFI

**Step 1: Create GRUB Configuration**

```bash
# Create GRUB directory
sudo mkdir -p /var/lib/tftpboot/grub

# Create grub.cfg
sudo nano /var/lib/tftpboot/grub/grub.cfg
```

**GRUB menu configuration:**

```
set default="0"
set timeout=30

menuentry 'Boot from local disk' {
    exit
}

menuentry 'Ubuntu 22.04 Live' {
    linux /ubuntu/vmlinuz ip=dhcp url=http://192.168.1.10/ubuntu/ubuntu-22.04.3-live-server-amd64.iso
    initrd /ubuntu/initrd
}

menuentry 'Install Ubuntu 22.04' {
    linux /ubuntu/vmlinuz ip=dhcp url=http://192.168.1.10/ubuntu/ubuntu-22.04.3-live-server-amd64.iso autoinstall
    initrd /ubuntu/initrd
}
```

### Supporting Both BIOS and UEFI

Your dnsmasq configuration (shown earlier) already handles both:
- BIOS systems get `pxelinux.0`
- UEFI systems get `bootx64.efi`

## 🖥️ Client Configuration

### Enabling PXE Boot in BIOS/UEFI

**General Steps:**
1. Enter BIOS/UEFI setup (usually F2, Del, F10, or F12 during boot)
2. Navigate to Boot menu
3. Enable Network Boot or PXE Boot
4. Set network boot as first boot device (or press F12 for boot menu)
5. Ensure Secure Boot is disabled (for some OS)
6. Save and exit

**Common BIOS Settings:**
```
Advanced → Network Stack Configuration → Enable
Boot → Boot Option #1 → Network Boot
Security → Secure Boot → Disabled (if needed)
```

### Testing PXE Boot

**Expected boot sequence:**
1. PC powers on
2. Shows "Searching for boot server..."
3. Displays "Getting IP address..." (DHCP)
4. Shows "Loading pxelinux.0..." (TFTP)
5. PXE menu appears
6. Select option and boot

## 📊 Advanced PXE Configuration

### MAC Address-Based Boot Options

Configure different boot options based on MAC address:

```bash
# Create MAC-specific config
# Format: 01-aa-bb-cc-dd-ee-ff (01 prefix + MAC with dashes)
sudo nano /var/lib/tftpboot/pxelinux.cfg/01-aa-bb-cc-dd-ee-10
```

```
DEFAULT ubuntu-auto-install
LABEL ubuntu-auto-install
    KERNEL ubuntu/vmlinuz
    APPEND initrd=ubuntu/initrd autoinstall ds=nocloud-net;s=http://192.168.1.10/configs/workstation-1/
```

### Automated Installations with Preseed/Cloud-Init

**For Ubuntu (cloud-init):**

```bash
# Create autoinstall directory
sudo mkdir -p /var/www/html/configs/autoinstall

# Create user-data file
sudo nano /var/www/html/configs/autoinstall/user-data
```

Example `user-data`:
```yaml
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: workstation-1
    username: admin
    password: "$6$rounds=4096$encrypted_password_hash"
  ssh:
    install-server: yes
  packages:
    - vim
    - curl
    - git
  late-commands:
    - echo 'admin ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/admin
```

### iPXE for Advanced Features

iPXE provides more features than PXELINUX:

```bash
# Install iPXE
sudo apt install ipxe

# Copy iPXE binary
sudo cp /usr/lib/ipxe/undionly.kpxe /var/lib/tftpboot/

# Update dnsmasq to use iPXE
sudo nano /etc/dnsmasq.conf
```

Add:
```
dhcp-boot=undionly.kpxe
```

Create iPXE menu:
```bash
sudo nano /var/lib/tftpboot/boot.ipxe
```

```
#!ipxe

:menu
menu PXE Boot Menu
item ubuntu Ubuntu 22.04
item windows Windows 10
item shell iPXE Shell
choose --default ubuntu --timeout 30000 target && goto ${target}

:ubuntu
kernel http://192.168.1.10/ubuntu/vmlinuz
initrd http://192.168.1.10/ubuntu/initrd
imgargs vmlinuz initrd=initrd ip=dhcp url=http://192.168.1.10/ubuntu/ubuntu-22.04.3-live-server-amd64.iso
boot

:windows
kernel wimboot
initrd winpe.wim
boot

:shell
shell
```

## 🔍 Monitoring and Logging

### Enable Detailed Logging

```bash
# Edit dnsmasq config
sudo nano /etc/dnsmasq.conf
```

Add:
```
log-dhcp
log-queries
log-facility=/var/log/dnsmasq.log
```

### Monitor in Real-Time

```bash
# Watch DHCP/TFTP requests
sudo tail -f /var/log/dnsmasq.log

# Watch TFTP specifically
sudo tail -f /var/log/syslog | grep tftp

# Monitor Apache access (for HTTP downloads)
sudo tail -f /var/log/apache2/access.log
```

### Common Log Messages

**Successful PXE boot:**
```
DHCPDISCOVER from aa:bb:cc:dd:ee:10
DHCPOFFER to 192.168.1.101
DHCPREQUEST from aa:bb:cc:dd:ee:10
DHCPACK to 192.168.1.101
TFTP sent /var/lib/tftpboot/pxelinux.0 to 192.168.1.101
```

## 🚨 Troubleshooting

### Issue: PXE-E51 (No DHCP or Proxy DHCP offers)

**Cause:** Client can't find DHCP server

**Solutions:**
```bash
# Check if dnsmasq is running
sudo systemctl status dnsmasq

# Check DHCP is enabled
sudo grep dhcp-range /etc/dnsmasq.conf

# Check firewall
sudo ufw status
sudo ufw allow 67/udp
sudo ufw allow 68/udp

# Test DHCP
sudo nmap --script broadcast-dhcp-discover
```

### Issue: PXE-E32 (TFTP open timeout)

**Cause:** TFTP server not responding

**Solutions:**
```bash
# Check TFTP is enabled
sudo grep enable-tftp /etc/dnsmasq.conf

# Check TFTP port
sudo netstat -tulnp | grep :69

# Test TFTP manually
tftp 192.168.1.10
> get pxelinux.0
> quit

# Check file permissions
ls -la /var/lib/tftpboot/pxelinux.0
sudo chmod 644 /var/lib/tftpboot/pxelinux.0
```

### Issue: Boot Menu Doesn't Appear

**Cause:** Missing menu files

**Solutions:**
```bash
# Check default config exists
ls -la /var/lib/tftpboot/pxelinux.cfg/default

# Check menu.c32 exists
ls -la /var/lib/tftpboot/menu.c32

# Re-copy syslinux files
sudo cp /usr/lib/syslinux/modules/bios/*.c32 /var/lib/tftpboot/
```

### Issue: Slow Boot or Download

**Cause:** Network bottleneck

**Solutions:**
```bash
# Check network speed
iperf3 -s  # On server
iperf3 -c 192.168.1.10  # On client

# Use HTTP instead of TFTP for large files
# (TFTP is slow, HTTP is faster)

# Ensure gigabit connection
ethtool eno1 | grep Speed
```

## 📋 Checklist for PXE Setup

- [ ] Server has static IP configured
- [ ] dnsmasq installed and configured
- [ ] TFTP directory created with proper permissions
- [ ] Boot files copied (pxelinux.0, *.c32)
- [ ] Boot menu created
- [ ] OS images downloaded and extracted
- [ ] HTTP server configured for large files
- [ ] Firewall rules added (DHCP, TFTP, HTTP)
- [ ] Services started and enabled
- [ ] Client BIOS configured for network boot
- [ ] PXE boot tested successfully

## 🔗 Related Documentation

- [[Network Setup Guide]] - Network infrastructure
- [[FOG Project Setup]] - Complete deployment solution
- [[Image Management Guide]] - Managing OS images
- [[DHCP and DNS Configuration]] - Detailed DHCP setup
- [[Troubleshooting Guide]] - Advanced troubleshooting

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate to Advanced
