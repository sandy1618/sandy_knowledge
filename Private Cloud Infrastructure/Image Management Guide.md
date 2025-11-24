---
title: Image Management Guide
tags: [imaging, deployment, backup, cloning, disk-management]
created: 2025-11-24
---

# Image Management Guide

Comprehensive guide to creating, managing, and deploying OS images for your private cloud infrastructure.

## 🎯 What is Image Management?

**Image management** is the process of creating, storing, maintaining, and deploying disk images of operating systems and applications. An image is a complete snapshot of a computer's disk that can be restored to identical or different hardware.

### Benefits of Image Management

✅ **Rapid Deployment:** Install OS in minutes instead of hours
✅ **Consistency:** Identical configuration across all PCs
✅ **Version Control:** Maintain multiple image versions
✅ **Disaster Recovery:** Quick restoration from failures
✅ **Standardization:** Enforce organizational standards
✅ **Time Savings:** Eliminate repetitive manual installations

## 📊 Image Types

### 1. Disk Image (Complete Disk Clone)

**What it includes:**
- All partitions (boot, system, recovery)
- Exact sector-by-sector copy
- Bootloader and partition table

**Use cases:**
- Bare metal restoration
- Hardware replacement
- Disaster recovery

**Tools:** Clonezilla, dd, FOG

### 2. Partition Image

**What it includes:**
- Single partition contents
- Filesystem data only
- Can resize during deployment

**Use cases:**
- Standard deployments
- Flexible sizing
- Most common approach

**Tools:** FOG, Norton Ghost, Macrium Reflect

### 3. System Image

**What it includes:**
- Operating system and applications
- System settings and configurations
- Excludes user data

**Use cases:**
- Windows deployment
- Enterprise rollouts
- Refresh/repave scenarios

**Tools:** Windows Imaging Format (WIM), FOG

### 4. Application Image/Template

**What it includes:**
- Specific application layer
- Dependencies and configurations
- Can be layered on base OS

**Use cases:**
- Software deployment
- Container images
- Modular deployments

**Tools:** Docker, Ansible, Snapins

## 🛠️ Image Creation Process

### Preparing the Source Computer

#### For Windows

**Step 1: Install and Configure Windows**
```
1. Install Windows (10/11)
2. Install Windows Updates
3. Install drivers (if needed)
4. Activate Windows (KMS or retail)
5. Install software (Office, browsers, etc.)
6. Configure settings
7. Remove temporary files
8. Run Disk Cleanup
```

**Step 2: Optimize the System**
```powershell
# Run as Administrator

# Clean temporary files
cleanmgr /sageset:1
cleanmgr /sagerun:1

# Remove Windows Update cache (optional)
# Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

# Defragment (if HDD, skip for SSD)
defrag C: /O

# Disable hibernation (saves space)
powercfg /h off
```

**Step 3: Sysprep (Generalize)**

Sysprep prepares Windows for imaging by:
- Removing unique identifiers (SID)
- Removing hardware-specific drivers
- Resetting activation
- Enabling OOBE on next boot

```
1. Open: C:\Windows\System32\Sysprep\sysprep.exe
2. System Cleanup Action: Enter System Out-of-Box Experience (OOBE)
3. Check: Generalize
4. Shutdown Options: Shutdown
5. Click OK
```

**Alternative: Sysprep via Command Line**
```cmd
C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown
```

**Sysprep with Answer File (unattend.xml):**
```cmd
C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown /unattend:C:\unattend.xml
```

#### For Linux

**Step 1: Install and Configure Linux**
```bash
# Install Ubuntu/Debian/CentOS
# Install updates
sudo apt update && sudo apt upgrade -y  # Ubuntu/Debian
sudo yum update -y  # CentOS/RHEL

# Install software
sudo apt install -y vim git htop  # Example packages

# Configure settings
# Set timezone, keyboard, etc.
```

**Step 2: Prepare for Imaging**
```bash
# Clean package cache
sudo apt clean  # Ubuntu/Debian
sudo yum clean all  # CentOS/RHEL

# Remove old kernels (Ubuntu)
sudo apt autoremove -y

# Clear logs
sudo truncate -s 0 /var/log/*.log
sudo truncate -s 0 /var/log/**/*.log

# Clear bash history
history -c
cat /dev/null > ~/.bash_history

# Clear machine-id (will be regenerated on boot)
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clear network persistent rules (if needed)
sudo rm /etc/udev/rules.d/70-persistent-net.rules

# Shutdown
sudo shutdown -h now
```

### Capturing the Image with FOG

See **[[FOG Project Setup]]** for detailed FOG instructions.

**Quick Steps:**
```
1. Create image definition in FOG
2. Associate image with host
3. Create capture task
4. Boot client via PXE
5. Image automatically captured
6. Stored in /images on FOG server
```

### Capturing with Clonezilla

**Step 1: Boot Clonezilla**
- Boot from Clonezilla USB or via PXE
- Select appropriate options

**Step 2: Choose Mode**
```
device-image: Work with disk/partition images
```

**Step 3: Choose Mount Point**
```
local_dev: Use local device (USB drive)
ssh_server: Use SSH server
samba_server: Use Samba server
nfs_server: Use NFS server
```

