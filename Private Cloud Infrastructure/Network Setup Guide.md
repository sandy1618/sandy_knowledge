---
title: Network Setup Guide
tags: [networking, lan, ip-addressing, dhcp, dns]
created: 2025-11-24
---

# Network Setup Guide

Complete guide to setting up your network infrastructure for private cloud operations.

## 🎯 Overview

This guide covers the network foundation for your private cloud, including IP addressing, DHCP configuration, DNS setup, and network topology planning.

## 📊 Network Architecture Planning

### Choosing Your Network Topology

#### Option 1: Simple Flat Network (Recommended for Home/Small Office)
```
Internet ──► Router (192.168.1.1) ──► Switch ──► All Devices
                                           ├──► Server (192.168.1.10)
                                           ├──► PC1 (192.168.1.101)
                                           ├──► PC2 (192.168.1.102)
                                           └──► PC3 (192.168.1.103)
```

**Pros:**
- Simple to set up and manage
- No additional hardware required
- Good for up to 20-30 devices

**Cons:**
- All traffic on same broadcast domain
- Limited security segmentation
- Harder to isolate issues

#### Option 2: Segmented Network (Recommended for Business)
```
Internet ──► Router ──► Core Switch
                           ├──► VLAN 10 (Management) - 10.0.10.0/24
                           │      └──► Server (10.0.10.10)
                           ├──► VLAN 20 (Workstations) - 10.0.20.0/24
                           │      ├──► PC1 (10.0.20.101)
                           │      └──► PC2 (10.0.20.102)
                           └──► VLAN 30 (Services) - 10.0.30.0/24
                                  └──► Storage (10.0.30.50)
```

**Pros:**
- Better security and isolation
- Improved performance
- Easier troubleshooting
- Professional setup

**Cons:**
- Requires managed switch
- More complex configuration
- Higher initial cost

## 🔢 IP Address Planning

### Understanding IP Addressing

**IPv4 Address Format:** `192.168.1.100`
- **Network ID:** 192.168.1.0 (identifies the network)
- **Host ID:** .100 (identifies the device)
- **Subnet Mask:** 255.255.255.0 or /24 (defines network size)

### Private IP Address Ranges

As per RFC 1918, use these ranges for private networks:

| Range | CIDR | Usable Hosts | Best For |
|-------|------|--------------|----------|
| 10.0.0.0 - 10.255.255.255 | 10.0.0.0/8 | 16,777,214 | Large enterprises |
| 172.16.0.0 - 172.31.255.255 | 172.16.0.0/12 | 1,048,574 | Medium businesses |
| 192.168.0.0 - 192.168.255.255 | 192.168.0.0/16 | 65,534 | Home/small business |

### Recommended IP Allocation Scheme

For a typical small infrastructure (192.168.1.0/24):

```
192.168.1.0/24 (255.255.255.0) - 254 usable addresses

Network Layout:
├── 192.168.1.1        - Gateway/Router
├── 192.168.1.2-9      - Network infrastructure (switches, APs)
├── 192.168.1.10-20    - Servers
│   ├── 192.168.1.10   - Private Cloud Server (FOG/PXE)
│   ├── 192.168.1.11   - DNS Server (can be same as .10)
│   ├── 192.168.1.12   - File Server/NAS
│   └── 192.168.1.15   - Backup Server
├── 192.168.1.21-50    - Reserved for future servers
├── 192.168.1.51-99    - DHCP Pool (dynamic assignment)
├── 192.168.1.100-200  - Client PCs (static assignments)
│   ├── 192.168.1.101  - PC-001
│   ├── 192.168.1.102  - PC-002
│   ├── 192.168.1.103  - PC-003
│   └── ...
└── 192.168.1.201-254  - Printers, IoT devices, misc
```

### Documentation Template

Create a spreadsheet or document tracking all IPs:

```
| IP Address    | Hostname      | MAC Address       | Device Type | Location | Notes        |
|---------------|---------------|-------------------|-------------|----------|--------------|
| 192.168.1.1   | gateway       | aa:bb:cc:dd:ee:01 | Router      | Rack     | Main gateway |
| 192.168.1.10  | fog-server    | aa:bb:cc:dd:ee:02 | Server      | Rack     | Ubuntu 22.04 |
| 192.168.1.101 | workstation-1 | aa:bb:cc:dd:ee:10 | Workstation | Desk 1   | i5, 16GB RAM |
| 192.168.1.102 | workstation-2 | aa:bb:cc:dd:ee:11 | Workstation | Desk 2   | i7, 32GB RAM |
```

