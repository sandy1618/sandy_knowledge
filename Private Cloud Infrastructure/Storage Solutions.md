---
title: Storage Solutions
tags: [storage, nas, san, nfs, samba, backup]
created: 2025-11-24
---

# Storage Solutions

Comprehensive guide to implementing storage solutions for your private cloud infrastructure.

## 🎯 Storage Overview

### Types of Storage

**1. Direct Attached Storage (DAS)**
- Storage directly connected to server
- Examples: Internal HDDs/SSDs, USB drives
- Best for: Single server, simple setups

**2. Network Attached Storage (NAS)**
- File-level storage accessible over network
- Protocols: NFS, SMB/CIFS, AFP
- Best for: File sharing, home directories

**3. Storage Area Network (SAN)**
- Block-level storage over network
- Protocols: iSCSI, Fibre Channel
- Best for: Databases, VMs, high performance

**4. Object Storage**
- Data stored as objects with metadata
- Examples: MinIO, Ceph, OpenStack Swift
- Best for: Large files, backups, archives

## 📊 Storage Architecture

```
Private Cloud Storage Infrastructure

Server (192.168.1.10)
├── OS Disk: 100 GB SSD
├── Data Disk 1: 1 TB HDD (NFS Exports)
│   ├── /images (FOG images)
│   ├── /home (User home directories)
│   └── /shared (Shared files)
└── Data Disk 2: 2 TB HDD (Backups)
    └── /backups

Optional: Dedicated NAS (192.168.1.12)
├── 4x 2TB HDDs in RAID 5
├── Total: 6 TB usable
├── Protocols: NFS, SMB, iSCSI
└── Purpose: Central file storage
```

## 💾 NFS (Network File System) Setup

### NFS Server Installation

**Install NFS server:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y nfs-kernel-server

# CentOS/RHEL
sudo yum install -y nfs-utils
sudo systemctl enable nfs-server
sudo systemctl start nfs-server
```

### Configure NFS Exports

**Create directories:**
```bash
# Create storage directories
sudo mkdir -p /storage/images
sudo mkdir -p /storage/shared
sudo mkdir -p /storage/home
sudo mkdir -p /storage/backups

# Set permissions
sudo chmod 755 /storage
sudo chmod 755 /storage/shared
sudo chmod 700 /storage/home
```

**Configure exports:**
```bash
sudo nano /etc/exports
```

```
# NFS Exports Configuration

# FOG images directory - Read/Write for FOG server only
/storage/images 192.168.1.10(rw,sync,no_root_squash,no_subtree_check)

# Shared files - Read/Write for all local network
/storage/shared 192.168.1.0/24(rw,sync,no_root_squash,no_subtree_check)

# Home directories - Read/Write for all, with root squashing
/storage/home 192.168.1.0/24(rw,sync,root_squash,no_subtree_check)

# Backups - Read-only for network, Read/Write for backup server
/storage/backups 192.168.1.0/24(ro,sync,no_subtree_check)
/storage/backups 192.168.1.15(rw,sync,no_root_squash,no_subtree_check)

# Export options explained:
# rw - Read/Write access
# ro - Read-only access
# sync - Synchronous writes (safer but slower)
# async - Asynchronous writes (faster but risky)
# no_root_squash - Root on client = root on server
# root_squash - Root on client = nobody on server (more secure)
# no_subtree_check - Disable subtree checking (better performance)
```

**Apply exports:**
```bash
# Export all directories
sudo exportfs -ra

# Verify exports
sudo exportfs -v

# Show what's exported
showmount -e localhost
```

**Start NFS service:**
```bash
# Ubuntu/Debian
sudo systemctl start nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# CentOS/RHEL
sudo systemctl start nfs-server
sudo systemctl enable nfs-server

# Check status
sudo systemctl status nfs-server
```

### NFS Client Configuration

**Install NFS client:**
```bash
# Ubuntu/Debian
sudo apt install -y nfs-common

# CentOS/RHEL
sudo yum install -y nfs-utils
```

**Mount NFS shares:**
```bash
# Create mount points
sudo mkdir -p /mnt/shared
sudo mkdir -p /mnt/home

