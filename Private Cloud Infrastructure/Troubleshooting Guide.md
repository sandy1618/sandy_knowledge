---
title: Troubleshooting Guide
tags: [troubleshooting, debugging, problems, solutions, diagnostics]
created: 2025-11-24
---

# Troubleshooting Guide

Comprehensive troubleshooting guide for private cloud infrastructure issues.

## 🎯 Troubleshooting Methodology

### Systematic Approach

```
1. IDENTIFY
   - What is the problem?
   - When did it start?
   - What changed?

2. GATHER INFORMATION
   - Check logs
   - Test connectivity
   - Review configurations

3. ANALYZE
   - Identify patterns
   - Isolate the issue
   - Form hypothesis

4. TEST
   - Try solutions
   - Verify results
   - Document findings

5. IMPLEMENT
   - Apply permanent fix
   - Monitor system
   - Update documentation
```

## 🌐 Network Issues

### Cannot Ping Gateway

**Symptoms:** Client cannot ping 192.168.1.1

**Diagnosis:**
```bash
# Check cable connection
ip link show

# Check IP configuration
ip addr show
ip route show

# Check if interface is up
sudo ip link set eno1 up

# Test with different IP
ping 127.0.0.1  # Loopback
```

**Common Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Cable unplugged | Connect cable securely |
| Wrong IP/subnet | Fix IP configuration |
| Interface down | `sudo ip link set eno1 up` |
| Firewall blocking | Check `iptables -L` |
| Switch port disabled | Check switch configuration |

### DHCP Not Working

**Symptoms:** Client not receiving IP address

**Diagnosis:**
```bash
# On server: Check DHCP service
sudo systemctl status isc-dhcp-server
sudo systemctl status dnsmasq

# Check DHCP logs
sudo tail -f /var/log/syslog | grep -i dhcp
sudo journalctl -u isc-dhcp-server -f

# Test DHCP configuration
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf

# On client: Request IP manually
sudo dhclient -v
sudo dhclient -r && sudo dhclient -v

# Check for DHCP offers
sudo nmap --script broadcast-dhcp-discover
```

**Common Issues:**

**Issue 1: DHCP server not listening on correct interface**
```bash
# Edit /etc/default/isc-dhcp-server
INTERFACESv4="eno1"

sudo systemctl restart isc-dhcp-server
```

**Issue 2: IP range exhausted**
```bash
# Check leases
sudo cat /var/lib/dhcp/dhcpd.leases | grep "lease"

# Increase range in /etc/dhcp/dhcpd.conf
range 192.168.1.100 192.168.1.250;
```

**Issue 3: Firewall blocking DHCP**
```bash
sudo ufw allow 67/udp
sudo ufw allow 68/udp
sudo systemctl restart isc-dhcp-server
```

### DNS Not Resolving

**Symptoms:** Cannot resolve hostnames

**Diagnosis:**
```bash
# Test DNS locally
nslookup fog-server.local 127.0.0.1
dig @localhost fog-server.local

# Test public DNS
nslookup google.com 8.8.8.8

# Check DNS configuration
cat /etc/resolv.conf

# Check DNS service
sudo systemctl status bind9
sudo systemctl status dnsmasq

# View DNS logs
sudo tail -f /var/log/syslog | grep -i named
sudo tail -f /var/log/dnsmasq.log
```

**Common Fixes:**

**Issue 1: Wrong DNS server in /etc/resolv.conf**
```bash
# Fix resolv.conf
sudo nano /etc/resolv.conf
nameserver 192.168.1.10
nameserver 8.8.8.8
```

**Issue 2: Firewall blocking DNS**
```bash
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

**Issue 3: DNS cache issues**
```bash
# Flush DNS cache (systemd-resolved)
sudo systemd-resolve --flush-caches

# Restart dnsmasq
sudo systemctl restart dnsmasq
```

### Slow Network Performance

**Diagnosis:**
```bash
# Test network speed
sudo apt install -y iperf3

# On server
iperf3 -s

# On client
iperf3 -c 192.168.1.10

# Check network interface speed
ethtool eno1 | grep Speed

# Check for errors
ip -s link show eno1

