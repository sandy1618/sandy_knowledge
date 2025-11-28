---
title: FOG Project Setup Guide
tags: [fog, deployment, imaging, pxe, automation]
created: 2025-11-24
---

# FOG Project Setup Guide

Complete guide to installing and configuring FOG (Free Open-source Ghost) for automated OS deployment and management.

## 🎯 What is FOG Project?

**FOG Project** is a free, open-source network computer cloning and management solution. It provides:

- **OS Imaging:** Capture and deploy disk images
- **PXE Boot:** Automatic network boot configuration
- **Inventory Management:** Track hardware information
- **Remote Management:** Wake-on-LAN, snapins, printers
- **Web Interface:** Easy-to-use management portal
- **Multi-platform:** Windows, Linux, macOS support

### Why Use FOG?

✅ **All-in-One Solution:** DHCP, TFTP, PXE, Imaging in one package
✅ **User-Friendly:** Web-based interface, no command line needed
✅ **Fast Deployment:** Multicast imaging for multiple PCs simultaneously
✅ **Free and Open Source:** No licensing costs
✅ **Active Community:** Large user base and support
✅ **Extensible:** Plugin system for additional features

## 📊 FOG Architecture

```
FOG Server (192.168.1.10)
├── Web Interface (Apache/PHP)
│   └── http://192.168.1.10/fog
├── MySQL Database
│   └── Stores hosts, images, tasks, etc.
├── TFTP Server
│   └── Serves boot files
├── NFS Server
│   └── Stores disk images
├── FTP Server
│   └── Image uploads/downloads
└── FOG Services
    ├── Imaging service
    ├── Multicast service
    ├── Scheduler
    └── Wake-on-LAN

Client PCs
├── PXE boot to FOG menu
├── Register with FOG server
├── Receive tasks (capture/deploy image)
└── Report inventory
```

## 🚀 Installation

### System Requirements

**Server Requirements:**
- **OS:** Ubuntu 22.04 LTS (recommended), Debian, CentOS, Rocky Linux
- **CPU:** 2+ cores (4+ for multicast)
- **RAM:** 4 GB minimum (8+ GB recommended)
- **Storage:** 
  - 100 GB for system
  - 500+ GB for images (depends on number of images)
- **Network:** Gigabit Ethernet

**Client Requirements:**
- PXE boot capable
- Network boot enabled in BIOS
- Supported by FOG (most modern hardware)

### Pre-Installation Preparation

**Step 1: Update System**
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot  # If kernel was updated
```

**Step 2: Set Static IP**

See [[Network Setup Guide]] for detailed instructions.

Quick method:
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: no
      addresses: [192.168.1.10/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

```bash
sudo netplan apply
```

**Step 3: Set Hostname**
```bash
sudo hostnamectl set-hostname fog-server
sudo nano /etc/hosts
```

Add:
```
127.0.0.1 localhost
192.168.1.10 fog-server fog-server.local
```

### FOG Installation

**Step 1: Download FOG**
```bash
# Install git
sudo apt install -y git

# Clone FOG repository
cd ~
git clone https://github.com/FOGProject/fogproject.git

# Navigate to installer
cd fogproject/bin
```

**Step 2: Run Installer**
```bash
sudo ./installfog.sh
```

**Step 3: Answer Installation Questions**

```
What version of Linux would you like to run the installation for?
    1) Redhat Based Linux (Fedora, CentOS, RHEL, Mageia)
    2) Debian Based Linux (Debian, Ubuntu, Kubuntu, Edubuntu)
> 2

What type of installation would you like to do?
    N) Normal Server
    S) Storage Node
> N

What is the IP address to be used by this FOG Server? [192.168.1.10]
> [Press Enter]

Would you like to setup a router address for the DHCP server? [Y/n]
> Y

What is the IP address to be used for the router on the DHCP server? [192.168.1.1]
> [Press Enter]

Would you like to setup a DNS address for the DHCP server? [Y/n]
> Y

What is the IP address to be used for DNS on the DHCP server? [8.8.8.8]
> [Press Enter]

Would you like to use the FOG server for DHCP service? [Y/n]
> Y (or N if you have existing DHCP - see notes below)

This version of FOG has internationalization support, would you like to install the language packs? [Y/n]
> N (unless you need non-English support)

