---
title: Automation and Scripts
tags: [automation, scripts, ansible, bash, deployment]
created: 2025-11-24
---

# Automation and Scripts

Comprehensive guide to automating tasks in your private cloud infrastructure.

## 🎯 Automation Overview

### Benefits of Automation

✅ **Consistency:** Same process every time
✅ **Speed:** Execute tasks in seconds
✅ **Reliability:** Reduce human error
✅ **Scalability:** Manage many systems easily
✅ **Documentation:** Scripts serve as documentation
✅ **Repeatability:** Easy to reproduce setups

### Automation Tools

| Tool | Purpose | Best For |
|------|---------|----------|
| Bash Scripts | Simple automation | System tasks, backups |
| Ansible | Configuration management | Multi-host deployments |
| Cron | Scheduled tasks | Backups, maintenance |
| systemd timers | Modern scheduling | Replacing cron |
| Python | Complex automation | APIs, data processing |

## 📜 Bash Scripts

### Basic Script Structure

**Template script:**
```bash
#!/bin/bash
# Script: example.sh
# Description: Template for bash scripts
# Author: Admin
# Date: 2023-11-24

# Exit on error
set -e

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/example.log"
DATE=$(date +%Y%m%d-%H%M%S)

# Functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log_message "ERROR: $1"
    exit 1
}

# Main script
main() {
    log_message "Script started"
    
    # Your code here
    
    log_message "Script completed successfully"
}

# Run main function
main "$@"
```

### Deployment Automation Script

**Deploy OS image to multiple PCs:**
```bash
#!/bin/bash
# Script: deploy-image.sh
# Description: Deploy OS image to multiple hosts via FOG

set -e

# Configuration
FOG_SERVER="192.168.1.10"
FOG_USER="foguser"
FOG_PASSWORD="fogpassword"
IMAGE_NAME="windows10-standard-v1.2"
LOG_FILE="/var/log/deploy-image.log"

# Host list (hostname:mac_address)
HOSTS=(
    "workstation-1:aa:bb:cc:dd:ee:10"
    "workstation-2:aa:bb:cc:dd:ee:11"
    "workstation-3:aa:bb:cc:dd:ee:12"
)

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Deploy to single host via FOG API
deploy_host() {
    local hostname=$1
    local mac=$2
    
    log_message "Creating deploy task for $hostname ($mac)"
    
    # Use FOG API to create deploy task
    curl -X POST "http://$FOG_SERVER/fog/host/deploy" \
        -u "$FOG_USER:$FOG_PASSWORD" \
        -d "hostname=$hostname" \
        -d "mac=$mac" \
        -d "image=$IMAGE_NAME" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "✓ Deploy task created for $hostname"
    else
        log_message "✗ Failed to create deploy task for $hostname"
        return 1
    fi
}

# Wake on LAN
wake_host() {
    local mac=$1
    log_message "Waking up host with MAC: $mac"
    wakeonlan "$mac" >> "$LOG_FILE" 2>&1
}

# Main deployment loop
main() {
    log_message "=== Starting mass deployment ==="
    log_message "Image: $IMAGE_NAME"
    log_message "Target hosts: ${#HOSTS[@]}"
    
    for host_info in "${HOSTS[@]}"; do
        IFS=':' read -r hostname mac <<< "$host_info"
        
        # Create deploy task
        deploy_host "$hostname" "$mac"
        
        # Wait a moment
        sleep 2
        
        # Wake up the host
        wake_host "$mac"
        
        log_message "---"
    done
    
    log_message "=== Deployment tasks created ==="
    log_message "Hosts will boot via PXE and begin imaging"
}

# Check prerequisites
if ! command -v wakeonlan &> /dev/null; then
    echo "Error: wakeonlan not installed"
    echo "Install with: sudo apt install wakeonlan"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl not installed"
    echo "Install with: sudo apt install curl"
    exit 1
fi

# Run main function
main "$@"
```

### Backup Automation Script