**Step 4: Select Source**
```
savedisk: Save entire disk as image
saveparts: Save partitions as image
```

**Step 5: Configure Image**
```
Image name: windows10-office-20231124
Source disk: /dev/sda
Compression: -z1p (parallel gzip)
```

**Step 6: Start Capture**
- Confirm settings
- Wait for completion
- Image saved to specified location

### Creating WIM Images (Windows)

**Using DISM (Deployment Image Servicing and Management):**

**Capture Image:**
```powershell
# Boot into WinPE or another Windows installation

# Capture Windows partition
Dism /Capture-Image /ImageFile:C:\install.wim /CaptureDir:D:\ /Name:"Windows 10 Pro"

# Capture with compression
Dism /Capture-Image /ImageFile:C:\install.wim /CaptureDir:D:\ /Name:"Windows 10 Pro" /Compress:max /CheckIntegrity /Verify
```

**Apply Image:**
```powershell
# List images in WIM
Dism /Get-WimInfo /WimFile:C:\install.wim

# Apply image
Dism /Apply-Image /ImageFile:C:\install.wim /Index:1 /ApplyDir:D:\
```

## 💾 Image Storage Strategies

### Storage Calculations

**Estimate storage needs:**

```
Windows 10 Base: 20-30 GB
Windows 10 with Office: 40-50 GB
Ubuntu Desktop: 15-20 GB
Ubuntu Server: 5-10 GB

Compression ratios (typical):
- Windows: 40-50% of original size
- Linux: 30-40% of original size

Example:
10 Windows images × 50 GB × 0.45 compression = 225 GB
5 Linux images × 20 GB × 0.35 compression = 35 GB
Total: 260 GB + overhead = ~300 GB minimum
```

### Storage Organization

**Recommended structure:**
```
/images/
├── production/
│   ├── windows10-standard-v1.0/
│   ├── windows10-standard-v1.1/
│   ├── ubuntu-desktop-v1.0/
│   └── ubuntu-server-v1.0/
├── development/
│   ├── windows10-dev-test/
│   └── ubuntu-dev-test/
├── legacy/
│   ├── windows7-archived/
│   └── old-images/
└── templates/
    ├── win10-base/
    └── ubuntu-base/
```

### Naming Conventions

**Good naming scheme:**
```
Format: [OS]-[Type]-[Version]-[Date]

Examples:
- win10-pro-office365-v1.0-20231124
- ubuntu22-server-lamp-v2.1-20231124
- rhel9-dev-tools-v1.0-20231124

Benefits:
- Easy to identify
- Sortable by date
- Version tracking
- Purpose clear
```

### Version Control

**Track image changes:**

```markdown
## Image: windows10-standard-v1.0
Created: 2023-11-24
Base: Windows 10 Pro 22H2
Software:
- Office 2021
- Chrome 119
- Adobe Reader DC
Modifications:
- Disabled unnecessary services
- Applied November 2023 updates
- Configured company policies

## Image: windows10-standard-v1.1
Created: 2023-12-15
Base: windows10-standard-v1.0
Changes:
- Updated to Chrome 120
- Added Teams
- Fixed printer driver issue
```

## 🚀 Image Deployment Strategies

### Unicast Deployment (One-to-One)

**When to use:**
- Single PC deployment
- Different images for different PCs
- Testing new images

**Process:**
```
1. Assign image to host in FOG
2. Create deploy task
3. Boot client
4. Image deployed
5. ~15-30 minutes per PC
```

**Pros:**
- ✅ Flexible timing
- ✅ Different images per PC
- ✅ Simple process

**Cons:**
- ❌ Slow for many PCs
- ❌ Sequential only

### Multicast Deployment (One-to-Many)

**When to use:**
- Same image to multiple PCs
- Computer lab setup
- Mass deployment events

**Process:**
```
1. Create multicast session
2. Add clients to session
3. Boot all clients
4. Wait for all to join
5. Deploy simultaneously
6. ~15-30 minutes total (same as unicast!)
```

**Pros:**
- ✅ Fast for many PCs
- ✅ Efficient bandwidth use
- ✅ Synchronized completion

**Cons:**
- ❌ All PCs must use same image
- ❌ Waits for all clients
- ❌ Requires multicast-capable network

### Automated Scheduled Deployment

**When to use:**
- Off-hours deployment
- Maintenance windows
- Automated refresh cycles

**FOG Scheduled Tasks:**
```
1. Navigate to: Tasks → Advanced → Deploy Image
2. Select hosts or groups
3. Set schedule: Daily at 2:00 AM
4. Enable Wake-on-LAN
5. Save task
```

**Cron-based automation:**
```bash
# Schedule FOG task via API
0 2 * * * /usr/local/bin/fog-deploy-task.sh groupid=5
```

## 🔧 Image Maintenance

### Regular Updates

**Monthly update cycle:**
```
Week 1: Update master PC
  - Windows/Linux updates
  - Software updates
  - Security patches

Week 2: Test updated image
  - Deploy to test PC
  - Verify functionality
  - Check compatibility

Week 3: Capture new image
  - Sysprep/prepare
  - Capture as new version
  - Document changes

Week 4: Deploy to production
  - Update FOG image associations
  - Deploy to pilot group
  - Monitor for issues
```