## 🖥️ Server Network Configuration

### Ubuntu Server Static IP Configuration

**Method 1: Netplan (Ubuntu 18.04+)**

Edit `/etc/netplan/00-installer-config.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:  # Your network interface name (use 'ip a' to find)
      dhcp4: no
      addresses:
        - 192.168.1.10/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
        search:
          - local
```

Apply configuration:
```bash
sudo netplan apply
sudo netplan --debug apply  # For troubleshooting
```

**Method 2: NetworkManager (Desktop versions)**

```bash
# Using nmcli
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.10/24
sudo nmcli con mod "Wired connection 1" ipv4.gateway 192.168.1.1
sudo nmcli con mod "Wired connection 1" ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con up "Wired connection 1"
```

### Finding Your Network Interface Name

```bash
# List all network interfaces
ip a

# Or use
ip link show

# Common names:
# - eth0, eth1 (older naming)
# - eno1, eno2 (onboard ethernet)
# - enp3s0 (PCI ethernet)
# - wlo1 (wireless)
```

## 💻 Client PC Network Configuration

### Option 1: Static IP via DHCP Reservation (Recommended)

Configure on your DHCP server (router or dedicated server):

```
MAC Address: aa:bb:cc:dd:ee:10
Reserved IP: 192.168.1.101
Hostname: workstation-1
```

**Benefits:**
- Centralized management
- Clients get IP automatically
- Easy to change later
- No manual client configuration

### Option 2: Manual Static IP Configuration

**Windows:**
```
1. Open Settings → Network & Internet → Ethernet
2. Click "Edit" under IP assignment
3. Set to Manual
4. Enter:
   - IP Address: 192.168.1.101
   - Subnet Mask: 255.255.255.0
   - Gateway: 192.168.1.1
   - DNS: 192.168.1.1 (or 8.8.8.8)
```

**Linux:**
```bash
# Using netplan (Ubuntu)
sudo nano /etc/netplan/01-netcfg.yaml

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.1.101/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]

sudo netplan apply
```

## 🌐 DNS Configuration

### Option 1: Use Router as DNS Server

**Configuration on Clients:**
```
DNS Server: 192.168.1.1
```

**Router DNS Forwarding:**
- Configure router to forward to public DNS (8.8.8.8, 1.1.1.1)
- Add local hostname mappings if supported

### Option 2: Dedicated DNS Server (Recommended)

**Install dnsmasq on your private cloud server:**

```bash
# Install dnsmasq
sudo apt update
sudo apt install dnsmasq

# Backup original config
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup

# Edit configuration
sudo nano /etc/dnsmasq.conf
```

**Basic dnsmasq configuration:**
```conf
# Listen on private cloud server IP
listen-address=192.168.1.10

# Upstream DNS servers
server=8.8.8.8
server=8.8.4.4

# Local domain
domain=local
local=/local/

# Expand simple hostnames
expand-hosts

# Add local hostnames
address=/fog-server.local/192.168.1.10
address=/workstation-1.local/192.168.1.101
address=/workstation-2.local/192.168.1.102

# Cache settings
cache-size=1000

# Don't forward private reverse lookups
bogus-priv

# Log queries for debugging (optional)
log-queries
log-facility=/var/log/dnsmasq.log
```

**Start and enable service:**
```bash
sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq
sudo systemctl status dnsmasq
```

**Test DNS:**
```bash
# Test from server
nslookup fog-server.local 127.0.0.1

# Test from client
nslookup fog-server.local 192.168.1.10
```

### Option 3: Use /etc/hosts for Simple Setup

**On each machine:**
```bash
sudo nano /etc/hosts
```

**Add entries:**
```
192.168.1.10    fog-server fog-server.local
192.168.1.101   workstation-1 workstation-1.local
192.168.1.102   workstation-2 workstation-2.local
192.168.1.12    nas nas.local
```

## 🔧 Network Testing and Verification