Are you sure you wish to continue? [Y/n]
> Y
```

**Step 4: Wait for Installation**

Installation takes 10-30 minutes depending on system speed.

**Step 5: Complete Web Installation**

After script completes, open web browser:
```
http://192.168.1.10/fog/management
```

Click "Install/Upgrade Now" and follow prompts.

**Step 6: Update FOG Database Schema**

Run the database installation script when prompted.

### Post-Installation Configuration

**Step 1: Login to FOG Web Interface**
```
URL: http://192.168.1.10/fog/management
Default Username: fog
Default Password: password
```

**Important:** Change the default password immediately!

**Step 2: Configure FOG Settings**

Navigate to **FOG Configuration → FOG Settings**

**Storage Settings:**
```
FOG_NFS_DATADIR: /images
FOG_TFTP_PXE_KERNEL_DIR: /tftpboot
```

**Network Settings:**
```
FOG_WEB_HOST: 192.168.1.10
FOG_TFTP_HOST: 192.168.1.10
FOG_NFS_HOST: 192.168.1.10
```

**Bandwidth Settings:**
```
FOG_MULTICAST_MAX_SESSIONS: 64
FOG_PIGZ_COMP: 9 (compression level)
FOG_UDP_SENDER_MAXWAIT: 10
```

## 🖥️ Registering Client PCs

### Method 1: Quick Registration

**Step 1: Boot Client via PXE**
- Enable PXE boot in BIOS
- Boot from network
- FOG menu appears

**Step 2: Perform Quick Registration**
- Select "Perform Full Host Registration and Inventory"
- Answer questions:
  ```
  Hostname: workstation-1
  Image ID: [Select or create later]
  Would you like to associate this host with groups? N
  Would you like to associate this host with snapins? N
  Would you like to associate this host with printers? N
  Would you like to associate the hardware to all other hosts? N
  ```

**Step 3: Complete Registration**
- PC will inventory hardware
- Reboot when complete
- Host now registered in FOG

### Method 2: Manual Registration via Web Interface

**Navigate to:** Hosts → Create New Host

**Required Information:**
```
Host Name: workstation-1
Primary MAC: aa:bb:cc:dd:ee:10
Host Image: [Select from list]
Host Product Key: [If using Windows]
```

**Optional Information:**
```
Host Description: Marketing Workstation
Host Tags: [For grouping]
Host Snapins: [Software to deploy]
Host Printers: [Printers to install]
```

## 💾 Creating and Managing Images

### Creating Your First Image

**Step 1: Prepare Source PC**

On the PC you want to image:
```
1. Install OS (Windows/Linux)
2. Install all software
3. Configure settings
4. Run Windows Sysprep (for Windows)
5. Shut down
```

**Windows Sysprep:**
```
C:\Windows\System32\Sysprep\sysprep.exe
- System Cleanup Action: Enter System Out-of-Box Experience (OOBE)
- Generalize: Checked
- Shutdown Options: Shutdown
```

**Step 2: Create Image Definition in FOG**

Navigate to **Image Management → Create New Image**

```
Image Name: windows10-standard
Image Description: Windows 10 with Office 2021
Storage Group: default
Operating System: Windows 10
Image Type: Multiple Partition Image - Single Disk (99% of cases)
Partition: Everything
Image Compression: Gzip (default)
```

**Step 3: Associate Image with Host**

Navigate to **Hosts → [Your Host]**
- Set "Host Image" to your newly created image
- Save

**Step 4: Create Capture Task**

Navigate to **Hosts → [Your Host] → Basic Tasks**
- Click "Capture"
- Confirm task creation

**Step 5: Boot Client and Capture**
- Boot client via PXE
- FOG will automatically start capture
- Progress shown on screen
- PC will reboot when complete

**Typical Capture Times:**
- 50 GB Windows installation: 15-30 minutes
- 20 GB Linux installation: 10-15 minutes
- (Depends on network speed and disk speed)

### Deploying Images

**Step 1: Create Deploy Task**

Navigate to **Hosts → [Target Host] → Basic Tasks**
- Click "Deploy"
- Confirm task creation

**Step 2: Boot Client**
- Client boots via PXE
- FOG automatically starts deployment
- Progress shown on screen
- PC will reboot when complete

**Step 3: Post-Deployment**
- Windows: Complete OOBE (create user, etc.)
- Linux: Login and configure as needed

### Multi-Cast Deployment

Deploy same image to multiple PCs simultaneously:

**Step 1: Create Multicast Session**

Navigate to **Tasks → Active Multicast Tasks**
- Click "Create New Session"

```
Session Name: windows10-deploy-20231124
Image: windows10-standard
Start Time: Immediately
Port: 9000
```

**Step 2: Add Clients to Session**

For each client:
- Navigate to **Hosts → [Host] → Basic Tasks**
- Click "Multicast"
- Select the session
- Confirm

**Step 3: Start Deployment**
- Boot all clients
- They will wait for all clients to join
- Deployment starts automatically when ready
- All clients receive data simultaneously

**Benefits of Multicast:**
- ✅ Same network bandwidth as single deployment
- ✅ Deploy to 10, 20, 50+ PCs at once
- ✅ Faster than sequential deployments
- ✅ Ideal for computer labs

## 🔧 Advanced Features

### Snapins (Software Deployment)

**What are Snapins?**
- Software packages deployed after imaging
- Can be executables, scripts, or installers
- Run automatically after OS deployment

**Creating a Snapin:**

Navigate to **Snapins → Create New Snapin**

```
Snapin Name: Google Chrome
Snapin Description: Installs Google Chrome browser
Snapin File: ChromeSetup.exe
Snapin Run With: [blank for EXE]
Snapin Run With Argument: /silent /install
Snapin Template: Chrome Install
```

**Associating Snapin with Host:**
- Navigate to **Hosts → [Host]**
- Click "Host Associations" tab
- Select snapins to deploy
- Save

### Wake-on-LAN

**Remotely wake up computers:**

**Requirements:**
- Network card supports WOL
- Enabled in BIOS
- PC connected to power and network

**Using WOL:**
```bash
# From command line
sudo etherwakeonlan aa:bb:cc:dd:ee:10

