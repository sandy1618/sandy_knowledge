# PXE Boot and MaaS Setup Guide for Ubuntu Servers

## Table of Contents
1. [Understanding PXE Boot](#understanding-pxe-boot)
2. [What is MaaS](#what-is-maas)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Setup](#step-by-step-setup)
5. [Commissioning and Deploying Servers](#commissioning-and-deploying-servers)
6. [Troubleshooting](#troubleshooting)

---

## Understanding PXE Boot

### What is PXE?
**PXE (Preboot eXecution Environment)** is a network protocol that allows computers to boot from a network interface instead of a local disk or USB drive. This is how data centers and enterprises manage hundreds or thousands of servers without physical intervention.

### How PXE Boot Works

#### The Boot Sequence
```
1. Server powers on
   ↓
2. BIOS/UEFI checks boot order (finds Network Boot)
   ↓
3. Network card sends DHCP broadcast: "I need an IP and boot info"
   ↓
4. PXE Server responds with:
   - IP address
   - TFTP server address
   - Boot file name (e.g., pxelinux.0)
   ↓
5. Server downloads boot loader via TFTP
   ↓
6. Boot loader downloads kernel and initramfs
   ↓
7. Kernel boots into minimal Linux environment
   ↓
8. Auto-installer runs (using preseed/cloud-init config)
   ↓
9. OS installed, server reboots into new OS
```

#### Components Required
1. **DHCP Server**: Assigns IP addresses and provides boot file location
2. **TFTP Server**: Hosts boot files (kernel, initramfs, bootloader)
3. **HTTP/NFS Server**: Hosts the OS installation files
4. **Configuration Files**: Automates the installation (preseed, cloud-init, kickstart)

---

## What is MaaS

### Overview
**MaaS (Metal as a Service)** by Canonical is an open-source tool that turns physical servers into a cloud-like resource pool. Think of it as AWS for bare metal servers.

### What MaaS Does
- **Discovery**: Automatically detects servers on your network
- **Provisioning**: Installs OS via PXE boot
- **Management**: Monitor, redeploy, and control servers
- **Automation**: Deploy via API/CLI (integrate with Ansible, Terraform)
- **IPAM**: IP Address Management and DNS
- **Power Control**: Wake-on-LAN, IPMI, BMC integration

### MaaS vs Manual PXE
| Feature | Manual PXE | MaaS |
|---------|-----------|------|
| Setup Complexity | High | Medium |
| Web UI | No | Yes |
| Auto-Discovery | No | Yes |
| Power Management | Manual | Automated |
| API Access | No | Yes |
| Best For | Learning | Production |

---

## Prerequisites

### Hardware Requirements

#### MaaS Controller (1 server/VM)
- **CPU**: 4+ cores
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 40GB+ (more if storing OS images)
- **Network**: 2 NICs recommended (1 for management, 1 for PXE)

#### Target Servers (Your 5 bare metal servers)
- **BIOS**: PXE/Network Boot enabled
- **Network**: Connected to same network as MaaS
- **Optional**: IPMI/BMC for remote power control

### Network Requirements
- **Static IP** for MaaS controller
- **DHCP Range** available for PXE clients
- **Router Access** to configure DHCP relay (if needed)

### Software Requirements
- Ubuntu 22.04 LTS or 24.04 LTS (for MaaS controller)
- Internet access (for downloading OS images)

---

## Step-by-Step Setup

### Phase 1: Prepare MaaS Controller

#### Step 1: Install Ubuntu Server
Install Ubuntu Server 22.04 or 24.04 on your MaaS controller machine.

```bash
# Update system
sudo apt update && sudo apt upgrade -y
```

#### Step 2: Configure Network
Set a static IP for the MaaS controller.

```bash
# Edit netplan configuration
sudo nano /etc/netplan/00-installer-config.yaml
```

Example configuration:
```yaml
network:
  version: 2
  ethernets:
    enp0s3:  # Replace with your interface name
      addresses:
        - 192.168.1.10/24  # MaaS controller IP
      routes:
        - to: default
          via: 192.168.1.1  # Your router
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

Apply the configuration:
```bash
sudo netplan apply
```

#### Step 3: Install MaaS
```bash
# Install MaaS snap package
sudo snap install maas

# Check version
maas --version
```

#### Step 4: Initialize MaaS Database
```bash
# Initialize the database
sudo maas init region+rack --database-uri maas-test-db:///

# This creates:
# - PostgreSQL database
# - Region controller (API/UI)
# - Rack controller (DHCP/TFTP/PXE)
```

**Alternative**: For production, use external PostgreSQL:
```bash
# Install PostgreSQL
sudo apt install postgresql -y

# Create database
sudo -u postgres psql -c "CREATE USER maas WITH PASSWORD 'your-password'"
sudo -u postgres createdb -O maas maasdb

# Initialize with external DB
sudo maas init region+rack --database-uri \
  postgres://maas:your-password@localhost/maasdb
```

#### Step 5: Create Admin User
```bash
# Create an admin account
sudo maas createadmin

# Follow prompts:
# Username: admin
# Password: [your password]
# Email: admin@example.com
# SSH public key: [paste your public key or skip]
```

#### Step 6: Access MaaS Web UI
```bash
# Get the URL
echo "http://$(hostname -I | awk '{print $1}'):5240/MAAS"
```

Open this URL in your browser and login with your admin credentials.

---

### Phase 2: Configure MaaS

#### Step 7: Initial Configuration (Web UI)

1. **Welcome Screen**:
   - Choose **"Region and Rack"** installation type
   - Click Continue

2. **DNS Configuration**:
   - DNS forwarder: `8.8.8.8` (or your preferred DNS)
   - Click Continue

3. **Ubuntu Images**:
   - Select Ubuntu versions to sync:
     - ✓ Ubuntu 22.04 LTS (Jammy)
     - ✓ Ubuntu 24.04 LTS (Noble)
   - Architecture: amd64
   - Click "Continue" to download images (this takes time)

4. **SSH Keys** (Optional but recommended):
   - Add your public SSH key
   - This will be added to all deployed servers

#### Step 8: Configure Networking

Navigate to: **Settings → Network → Add Fabric**

1. **Create Fabric**:
   - Name: `lab-network`
   - Click "Add Fabric"

2. **Configure VLAN**:
   - Click on the VLAN
   - Set as "Untagged"
   - Enable DHCP: ✓

3. **Add Subnet**:
   - Click "Add Subnet"
   - CIDR: `192.168.1.0/24`
   - Gateway: `192.168.1.1`
   - DNS: `8.8.8.8`
   - Click "Add"

4. **Configure DHCP**:
   - Click on your subnet
   - Click "Enable DHCP"
   - Rack controller: Select your controller
   - Dynamic range: `192.168.1.100 - 192.168.1.200`
   - Click "Configure DHCP"

#### Step 9: Router Configuration

**Option A**: Use MaaS as DHCP server (Recommended)
- MaaS handles everything
- Disable DHCP on your router
- Point PXE clients to this network

**Option B**: Use Router as DHCP + DHCP Relay
If you can't disable router DHCP, configure DHCP relay:

On your router (if supported):
```bash
# Add DHCP option
dhcp-option=66,192.168.1.10  # TFTP server (MaaS IP)
dhcp-option=67,pxelinux.0     # Boot file
```

**Option C**: Configure Static DHCP Reservations
Reserve IPs for your 5 servers on your router, then configure MaaS to manage only those IPs.

---

### Phase 3: Prepare Target Servers

#### Step 10: Configure BIOS Settings

For each of your 5 bare metal servers:

1. **Boot into BIOS/UEFI** (usually DEL, F2, or F12 during boot)

2. **Enable Network Boot**:
   - Find "Boot Options" or "Boot Order"
   - Enable "PXE Boot" or "Network Boot"
   - Move "Network Boot" above "Hard Drive" in boot order

3. **Enable Wake-on-LAN** (if available):
   - Find "Power Management" or "Advanced"
   - Enable "Wake on LAN"
   - Enable "Power On by PCI-E"

4. **Optional: IPMI/BMC Setup**:
   - If your servers have IPMI (Supermicro, Dell iDRAC, HP iLO):
   - Enable IPMI
   - Set static IP for BMC
   - Note the username/password

5. **Save and Exit**

#### Step 11: Record Server Information

Create a spreadsheet with:
```
Server | MAC Address       | Static IP      | IPMI IP        | Notes
-------|-------------------|----------------|----------------|-------
srv1   | 00:1A:2B:3C:4D:01| 192.168.1.101  | 192.168.1.51   | 64GB RAM
srv2   | 00:1A:2B:3C:4D:02| 192.168.1.102  | 192.168.1.52   | 32GB RAM
srv3   | 00:1A:2B:3C:4D:03| 192.168.1.103  | 192.168.1.53   | 32GB RAM
srv4   | 00:1A:2B:3C:4D:04| 192.168.1.104  | 192.168.1.54   | 16GB RAM
srv5   | 00:1A:2B:3C:4D:05| 192.168.1.105  | 192.168.1.55   | 16GB RAM
```

---

### Phase 4: Enlist and Commission Servers

#### Step 12: Auto-Discovery (Easiest Method)

1. **Power on the first server**
2. **Watch the screen**: It should:
   - Get IP via DHCP
   - Download boot files from MaaS
   - Boot into "Ephemeral Ubuntu" (MaaS commissioning OS)
   - Appear in MaaS UI as "New"

3. **In MaaS UI**:
   - Go to "Machines"
   - You'll see a new machine with status "New"
   - Click on it, set a hostname: `srv1`
   - Click "Save"

#### Step 13: Manual Enlistment (Alternative)

If auto-discovery doesn't work:

```bash
# SSH to MaaS controller
ssh admin@192.168.1.10

# Add machine manually
maas admin machines create \
  architecture=amd64 \
  mac_addresses=00:1A:2B:3C:4D:01 \
  hostname=srv1 \
  power_type=manual
```

#### Step 14: Commission the Server

Commissioning = MaaS gathers hardware info (CPU, RAM, disks, network)

**In Web UI**:
1. Select the machine (srv1)
2. Click "Take Action" → "Commission"
3. Wait 5-10 minutes
4. Status changes: New → Commissioning → Ready

**What happens**:
- Server reboots into ephemeral OS
- MaaS inventories hardware
- Tests network, storage
- Server powers off
- Status: "Ready" (ready to deploy)

#### Step 15: Add Power Control (Optional but Recommended)

If you have IPMI/BMC:

1. Click on srv1
2. Go to "Configuration" tab
3. Under "Power":
   - Power type: `IPMI`
   - Power address: `192.168.1.51`
   - Power user: `ADMIN`
   - Power password: `ADMIN` (or your BMC password)
   - Click "Save"

4. Test it:
   - Click "Take Action" → "Power off"
   - Server should turn off remotely!

**Repeat Steps 12-15 for all 5 servers**

---

### Phase 5: Deploy Operating System

#### Step 16: Deploy Ubuntu to a Server

**In Web UI**:
1. Go to "Machines"
2. Select srv1 (status should be "Ready")
3. Click "Take Action" → "Deploy"
4. Choose:
   - OS: Ubuntu 22.04 LTS
   - Kernel: Default (GA kernel)
   - Click "Start deployment"

**What happens**:
```
1. MaaS powers on srv1 (via IPMI or Wake-on-LAN)
2. srv1 PXE boots from MaaS
3. MaaS sends Ubuntu installer
4. Installer:
   - Partitions disk (default: LVM)
   - Installs Ubuntu
   - Configures network (static IP)
   - Installs SSH keys
   - Runs cloud-init scripts
5. Server reboots
6. Status: "Deployed"
7. You can now SSH to srv1
```

#### Step 17: Access Your Deployed Server

```bash
# SSH from your laptop (using the SSH key you added)
ssh ubuntu@192.168.1.101

# Or if you set a hostname in MaaS DNS:
ssh ubuntu@srv1.maas
```

You now have a fresh Ubuntu installation, no USB required!

---

### Phase 6: Advanced Configuration

#### Step 18: Custom Cloud-Init Scripts

To auto-install Docker, Kubernetes, etc., use cloud-init.

**In Web UI**:
1. Go to "Machines" → srv1 → "Configuration"
2. Scroll to "User data"
3. Paste cloud-init YAML:

```yaml
#cloud-config
packages:
  - docker.io
  - docker-compose
  - htop

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
  - curl -fsSL https://get.k3s.io | sh -

write_files:
  - path: /etc/motd
    content: |
      Welcome to srv1 - Auto-deployed by MaaS
    permissions: '0644'
```

4. Click "Save"
5. Now when you deploy, Docker and K3s will be auto-installed!

#### Step 19: Create Deployment Presets

**Tags**: Organize servers by role
1. Go to "Settings" → "Tags"
2. Create tags:
   - `kubernetes-master`
   - `kubernetes-worker`
   - `docker-swarm`

3. Apply tags to machines:
   - srv1: `kubernetes-master`
   - srv2-5: `kubernetes-worker`

**Storage Layouts**: Customize disk partitioning
1. Machine → Configuration → Storage
2. Choose layout:
   - Flat (simple)
   - LVM (flexible)
   - bcache (SSD cache)
   - Custom

#### Step 20: Batch Deployment

Deploy all 5 servers at once:

**CLI Method**:
```bash
# SSH to MaaS controller
maas login admin http://localhost:5240/MAAS $(sudo maas apikey --username=admin)

# Deploy all ready machines
maas admin machines deploy-many \
  filter=status:Ready \
  distro_series=jammy \
  user_data=$(base64 -w0 cloud-init.yaml)
```

**Web UI Method**:
1. Go to "Machines"
2. Select all 5 servers (checkboxes)
3. Click "Take Action" → "Deploy"
4. Choose OS and click "Deploy 5 machines"

---

## Commissioning and Deploying Servers

### Server Lifecycle in MaaS

```
New → Commission → Ready → Deploy → Deployed
 ↓         ↓          ↓        ↓         ↓
Add    Inventory   Idle   Installing  Running
```

### Common Operations

#### Release a Server (Wipe and Return to Pool)
```bash
# In UI: Machine → Take Action → Release
# This wipes the disk and returns status to "Ready"
```

#### Re-Deploy (Reinstall OS)
```bash
# Release first, then Deploy again
# Or use "Take Action" → "Mark Broken" → "Override Failed Testing" → "Deploy"
```

#### Power Management Commands
```bash
# Power on
maas admin machine power-on <system-id>

# Power off
maas admin machine power-off <system-id>

# Check power state
maas admin machine query-power-state <system-id>
```

---

## Troubleshooting

### Issue 1: Server Not PXE Booting

**Symptoms**: Server doesn't detect MaaS, boots to existing OS or "No boot device"

**Solutions**:
```bash
# Check DHCP is running on MaaS
sudo systemctl status maas-dhcpd

# Check TFTP is running
sudo systemctl status maas-rackd

# Verify network boot in BIOS
# - Check boot order
# - Disable Secure Boot (if UEFI)
# - Try legacy BIOS mode

# Check firewall
sudo ufw status
sudo ufw allow 67/udp   # DHCP
sudo ufw allow 69/udp   # TFTP
sudo ufw allow 5240/tcp # MaaS UI
```

### Issue 2: Images Not Downloading

**Symptoms**: "No images available" when deploying

**Solutions**:
```bash
# Check image sync status
maas admin boot-resources read

# Manually sync images
maas admin boot-sources import

# Check disk space
df -h /var/snap/maas/common
```

### Issue 3: Commission Stuck

**Symptoms**: Server stuck in "Commissioning" state

**Solutions**:
```bash
# Check server console/IPMI to see what's happening

# Abort and retry
maas admin machine abort <system-id>
maas admin machine commission <system-id>

# Check logs on MaaS controller
sudo tail -f /var/snap/maas/common/log/rackd.log
```

### Issue 4: No IPMI Control

**Symptoms**: Can't power on/off servers remotely

**Solutions**:
```bash
# Test IPMI manually
sudo apt install ipmitool
ipmitool -I lanplus -H 192.168.1.51 -U ADMIN -P ADMIN power status

# If that works, double-check MaaS power config
# Some BMCs need "IPMI 2.0" or "LAN 2.0" driver

# Alternative: Use Wake-on-LAN
maas admin machine power-on <system-id> power_type=wakeonlan
```

### Issue 5: Network Issues After Deployment

**Symptoms**: Can't SSH to deployed server

**Solutions**:
```bash
# Check MaaS assigned correct IP
# In UI: Machine → Network → Check IP address

# Verify DNS
ping srv1.maas

# Check if server finished deployment
# Status should be "Deployed", not "Deploying"

# Try console access via IPMI if available
```

---

## Next Steps

### Integration with Automation Tools

**Ansible**:
```bash
# Export MaaS inventory for Ansible
maas admin machines read | jq -r '.[] | .hostname + " ansible_host=" + .ip_addresses[0]'
```

**Terraform**:
```hcl
provider "maas" {
  api_url = "http://192.168.1.10:5240/MAAS"
  api_key = "your-api-key"
}

resource "maas_machine" "srv1" {
  hostname = "srv1"
  # ... configuration
}
```

**Kubernetes**: Use MaaS with Juju to deploy Kubernetes clusters automatically.

---

## Summary

You now have:
- ✅ MaaS controller installed and configured
- ✅ 5 bare metal servers managed remotely
- ✅ Ability to deploy/redeploy Ubuntu without touching hardware
- ✅ Cloud-init for automated software installation
- ✅ Power management via IPMI/Wake-on-LAN

**The Data Center Method = PXE + MaaS + Automation**

This is exactly how AWS, Google Cloud, and Azure manage their physical infrastructure—and now you can too!