### Essential Network Tests

**1. Test Connectivity:**
```bash
# Ping gateway
ping -c 4 192.168.1.1

# Ping server
ping -c 4 192.168.1.10

# Ping internet
ping -c 4 8.8.8.8
ping -c 4 google.com
```

**2. Verify IP Configuration:**
```bash
# Linux
ip addr show
ip route show
cat /etc/resolv.conf

# Windows
ipconfig /all
route print
```

**3. Test DNS Resolution:**
```bash
# Linux
nslookup fog-server.local
dig fog-server.local

# Windows
nslookup fog-server.local
```

**4. Check Network Performance:**
```bash
# Install iperf3
sudo apt install iperf3  # Linux
# Download for Windows from: https://iperf.fr/

# On server:
iperf3 -s

# On client:
iperf3 -c 192.168.1.10
```

**Expected Results:**
- Gigabit Ethernet: ~900-940 Mbps
- Fast Ethernet (100Mbps): ~90-95 Mbps

## 🔥 Firewall Configuration

### Ubuntu Server Firewall (UFW)

```bash
# Enable firewall
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS (for web interface)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow TFTP (for PXE boot)
sudo ufw allow 69/udp

# Allow NFS (if using NFS for storage)
sudo ufw allow 2049/tcp

# Allow DNS
sudo ufw allow 53/tcp
sudo ufw allow 53/udp

# Allow DHCP
sudo ufw allow 67/udp
sudo ufw allow 68/udp

# Allow from specific subnet only
sudo ufw allow from 192.168.1.0/24 to any port 3306  # MySQL example

# Check status
sudo ufw status verbose
```

### Router Configuration

**Port Forwarding (if accessing from internet - NOT recommended for security):**
- Only forward what's absolutely necessary
- Use VPN instead for remote access

**DHCP Settings:**
- Disable DHCP on router if using dedicated DHCP server
- Or configure DHCP relay if using separate DHCP server

## 📋 Network Documentation Checklist

Create a network documentation file with:

- [ ] Network diagram showing all devices
- [ ] IP address allocation table
- [ ] MAC address listing
- [ ] DNS server addresses
- [ ] Gateway/router information
- [ ] VLAN configuration (if applicable)
- [ ] Firewall rules
- [ ] Service ports used
- [ ] WiFi credentials (if applicable)
- [ ] ISP information and credentials
- [ ] Hardware inventory (switches, cables, etc.)

## 🚨 Troubleshooting Common Issues

### Issue: Can't Ping Gateway

**Possible Causes:**
- Wrong IP address or subnet mask
- Cable not connected
- Switch port disabled
- Firewall blocking ICMP

**Solutions:**
```bash
# Check cable is connected
ip link show

# Verify IP configuration
ip addr show

# Check routing table
ip route show

# Test with different device
```

### Issue: Can Ping Gateway But Not Internet

**Possible Causes:**
- Wrong gateway address
- Router not connected to internet
- DNS not configured

**Solutions:**
```bash
# Check gateway is reachable
ping 192.168.1.1

# Check internet connectivity from gateway
ping 8.8.8.8

# Verify DNS
cat /etc/resolv.conf
```

### Issue: DNS Not Resolving

**Possible Causes:**
- Wrong DNS server configured
- DNS server not running
- Firewall blocking DNS

**Solutions:**
```bash
# Test with public DNS
nslookup google.com 8.8.8.8

# Check DNS server status
sudo systemctl status dnsmasq

# Check firewall
sudo ufw status
```

## 🔗 Related Documentation

- [[DHCP and DNS Configuration]] - Detailed DHCP/DNS setup
- [[PXE Boot Setup]] - Network boot configuration
- [[Security Best Practices]] - Network security
- [[Troubleshooting Guide]] - Advanced troubleshooting

## 📚 Additional Resources

- [Subnet Calculator](https://www.subnet-calculator.com/)
- [IP Address Guide](https://www.arin.net/knowledge/address_filters.html)
- [Netplan Examples](https://netplan.io/examples/)
- [Ubuntu Networking Guide](https://ubuntu.com/server/docs/network-configuration)

---

**Last Updated:** 2025-11-24
**Difficulty:** Beginner to Intermediate