# From FOG web interface
Navigate to Hosts → [Host] → Advanced → Wake On LAN
```

**Scheduled Wake:**
- Navigate to **FOG Configuration → FOG Settings**
- Set **FOG_WOL_HOST**: enabled
- Create scheduled task to wake hosts

### Host Groups

**Organize hosts into groups:**

Navigate to **Groups → Create New Group**

```
Group Name: Marketing Department
Group Description: All marketing workstations
Group Members: [Select hosts]
```

**Benefits:**
- Deploy image to entire group at once
- Manage settings for all members
- Report on group inventory

### Printer Management

**Deploy printers automatically:**

Navigate to **Printer Management → Create New Printer**

```
Printer Name: HP-LaserJet-Floor2
Printer Type: Network
Printer Port: 192.168.1.200
Printer Model: HP LaserJet Pro
```

**Associate with Host:**
- Navigate to **Hosts → [Host]**
- Click "Host Associations" tab
- Select printers
- Save

### Inventory Reports

**View hardware inventory:**

Navigate to **Reports → Host Inventory**

**Available information:**
- CPU, RAM, Motherboard
- Hard drives, sizes
- Network cards, MACs
- Operating system
- Last check-in time

**Export Reports:**
- CSV format
- PDF format
- Custom queries

## 🔐 Security Best Practices

### Change Default Credentials

```bash
# Change FOG web interface password
Navigate to User Management → fog → Change Password

# Change MySQL root password
sudo mysql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'NewStrongPassword';
FLUSH PRIVILEGES;
EXIT;

# Update FOG config
sudo nano /var/www/html/fog/lib/fog/config.class.php
# Update MYSQL_PASSWORD
```

### Secure Web Interface

**Enable HTTPS:**
```bash
# Install SSL certificate
sudo apt install certbot python3-certbot-apache

# Generate certificate (for domain) or use self-signed
sudo certbot --apache -d fog-server.local

# Or create self-signed certificate
sudo a2enmod ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/fog-selfsigned.key \
    -out /etc/ssl/certs/fog-selfsigned.crt