# Mount manually
sudo mount -t nfs 192.168.1.10:/storage/shared /mnt/shared
sudo mount -t nfs 192.168.1.10:/storage/home /mnt/home

# Verify mount
df -h | grep nfs
mount | grep nfs
```

**Permanent mounts (fstab):**
```bash
sudo nano /etc/fstab
```

```
# NFS mounts
192.168.1.10:/storage/shared    /mnt/shared    nfs    defaults,_netdev    0 0
192.168.1.10:/storage/home      /mnt/home      nfs    defaults,_netdev    0 0

# With performance options
192.168.1.10:/storage/shared    /mnt/shared    nfs    rw,hard,intr,rsize=8192,wsize=8192,timeo=14,_netdev    0 0
```

**Mount all fstab entries:**
```bash
sudo mount -a
```

## 🗂️ Samba (SMB/CIFS) Setup

### Samba Server Installation

**Install Samba:**
```bash
# Ubuntu/Debian
sudo apt install -y samba samba-common-bin

# CentOS/RHEL
sudo yum install -y samba samba-client
```

### Configure Samba Shares

**Backup original config:**
```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

**Edit Samba configuration:**
```bash
sudo nano /etc/samba/smb.conf
```

```ini
[global]
    workgroup = WORKGROUP
    server string = Private Cloud File Server
    netbios name = FILESERVER
    security = user
    map to guest = bad user
    dns proxy = no
    
    # Performance tuning
    socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=65536 SO_SNDBUF=65536
    read raw = yes
    write raw = yes
    max xmit = 65535
    
    # Logging
    log file = /var/log/samba/log.%m
    max log size = 1000
    log level = 1

# Public share - No authentication
[Public]
    path = /storage/shared
    browseable = yes
    read only = no
    guest ok = yes
    create mask = 0755
    directory mask = 0755
    comment = Public shared folder

# Private share - Authentication required
[Private]
    path = /storage/private
    browseable = yes
    read only = no
    guest ok = no
    valid users = @users
    create mask = 0660
    directory mask = 0770
    comment = Private shared folder

# Home directories
[homes]
    comment = Home Directories
    browseable = no
    read only = no
    create mask = 0700
    directory mask = 0700
    valid users = %S

# Images share (for FOG)
[Images]
    path = /storage/images
    browseable = yes
    read only = no
    guest ok = no
    valid users = foguser
    comment = Disk Images
    create mask = 0644
    directory mask = 0755
```

**Create Samba users:**
```bash
# Create system user (if doesn't exist)
sudo useradd -M -s /sbin/nologin sambuser

# Set Samba password
sudo smbpasswd -a sambuser
# Enter password when prompted

# Enable user
sudo smbpasswd -e sambuser

# Create user for FOG
sudo useradd -M -s /sbin/nologin foguser
sudo smbpasswd -a foguser
```

**Test configuration:**
```bash
# Test config syntax
testparm

# Restart Samba
sudo systemctl restart smbd
sudo systemctl restart nmbd

# Enable on boot
sudo systemctl enable smbd
sudo systemctl enable nmbd

# Check status
sudo systemctl status smbd
sudo systemctl status nmbd
```

### Samba Client Access

**Linux client:**
```bash
# Install Samba client
sudo apt install -y cifs-utils

# Create mount point
sudo mkdir -p /mnt/samba-shared

# Mount manually
sudo mount -t cifs //192.168.1.10/Public /mnt/samba-shared -o guest

# Mount with authentication
sudo mount -t cifs //192.168.1.10/Private /mnt/samba-private -o username=sambuser,password=yourpassword

# Permanent mount (fstab)
sudo nano /etc/fstab
```

```
//192.168.1.10/Public    /mnt/samba-shared    cifs    guest,uid=1000,iocharset=utf8    0 0
//192.168.1.10/Private   /mnt/samba-private   cifs    credentials=/root/.smbcredentials,uid=1000,iocharset=utf8    0 0
```

**Create credentials file:**
```bash
sudo nano /root/.smbcredentials
```

```
username=sambuser
password=yourpassword
```

```bash
sudo chmod 600 /root/.smbcredentials
```