**Comprehensive backup script:**
```bash
#!/bin/bash
# Script: backup-all.sh
# Description: Backup all critical data

set -e

# Configuration
BACKUP_ROOT="/backups"
SOURCE_DIRS=(
    "/storage/images"
    "/storage/shared"
    "/etc"
    "/home"
)
RETENTION_DAYS=30
LOG_FILE="/var/log/backup-all.log"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/backup-$DATE"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup function
backup_directory() {
    local source=$1
    local name=$(basename "$source")
    local dest="$BACKUP_DIR/$name"
    
    log_message "Backing up $source to $dest"
    
    rsync -av --delete \
        --exclude 'lost+found' \
        --exclude '.cache' \
        --exclude '*.tmp' \
        "$source/" "$dest/" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "✓ Backed up $source successfully"
    else
        log_message "✗ Failed to backup $source"
        return 1
    fi
}

# Backup system configuration
backup_system_config() {
    log_message "Backing up system configuration"
    
    local config_dir="$BACKUP_DIR/system-config"
    mkdir -p "$config_dir"
    
    # Network configuration
    cp -r /etc/netplan "$config_dir/" 2>/dev/null || true
    cp /etc/network/interfaces "$config_dir/" 2>/dev/null || true
    
    # Service configurations
    cp -r /etc/apache2 "$config_dir/" 2>/dev/null || true
    cp -r /etc/samba "$config_dir/" 2>/dev/null || true
    cp /etc/dhcp/dhcpd.conf "$config_dir/" 2>/dev/null || true
    cp /etc/exports "$config_dir/" 2>/dev/null || true
    
    # Create package list
    dpkg --get-selections > "$config_dir/packages.list"
    
    log_message "✓ System configuration backed up"
}

# Database backup
backup_databases() {
    log_message "Backing up databases"
    
    local db_dir="$BACKUP_DIR/databases"
    mkdir -p "$db_dir"
    
    # MySQL/MariaDB backup
    if command -v mysqldump &> /dev/null; then
        mysqldump --all-databases > "$db_dir/all-databases.sql" 2>> "$LOG_FILE"
        log_message "✓ MySQL databases backed up"
    fi
}

# Compress backup
compress_backup() {
    log_message "Compressing backup"
    
    cd "$BACKUP_ROOT"
    tar -czf "backup-$DATE.tar.gz" "backup-$DATE/" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "✓ Backup compressed"
        rm -rf "backup-$DATE/"
        log_message "✓ Temporary files cleaned up"
    else
        log_message "✗ Failed to compress backup"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log_message "Cleaning up old backups (older than $RETENTION_DAYS days)"
    
    find "$BACKUP_ROOT" -name "backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete
    
    log_message "✓ Old backups removed"
}

# Send notification
send_notification() {
    local status=$1
    local message=$2
    
    # Send email (if mail is configured)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "Backup $status" admin@local
    fi
    
    # Log to syslog
    logger -t backup "$status: $message"
}

# Main function
main() {
    log_message "=== Starting backup ==="
    
    local errors=0
    
    # Backup directories
    for dir in "${SOURCE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            backup_directory "$dir" || ((errors++))
        else
            log_message "⚠ Directory $dir does not exist, skipping"
        fi
    done
    
    # Backup system config
    backup_system_config || ((errors++))
    
    # Backup databases
    backup_databases || ((errors++))
    
    # Compress backup
    compress_backup || ((errors++))
    
    # Clean old backups
    cleanup_old_backups
    
    # Report
    if [ $errors -eq 0 ]; then
        log_message "=== Backup completed successfully ==="
        send_notification "SUCCESS" "Backup completed successfully at $DATE"
        exit 0
    else
        log_message "=== Backup completed with $errors error(s) ==="
        send_notification "WARNING" "Backup completed with $errors error(s)"
        exit 1
    fi
}

# Run main function
main "$@"
```

**Make executable and schedule:**
```bash
sudo chmod +x /usr/local/bin/backup-all.sh

# Add to crontab
sudo crontab -e
```

```cron
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-all.sh

# Weekly full backup on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/backup-all.sh
```

### System Monitoring Script