# Monitor bandwidth
sudo apt install -y nload
nload eno1
```

**Common Causes:**

| Issue | Expected | Fix |
|-------|----------|-----|
| Wrong speed negotiation | 1000 Mbps | Force gigabit: `ethtool -s eno1 speed 1000 duplex full` |
| Bad cable | >900 Mbps | Replace with Cat6 cable |
| Switch bottleneck | >900 Mbps | Upgrade to gigabit switch |
| MTU mismatch | 1500 | Set MTU: `ip link set eno1 mtu 1500` |

## 💾 PXE Boot Issues

### PXE-E51: No DHCP Offers

**Symptoms:** Client displays "PXE-E51: No DHCP or proxy DHCP offers were received"

**Diagnosis:**
```bash
# Check DHCP is running
sudo systemctl status isc-dhcp-server

# Monitor DHCP requests
sudo tcpdump -i eno1 port 67 or port 68

# Check DHCP configuration
sudo dhcpd -t

# Verify network connectivity
ping 192.168.1.10
```

**Solutions:**
```bash
# Restart DHCP service
sudo systemctl restart isc-dhcp-server

# Check DHCP listens on correct interface
sudo nano /etc/default/isc-dhcp-server
INTERFACESv4="eno1"

# Verify firewall allows DHCP
sudo ufw allow 67/udp
sudo ufw allow 68/udp
```

### PXE-E32: TFTP Open Timeout

**Symptoms:** "PXE-E32: TFTP open timeout"

**Diagnosis:**
```bash
# Check TFTP service
sudo systemctl status tftpd-hpa
# Or for dnsmasq
sudo netstat -tulpn | grep :69

# Test TFTP manually
tftp 192.168.1.10
> get pxelinux.0
> quit

# Check file permissions
ls -la /var/lib/tftpboot/pxelinux.0
```

**Solutions:**
```bash
# Fix permissions
sudo chmod 644 /var/lib/tftpboot/pxelinux.0
sudo chmod 755 /var/lib/tftpboot/

# Restart TFTP
sudo systemctl restart tftpd-hpa

# For dnsmasq
sudo systemctl restart dnsmasq

# Check firewall
sudo ufw allow 69/udp
```

### Boot Menu Not Appearing

**Symptoms:** PXE boots but menu doesn't show

**Diagnosis:**
```bash
# Check menu files exist
ls -la /var/lib/tftpboot/pxelinux.cfg/default
ls -la /var/lib/tftpboot/menu.c32

