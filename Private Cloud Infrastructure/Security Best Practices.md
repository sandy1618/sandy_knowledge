---
title: Security Best Practices
tags: [security, hardening, firewall, encryption, access-control]
created: 2025-11-24
---

# Security Best Practices

Comprehensive guide to securing your private cloud infrastructure.

## 🎯 Security Overview

### Security Layers

```
Defense in Depth Strategy:

Physical Security
    ↓
Network Security (Firewall, VLANs, IDS/IPS)
    ↓
Host Security (OS Hardening, Updates)
    ↓
Application Security (Service Configuration)
    ↓
Data Security (Encryption, Backups)
    ↓
Access Control (Authentication, Authorization)
    ↓
Monitoring & Logging
```

### Security Principles

1. **Least Privilege:** Grant minimum necessary access
2. **Defense in Depth:** Multiple security layers
3. **Fail Secure:** Default to secure state on failure
4. **Keep it Simple:** Complexity is the enemy of security
5. **Regular Updates:** Patch vulnerabilities promptly
6. **Monitor Everything:** Detect and respond to incidents

## 🔒 Physical Security

### Server Room/Rack Security

**Physical measures:**
- [ ] Lock server room door
- [ ] Limit physical access
- [ ] Use locked server rack
- [ ] Cable management to prevent tampering
- [ ] Security cameras (if sensitive)
- [ ] Environmental monitoring (temperature, humidity)
- [ ] UPS for power protection
- [ ] Fire suppression system

**BIOS/UEFI Security:**
```
- Set strong BIOS password
- Disable unused boot devices
- Enable Secure Boot (where applicable)
- Disable USB boot (if not needed)
- Enable TPM if available
- Set boot password
```

## 🌐 Network Security

### Firewall Configuration (UFW)

**Install and enable UFW:**
```bash
# Install (if not installed)
sudo apt install -y ufw

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (IMPORTANT: do this first!)
sudo ufw allow 22/tcp
# Or limit SSH to specific IP
sudo ufw allow from 192.168.1.0/24 to any port 22

# Allow services from local network only
sudo ufw allow from 192.168.1.0/24 to any port 80    # HTTP
sudo ufw allow from 192.168.1.0/24 to any port 443   # HTTPS
sudo ufw allow from 192.168.1.0/24 to any port 69 proto udp  # TFTP
sudo ufw allow from 192.168.1.0/24 to any port 2049  # NFS
sudo ufw allow from 192.168.1.0/24 to any port 445   # Samba
sudo ufw allow from 192.168.1.0/24 to any port 139   # Samba

# DHCP
sudo ufw allow from 192.168.1.0/24 to any port 67 proto udp
sudo ufw allow from 192.168.1.0/24 to any port 68 proto udp

# DNS
sudo ufw allow from 192.168.1.0/24 to any port 53

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

**Advanced UFW rules:**
```bash
# Rate limit SSH (prevent brute force)
sudo ufw limit 22/tcp

# Allow specific IP to specific port
sudo ufw allow from 192.168.1.101 to any port 3306  # MySQL

# Block specific IP
sudo ufw deny from 192.168.1.99

# Allow port range
sudo ufw allow 9000:9999/udp  # Multicast

# Delete rule
sudo ufw delete allow 80/tcp

# View numbered rules
sudo ufw status numbered

# Delete by number
sudo ufw delete 3
```

### iptables (Advanced)

**Basic iptables rules:**
```bash
# Flush existing rules
sudo iptables -F

# Set default policies
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow from local network
sudo iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 443 -j ACCEPT

# Save rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# Restore on boot
sudo apt install iptables-persistent
```

### Network Segmentation (VLANs)

**VLAN Strategy:**
```
VLAN 10 - Management (192.168.10.0/24)
  - FOG server, NAS, switches
  
VLAN 20 - Workstations (192.168.20.0/24)
  - Client PCs
  
VLAN 30 - Services (192.168.30.0/24)
  - Web servers, databases
  
VLAN 99 - Isolated/Quarantine (192.168.99.0/24)
  - Testing, untrusted devices
```

### Intrusion Detection (Fail2ban)

**Install Fail2ban:**
```bash
sudo apt install -y fail2ban
```

**Configure Fail2ban:**
```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
destemail = admin@local
sendername = Fail2Ban

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h

[apache-auth]
enabled = true
port = http,https
logpath = /var/log/apache2/*error.log

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
```

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Check status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Unban IP
sudo fail2ban-client unban 192.168.1.50
```

## 🖥️ Host Security

### OS Hardening

**Keep system updated:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# Enable automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Remove unnecessary services:**
```bash
# List all services
systemctl list-unit-files --type=service

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth

# Check listening ports
sudo ss -tulpn
sudo netstat -tulpn
```

**Secure shared memory:**
```bash
# Edit fstab
sudo nano /etc/fstab
```

Add:
```
tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0
```

**Kernel hardening (sysctl):**
```bash
sudo nano /etc/sysctl.conf
```

```ini
# IP Forwarding (disable if not router)
net.ipv4.ip_forward = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP ping requests (optional)
# net.ipv4.icmp_echo_ignore_all = 1

# Increase range of ephemeral ports
net.ipv4.ip_local_port_range = 2000 65000

# Decrease TCP FIN timeout
net.ipv4.tcp_fin_timeout = 15

# Disable IPv6 (if not using)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

```bash
# Apply changes
sudo sysctl -p
```

### User Account Security

**Strong password policy:**
```bash
# Install password quality checking
sudo apt install -y libpam-pwquality

# Edit PAM configuration
sudo nano /etc/pam.d/common-password
```

Find line with `pam_pwquality.so` and modify:
```
password requisite pam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1
```

**Password aging:**
```bash
# Edit login.defs
sudo nano /etc/login.defs
```

```
PASS_MAX_DAYS 90
PASS_MIN_DAYS 7
PASS_WARN_AGE 14
```

**Lock inactive accounts:**
```bash
# Lock account after 30 days of inactivity
sudo useradd -D -f 30

# For existing user
sudo usermod -f 30 username
```

**Disable root login:**
```bash
# Lock root account
sudo passwd -l root

# Disable root SSH login
sudo nano /etc/ssh/sshd_config
```

```
PermitRootLogin no
```

### SSH Hardening

**Configure SSH securely:**
```bash
sudo nano /etc/ssh/sshd_config
```

```
# Change default port (optional)
Port 2222

# Disable root login
PermitRootLogin no

# Allow specific users only
AllowUsers admin user1 user2

# Disable password authentication (use keys only)
PasswordAuthentication no
PubkeyAuthentication yes

# Disable empty passwords
PermitEmptyPasswords no

# Limit authentication attempts
MaxAuthTries 3
MaxSessions 5

# Use Protocol 2 only
Protocol 2

# Disable X11 forwarding (if not needed)
X11Forwarding no

# Set idle timeout
ClientAliveInterval 300
ClientAliveCountMax 2

# Log level
LogLevel VERBOSE

# Use strong ciphers only
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
```

```bash
# Restart SSH
sudo systemctl restart sshd
```

**SSH key authentication:**
```bash
# On client, generate key pair
ssh-keygen -t ed25519 -a 100 -C "admin@privatecloud"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@192.168.1.10

# Test connection
ssh admin@192.168.1.10
```

**Two-Factor Authentication (2FA):**
```bash
# Install Google Authenticator
sudo apt install -y libpam-google-authenticator

# Configure for user
google-authenticator
# Answer questions, scan QR code with authenticator app

# Edit PAM SSH config
sudo nano /etc/pam.d/sshd
```

Add:
```
auth required pam_google_authenticator.so
```

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config
```

```
ChallengeResponseAuthentication yes
```

```bash
sudo systemctl restart sshd
```

## 🔐 Data Security

### Encryption at Rest

**Encrypt disk with LUKS:**
```bash
# Install cryptsetup
sudo apt install -y cryptsetup

# Encrypt partition (WARNING: destroys data!)
sudo cryptsetup luksFormat /dev/sdb1

# Open encrypted partition
sudo cryptsetup luksOpen /dev/sdb1 encrypted_storage

# Format encrypted partition
sudo mkfs.ext4 /dev/mapper/encrypted_storage

# Mount
sudo mkdir /mnt/encrypted
sudo mount /dev/mapper/encrypted_storage /mnt/encrypted
```

**Auto-mount encrypted partition:**
```bash
# Add key file
sudo dd if=/dev/urandom of=/root/keyfile bs=1024 count=4
sudo chmod 0400 /root/keyfile
sudo cryptsetup luksAddKey /dev/sdb1 /root/keyfile

# Edit crypttab
sudo nano /etc/crypttab
```

```
encrypted_storage /dev/sdb1 /root/keyfile luks
```

```bash
# Edit fstab
sudo nano /etc/fstab
```

```
/dev/mapper/encrypted_storage /mnt/encrypted ext4 defaults 0 2
```

### Backup Security

**Encrypt backups:**
```bash
# Using GPG
tar -czf - /storage | gpg -c -o /backups/storage-$(date +%Y%m%d).tar.gz.gpg

# Restore
gpg -d /backups/storage-20231124.tar.gz.gpg | tar -xzf -

# Using rsync with encryption
rsync -av --rsync-path="sudo rsync" \
    -e "ssh -i /root/.ssh/backup_key" \
    /storage/ backup-server:/encrypted/backups/
```

**Verify backup integrity:**
```bash
# Create checksums
find /storage -type f -exec sha256sum {} \; > /backups/checksums-$(date +%Y%m%d).txt

# Verify
sha256sum -c /backups/checksums-20231124.txt
```

### Secure File Permissions

**Review permissions:**
```bash
# Find world-writable files
find / -type f -perm -0002 -ls 2>/dev/null

# Find world-writable directories
find / -type d -perm -0002 -ls 2>/dev/null

# Find files without owner
find / -nouser -o -nogroup 2>/dev/null

# Find SUID/SGID files
find / -type f \( -perm -4000 -o -perm -2000 \) -ls 2>/dev/null
```

**Recommended permissions:**
```bash
# Web server files
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Images directory
sudo chown -R fog:fog /images
sudo chmod 755 /images

# Configuration files
sudo chmod 600 /etc/ssh/sshd_config
sudo chmod 600 /root/.ssh/authorized_keys
sudo chmod 700 /root/.ssh
```

## 📊 Monitoring and Auditing

### System Auditing (auditd)

**Install auditd:**
```bash
sudo apt install -y auditd audispd-plugins
```

**Configure audit rules:**
```bash
sudo nano /etc/audit/rules.d/audit.rules
```

```bash
# Delete all existing rules
-D

# Buffer Size
-b 8192

# Failure Mode (0=silent 1=printk 2=panic)
-f 1

# Audit system configuration changes
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers

# Audit SSH config
-w /etc/ssh/sshd_config -p wa -k sshd

# Audit network changes
-w /etc/hosts -p wa -k network_changes
-w /etc/network/ -p wa -k network_changes

# Audit login/logout
-w /var/log/faillog -p wa -k login
-w /var/log/lastlog -p wa -k login
-w /var/log/tallylog -p wa -k login

# Audit file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete

# Audit sudo usage
-w /usr/bin/sudo -p x -k sudo_usage

# Make configuration immutable
-e 2
```

```bash
# Restart auditd
sudo systemctl restart auditd

# Search audit logs
sudo ausearch -k identity
sudo ausearch -k network_changes
sudo ausearch -ts today

# Generate audit reports
sudo aureport -au
sudo aureport -f
```

### Log Management

**Centralize logs with rsyslog:**
```bash
sudo nano /etc/rsyslog.conf
```

```
# Send all logs to central server
*.* @192.168.1.15:514

# Or TCP
*.* @@192.168.1.15:514
```

**Log rotation:**
```bash
sudo nano /etc/logrotate.d/private-cloud
```

```
/var/log/private-cloud/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
```

### Monitoring with Netdata

**Install Netdata:**
```bash
bash <(curl -Ss https://my-netdata.io/kickstart.sh)
```

**Access:** `http://192.168.1.10:19999`

**Secure Netdata:**
```bash
sudo nano /etc/netdata/netdata.conf
```

```ini
[web]
    bind to = 192.168.1.10
    
[global]
    # Access control
    allow connections from = localhost 192.168.1.*
```

## 🚨 Incident Response

### Security Incident Checklist

**1. Detect:**
- [ ] Monitor logs for anomalies
- [ ] Review failed login attempts
- [ ] Check network connections
- [ ] Verify running processes

**2. Contain:**
- [ ] Disconnect affected systems from network
- [ ] Block malicious IPs
- [ ] Disable compromised accounts
- [ ] Preserve evidence

**3. Eradicate:**
- [ ] Remove malware/backdoors
- [ ] Close vulnerabilities
- [ ] Change all passwords
- [ ] Update systems

**4. Recover:**
- [ ] Restore from clean backups
- [ ] Verify system integrity
- [ ] Reconnect to network
- [ ] Monitor closely

**5. Document:**
- [ ] Timeline of events
- [ ] Actions taken
- [ ] Lessons learned
- [ ] Update procedures

### Quick Response Commands

```bash
# Check active connections
sudo netstat -tupan | grep ESTABLISHED
sudo ss -tupan

# View logged-in users
who
w
last

# Check running processes
ps auxf
top
htop

# Review recent commands
history
sudo cat /root/.bash_history

# Check for rootkits
sudo apt install -y rkhunter chkrootkit
sudo rkhunter --check
sudo chkrootkit

# Find recently modified files
find / -mtime -1 -type f 2>/dev/null

# Check for suspicious cron jobs
sudo crontab -l
sudo cat /etc/crontab
sudo ls -la /etc/cron.*
```

## 📋 Security Checklist

### Monthly Security Tasks

- [ ] Review system logs
- [ ] Check for failed login attempts
- [ ] Update all systems
- [ ] Review firewall rules
- [ ] Check backup integrity
- [ ] Review user accounts
- [ ] Audit file permissions
- [ ] Test disaster recovery
- [ ] Review security policies
- [ ] Check for security advisories

## 🔗 Related Documentation

- [[Network Setup Guide]] - Network security
- [[Storage Solutions]] - Securing storage
- [[Troubleshooting Guide]] - Security troubleshooting
- [[Automation and Scripts]] - Security automation

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate to Advanced