**Monitor system health:**
```bash
#!/bin/bash
# Script: monitor-system.sh
# Description: Monitor system health and send alerts

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=90

# Alert email
ALERT_EMAIL="admin@local"

check_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_int=${cpu_usage%.*}
    
    if [ "$cpu_int" -gt "$CPU_THRESHOLD" ]; then
        echo "ALERT: CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
        return 1
    fi
    return 0
}

check_memory() {
    local mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')
    
    if [ "$mem_usage" -gt "$MEMORY_THRESHOLD" ]; then
        echo "ALERT: Memory usage is ${mem_usage}% (threshold: ${MEMORY_THRESHOLD}%)"
        return 1
    fi
    return 0
}

check_disk() {
    local alerts=0
    
    while IFS= read -r line; do
        local usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local mount=$(echo "$line" | awk '{print $6}')
        
        if [ "$usage" -gt "$DISK_THRESHOLD" ]; then
            echo "ALERT: Disk usage on $mount is ${usage}% (threshold: ${DISK_THRESHOLD}%)"
            ((alerts++))
        fi
    done < <(df -h | grep -vE 'tmpfs|cdrom|Filesystem')
    
    [ $alerts -eq 0 ] && return 0 || return 1
}

check_services() {
    local services=("apache2" "nfs-server" "smbd" "isc-dhcp-server")
    local alerts=0
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            echo "ALERT: Service $service is not running"
            ((alerts++))
        fi
    done
    
    [ $alerts -eq 0 ] && return 0 || return 1
}

main() {
    local alerts=""
    local errors=0
    
    # Run checks
    alerts+=$(check_cpu) || ((errors++))
    alerts+=$'\n'$(check_memory) || ((errors++))
    alerts+=$'\n'$(check_disk) || ((errors++))
    alerts+=$'\n'$(check_services) || ((errors++))
    
    # Send alert if any check failed
    if [ $errors -gt 0 ]; then
        echo "$alerts" | mail -s "System Health Alert" "$ALERT_EMAIL"
        echo "$alerts"
        exit 1
    else
        echo "All checks passed"
        exit 0
    fi
}

main "$@"
```

## 🤖 Ansible Automation

### Installing Ansible

```bash
# Install Ansible
sudo apt update
sudo apt install -y ansible

# Verify installation
ansible --version
```

### Ansible Inventory

**Create inventory file:**
```bash
sudo nano /etc/ansible/hosts
```

```ini
[fog_server]
192.168.1.10 ansible_user=admin

[workstations]
192.168.1.101 ansible_user=admin hostname=workstation-1
192.168.1.102 ansible_user=admin hostname=workstation-2
192.168.1.103 ansible_user=admin hostname=workstation-3

[nas]
192.168.1.12 ansible_user=admin

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

### Basic Ansible Commands

```bash
# Ping all hosts
ansible all -m ping

# Run command on all hosts
ansible all -a "uptime"

# Update all hosts
ansible all -m apt -a "update_cache=yes upgrade=dist" --become

# Copy file to all hosts
ansible all -m copy -a "src=/tmp/file.txt dest=/tmp/file.txt"

# Restart service
ansible workstations -m service -a "name=apache2 state=restarted" --become
```

### Ansible Playbook Examples

**Update all systems:**
```yaml
# playbook-update.yml
---
- name: Update all systems
  hosts: all
  become: yes
  
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
    
    - name: Upgrade all packages
      apt:
        upgrade: dist
    
    - name: Remove unused packages
      apt:
        autoremove: yes
    
    - name: Check if reboot required
      stat:
        path: /var/run/reboot-required
      register: reboot_required
    
    - name: Reboot if required
      reboot:
        msg: "Rebooting after updates"
        reboot_timeout: 300
      when: reboot_required.stat.exists
```

**Deploy configuration files:**
```yaml
# playbook-config.yml
---
- name: Deploy configuration files
  hosts: workstations
  become: yes
  
  tasks:
    - name: Copy SSH config
      copy:
        src: files/ssh_config
        dest: /etc/ssh/sshd_config
        owner: root
        group: root
        mode: '0644'
      notify: Restart SSH
    
    - name: Deploy user bashrc
      copy:
        src: files/bashrc
        dest: /home/{{ ansible_user }}/.bashrc
        owner: "{{ ansible_user }}"
        mode: '0644'
    
    - name: Install common packages
      apt:
        name:
          - vim
          - git
          - htop
          - curl
          - wget
        state: present
  
  handlers:
    - name: Restart SSH
      service:
        name: sshd
        state: restarted
```

**Setup NFS client:**
```yaml
# playbook-nfs-client.yml
---
- name: Configure NFS client
  hosts: workstations
  become: yes
  
  vars:
    nfs_server: 192.168.1.10
    nfs_shares:
      - { src: "/storage/shared", dest: "/mnt/shared" }
      - { src: "/storage/home", dest: "/mnt/home" }
  
  tasks:
    - name: Install NFS client
      apt:
        name: nfs-common
        state: present
    
    - name: Create mount points
      file:
        path: "{{ item.dest }}"
        state: directory
        mode: '0755'
      loop: "{{ nfs_shares }}"
    
    - name: Mount NFS shares
      mount:
        path: "{{ item.dest }}"
        src: "{{ nfs_server }}:{{ item.src }}"
        fstype: nfs
        opts: defaults,_netdev
        state: mounted
      loop: "{{ nfs_shares }}"
```

**Run playbooks:**
```bash
# Check syntax
ansible-playbook playbook-update.yml --syntax-check

# Dry run
ansible-playbook playbook-update.yml --check

# Run playbook
ansible-playbook playbook-update.yml

# Run on specific hosts
ansible-playbook playbook-config.yml --limit workstation-1

# Run with verbose output
ansible-playbook playbook-nfs-client.yml -vvv
```

## ⏰ Scheduled Tasks

### Using Cron

**Edit crontab:**
```bash
# Edit user crontab
crontab -e

# Edit root crontab
sudo crontab -e
```

**Cron syntax:**
```
* * * * * command
│ │ │ │ │
│ │ │ │ └─ Day of week (0-7, 0 and 7 are Sunday)
│ │ │ └─── Month (1-12)
│ │ └───── Day of month (1-31)
│ └─────── Hour (0-23)
└───────── Minute (0-59)
```

**Common cron examples:**
```cron
# Every day at 2 AM
0 2 * * * /usr/local/bin/backup-all.sh

# Every hour
0 * * * * /usr/local/bin/check-services.sh

# Every 15 minutes
*/15 * * * * /usr/local/bin/monitor-system.sh

# Every Monday at 3 AM
0 3 * * 1 /usr/local/bin/weekly-maintenance.sh

# First day of month at 4 AM
0 4 1 * * /usr/local/bin/monthly-report.sh

# Every reboot
@reboot /usr/local/bin/startup-script.sh

# Daily
@daily /usr/local/bin/daily-tasks.sh

# Weekly (Sunday)
@weekly /usr/local/bin/weekly-tasks.sh

# Monthly
@monthly /usr/local/bin/monthly-tasks.sh
```

### Using systemd Timers

**Create timer unit:**
```bash
sudo nano /etc/systemd/system/backup.timer
```

```ini
[Unit]
Description=Daily backup timer
Requires=backup.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Create service unit:**
```bash
sudo nano /etc/systemd/system/backup.service
```

```ini
[Unit]
Description=Backup service
Wants=backup.timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-all.sh
User=root

[Install]
WantedBy=multi-user.target
```

**Enable and start timer:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable backup.timer
sudo systemctl start backup.timer

# Check timer status
sudo systemctl status backup.timer
sudo systemctl list-timers
```

## 🔗 Related Documentation

- [[Network Setup Guide]] - Network automation
- [[FOG Project Setup]] - FOG API automation
- [[Storage Solutions]] - Storage automation
- [[Security Best Practices]] - Security automation

---

**Last Updated:** 2025-11-24
**Difficulty:** Intermediate to Advanced