### Image Optimization

**Reduce image size:**

**Windows:**
```powershell
# Disable hibernation
powercfg /h off

# Clear Windows Update cache
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

# Remove old Windows.old folder
rd /s /q C:\Windows.old

# Compact OS (Windows 10+)
Compact.exe /CompactOS:always

# Clear temp files
del /q /f /s %TEMP%\*
del /q /f /s C:\Windows\Temp\*
```

**Linux:**
```bash
# Remove old kernels
sudo apt autoremove -y

# Clean package cache
sudo apt clean

# Remove orphaned packages
sudo apt autoremove --purge -y

# Zero out free space (improves compression)
sudo dd if=/dev/zero of=/zerofile bs=1M
sudo rm /zerofile
```

### Testing Images

**Test checklist:**
- [ ] Deploy to test PC successfully
- [ ] OS boots without errors
- [ ] Network configuration works
- [ ] All software launches correctly
- [ ] Drivers installed properly
- [ ] No activation issues
- [ ] User can login
- [ ] Domain join works (if applicable)
- [ ] Printers work
- [ ] Performance is acceptable

## 📋 Image Management Best Practices

### Documentation

**Maintain image catalog:**

| Image Name | Version | Date | Base OS | Software | Size | Status |
|------------|---------|------|---------|----------|------|--------|
| win10-std | v1.2 | 2023-11-24 | Win10 Pro 22H2 | Office 2021, Chrome | 18 GB | Active |
| ubuntu-desk | v2.0 | 2023-10-15 | Ubuntu 22.04 | LibreOffice, Firefox | 6 GB | Active |
| win10-dev | v1.0 | 2023-09-01 | Win10 Pro | VS Code, Docker | 25 GB | Testing |

### Versioning Strategy

**Semantic versioning:**
```
v[Major].[Minor].[Patch]

Examples:
v1.0.0 - Initial release
v1.1.0 - Added software
v1.1.1 - Bug fixes
v2.0.0 - Major changes (new OS version)
```

### Backup Strategy

**Protect your images:**
```bash
# Daily backup to secondary storage
rsync -av /images/ /backup/images/

# Weekly backup to external drive
rsync -av /images/ /mnt/external/images/

# Monthly off-site backup
rsync -av /images/ remote-server:/backups/images/

# Automate with cron
0 2 * * * rsync -av /images/ /backup/images/
```

### Security Considerations

**Image security:**
- ❌ Never include passwords in images
- ❌ Don't store license keys in clear text
- ✅ Use Sysprep to remove unique identifiers
- ✅ Include latest security updates
- ✅ Encrypt image storage if needed
- ✅ Control access to image repository
- ✅ Audit image modifications

## 🔄 Image Lifecycle

```
Create → Test → Deploy → Monitor → Update → Retire

1. CREATE
   - Build master PC
   - Install and configure
   - Capture image

2. TEST
   - Deploy to test PC
   - Verify functionality
   - Document results

3. DEPLOY
   - Mark as production
   - Deploy to users
   - Provide support

4. MONITOR
   - Track issues
   - Gather feedback
   - Plan updates

5. UPDATE
   - Apply patches
   - Update software
   - Capture new version

6. RETIRE
   - Move to archive
   - Remove from production
   - Keep for reference
```

## 🚨 Troubleshooting Common Issues

### Issue: Image Won't Deploy

**Causes:**
- Disk too small on target
- Wrong partition scheme (MBR vs GPT)
- UEFI/BIOS mismatch

**Solutions:**
```
1. Check target disk size ≥ source
2. Verify partition scheme matches
3. Check BIOS mode matches image
4. Review FOG logs
5. Try re-capturing image
```

### Issue: Image Deployed But Won't Boot

**Causes:**
- Bootloader not installed
- Wrong boot mode (UEFI/BIOS)
- Disk signature conflict

**Solutions:**
```
1. Repair bootloader:
   Windows: bootrec /fixmbr, /fixboot
   Linux: grub-install

2. Check BIOS boot mode

3. Reset disk signature (Windows):
   diskpart > uniqueid disk
```

### Issue: Image Too Large

**Solutions:**
```
1. Remove unnecessary files before capture
2. Increase compression level
3. Exclude temp files/logs
4. Use partition image instead of disk image
5. Clean Windows component store
```

## 🔗 Related Documentation

- [[FOG Project Setup]] - FOG-based imaging
- [[PXE Boot Setup]] - Network boot infrastructure
- [[Automation and Scripts]] - Image deployment automation
- [[Troubleshooting Guide]] - Advanced troubleshooting
- [[Security Best Practices]] - Secure image management

## 📚 Additional Resources

- [Microsoft DISM Documentation](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism---deployment-image-servicing-and-management-technical-reference-for-windows)
- [Clonezilla Documentation](https://clonezilla.org/clonezilla-live-doc.php)
- [Sysprep Documentation](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation)

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate to Advanced
