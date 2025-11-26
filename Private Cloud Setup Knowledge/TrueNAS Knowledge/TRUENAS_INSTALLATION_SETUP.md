# TrueNAS Installation and Setup Guide

## Table of Contents
1. [Introduction to TrueNAS](#introduction-to-truenas)
2. [Hardware Requirements](#hardware-requirements)
3. [Pre-Installation Planning](#pre-installation-planning)
4. [Installation Process](#installation-process)
5. [Initial Configuration](#initial-configuration)
6. [Network Configuration - Static IP Setup](#network-configuration---static-ip-setup)
7. [Storage Configuration - ZFS Pools](#storage-configuration---zfs-pools)
8. [Dataset and Share Creation](#dataset-and-share-creation)
9. [User and Permission Management](#user-and-permission-management)
10. [Advanced Features](#advanced-features)
11. [Troubleshooting](#troubleshooting)

---

## Introduction to TrueNAS

### What is TrueNAS?
**TrueNAS** is an enterprise-grade, open-source Network Attached Storage (NAS) operating system based on FreeBSD. It uses the ZFS filesystem, which provides:
- **Data integrity** - Built-in checksums prevent silent data corruption
- **Snapshots** - Point-in-time copies of your data
- **Replication** - Backup data to another TrueNAS or remote location
- **Compression** - Save disk space automatically
- **RAID** - Multiple redundancy levels (RAID-Z, RAID-Z2, RAID-Z3)

### TrueNAS Versions
| Version | Base OS | Use Case | Web Framework |
|---------|---------|----------|---------------|
| **TrueNAS CORE** | FreeBSD | Traditional NAS, most stable | Legacy UI |
| **TrueNAS SCALE** | Debian Linux | Apps, VMs, Kubernetes | Modern UI |

**Recommendation**: Use **TrueNAS SCALE** for:
- Running apps (Nextcloud, Plex, etc.)
- Docker containers
- Better hardware compatibility
- Active development

---

## Hardware Requirements

### Minimum Requirements
| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **CPU** | 2 cores | 4+ cores | More cores for apps/VMs |
| **RAM** | 8 GB | 16+ GB | 1GB RAM per 1TB storage (ZFS rule) |
| **Boot Drive** | 16 GB USB/SSD | 32GB+ SSD | Mirrored boot drives recommended |
| **Storage Drives** | 2 drives | 4+ drives | For redundancy (RAID-Z) |
| **Network** | 1 Gbps NIC | 10 Gbps NIC | 2 NICs for redundancy |

### Storage Drive Configuration
**Best Practices**:
```
2 Drives  → Mirror (RAID-1)      - 50% capacity, survives 1 failure
3 Drives  → RAID-Z1               - 66% capacity, survives 1 failure  
4 Drives  → RAID-Z1               - 75% capacity, survives 1 failure
5 Drives  → RAID-Z2               - 60% capacity, survives 2 failures
6+ Drives → RAID-Z2 or RAID-Z3    - Best for large arrays
```

### Example Hardware Setup
```
Server: Old desktop or server
├─ CPU: Intel i5 or AMD Ryzen 5
├─ RAM: 16GB DDR4
├─ Boot: 32GB USB stick (mirrored pair)
├─ Storage: 4x 4TB HDDs (RAID-Z1 = 12TB usable)
├─ Network: 1 Gbps Ethernet
└─ Extra: 1TB NVMe SSD for cache (optional)
```

---

## Pre-Installation Planning

### Network Planning

#### IP Address Scheme
```
Network: 192.168.1.0/24
Gateway: 192.168.1.1 (Router)

Device Assignments:
├─ 192.168.1.1     - Router
├─ 192.168.1.10    - TrueNAS (STATIC - we'll configure this)
├─ 192.168.1.11    - Proxmox Host 1
├─ 192.168.1.20-50 - Reserved for servers
└─ 192.168.1.100+  - DHCP pool for clients
```

#### DNS Planning
- **Primary DNS**: 192.168.1.1 (your router) or 8.8.8.8
- **Secondary DNS**: 1.1.1.1 or 8.8.4.4
- **Domain**: home.local or your custom domain

### Storage Planning

#### Decide on Pool Layout
**Example 1: 4x 4TB Drives**
```
Option A: RAID-Z1
- Usable: 12TB
- Protection: 1 drive failure
- Performance: Good reads, OK writes

Option B: 2x Mirror
- Usable: 8TB  
- Protection: 1 drive per mirror
- Performance: Better writes
```

**Example 2: 6x 4TB Drives**
```
Option A: RAID-Z2 (Recommended)
- Usable: 16TB
- Protection: 2 drive failures
- Best balance

Option B: RAID-Z3
- Usable: 12TB
- Protection: 3 drive failures  
- Overkill for home use
```

### Backup Planning
**ZFS is NOT a backup!** Even with RAID, you need:
1. **3-2-1 Rule**:
   - 3 copies of data
   - 2 different media types
   - 1 offsite backup

2. **Backup Options**:
   - Cloud: Backblaze B2, AWS S3
   - Local: Second TrueNAS or external drives
   - Replication: To another TrueNAS server

---

## Installation Process

### Step 1: Download TrueNAS SCALE

```bash
# From your laptop, download from:
# https://www.truenas.com/download-truenas-scale/

# Verify checksum (important!)
sha256sum TrueNAS-SCALE-*.iso
```

### Step 2: Create Bootable USB

**On Linux/Mac**:
```bash
# Find USB drive
lsblk

# Write ISO (replace sdX with your USB drive)
sudo dd if=TrueNAS-SCALE-*.iso of=/dev/sdX bs=4M status=progress
sync
```

**On Windows**:
- Use **Rufus** or **balenaEtcher**
- Select ISO
- Select USB drive
- Write

### Step 3: Prepare Boot Drive(s)

**Best Practice**: Use 2x USB sticks or small SSDs for mirrored boot
```
Option A: Single Boot Drive
└─ 1x 32GB USB stick (simple, no redundancy)

Option B: Mirrored Boot (Recommended)
├─ 2x 32GB USB sticks or
└─ 2x 120GB SATA SSDs (better reliability)
```

**Important**: Boot drives are separate from storage drives!

### Step 4: Boot from Installer

1. **Plug in**:
   - Installation USB
   - Boot drive(s)
   - Storage drives

2. **Enter BIOS** (DEL, F2, or F12):
   - Set boot order: USB first
   - Enable AHCI mode for SATA
   - Disable Secure Boot (if UEFI)
   - Save and exit

3. **Server boots** into TrueNAS installer

### Step 5: Run Installer

```
TrueNAS Installer Menu:
┌──────────────────────────────────┐
│ 1. Install/Upgrade               │ ← Choose this
│ 2. Shell                          │
│ 3. Reboot                         │
└──────────────────────────────────┘
```

1. **Select Install Destination**:
   ```
   Choose Drive:
   ├─ da0 (32GB USB) ← Select for single boot
   └─ da1 (32GB USB) ← Select for mirror
   
   ⚠️  DO NOT select your storage drives (4TB HDDs)!
   ```

2. **Confirm** - Type `YES` (installer warns it will erase drive)

3. **Wait** - 5-10 minutes for installation

4. **Remove installer USB** when prompted

5. **Reboot** - System boots into TrueNAS

---

## Initial Configuration

### Step 6: Console Setup (First Boot)

After installation, you'll see console menu:

```
TrueNAS Console
┌─────────────────────────────────────┐
│ 1. Configure Network Interfaces     │
│ 2. Configure Link Aggregation       │
│ 3. Configure VLAN Interface         │
│ 4. Configure Default Route          │
│ 5. Configure Static Routes          │
│ 6. Configure DNS                    │
│ 7. Reset Root Password              │
│ 8. Reset to factory defaults        │
│ 9. Shell                            │
│ 10. Reboot                          │
│ 11. Shutdown                        │
└─────────────────────────────────────┘

The web interface is at: http://192.168.1.XXX
```

**Note the IP address shown** - this is temporary DHCP address.

### Step 7: Access Web Interface (Initial)

1. **From your laptop**, open browser:
   ```
   http://192.168.1.XXX  (use IP shown on console)
   ```

2. **Login**:
   - Username: `root`
   - Password: `[blank]` (no password on first boot)

3. **You'll be prompted** to set root password:
   - Enter strong password
   - Confirm password
   - **SAVE THIS PASSWORD!**

---

## Network Configuration - Static IP Setup

### Why Static IP?
- NAS should always be at same IP address
- Clients need reliable path to your data
- DNS/shares won't break when DHCP lease expires

### Step 8: Configure Static IP (Web UI)

1. **Navigate**: Network → Interfaces

2. **Click on your interface** (usually `enp0s3` or `eth0`)

3. **Configure**:
   ```
   DHCP: ✗ Disable
   
   IPv4 Configuration:
   ├─ IP Address: 192.168.1.10
   ├─ Netmask: 24 (or 255.255.255.0)
   └─ Description: Primary Network Interface
   
   Aliases: (leave empty for now)
   ```

4. **Click "Save"**

5. **Navigate**: Network → Global Configuration

6. **Configure**:
   ```
   Hostname: truenas
   Domain: home.local
   
   IPv4 Default Gateway: 192.168.1.1
   
   DNS Servers:
   ├─ Nameserver 1: 192.168.1.1  (or 8.8.8.8)
   └─ Nameserver 2: 1.1.1.1
   ```

7. **Click "Save"**

8. **Test Configuration**:
   - Click "Test Changes" (90 second timer starts)
   - If network works, click "Save Changes"
   - If no response, changes auto-revert after 90 seconds

### Step 9: Verify Network Configuration

After applying changes, verify:

1. **Console shows new IP**:
   ```
   The web interface is at: http://192.168.1.10
   ```

2. **Access from new IP**:
   ```
   http://192.168.1.10
   ```

3. **Test internet connectivity** (from TrueNAS shell):
   ```bash
   # Go to Shell in web UI, or option 9 on console
   ping -c 3 8.8.8.8
   ping -c 3 google.com
   ```

### Step 10: Configure Router (Optional but Recommended)

**Reserve IP in Router DHCP**:
1. Login to router (192.168.1.1)
2. Find DHCP settings
3. Add static DHCP reservation:
   - MAC Address: [TrueNAS MAC - shown in Network → Interfaces]
   - IP Address: 192.168.1.10
   - Hostname: truenas

**Why?** Backup in case you accidentally enable DHCP on TrueNAS.

### Step 11: Configure DNS Hostname (Optional)

**Option A: Router DNS** (if supported):
- Add entry: `truenas.home.local → 192.168.1.10`
- Access NAS via: `http://truenas.home.local`

**Option B: Hosts File** (on your laptop):
```bash
# Edit hosts file
sudo nano /etc/hosts  # Linux/Mac
# C:\Windows\System32\drivers\etc\hosts  # Windows

# Add line:
192.168.1.10    truenas truenas.home.local
```

Now access via: `http://truenas`

---

## Storage Configuration - ZFS Pools

### Understanding ZFS Terminology

```
Pool (tank)                    ← Top-level storage container
├─ Vdev 1 (RAID-Z1)           ← Virtual device (redundancy group)
│  ├─ Disk 1
│  ├─ Disk 2  
│  └─ Disk 3
├─ Dataset (documents)         ← Filesystem within pool
│  ├─ Compression: lz4
│  └─ Quota: 500GB
└─ Zvol (vm-disk)             ← Block device (for VMs)
```

### Understanding RAID (Redundant Array of Independent Disks)

**RAID Full Form**: **R**edundant **A**rray of **I**ndependent **D**isks (originally "Inexpensive" Disks)

**What is RAID?**
RAID is a technology that combines multiple physical hard drives into a single logical unit to achieve:
- **Redundancy**: Data survives drive failures
- **Performance**: Faster read/write speeds
- **Capacity**: Larger storage pools

---

### Complete RAID Levels Guide

#### RAID 0 - Striping (No Redundancy)
```
Diagram:
┌─────────┬─────────┐
│ Drive 1 │ Drive 2 │
├─────────┼─────────┤
│ Block A1│ Block A2│
│ Block B1│ Block B2│
│ Block C1│ Block C2│
└─────────┴─────────┘

How it works: Data split across all drives
├─ File "A" → A1 on Drive 1, A2 on Drive 2
├─ File "B" → B1 on Drive 1, B2 on Drive 2
└─ Both drives work simultaneously

Capacity: 100% (2x 4TB = 8TB usable)
Protection: NONE - any drive fails = all data lost ❌
Speed: ⭐⭐⭐ (fastest, reads/writes to all drives)
Use Case: Video editing scratch disk, temp files
Verdict: NEVER for important data!
```

---

#### RAID 1 - Mirroring
```
Diagram:
┌─────────┬─────────┐
│ Drive 1 │ Drive 2 │
├─────────┼─────────┤
│ Block A │ Block A │ ← Same data
│ Block B │ Block B │ ← Same data
│ Block C │ Block C │ ← Same data
└─────────┴─────────┘

How it works: Complete copy on each drive
├─ File "A" → Written to BOTH drives identically
├─ File "B" → Written to BOTH drives identically
└─ Perfect clones of each other

Capacity: 50% (2x 4TB = 4TB usable)
Protection: 1 drive can fail ✓
Speed: ⭐⭐ (reads fast, writes moderate)
Use Case: Boot drives, critical data
Verdict: Simple, reliable, expensive per GB
```

---

#### RAID 5 - Striping with Parity (Minimum 3 drives)
```
Diagram (3 drives):
┌─────────┬─────────┬─────────┐
│ Drive 1 │ Drive 2 │ Drive 3 │
├─────────┼─────────┼─────────┤
│ Block A1│ Block A2│ Parity A│ ← Row 1
│ Block B1│ Parity B│ Block B2│ ← Row 2
│ Parity C│ Block C1│ Block C2│ ← Row 3
└─────────┴─────────┴─────────┘

How it works: Data + rotating parity
├─ File "A" → A1, A2 on data drives, Parity on Drive 3
├─ Parity rotates across all drives
└─ Can rebuild any drive using other 2

Capacity: (N-1)/N drives (3x 4TB = 8TB usable = 67%)
Protection: 1 drive can fail ✓
Speed: ⭐⭐ (reads good, writes slower due to parity calc)
Use Case: File servers, general storage
Warning: Deprecated - use RAID-Z1 (ZFS) instead
Problem: Drive rebuild can take DAYS, high risk of 2nd failure
```

---

#### RAID 6 - Dual Parity (Minimum 4 drives)
```
Diagram (4 drives):
┌─────────┬─────────┬─────────┬─────────┐
│ Drive 1 │ Drive 2 │ Drive 3 │ Drive 4 │
├─────────┼─────────┼─────────┼─────────┤
│ Block A1│ Block A2│ Parity A│ Parity A'│ ← 2 parities
│ Block B1│ Parity B│ Block B2│ Parity B'│
│ Parity C│ Block C1│ Block C2│ Parity C'│
└─────────┴─────────┴─────────┴─────────┘

How it works: 2 parity blocks per stripe
├─ Like RAID 5, but with 2 parity calculations
└─ Can lose ANY 2 drives and rebuild

Capacity: (N-2)/N drives (4x 4TB = 8TB usable = 50%)
Protection: 2 drives can fail ✓✓
Speed: ⭐ (reads OK, writes slow - more parity)
Use Case: Important data, large arrays
Verdict: Good for enterprise, but ZFS RAID-Z2 better
```

---

#### RAID 10 (1+0) - Mirrored Stripe ⭐ Why it's called RAID 10
```
Diagram (4 drives):
        RAID 0 (Stripe)
              ↓
    ┌─────────┴─────────┐
    │                   │
RAID 1        RAID 1
Mirror        Mirror
    │             │
┌───┴───┐     ┌───┴───┐
│       │     │       │
Drive1  Drive2 Drive3 Drive4
  A      A      B      B
  C      C      D      D
  E      E      F      F

How it works: First MIRROR (1), then STRIPE (0)
Step 1: Create 2 mirrors
├─ Mirror 1: Drive 1 ↔ Drive 2 (contains A, C, E)
└─ Mirror 2: Drive 3 ↔ Drive 4 (contains B, D, F)

Step 2: Stripe across mirrors
├─ File "A" → Goes to Mirror 1 (written to both drives)
├─ File "B" → Goes to Mirror 2 (written to both drives)
└─ Files alternate between mirror pairs

Why "10"?
├─ "1" = RAID 1 (mirroring within pairs)
├─ "0" = RAID 0 (striping across pairs)
└─ Combined = "10" = Mirror first, then stripe

Capacity: 50% (4x 4TB = 8TB usable)
Protection: 1 drive per mirror can fail
├─ Can lose Drive1 OR Drive2 (not both) ✓
├─ Can lose Drive3 OR Drive4 (not both) ✓
├─ Can lose Drive1 AND Drive3 (different mirrors) ✓✓
└─ Cannot lose Drive1 AND Drive2 (same mirror) ❌

Speed: ⭐⭐⭐ (fastest redundant config)
├─ Reads: 4 drives working in parallel
└─ Writes: 2 mirror pairs writing simultaneously

Use Case: 
├─ Databases (SQL, PostgreSQL, MySQL)
├─ Virtual machine storage
├─ Any high-performance + redundancy need
└─ Enterprise servers

Verdict: Best performance with redundancy, but expensive (50% capacity)
```

**RAID 10 vs RAID 01 (rare)**:
```
RAID 10: Mirror → Stripe (better)
RAID 01: Stripe → Mirror (worse, less fault tolerant)
```

---

#### ZFS RAID-Z1, Z2, Z3 (Modern Alternative)

**Why ZFS is Better than Traditional RAID**:
- Self-healing: Detects and repairs corruption automatically
- Snapshots: Instant backups
- No write-hole: Traditional RAID 5/6 can corrupt on power loss
- Flexible: Can use different size drives (not recommended, but works)

```
RAID-Z1 = Like RAID 5, but better
├─ Minimum: 3 drives (2 data + 1 parity)
├─ 4 drives: 75% usable (3 data + 1 parity)
└─ Protection: 1 drive failure

RAID-Z2 = Like RAID 6, but better  
├─ Minimum: 4 drives (2 data + 2 parity)
├─ 4 drives: 50% usable
├─ 6 drives: 67% usable
└─ Protection: 2 drive failures

RAID-Z3 = No traditional equivalent
├─ Minimum: 5 drives (2 data + 3 parity)
├─ 6 drives: 50% usable
└─ Protection: 3 drive failures (overkill for most)
```

---

### RAID Comparison Table

| RAID | Min Drives | Capacity Formula | Usable (4TB drives) | Failures | Speed | Traditional Use |
|------|------------|------------------|---------------------|----------|-------|-----------------|
| **0** | 2 | 100% | 16TB (4x) | 0 ❌ | ⭐⭐⭐ | Never for data |
| **1** | 2 | 50% | 4TB (2x) | 1 ✓ | ⭐⭐ | Boot drives |
| **5** | 3 | (N-1)/N | 8TB (3x) | 1 ✓ | ⭐⭐ | Deprecated |
| **6** | 4 | (N-2)/N | 8TB (4x) | 2 ✓✓ | ⭐ | Large arrays |
| **10** | 4 | 50% | 8TB (4x) | 1 per mirror | ⭐⭐⭐ | Performance |
| **Z1** | 3 | (N-1)/N | 12TB (4x) | 1 ✓ | ⭐⭐ | Home NAS ⭐ |
| **Z2** | 4 | (N-2)/N | 8TB (4x) | 2 ✓✓ | ⭐⭐ | Important data |
| **Z3** | 5 | (N-3)/N | 12TB (6x) | 3 ✓✓✓ | ⭐ | Mission critical |

---

### Step 12: Create Storage Pool

1. **Navigate**: Storage → Pools → "Create Pool"

2. **Pool Manager Opens**:
   ```
   Name: tank  (or your choice: data, storage, etc.)
   ```

3. **Select Layout**:
   
   **Understanding Storage Efficiency**:
   "Usable" percentage refers to how much actual storage you get after accounting for redundancy/parity data.
   
   ### Example 1: 2 Drives (2x 4TB = 8TB Raw)
   
   **Option A: Stripe (RAID-0)**
   ```
   Configuration: Both drives combined, no redundancy
   ├─ Drive 1: 4TB
   ├─ Drive 2: 4TB
   ├─ Total Raw: 8TB
   ├─ Usable Storage: 8TB (100%)
   ├─ Protection: NONE - any drive failure = TOTAL DATA LOSS ❌
   └─ Use Case: NEVER use this for important data!
   ```
   
   **Option B: Mirror (RAID-1)** ⭐ Recommended for 2 drives
   ```
   Configuration: Complete copy on each drive
   ├─ Drive 1: 4TB (copy of all data)
   ├─ Drive 2: 4TB (copy of all data)
   ├─ Total Raw: 8TB
   ├─ Usable Storage: 4TB (50%)
   ├─ Protection: 1 drive can fail, data still safe ✓
   ├─ Read Speed: Fast (can read from both drives)
   └─ Write Speed: Moderate (must write to both)
   
   Math: 8TB raw ÷ 2 copies = 4TB usable
   ```
   
   ---
   
   ### Example 2: 4 Drives (4x 4TB = 16TB Raw)
   
   **Option A: Stripe (RAID-0)**
   ```
   Configuration: All drives combined, no safety
   ├─ Total Raw: 16TB
   ├─ Usable Storage: 16TB (100%)
   ├─ Protection: NONE - losing ANY drive = lose EVERYTHING ❌
   └─ Verdict: NEVER use for home NAS!
   ```
   
   **Option B: 2x Mirror (RAID-10)** ⭐ Best for speed
   ```
   Configuration: 2 pairs of mirrored drives
   ├─ Pair 1: Drive 1 + Drive 2 (mirrored)
   ├─ Pair 2: Drive 3 + Drive 4 (mirrored)
   ├─ Total Raw: 16TB
   ├─ Usable Storage: 8TB (50%)
   ├─ Protection: 1 drive per mirror can fail (2 total) ✓
   ├─ Read Speed: FAST (reads from 4 drives)
   ├─ Write Speed: FAST (writes in parallel)
   └─ Best For: Databases, VMs, high performance needs
   
   Math: 16TB raw ÷ 2 (mirroring) = 8TB usable
   ```
   
   **Option C: RAID-Z1 (ZFS equivalent to RAID-5)** ⭐⭐ Recommended for 4 drives
   ```
   Configuration: 3 data blocks + 1 parity block per stripe
   ├─ Drive 1: Mix of data + parity
   ├─ Drive 2: Mix of data + parity  
   ├─ Drive 3: Mix of data + parity
   ├─ Drive 4: Mix of data + parity
   ├─ Total Raw: 16TB
   ├─ Usable Storage: 12TB (75%)
   ├─ Protection: 1 drive can fail, rebuild from parity ✓
   ├─ Read Speed: Good (reads across 4 drives)
   ├─ Write Speed: Moderate (must calculate parity)
   └─ Best For: General home NAS, best balance of space/safety
   
   Math: 16TB raw - 4TB parity = 12TB usable
   Why 75%? = 3 drives store data, 1 drive worth stores parity
   ```
   
   **Option D: RAID-Z2 (ZFS equivalent to RAID-6)**
   ```
   Configuration: 2 data blocks + 2 parity blocks per stripe
   ├─ Drive 1: Mix of data + parity
   ├─ Drive 2: Mix of data + parity  
   ├─ Drive 3: Mix of data + parity
   ├─ Drive 4: Mix of data + parity
   ├─ Total Raw: 16TB
   ├─ Usable Storage: 8TB (50%)
   ├─ Protection: 2 drives can fail simultaneously ✓✓
   ├─ Read Speed: Good
   ├─ Write Speed: Slower (more parity calculations)
   └─ Best For: Critical data, paranoid about failures
   
   Math: 16TB raw - 8TB parity = 8TB usable
   Why 50%? = 2 drives store data, 2 drives worth store parity
   ```
   
   ---
   
   ### Example 3: 6 Drives (6x 4TB = 24TB Raw)
   
   **Option A: RAID-Z2** ⭐⭐ Best for 6 drives
   ```
   Configuration: 4 data + 2 parity per stripe
   ├─ Total Raw: 24TB
   ├─ Usable Storage: 16TB (67%)
   ├─ Protection: 2 drives can fail ✓✓
   └─ Best For: Large media libraries, important data
   
   Math: 24TB raw - 8TB parity (2 drives) = 16TB usable
   ```
   
   **Option B: RAID-Z3**
   ```
   Configuration: 3 data + 3 parity per stripe
   ├─ Total Raw: 24TB
   ├─ Usable Storage: 12TB (50%)
   ├─ Protection: 3 drives can fail ✓✓✓
   └─ Best For: Mission-critical data (usually overkill for home)
   
   Math: 24TB raw - 12TB parity (3 drives) = 12TB usable
   ```
   
   ---
   
   ### Quick Reference Table
   
   | Drives | Config | Raw | Usable | % | Failures | Speed | Best For |
   |--------|--------|-----|--------|---|----------|-------|----------|
   | 2x 4TB | Mirror | 8TB | 4TB | 50% | 1 | Good | Simple NAS |
   | 4x 4TB | Mirror | 16TB | 8TB | 50% | 2 | Fast | Performance |
   | 4x 4TB | RAID-Z1 | 16TB | 12TB | 75% | 1 | Good | **Best balance** |
   | 4x 4TB | RAID-Z2 | 16TB | 8TB | 50% | 2 | OK | Extra safety |
   | 6x 4TB | RAID-Z2 | 24TB | 16TB | 67% | 2 | Good | **Large arrays** |
   | 6x 4TB | RAID-Z3 | 24TB | 12TB | 50% | 3 | OK | Paranoid |
   
   ---
   
   ### Choosing the Right Configuration
   
   **For your setup (4x 4TB drives):**
   
   ```
   ⭐ RECOMMENDED: RAID-Z1
   └─ You get: 12TB usable (75% efficiency)
   └─ Safety: Survives 1 drive failure
   └─ Speed: Good for most use cases
   └─ Perfect for: Home media server, file storage
   
   Consider RAID-Z2 if:
   └─ You have irreplaceable data (family photos, work)
   └─ Can't afford ANY data loss
   └─ Trade-off: Only 8TB usable (50% efficiency)
   
   Consider Mirrors if:
   └─ You need maximum write performance
   └─ Running VMs or databases
   └─ Trade-off: Only 8TB usable (50% efficiency)
   ```
   
   ---
   
   **For 4 drives in TrueNAS (selecting RAID-Z1 layout)**:
   ```
   Available Disks:
   ├─ da2: 4.0 TB
   ├─ da3: 4.0 TB
   ├─ da4: 4.0 TB
   └─ da5: 4.0 TB
   
   Selected Layout: RAID-Z1
   ```

4. **Drag disks** to Data VDevs area:
   - Select "RAID-Z1"
   - Drag all 4 disks into the vdev box

5. **Configuration Preview**:
   ```
   Pool: tank
   ├─ Data VDev: RAID-Z1
   │  ├─ da2 (4 TB)
   │  ├─ da3 (4 TB)
   │  ├─ da4 (4 TB)
   │  └─ da5 (4 TB)
   └─ Usable: 11.1 TB (75% of raw 16TB)
   ```

6. **Advanced Options** (click "Advanced"):
   ```
   Ashift: Auto (or 12 for 4K drives)
   Encryption: ✓ Enable (optional but recommended)
   └─ If enabled, set encryption passphrase
      ⚠️  SAVE THIS PASSPHRASE! Lose it = lose all data
   
   Compression: lz4 (recommended - no performance hit)
   Deduplication: ✗ Disable (needs massive RAM)
   ```

7. **Click "Create"** - Confirm warnings

8. **Wait**: Pool creation takes 1-2 minutes

### Step 13: Verify Pool Creation

1. **Navigate**: Storage → Pools

2. **You should see**:
   ```
   tank
   ├─ Status: ONLINE ✓
   ├─ Health: Healthy
   ├─ Total: 11.1 TB
   ├─ Used: 512 KB
   └─ Available: 11.1 TB
   ```

3. **Check from Shell** (optional):
   ```bash
   zpool status
   # Should show: pool 'tank' is ONLINE
   
   zpool list
   # Shows capacity and health
   ```

---

## Dataset and Share Creation

### Understanding Datasets vs Shares

```
Dataset = ZFS Filesystem (internal organization)
├─ Can have quotas, compression, snapshots
└─ Not directly accessible to network

Share = Network protocol exposing dataset
├─ SMB (Windows shares)
├─ NFS (Linux/Unix)
└─ iSCSI (block storage)
```

### Step 14: Create Datasets

1. **Navigate**: Storage → Pools → tank → "Add Dataset"

2. **Create "Media" Dataset** (example):
   ```
   Name: media
   
   Data Type:
   ├─ Generic (for files) ← Choose this
   └─ App (for TrueNAS apps)
   
   Compression: lz4 (inherited from pool)
   
   Quota: (optional)
   ├─ Dataset Quota: 2 TB (example)
   └─ Leave blank for unlimited
   
   Record Size: 128K (default for general use)
   ├─ 128K: Default (good for most)
   ├─ 1M: Large files (videos)
   └─ 16K: Small files (databases)
   ```

3. **Click "Save"**

4. **Repeat** for other datasets:
   ```
   tank
   ├─ media      (movies, music, photos)
   ├─ documents  (office files, PDFs)
   ├─ backups    (computer backups)
   └─ nextcloud  (for Nextcloud app)
   ```

### Step 15: Create SMB (Windows) Share

**SMB = Best for Windows, Mac, Linux desktop clients**

1. **Navigate**: Sharing → Windows Shares (SMB) → "Add"

2. **Configure**:
   ```
   Path: /mnt/tank/media (click folder icon to browse)
   Name: Media (share name clients will see)
   Purpose: Default share parameters
   Description: Movies and music
   
   Advanced Options:
   ├─ Export Read Only: ✗ (allow writes)
   ├─ Browsable: ✓ (visible in network)
   └─ Enable: ✓
   ```

3. **Click "Save"**

4. **Enable SMB Service**:
   - Popup asks: "Enable SMB service?"
   - Click "Enable Service"
   - Toggle: "Start Automatically" ✓

5. **Repeat** for other shares:
   ```
   Shares:
   ├─ \\truenas\Media      → /mnt/tank/media
   ├─ \\truenas\Documents  → /mnt/tank/documents
   └─ \\truenas\Backups    → /mnt/tank/backups
   ```

### Step 16: Create NFS Share (Optional - for Linux clients)

1. **Navigate**: Sharing → Unix Shares (NFS) → "Add"

2. **Configure**:
   ```
   Path: /mnt/tank/media
   Description: Media NFS Share
   
   Networks:
   └─ 192.168.1.0/24 (allow entire local network)
   
   Hosts: (leave blank for all)
   
   Maproot User: root (or 'nobody' for security)
   Maproot Group: wheel
   ```

3. **Click "Save"**

4. **Enable NFS Service**: Services → NFS → Start + Auto-start

---

## User and Permission Management

### Step 17: Create Users

1. **Navigate**: Credentials → Local Users → "Add"

2. **Create User**:
   ```
   Full Name: John Doe
   Username: john
   Email: john@example.com
   Password: [strong password]
   
   User ID: [auto-generated]
   Primary Group: [auto-create 'john' group]
   
   Home Directory: /nonexistent (no home on NAS)
   
   Shell: nologin (can't SSH to NAS)
   ├─ Use 'bash' if user needs shell access
   
   Samba Authentication: ✓ Enable
   └─ Required for SMB shares
   ```

3. **Click "Save"**

4. **Repeat** for family members/users

### Step 18: Configure Share Permissions

**Option A: Simple (Everyone has access)**:
```
1. Storage → Pools → tank/media → Edit Permissions
2. Owner: root
3. Group: Users
4. Mode: 775 (rwxrwxr-x)
5. Apply recursively: ✓
```

**Option B: User-specific (Recommended)**:
```
1. Create group for share access:
   Credentials → Local Groups → Add
   └─ Group Name: media-users
      Members: john, jane, admin

2. Set permissions:
   Storage → tank/media → Edit Permissions
   ├─ Owner: root
   ├─ Group: media-users
   ├─ Mode: 770 (rwxrwx---)
   └─ Apply recursively: ✓
```

### Step 19: Test Access from Client

**Windows**:
```
1. Open File Explorer
2. Address bar: \\192.168.1.10\Media
3. Login: john / [password]
4. Map Network Drive:
   - Right-click → Map Network Drive
   - Drive: Z:
   - Folder: \\192.168.1.10\Media
   - Reconnect at sign-in: ✓
```

**Mac**:
```
1. Finder → Go → Connect to Server (⌘K)
2. Server: smb://192.168.1.10/Media
3. Login: john / [password]
4. Add to Login Items for auto-mount
```

**Linux**:
```bash
# Install CIFS utilities
sudo apt install cifs-utils

# Mount SMB share
sudo mount -t cifs //192.168.1.10/Media /mnt/nas \
  -o username=john,password=yourpass,uid=1000,gid=1000

# Auto-mount on boot (add to /etc/fstab):
//192.168.1.10/Media /mnt/nas cifs credentials=/root/.smbcredentials,uid=1000,gid=1000 0 0
```

---

## Advanced Features

### Step 20: Configure Snapshots (Automatic Backups)

Snapshots = Point-in-time copies of your data (nearly instant, uses minimal space)

1. **Navigate**: Data Protection → Periodic Snapshot Tasks → "Add"

2. **Configure**:
   ```
   Dataset: tank/media
   
   Schedule:
   ├─ Recursive: ✓ (snapshot subdirectories too)
   ├─ Frequency: Daily
   ├─ Time: 2:00 AM
   └─ Days: All
   
   Lifetime:
   ├─ Keep snapshots for: 30 days
   └─ (older snapshots auto-deleted)
   
   Naming: auto-%Y%m%d-%H%M
   ```

3. **Click "Save"**

4. **Create multiple snapshot schedules**:
   ```
   Schedule        Keep        Purpose
   ├─ Hourly       24 hours    Recent changes
   ├─ Daily        30 days     Last month
   ├─ Weekly       12 weeks    Last quarter
   └─ Monthly      12 months   Last year
   ```

### Step 21: Configure Scrubs (Data Integrity Checks)

Scrubs verify data integrity and fix silent corruption.

1. **Navigate**: Data Protection → Scrub Tasks → "Add"

2. **Configure**:
   ```
   Pool: tank
   Threshold: 35 (days between scrubs)
   Schedule: Monthly, 1st Sunday, 3:00 AM
   ```

3. **Click "Save"**

**What happens**: ZFS reads all data, verifies checksums, repairs errors.

### Step 22: Configure S.M.A.R.T. Tests (Drive Health)

1. **Navigate**: Data Protection → S.M.A.R.T. Tests → "Add"

2. **Configure SHORT test**:
   ```
   All Disks: ✓
   Type: Short
   Schedule: Weekly, Sunday, 1:00 AM
   ```

3. **Add LONG test**:
   ```
   All Disks: ✓
   Type: Long
   Schedule: Monthly, 1st Sunday, 2:00 AM
   ```

### Step 23: Configure Email Alerts

Get notified of issues!

1. **Navigate**: System Settings → General → Email

2. **Configure SMTP**:
   ```
   Gmail Example:
   ├─ Outgoing Mail Server: smtp.gmail.com
   ├─ Port: 587
   ├─ Security: TLS
   ├─ Username: youremail@gmail.com
   ├─ Password: [App Password - not your Gmail password!]
   └─ From Email: youremail@gmail.com
   
   To Email: youremail@gmail.com
   ```

3. **Click "Save" then "Send Test Email"**

4. **Configure Alerts**:
   - System Settings → Alert Settings
   - Enable alerts for:
     - Pool health changes
     - Disk failures
     - High temperature
     - Scrub completion

---

## Troubleshooting

### Issue 1: Can't Access Web UI

**Symptoms**: Browser can't reach http://192.168.1.10

**Solutions**:
```bash
# Check from console (option 9 - Shell)
1. Verify IP: ip addr show
2. Ping gateway: ping 192.168.1.1
3. Check web service: service middlewared status
4. Restart web service: service middlewared restart

# From your laptop:
1. Ping TrueNAS: ping 192.168.1.10
2. Check firewall: telnet 192.168.1.10 80
```

### Issue 2: SMB Shares Not Visible

**Symptoms**: Can't see \\truenas in Network

**Solutions**:
```
1. Check SMB service: Services → SMB → Verify Running
2. Check Windows: 
   - Enable "SMB 1.0/CIFS File Sharing Support" (Control Panel)
   - Or directly access: \\192.168.1.10\Media
3. Check TrueNAS firewall (should be disabled by default)
4. Verify user has Samba Authentication enabled
```

### Issue 3: Pool Shows DEGRADED

**Symptoms**: Storage → Pool shows yellow/red status

**Solutions**:
```bash
# Check pool status
zpool status tank

# If drive failed:
1. Physically replace failed drive
2. Navigate: Storage → tank → Status
3. Click failed drive → Replace
4. Select new drive → Confirm
5. Resilver starts (rebuilds data, takes hours)
```

### Issue 4: Out of Space

**Symptoms**: Pool at 90%+ capacity

**Solutions**:
```
1. Check dataset usage: Storage → Pools → tank
2. Delete old snapshots: Data Protection → Snapshots
3. Check for large files: System → Shell
   - du -sh /mnt/tank/* | sort -h
4. Empty recycle bin: Sharing → SMB → Edit share
   - Disable "Export Recycle Bin"
5. Add more drives (expand pool)
```

### Issue 5: Slow Performance

**Symptoms**: File transfers are slow

**Solutions**:
```
1. Check network speed: Test with iperf3
2. Check disk health: Storage → Disks → S.M.A.R.T. status
3. Check pool fragmentation: zpool list (check FRAG%)
4. Disable sync writes (for non-critical data):
   - Dataset properties → Sync: Disabled
5. Add L2ARC cache: Add SSD as cache device
6. Check for scrub/resilver: Should run during off-hours
```

---

## Next Steps

Now that TrueNAS is configured:
1. ✅ Set up automated backups (replication or cloud)
2. ✅ Configure Nextcloud (see separate guide)
3. ✅ Set up other apps (Plex, Jellyfin, etc.)
4. ✅ Test disaster recovery (can you restore from backups?)
5. ✅ Monitor regularly (check alerts, scrub results)

**TrueNAS is now ready to serve as your network storage!**