**Windows client:**
```
1. Open File Explorer
2. Type in address bar: \\192.168.1.10\Public
3. Or map network drive:
   - Right-click "This PC" → "Map network drive"
   - Drive: Z:
   - Folder: \\192.168.1.10\Public
   - Check "Reconnect at sign-in"
```

## 🔌 iSCSI (SAN) Setup

### iSCSI Target (Server) Setup

**Install iSCSI target:**
```bash
# Ubuntu/Debian
sudo apt install -y tgt

# CentOS/RHEL
sudo yum install -y targetcli
```

**Using targetcli (modern way):**
```bash
# Start targetcli
sudo targetcli

# Inside targetcli:
# Create backstores (storage)
/backstores/fileio create disk1 /storage/iscsi/disk1.img 10G

# Create iSCSI target
/iscsi create iqn.2023-11.local.fileserver:storage

# Create LUN
/iscsi/iqn.2023-11.local.fileserver:storage/tpg1/luns create /backstores/fileio/disk1

# Create ACL (allow specific initiator)
/iscsi/iqn.2023-11.local.fileserver:storage/tpg1/acls create iqn.2023-11.local.client:initiator1

# Set authentication (optional but recommended)
/iscsi/iqn.2023-11.local.fileserver:storage/tpg1 set attribute authentication=1
/iscsi/iqn.2023-11.local.fileserver:storage/tpg1/acls/iqn.2023-11.local.client:initiator1 set auth userid=iscsiuser
/iscsi/iqn.2023-11.local.fileserver:storage/tpg1/acls/iqn.2023-11.local.client:initiator1 set auth password=iscsipassword

# Save and exit
saveconfig
exit
```

### iSCSI Initiator (Client) Setup

**Install iSCSI initiator:**
```bash
# Ubuntu/Debian
sudo apt install -y open-iscsi

# CentOS/RHEL
sudo yum install -y iscsi-initiator-utils
```

**Configure initiator:**
```bash
# Set initiator name
sudo nano /etc/iscsi/initiatorname.iscsi
```

```
InitiatorName=iqn.2023-11.local.client:initiator1
```

**Discover and connect:**
```bash
# Discover targets
sudo iscsiadm -m discovery -t sendtargets -p 192.168.1.10

# Login to target
sudo iscsiadm -m node --targetname iqn.2023-11.local.fileserver:storage --portal 192.168.1.10:3260 --login

# Configure authentication (if needed)
sudo iscsiadm -m node --targetname iqn.2023-11.local.fileserver:storage --op=update --name node.session.auth.authmethod --value=CHAP
sudo iscsiadm -m node --targetname iqn.2023-11.local.fileserver:storage --op=update --name node.session.auth.username --value=iscsiuser
sudo iscsiadm -m node --targetname iqn.2023-11.local.fileserver:storage --op=update --name node.session.auth.password --value=iscsipassword

# Verify connection
sudo iscsiadm -m session

# Check new disk
lsblk
sudo fdisk -l
```

**Format and mount iSCSI disk:**
```bash
# Format (assuming /dev/sdb)
sudo mkfs.ext4 /dev/sdb

# Create mount point
sudo mkdir /mnt/iscsi

# Mount
sudo mount /dev/sdb /mnt/iscsi

# Permanent mount
sudo nano /etc/fstab
```

```
/dev/sdb    /mnt/iscsi    ext4    _netdev    0 0
```

## 💿 RAID Configuration

### Software RAID (mdadm)

**Install mdadm:**
```bash
sudo apt install -y mdadm
```

**Create RAID array:**

**RAID 0 (Striping - Performance, No Redundancy):**
```bash
sudo mdadm --create /dev/md0 --level=0 --raid-devices=2 /dev/sdb /dev/sdc
```

**RAID 1 (Mirroring - Redundancy):**
```bash
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc
```

**RAID 5 (Striping with Parity - Good balance):**
```bash
sudo mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd
```

**RAID 10 (Mirrored Stripes - Best performance with redundancy):**
```bash
sudo mdadm --create /dev/md0 --level=10 --raid-devices=4 /dev/sdb /dev/sdc /dev/sdd /dev/sde
```

**Format and mount RAID:**
```bash
# Format
sudo mkfs.ext4 /dev/md0

# Create mount point
sudo mkdir /mnt/raid

# Mount
sudo mount /dev/md0 /mnt/raid

# Save RAID configuration
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

# Update initramfs
sudo update-initramfs -u

# Add to fstab
echo "/dev/md0 /mnt/raid ext4 defaults 0 0" | sudo tee -a /etc/fstab
```

**Monitor RAID:**
```bash
# Check status
cat /proc/mdstat

# Detailed info
sudo mdadm --detail /dev/md0

# Monitor in real-time
watch cat /proc/mdstat
```

## 🔄 Backup Solutions

### Simple Backup with rsync

**Create backup script:**
```bash
sudo nano /usr/local/bin/backup-storage.sh
```

```bash
#!/bin/bash

# Backup configuration
SOURCE="/storage/"
BACKUP_DIR="/backups/storage"
DATE=$(date +%Y%m%d-%H%M%S)
LOG="/var/log/backup-storage.log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Perform backup
echo "$(date): Starting backup" >> "$LOG"
rsync -av --delete \
    --exclude 'lost+found' \
    --exclude '.cache' \
    --exclude '.Trash' \
    "$SOURCE" "$BACKUP_DIR/current" >> "$LOG" 2>&1

# Create daily snapshot (hardlinks for space efficiency)
cp -al "$BACKUP_DIR/current" "$BACKUP_DIR/daily-$DATE"

# Keep only last 7 daily backups
find "$BACKUP_DIR" -name "daily-*" -mtime +7 -exec rm -rf {} \;

echo "$(date): Backup completed" >> "$LOG"
```

```bash
sudo chmod +x /usr/local/bin/backup-storage.sh
```

**Schedule with cron:**
```bash
sudo crontab -e
```

```
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-storage.sh

# Weekly full backup on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/backup-full.sh
```

### Backup to Remote Server

**Using rsync over SSH:**
```bash
#!/bin/bash

# Remote backup configuration
REMOTE_USER="backup"
REMOTE_HOST="backup-server.local"
REMOTE_DIR="/backups/private-cloud"
SOURCE="/storage/"

# Perform remote backup
rsync -avz --delete \
    -e "ssh -i /root/.ssh/backup_key" \
    "$SOURCE" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
```

### Snapshot-based Backups with LVM

**Create LVM snapshot:**
```bash
# Create snapshot (10GB)
sudo lvcreate -L 10G -s -n storage-snapshot /dev/vg0/storage

# Mount snapshot
sudo mkdir /mnt/snapshot
sudo mount /dev/vg0/storage-snapshot /mnt/snapshot

# Backup from snapshot
rsync -av /mnt/snapshot/ /backups/storage-$(date +%Y%m%d)/

# Remove snapshot when done
sudo umount /mnt/snapshot
sudo lvremove /dev/vg0/storage-snapshot
```

## 📊 Storage Monitoring

### Check Disk Usage

```bash
# Overall disk usage
df -h

# Directory sizes
du -h --max-depth=1 /storage

# Find large files
find /storage -type f -size +100M -exec ls -lh {} \;

# Disk I/O statistics
iostat -x 1

# Monitor in real-time
watch -n 1 df -h
```

### SMART Monitoring

**Install smartmontools:**
```bash
sudo apt install -y smartmontools
```

**Check disk health:**
```bash
# Basic info
sudo smartctl -i /dev/sda

# Health status
sudo smartctl -H /dev/sda

# Detailed info
sudo smartctl -a /dev/sda

# Run short test
sudo smartctl -t short /dev/sda

# Run long test
sudo smartctl -t long /dev/sda

# View test results
sudo smartctl -l selftest /dev/sda
```

**Enable monitoring:**
```bash
# Edit smartd config
sudo nano /etc/smartd.conf
```

```
# Monitor all disks
DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,35,40 -m root
```

```bash
sudo systemctl enable smartd
sudo systemctl start smartd
```

## 🔗 Related Documentation

- [[Network Setup Guide]] - Network infrastructure
- [[Security Best Practices]] - Securing storage
- [[Automation and Scripts]] - Storage automation
- [[Troubleshooting Guide]] - Storage troubleshooting

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate to Advanced