# Check TFTP logs
sudo tail -f /var/log/syslog | grep tftp
```

**Solutions:**
```bash
# Re-copy syslinux files
sudo cp /usr/lib/syslinux/modules/bios/*.c32 /var/lib/tftpboot/

# Verify default menu exists
sudo nano /var/lib/tftpboot/pxelinux.cfg/default

# Test syntax
cat /var/lib/tftpboot/pxelinux.cfg/default
```

### UEFI vs BIOS Boot Issues

**Symptoms:** Works in BIOS mode but not UEFI (or vice versa)

**Solutions:**
```bash
# Ensure both boot files exist
ls -la /var/lib/tftpboot/pxelinux.0    # BIOS
ls -la /var/lib/tftpboot/bootx64.efi  # UEFI

# Copy UEFI bootloader
sudo cp /usr/lib/grub/x86_64-efi/monolithic/grubnetx64.efi.signed \
        /var/lib/tftpboot/bootx64.efi

# Update DHCP config for both
sudo nano /etc/dhcp/dhcpd.conf
```

```conf
# Detect and serve correct bootloader
if option architecture-type = 00:07 {
    filename "bootx64.efi";
} else {
    filename "pxelinux.0";
}
```

## 🖼️ FOG Imaging Issues

### Image Capture Fails

**Symptoms:** Image capture starts but fails partway through

**Diagnosis:**
```bash
# Check disk space on server
df -h /images

# Check NFS is running
sudo systemctl status nfs-server
showmount -e localhost

# Check client disk for errors
# (Boot client with Clonezilla or live USB)
sudo smartctl -a /dev/sda
sudo fsck /dev/sda1
```

**Solutions:**
```bash
# Free up space
sudo du -sh /images/*
sudo rm -rf /images/old-image/

# Repair client disk
# Boot with live USB
sudo fsck -f /dev/sda1

# Check NFS exports
sudo exportfs -ra
sudo exportfs -v
```

### Image Deployment Fails

**Symptoms:** Deploy task starts but fails

**Diagnosis:**
```bash
# Check FOG logs
sudo tail -f /var/log/apache2/error.log
sudo tail -f /opt/fog/log/foginstall.log

# Verify image exists
ls -lh /images/[image-name]

# Check target disk size
# Must be >= source disk size
```

**Solutions:**
```bash
# Target disk too small
# - Use larger disk
# - Or resize partition in image before capturing

# Disk not detected
# - Check SATA/AHCI mode in BIOS
# - Update FOG kernel: FOG Configuration → Kernel Update

# Permission issues
sudo chown -R fog:fog /images
sudo chmod -R 755 /images
```

### Multicast Not Working

**Symptoms:** Clients wait indefinitely for multicast session

**Diagnosis:**
```bash
# Check multicast service
sudo systemctl status FOGMulticastManager

# Check UDP ports
sudo netstat -tulpn | grep udpcast

# Verify all clients on same network segment
# Multicast doesn't cross routers without IGMP
```

**Solutions:**
```bash
# Restart multicast service
sudo systemctl restart FOGMulticastManager

# Check firewall
sudo ufw allow 9000:9999/udp

# Reduce session size
# FOG Configuration → Multicast Settings
# Set max clients to lower number (16-32)

# If crossing VLANs, enable IGMP snooping on switch
```

### Cannot Boot to Inventory/Register

**Symptoms:** "Unable to connect to fog server"

**Diagnosis:**
```bash
# Check network from client
# (At FOG boot screen, press Ctrl+C for shell)
ping 192.168.1.10

# Check FOG web interface accessible
curl http://192.168.1.10/fog/

# Check Apache/web server
sudo systemctl status apache2
```

**Solutions:**
```bash
# Restart web server
sudo systemctl restart apache2

# Check FOG settings
# Web interface → FOG Configuration → FOG Settings
# Verify TFTP_HOST and WEB_HOST are correct

# Firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 💿 Storage Issues

### NFS Mount Fails

**Symptoms:** `mount.nfs: access denied by server`

**Diagnosis:**
```bash
# On server: Check NFS exports
sudo exportfs -v
showmount -e localhost

# Check NFS service
sudo systemctl status nfs-server

# On client: Test connectivity
ping 192.168.1.10
showmount -e 192.168.1.10
```

**Solutions:**
```bash
# Fix exports permissions
sudo nano /etc/exports
# Ensure client IP/subnet is allowed

# Restart NFS
sudo exportfs -ra
sudo systemctl restart nfs-server

# Check firewall
sudo ufw allow from 192.168.1.0/24 to any port 2049
```

### Samba Share Not Accessible

**Symptoms:** Cannot connect to `\\192.168.1.10\share`

**Diagnosis:**
```bash
# Check Samba status
sudo systemctl status smbd
sudo systemctl status nmbd

# Test configuration
testparm

# Check share exists
sudo smbclient -L localhost -U%

# Check user
sudo pdbedit -L
```

**Solutions:**
```bash
# Restart Samba
sudo systemctl restart smbd nmbd

# Reset Samba password
sudo smbpasswd -a username

# Fix permissions
sudo chmod 755 /storage/shared
sudo chown nobody:nogroup /storage/shared  # For guest shares

# Firewall
sudo ufw allow 445/tcp
sudo ufw allow 139/tcp
```

### Disk Full

**Symptoms:** "No space left on device"

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find large directories
du -sh /storage/*
du -sh /images/*

# Find large files
find /storage -type f -size +1G -exec ls -lh {} \;

# Check inodes
df -i
```

**Solutions:**
```bash
# Remove old images
cd /images
sudo rm -rf old-image-name

# Clean logs
sudo journalctl --vacuum-time=7d
sudo find /var/log -name "*.log" -mtime +30 -delete

# Clean apt cache
sudo apt clean

# Remove old kernels
sudo apt autoremove -y
```

### Slow File Transfer

**Symptoms:** File copy/transfer very slow

**Diagnosis:**
```bash
# Test network speed
iperf3 -c 192.168.1.10

# Check disk I/O
iostat -x 1

# Check for errors
dmesg | grep -i error
```

**Solutions:**
```bash
# For NFS, adjust options
sudo nano /etc/fstab
# Add: rsize=8192,wsize=8192

# For Samba, tune settings
sudo nano /etc/samba/smb.conf
# Add in [global]:
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=65536 SO_SNDBUF=65536

# Check network speed
ethtool eno1
# Should show 1000Mb/s for gigabit
```

## 🔧 System Issues

### High CPU Usage

**Diagnosis:**
```bash
# Check processes
top
htop

# Identify high CPU process
ps aux --sort=-%cpu | head -10

# Check for specific service
sudo systemctl status [service-name]
```

**Solutions:**
```bash
# Restart problematic service
sudo systemctl restart [service-name]

# Limit CPU for service
sudo systemctl edit [service-name]
```

Add:
```ini
[Service]
CPUQuota=50%
```

### High Memory Usage

**Diagnosis:**
```bash
# Check memory
free -h

# Check swap usage
swapon --show

# Process memory usage
ps aux --sort=-%mem | head -10
```

**Solutions:**
```bash
# Clear cache
sudo sync
sudo echo 3 > /proc/sys/vm/drop_caches

# Add swap if needed
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Service Won't Start

**Diagnosis:**
```bash
# Check status
sudo systemctl status service-name

# View detailed logs
sudo journalctl -u service-name -n 50 --no-pager

# Check for port conflicts
sudo netstat -tulpn | grep :80
```

**Solutions:**
```bash
# Fix configuration
sudo systemctl edit service-name

# Reset failed state
sudo systemctl reset-failed service-name

# Start manually
sudo systemctl start service-name

# Check dependencies
systemctl list-dependencies service-name
```

## 🔍 Diagnostic Commands

### Network Diagnostics

```bash
# Show IP configuration
ip addr show
ip route show

# Test connectivity
ping -c 4 192.168.1.1
traceroute 8.8.8.8

# DNS lookup
nslookup google.com
dig google.com

# Port scanning
sudo nmap -p 1-1000 192.168.1.10

# Network connections
sudo netstat -tupan
sudo ss -tupan

# Packet capture
sudo tcpdump -i eno1 -n
```

### System Diagnostics

```bash
# System information
uname -a
lsb_release -a

# Hardware info
lshw
lscpu
lsmem
lsblk

# Disk usage
df -h
du -sh /*

# Process list
ps aux
ps auxf  # Tree view

# System logs
sudo journalctl -xe
sudo tail -f /var/log/syslog

# Boot logs
sudo journalctl -b
```

### Performance Diagnostics

```bash
# CPU/Memory/Disk
top
htop
vmstat 1
iostat -x 1

# Disk performance
sudo hdparm -Tt /dev/sda

# Network performance
iperf3 -s  # Server
iperf3 -c 192.168.1.10  # Client
```

## 📋 Troubleshooting Checklist

### When Things Go Wrong

**Initial Steps:**
- [ ] What changed recently?
- [ ] Can you reproduce the issue?
- [ ] Check system logs
- [ ] Verify network connectivity
- [ ] Check service status
- [ ] Review recent configuration changes

**Network Issues:**
- [ ] Can ping gateway?
- [ ] Can ping internet (8.8.8.8)?
- [ ] DNS resolving?
- [ ] Firewall rules correct?
- [ ] Cables connected?
- [ ] Switch ports active?

**Service Issues:**
- [ ] Service running?
- [ ] Configuration valid?
- [ ] Ports available?
- [ ] Firewall allowing traffic?
- [ ] Logs showing errors?
- [ ] Dependencies met?

**Storage Issues:**
- [ ] Disk space available?
- [ ] Permissions correct?
- [ ] Mount points accessible?
- [ ] NFS/Samba running?
- [ ] Network accessible?
- [ ] Disk healthy?

## 🔗 Related Documentation

- [[Network Setup Guide]] - Network troubleshooting
- [[PXE Boot Setup]] - PXE troubleshooting
- [[FOG Project Setup]] - FOG troubleshooting
- [[Storage Solutions]] - Storage troubleshooting
- [[Security Best Practices]] - Security issues

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate to Advanced