# Configure Apache
sudo nano /etc/apache2/sites-available/default-ssl.conf
```

### Restrict Access

**Firewall Rules:**
```bash
# Allow only from local network
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw allow from 192.168.1.0/24 to any port 443
sudo ufw allow from 192.168.1.0/24 to any port 69
sudo ufw allow from 192.168.1.0/24 to any port 21
sudo ufw allow from 192.168.1.0/24 to any port 2049

# SSH access
sudo ufw allow 22/tcp
```

### Regular Backups

**Backup FOG Configuration:**
```bash
# Create backup script
sudo nano /root/backup-fog.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/backups/fog"
DATE=$(date +%Y%m%d)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup MySQL database
mysqldump -u root -p fog > $BACKUP_DIR/fog-db-$DATE.sql

# Backup images (optional - can be large)
# rsync -av /images/ $BACKUP_DIR/images-$DATE/

# Backup FOG web files
tar -czf $BACKUP_DIR/fog-web-$DATE.tar.gz /var/www/html/fog/

# Backup FOG configuration
tar -czf $BACKUP_DIR/fog-config-$DATE.tar.gz /opt/fog/

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

```bash
# Make executable
sudo chmod +x /root/backup-fog.sh

# Schedule with cron
sudo crontab -e
# Add: 0 2 * * * /root/backup-fog.sh
```

## 🚨 Troubleshooting

### Issue: Client Can't PXE Boot

**Check:**
```bash
# Verify TFTP is running
sudo systemctl status tftpd-hpa

# Check DHCP configuration
sudo nano /etc/dhcp/dhcpd.conf

# Test TFTP manually
tftp 192.168.1.10
> get undionly.kpxe
> quit

# Check firewall
sudo ufw status
```

### Issue: Image Capture/Deploy Fails

**Common Causes:**
1. Disk errors on source/target PC
2. Network interruption
3. Insufficient space on FOG server

**Solutions:**
```bash
# Check disk space
df -h /images

# Check FOG logs
sudo tail -f /var/log/apache2/error.log
sudo tail -f /opt/fog/log/foginstall.log

# Verify NFS is running
sudo systemctl status nfs-server

# Test NFS mount
sudo mount -t nfs 192.168.1.10:/images /mnt
ls /mnt
sudo umount /mnt
```

### Issue: Slow Image Transfer

**Causes:**
- Network bottleneck
- Disk I/O limitations
- Compression settings

**Solutions:**
```bash
# Test network speed
iperf3 -s  # On server
iperf3 -c 192.168.1.10  # On client

# Adjust compression (lower = faster, larger)
Navigate to: Image Management → [Image] → Image Compression
Change to: 3 or 6 (instead of 9)

# Enable FTP transfer (faster than NFS for some scenarios)
Navigate to: FOG Configuration → FOG Settings
Set: FOG_TFTP_FTP_USERNAME and PASSWORD
```

### Issue: Multicast Not Working

**Check:**
```bash
# Verify UDP ports are open
sudo ufw allow 9000:9999/udp

# Check multicast service
sudo systemctl status FOGMulticastManager

# Verify clients are on same network segment
# Multicast doesn't cross routers without IGMP snooping
```

## 📋 FOG Maintenance Checklist

**Weekly:**
- [ ] Check disk space on /images
- [ ] Review failed tasks
- [ ] Update host inventory
- [ ] Test backups

**Monthly:**
- [ ] Update FOG to latest version
- [ ] Clean old images not in use
- [ ] Review and update user accounts
- [ ] Verify security settings

**Quarterly:**
- [ ] Audit all registered hosts
- [ ] Review and optimize images
- [ ] Update documentation
- [ ] Test disaster recovery

## 🔗 Related Documentation

- [[PXE Boot Setup]] - Understanding PXE infrastructure
- [[Image Management Guide]] - Advanced imaging techniques
- [[Network Setup Guide]] - Network configuration
- [[Automation and Scripts]] - Scripting FOG operations
- [[Troubleshooting Guide]] - Advanced troubleshooting

## 📚 External Resources

- [FOG Project Official Wiki](https://wiki.fogproject.org/)
- [FOG Project Forums](https://forums.fogproject.org/)
- [FOG Project GitHub](https://github.com/FOGProject/fogproject)
- [FOG Project YouTube Channel](https://www.youtube.com/user/FOGProject)

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate
