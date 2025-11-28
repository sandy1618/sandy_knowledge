---
title: DHCP and DNS Configuration
tags: [dhcp, dns, network-services, configuration]
created: 2025-11-24
---

# DHCP and DNS Configuration

Detailed guide for configuring DHCP (Dynamic Host Configuration Protocol) and DNS (Domain Name System) services for your private cloud infrastructure.

## 🎯 Understanding DHCP and DNS

### DHCP (Dynamic Host Configuration Protocol)

**What DHCP does:**
- Automatically assigns IP addresses to devices
- Provides network configuration (gateway, DNS servers)
- Enables PXE boot parameters
- Reduces manual configuration
- Prevents IP address conflicts

**DHCP Process (DORA):**
```
1. DISCOVER - Client broadcasts: "I need an IP address"
2. OFFER - Server responds: "You can use 192.168.1.101"
3. REQUEST - Client says: "I accept 192.168.1.101"
4. ACKNOWLEDGE - Server confirms: "192.168.1.101 is yours"
```

### DNS (Domain Name System)

**What DNS does:**
- Translates hostnames to IP addresses
- Enables use of friendly names (server.local instead of 192.168.1.10)
- Provides reverse lookups (IP to hostname)
- Supports service discovery
- Essential for many network services

**DNS Query Process:**
```
User requests: fog-server.local
    ↓
DNS Server checks its records
    ↓
Returns: 192.168.1.10
    ↓
User connects to 192.168.1.10
```

## 🔧 DHCP Server Setup

### Option 1: ISC DHCP Server (Traditional)

**Installation:**
```bash
# Update system
sudo apt update

# Install ISC DHCP Server
sudo apt install -y isc-dhcp-server
```

**Configuration:**

```bash
# Edit DHCP configuration
sudo nano /etc/dhcp/dhcpd.conf
```

**Basic DHCP configuration:**
```conf
# Global settings
default-lease-time 600;
max-lease-time 7200;
authoritative;

# DNS settings
option domain-name "local";
option domain-name-servers 192.168.1.10, 8.8.8.8;

# Subnet configuration
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option broadcast-address 192.168.1.255;
    
    # PXE boot configuration
    next-server 192.168.1.10;
    filename "pxelinux.0";
}

# Static IP reservations (by MAC address)
host workstation-1 {
    hardware ethernet aa:bb:cc:dd:ee:10;
    fixed-address 192.168.1.101;
    option host-name "workstation-1";
}

host workstation-2 {
    hardware ethernet aa:bb:cc:dd:ee:11;
    fixed-address 192.168.1.102;
    option host-name "workstation-2";
}

host workstation-3 {
    hardware ethernet aa:bb:cc:dd:ee:12;
    fixed-address 192.168.1.103;
    option host-name "workstation-3";
}
```

**Advanced DHCP configuration with PXE options:**
```conf
# DHCP Configuration with BIOS and UEFI support

subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option domain-name-servers 192.168.1.10, 8.8.8.8;
    option domain-name "local";
    
    # PXE boot server
    next-server 192.168.1.10;
    
    # Detect BIOS vs UEFI
    if exists user-class and option user-class = "iPXE" {
        filename "boot.ipxe";
    } elsif option architecture-type = 00:07 {
        # UEFI 64-bit
        filename "bootx64.efi";
    } elsif option architecture-type = 00:00 {
        # BIOS
        filename "pxelinux.0";
    } else {
        # Default to BIOS
        filename "pxelinux.0";
    }
}

# Group configuration (apply settings to multiple hosts)
group {
    option domain-name-servers 192.168.1.10;
    option domain-name "office.local";
    
    host pc-office-1 { hardware ethernet aa:bb:cc:dd:ee:20; fixed-address 192.168.1.111; }
    host pc-office-2 { hardware ethernet aa:bb:cc:dd:ee:21; fixed-address 192.168.1.112; }
}
```

**Specify interface to listen on:**
```bash
sudo nano /etc/default/isc-dhcp-server
```

```
# Interface to listen on
INTERFACESv4="eno1"
```

**Start and enable DHCP server:**
```bash
# Test configuration
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf

# Start service
sudo systemctl start isc-dhcp-server

# Enable on boot
sudo systemctl enable isc-dhcp-server

# Check status
sudo systemctl status isc-dhcp-server

# View active leases
sudo cat /var/lib/dhcp/dhcpd.leases
```

### Option 2: dnsmasq (Lightweight, Combined DHCP/DNS)

**Installation:**
```bash
sudo apt install -y dnsmasq
```

**Configuration:**
```bash
# Stop systemd-resolved (conflicts with dnsmasq)
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Edit dnsmasq config
sudo nano /etc/dnsmasq.conf
```

**dnsmasq configuration (DHCP + DNS + TFTP):**
```conf
# Listening interface
interface=eno1
bind-interfaces

# DHCP range
dhcp-range=192.168.1.100,192.168.1.200,12h

# Gateway
dhcp-option=3,192.168.1.1

# DNS servers to forward to
server=8.8.8.8
server=8.8.4.4

# Local domain
domain=local
local=/local/
expand-hosts

# DHCP static assignments
dhcp-host=aa:bb:cc:dd:ee:10,192.168.1.101,workstation-1,infinite
dhcp-host=aa:bb:cc:dd:ee:11,192.168.1.102,workstation-2,infinite
dhcp-host=aa:bb:cc:dd:ee:12,192.168.1.103,workstation-3,infinite

# PXE boot configuration
dhcp-boot=pxelinux.0,192.168.1.10
dhcp-option=66,192.168.1.10

# TFTP server
enable-tftp
tftp-root=/var/lib/tftpboot

# DNS local records
address=/fog-server.local/192.168.1.10
address=/nas.local/192.168.1.12

# DHCP options
dhcp-option=option:router,192.168.1.1
dhcp-option=option:dns-server,192.168.1.10

# Logging
log-queries
log-dhcp
log-facility=/var/log/dnsmasq.log

# Cache size
cache-size=1000

# Don't forward local addresses
bogus-priv
```

**Start dnsmasq:**
```bash
sudo systemctl start dnsmasq
sudo systemctl enable dnsmasq
sudo systemctl status dnsmasq
```

## 🌐 DNS Server Setup

### Option 1: dnsmasq (Simple, for small networks)

Already configured in the dnsmasq section above. Perfect for:
- Home labs
- Small offices
- Test environments
- Simple DNS needs

### Option 2: BIND9 (Advanced, production)

**Installation:**
```bash
sudo apt install -y bind9 bind9utils bind9-doc
```

**Basic configuration:**

```bash
# Edit named.conf.options
sudo nano /etc/bind/named.conf.options
```

```
options {
    directory "/var/cache/bind";
    
    // Forward queries to upstream DNS
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    // Allow queries from local network
    allow-query { localhost; 192.168.1.0/24; };
    
    // Security
    dnssec-validation auto;
    listen-on { 127.0.0.1; 192.168.1.10; };
    recursion yes;
    allow-recursion { localhost; 192.168.1.0/24; };
};
```

**Configure local zone:**

```bash
# Edit named.conf.local
sudo nano /etc/bind/named.conf.local
```

```
// Forward zone
zone "local" {
    type master;
    file "/etc/bind/zones/db.local";
};

// Reverse zone
zone "1.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.1";
};
```

**Create forward zone file:**

```bash
sudo mkdir -p /etc/bind/zones
sudo nano /etc/bind/zones/db.local
```

```
;
; BIND data file for local domain
;
$TTL    604800
@       IN      SOA     fog-server.local. admin.local. (
                              2023112401         ; Serial
                              604800         ; Refresh
                              86400         ; Retry
                              2419200         ; Expire
                              604800 )       ; Negative Cache TTL
;
@       IN      NS      fog-server.local.
@       IN      A       192.168.1.10

; Name servers
fog-server      IN      A       192.168.1.10

; Hosts
workstation-1   IN      A       192.168.1.101
workstation-2   IN      A       192.168.1.102
workstation-3   IN      A       192.168.1.103
nas             IN      A       192.168.1.12

; Aliases
www             IN      CNAME   fog-server
fileserver      IN      CNAME   nas
```

**Create reverse zone file:**

```bash
sudo nano /etc/bind/zones/db.192.168.1
```

```
;
; BIND reverse data file for 192.168.1.x
;
$TTL    604800
@       IN      SOA     fog-server.local. admin.local. (
                              2023112401         ; Serial
                              604800         ; Refresh
                              86400         ; Retry
                              2419200         ; Expire
                              604800 )       ; Negative Cache TTL
;
@       IN      NS      fog-server.local.

; PTR Records
10      IN      PTR     fog-server.local.
101     IN      PTR     workstation-1.local.
102     IN      PTR     workstation-2.local.
103     IN      PTR     workstation-3.local.
12      IN      PTR     nas.local.
```

**Check configuration and start:**

```bash
# Check configuration
sudo named-checkconf
sudo named-checkzone local /etc/bind/zones/db.local
sudo named-checkzone 1.168.192.in-addr.arpa /etc/bind/zones/db.192.168.1

# Restart BIND
sudo systemctl restart bind9
sudo systemctl enable bind9
sudo systemctl status bind9
```

## 🧪 Testing DHCP and DNS

### Testing DHCP

**Check DHCP leases:**
```bash
# ISC DHCP Server
sudo cat /var/lib/dhcp/dhcpd.leases

# dnsmasq
sudo cat /var/lib/misc/dnsmasq.leases

# View in real-time
sudo tail -f /var/log/syslog | grep DHCP
```

**Test DHCP from client:**
```bash
# Release current IP
sudo dhclient -r

# Request new IP
sudo dhclient -v

# Windows
ipconfig /release
ipconfig /renew
```

**Test with nmap:**
```bash
# Install nmap
sudo apt install nmap

# Discover DHCP server
sudo nmap --script broadcast-dhcp-discover -e eno1
```

### Testing DNS

**Forward lookup:**
```bash
# Using nslookup
nslookup fog-server.local 192.168.1.10
nslookup workstation-1.local

# Using dig
dig @192.168.1.10 fog-server.local
dig @192.168.1.10 workstation-1.local +short

# Using host
host fog-server.local 192.168.1.10
```

**Reverse lookup:**
```bash
nslookup 192.168.1.10
dig -x 192.168.1.10
host 192.168.1.10
```

**Test DNS resolution speed:**
```bash
time dig @192.168.1.10 google.com
time dig @8.8.8.8 google.com
```

**Check DNS cache (dnsmasq):**
```bash
sudo killall -USR1 dnsmasq
sudo tail /var/log/dnsmasq.log
```

## 📊 Advanced Configurations

### DHCP Failover (High Availability)

**Primary DHCP server configuration:**
```conf
failover peer "dhcp-failover" {
    primary;
    address 192.168.1.10;
    port 519;
    peer address 192.168.1.11;
    peer port 520;
    max-response-delay 60;
    max-unacked-updates 10;
    load balance max seconds 3;
    mclt 3600;
    split 128;
}

subnet 192.168.1.0 netmask 255.255.255.0 {
    pool {
        failover peer "dhcp-failover";
        range 192.168.1.100 192.168.1.200;
    }
    option routers 192.168.1.1;
}
```

**Secondary DHCP server configuration:**
```conf
failover peer "dhcp-failover" {
    secondary;
    address 192.168.1.11;
    port 520;
    peer address 192.168.1.10;
    peer port 519;
    max-response-delay 60;
    max-unacked-updates 10;
    load balance max seconds 3;
}

subnet 192.168.1.0 netmask 255.255.255.0 {
    pool {
        failover peer "dhcp-failover";
        range 192.168.1.100 192.168.1.200;
    }
    option routers 192.168.1.1;
}
```

### DNS Split Horizon

Serve different answers based on client location:

```
// Internal view
view "internal" {
    match-clients { 192.168.1.0/24; };
    
    zone "local" {
        type master;
        file "/etc/bind/zones/db.local.internal";
    };
};

// External view
view "external" {
    match-clients { any; };
    
    zone "local" {
        type master;
        file "/etc/bind/zones/db.local.external";
    };
};
```

### Dynamic DNS Updates

Allow DHCP to update DNS records automatically:

**BIND configuration:**
```
// Generate TSIG key
dnssec-keygen -a HMAC-MD5 -b 128 -n HOST dhcp-key

// Add to named.conf.local
key "dhcp-key" {
    algorithm hmac-md5;
    secret "generated-key-here";
};

zone "local" {
    type master;
    file "/etc/bind/zones/db.local";
    allow-update { key "dhcp-key"; };
};
```

**DHCP configuration:**
```conf
# Enable DDNS
ddns-update-style interim;
ddns-domainname "local";
ddns-rev-domainname "in-addr.arpa";

# TSIG key
key dhcp-key {
    algorithm hmac-md5;
    secret "generated-key-here";
};

# Zone configuration
zone local. {
    primary 192.168.1.10;
    key dhcp-key;
}

zone 1.168.192.in-addr.arpa. {
    primary 192.168.1.10;
    key dhcp-key;
}
```

## 🚨 Troubleshooting

### DHCP Issues

**Client not getting IP address:**
```bash
# Check DHCP server is running
sudo systemctl status isc-dhcp-server
sudo systemctl status dnsmasq

# Check logs
sudo tail -f /var/log/syslog | grep dhcp

# Test DHCP on network
sudo nmap --script broadcast-dhcp-discover

# Check firewall
sudo ufw status
sudo ufw allow 67/udp
sudo ufw allow 68/udp

# Verify configuration
sudo dhcpd -t
```

**IP address conflicts:**
```bash
# Check for duplicate IPs
sudo arping -D -I eno1 192.168.1.101

# Clear leases and restart
sudo systemctl stop isc-dhcp-server
sudo rm /var/lib/dhcp/dhcpd.leases
sudo touch /var/lib/dhcp/dhcpd.leases
sudo systemctl start isc-dhcp-server
```

### DNS Issues

**DNS not resolving:**
```bash
# Check DNS server is running
sudo systemctl status bind9
sudo systemctl status dnsmasq

# Test locally
dig @127.0.0.1 fog-server.local

# Check zone files
sudo named-checkzone local /etc/bind/zones/db.local

# View logs
sudo tail -f /var/log/syslog | grep named

# Check firewall
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

**Slow DNS resolution:**
```bash
# Check forwarders are responding
dig @8.8.8.8 google.com

# Adjust cache size (dnsmasq)
cache-size=5000

# Clear cache
sudo systemctl restart dnsmasq
sudo rndc flush  # BIND
```

## 📋 Maintenance Checklist

**Weekly:**
- [ ] Review DHCP leases
- [ ] Check for IP conflicts
- [ ] Monitor DNS query logs
- [ ] Verify services are running

**Monthly:**
- [ ] Update static reservations
- [ ] Review and cleanup old leases
- [ ] Check DNS zone serial numbers
- [ ] Backup configurations
- [ ] Update documentation

**Quarterly:**
- [ ] Audit DHCP ranges
- [ ] Review DNS records
- [ ] Test failover (if configured)
- [ ] Update security settings

## 🔗 Related Documentation

- [[Network Setup Guide]] - Network infrastructure basics
- [[PXE Boot Setup]] - PXE configuration with DHCP
- [[Security Best Practices]] - Securing network services
- [[Troubleshooting Guide]] - Advanced troubleshooting

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate
