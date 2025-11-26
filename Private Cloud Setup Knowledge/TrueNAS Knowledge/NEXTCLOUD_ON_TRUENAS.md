# Nextcloud Installation on TrueNAS SCALE

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Pre-Installation Planning](#pre-installation-planning)
4. [Method 1: TrueNAS Apps (Recommended)](#method-1-truenas-apps-recommended)
5. [Method 2: Docker Compose (Advanced)](#method-2-docker-compose-advanced)
6. [Initial Nextcloud Configuration](#initial-nextcloud-configuration)
7. [External Storage Configuration](#external-storage-configuration)
8. [User Management](#user-management)
9. [Mobile and Desktop Apps](#mobile-and-desktop-apps)
10. [Performance Optimization](#performance-optimization)
11. [Backup and Maintenance](#backup-and-maintenance)
12. [Troubleshooting](#troubleshooting)

---

## Introduction

### What is Nextcloud?
**Nextcloud** is a self-hosted, open-source cloud storage and collaboration platform. Think of it as your own private Dropbox/Google Drive/Microsoft 365.

**Features**:
- 📁 File storage and sync
- 📱 Mobile apps (iOS, Android)
- 🖥️ Desktop sync clients (Windows, Mac, Linux)
- 👥 User and group management
- 📝 Collaborative document editing (Collabora, OnlyOffice)
- 📅 Calendar and contacts
- 💬 Chat and video calls (Nextcloud Talk)
- 🔐 End-to-end encryption
- 🔗 Public file sharing with password protection

### Why on TrueNAS?
- **Unified Storage**: Use your TrueNAS ZFS pool
- **Snapshots**: Automatic backups via ZFS
- **Easy Management**: TrueNAS Apps catalog
- **Resource Efficiency**: Share hardware with NAS functions
- **Data Control**: Your data never leaves your server

---

## Prerequisites

### TrueNAS Requirements
- ✅ TrueNAS SCALE installed (see previous guide)
- ✅ Static IP configured (192.168.1.10)
- ✅ Storage pool created (tank)
- ✅ Internet access working
- ✅ 4GB+ RAM available for Nextcloud
- ✅ 50GB+ storage for Nextcloud data

### Network Requirements
- Static IP for TrueNAS: `192.168.1.10`
- Port 443 (HTTPS) accessible (for external access)
- Domain name (optional, for remote access)

---

## Pre-Installation Planning

### Step 1: Choose Storage Approach

**Two Options Available**:

#### Option A: Automatic (ixVolume) - Recommended for Most Users ⭐

TrueNAS SCALE 24.x+ automatically manages storage:
- **No manual dataset creation needed**
- TrueNAS creates datasets in `.ix-apps` pool automatically
- Snapshots work with your pool's snapshot schedule
- Cleaned up automatically if app is deleted
- Perfect for quick setup

**Skip to Step 2** if using this method!

#### Option B: Manual Datasets (Advanced)

Create dedicated datasets for full control over ZFS properties, quotas, and organization.

**When to use manual datasets**:
- Need custom ZFS properties per dataset
- Want specific record sizes for different data types
- Require per-dataset quotas
- Integration with existing backup workflows
- Prefer explicit control over storage layout

---

### Step 1A: Manual Dataset Creation (Optional - Advanced)

**Only follow this if you chose Option B above**

1. **Navigate**: Storage → Pools → tank → "Add Dataset"

2. **Configure Parent Dataset**:
   ```
   Name: nextcloud
   Dataset Preset: Apps (optimized for containers)
   
   Advanced Options:
   ├─ Record Size: 128K (good for mixed files)
   ├─ Compression: lz4 (enabled)
   └─ Atime: off (performance boost)
   ```

3. **Create Subdatasets** (optional but organized):
   
   **Important**: These are ZFS datasets, NOT network shares (SMB/NFS)
   
   For each subdataset, navigate to Storage → Pools → tank/nextcloud → "Add Dataset":
   
   **Subdataset: config**
   ```
   Name: config
   Dataset Type: Generic (filesystem for storing files)
   
   Purpose: Nextcloud configuration files
   ├─ Stores: config.php, app settings
   ├─ Size: Small (~100MB)
   └─ Share Type: NONE (internal Docker use only)
   
   Settings:
   ├─ Record Size: 128K (default)
   ├─ Compression: lz4
   ├─ Quota: 5 GB (more than enough)
   └─ Atime: off
   ```
   
   **Subdataset: data**
   ```
   Name: data
   Dataset Type: Generic (filesystem for storing files)
   
   Purpose: User files (documents, photos, uploads)
   ├─ Stores: All user-uploaded files
   ├─ Size: Large (grows with usage)
   └─ Share Type: NONE (accessed through Nextcloud only)
   
   Settings:
   ├─ Record Size: 1M (optimized for large files)
   ├─ Compression: lz4
   ├─ Quota: Unlimited (or set based on available space)
   └─ Atime: off
   ```
   
   **Subdataset: database**
   ```
   Name: database
   Dataset Type: Generic (filesystem for storing files)
   
   Purpose: PostgreSQL/MySQL database files
   ├─ Stores: Database tables, indexes
   ├─ Size: Medium (grows with users/files metadata)
   └─ Share Type: NONE (internal Docker use only)
   
   Settings:
   ├─ Record Size: 16K (optimized for databases)
   ├─ Compression: lz4 (or zstd for better ratio)
   ├─ Quota: 50 GB (adjust based on users)
   ├─ Atime: off
   └─ Sync: standard (or always for data safety)
   ```
   
   **Subdataset: html**
   ```
   Name: html
   Dataset Type: Generic (filesystem for storing files)
   
   Purpose: Nextcloud application files (PHP, JS, CSS)
   ├─ Stores: Nextcloud web application code
   ├─ Size: Medium (~5GB)
   └─ Share Type: NONE (internal Docker use only)
   
   Settings:
   ├─ Record Size: 128K (default)
   ├─ Compression: lz4
   ├─ Quota: 20 GB
   └─ Atime: off
   ```
   
   **Final Structure**:
   ```
   tank/nextcloud (parent dataset - Apps preset)
   ├─ config   → /mnt/tank/nextcloud/config   (Generic, 16K blocks)
   ├─ data     → /mnt/tank/nextcloud/data     (Generic, 1M blocks)
   ├─ database → /mnt/tank/nextcloud/database (Generic, 16K blocks)
   └─ html     → /mnt/tank/nextcloud/html     (Generic, 128K blocks)
   ```
   
   ---
   
   ### Understanding Dataset Types
   
   **Generic vs Apps vs SMB**:
   
   | Type | Purpose | When to Use |
   |------|---------|-------------|
   | **Generic** | Standard filesystem for files | Default for most use cases ✓ |
   | **Apps** | Optimized for containerized apps | Parent dataset for Nextcloud ✓ |
   | **SMB** | Pre-configured for Windows shares | Only for SMB/CIFS network shares ❌ |
   
   **Why NOT SMB for Nextcloud datasets?**
   - These datasets are accessed by Docker containers, not network clients
   - SMB adds unnecessary overhead (ACLs, permissions complexity)
   - Nextcloud manages its own file permissions internally
   - Using "Generic" gives you maximum flexibility
   
   **When to use SMB datasets**:
   ```
   ✓ tank/media     → Shared via SMB to Windows/Mac clients
   ✓ tank/documents → Shared via SMB to network users
   ✗ tank/nextcloud → NOT shared, used by Docker internally
   ```
   
   ---

### Step 2: Plan Access Method

**Option A: Local Network Only**
```
Access: http://192.168.1.10:9001
Use: Home network only
Security: Lower priority
```

**Option B: Remote Access via Domain**
```
Access: https://cloud.yourdomain.com
Use: From anywhere (office, travel, mobile)
Requirements:
├─ Domain name (from Cloudflare, Namecheap, etc.)
├─ DDNS or static public IP
├─ Port forwarding on router (443 → TrueNAS)
└─ SSL certificate (Let's Encrypt)
```

### Step 3: Choose Database

| Database | Best For | Resources |
|----------|----------|-----------|
| **SQLite** | Testing, <5 users | Minimal |
| **PostgreSQL** | Production, 5+ users | 512MB RAM |
| **MySQL/MariaDB** | Alternative to PostgreSQL | 512MB RAM |

**Recommendation**: PostgreSQL for production use.

---

## Method 1: TrueNAS Apps (Recommended)

### Step 4: Access TrueNAS Apps

1. **Navigate**: Apps → Available Applications

2. **Search**: "nextcloud"

3. **Click**: "Nextcloud" official app (by TrueCharts or official catalog)

### Step 5: Configure Nextcloud App

Click **"Install"** and configure:

#### Application Settings
```
Application Name: nextcloud
Version: [latest stable - auto-selected]
```

#### Nextcloud Configuration
```
Nextcloud Settings:
├─ Admin Username: admin
├─ Admin Password: [strong password - SAVE THIS!]
├─ Admin Email: admin@yourdomain.com
└─ Nextcloud Host: 192.168.1.10 (your TrueNAS IP)
   (or cloud.yourdomain.com if you have a domain)

Timezone: America/New_York (or your timezone)
```

**Important - Host Field**:
- Enter your TrueNAS IP address (e.g., `192.168.1.10`)
- This sets the trusted domain for Nextcloud
- You can add more domains later in Nextcloud config
- If using remote access, enter your domain name

#### Database Configuration
```
Database Type: PostgreSQL (recommended)

PostgreSQL Settings:
├─ Enable: ✓
├─ Database Name: nextcloud
├─ Database User: nextcloud
├─ Database Password: [auto-generated or custom]
└─ Host: localhost (app manages it)
```

#### Storage Configuration (Modern TrueCharts Version)

**TrueNAS SCALE 24.x+ with TrueCharts uses ixVolume (automatic management)**:

```
Storage Configuration Section:

1. Nextcloud AppData Storage (HTML, Custom Themes, Apps)
   ├─ Type: ixVolume (Dataset created automatically by the system)
   ├─ Enable ACL: ☐ Unchecked (not needed for containers)
   └─ Auto-managed at: /mnt/.ix-apps/[app-name]/app/html

2. Nextcloud User Data Storage
   ├─ Type: ixVolume (Dataset created automatically by the system)
   ├─ Enable ACL: ☐ Unchecked
   └─ Auto-managed at: /mnt/.ix-apps/[app-name]/user-data

3. Nextcloud Postgres Data Storage
   ├─ Type: ixVolume (Dataset created automatically by the system)
   ├─ Enable ACL: ☐ Unchecked
   └─ Auto-managed at: /mnt/.ix-apps/[app-name]/postgres-data
```

**What is ixVolume?**
- TrueNAS automatically creates and manages ZFS datasets
- Stored in special `.ix-apps` dataset on your pool
- No manual dataset creation needed
- Automatic cleanup when app is deleted
- Snapshots work automatically with your pool

**Alternative: Manual Host Path (Advanced Users)**

If you prefer manual control (click dropdown to change from ixVolume):

```
1. Nextcloud AppData Storage:
   ├─ Type: Host Path
   ├─ Host Path: /mnt/tank/nextcloud/html
   └─ Read Only: ☐ Unchecked

2. Nextcloud User Data Storage:
   ├─ Type: Host Path
   ├─ Host Path: /mnt/tank/nextcloud/data
   └─ Read Only: ☐ Unchecked

3. Nextcloud Postgres Data Storage:
   ├─ Type: Host Path
   ├─ Host Path: /mnt/tank/nextcloud/database
   └─ Read Only: ☐ Unchecked
```

**Recommendation**: Use **ixVolume** (default) unless you need:
- Custom dataset layouts
- Specific ZFS properties per dataset
- Integration with existing datasets
- Manual backup workflows

#### Networking Configuration

**Modern TrueCharts versions use simplified networking**:

```
Network Configuration:
├─ Web Port: 10000 (or auto-assigned by TrueNAS)
└─ Access via: http://192.168.1.10:10000

Certificate Configuration:
└─ Add certificate later for HTTPS (optional)
```

**Port Assignment**:
- TrueNAS automatically assigns an available port
- Default range: 9000-9999 or 10000+
- Note the assigned port after installation
- Access: `http://[truenas-ip]:[assigned-port]`

#### Ingress (Optional - Advanced)
```
For domain-based access (e.g., cloud.home.local):
├─ Enable Ingress: ☐ (advanced feature)
├─ Hostname: cloud.home.local
└─ Certificate: Select or create cert
```

#### Resource Limits (Recommended)
```
Resources Section:
├─ Enable Resource Limits: ☑ Checked
├─ CPU Limit: 2000m (2 cores)
├─ Memory Limit: 4Gi (4GB RAM)
└─ GPU: Not required for Nextcloud

Note: Limits prevent Nextcloud from consuming all server resources
```

#### Additional Storage (Optional)

For mounting external TrueNAS shares directly:

```
Additional Storage:
├─ Click "Add" to mount existing datasets
├─ Type: Host Path
├─ Host Path: /mnt/tank/media
├─ Mount Path: /media (inside container)
└─ Read Only: ☐ or ☑ (as needed)
```

### Step 6: Install and Wait

1. **Click**: "Install" (bottom right)

2. **Wait**: 5-15 minutes for:
   - Container images to download
   - Database initialization
   - Nextcloud setup

3. **Monitor**: Apps → Installed Applications
   - Status should change to: **Active** (green)

### Step 7: Access Nextcloud

1. **Find Access URL**:
   
   **Method 1**: Click "Open" button in TrueNAS Apps page
   ```
   Apps → Installed Applications → nextcloud → "Open" button
   ```
   
   **Method 2**: Check assigned port
   ```
   Apps → nextcloud → Click app name → "Application Info"
   Look for: Web Port: [assigned-port]
   Access: http://192.168.1.10:[assigned-port]
   ```
   
   **Typical URLs**:
   ```
   http://192.168.1.10:10000
   or
   http://192.168.1.10:9000
   (port varies based on auto-assignment)
   ```

2. **First Login**:
   ```
   Username: admin
   Password: [password you set during install]
   ```
   
   **If you see "Setup" screen instead**:
   - Some versions require initial setup in web UI
   - Create admin account
   - Select PostgreSQL database
   - Database host: `nextcloud-db:5432`
   - Enter database credentials from install

3. **Welcome Wizard**:
   - Install recommended apps: ✓
   - Click "Install"
   - Wait for apps to install (2-5 minutes)

4. **Initial Warnings** (Normal):
   ```
   You may see warnings about:
   ⚠️  PHP OPcache not configured
   ⚠️  Database missing indexes
   ⚠️  Default phone region not set
   
   Fix these in Step 12 (Initial Configuration)
   ```

**Success!** Nextcloud is now running.

**Troubleshooting Access Issues**:
```
1. Can't connect?
   - Check app status is "Active" (green)
   - Verify firewall isn't blocking port
   - Try from TrueNAS Shell: curl http://localhost:[port]

2. Shows "Access through untrusted domain"?
   - See Step 14 (Configure Trusted Domains)

3. Port not responding?
   - Wait 5 minutes after install completes
   - Containers may still be initializing
   - Check logs: Apps → nextcloud → Logs
```

---

## Method 2: Docker Compose (Advanced)

For users who want more control or need custom configurations.

### Step 8: Enable Docker Compose

1. **Navigate**: System Settings → Advanced → "Init/Shutdown Scripts"

2. **Add Script**: 
   - Type: Command
   - Command: `systemctl enable --now docker`
   - When: Post Init

3. **Or via Shell**:
   ```bash
   systemctl enable --now docker
   docker --version
   ```

### Step 9: Create Docker Compose File

1. **Navigate**: System Settings → Shell

2. **Create directory**:
   ```bash
   mkdir -p /mnt/tank/nextcloud-docker
   cd /mnt/tank/nextcloud-docker
   ```

3. **Create `docker-compose.yml`**:
   ```bash
   nano docker-compose.yml
   ```

4. **Paste configuration**:
   ```yaml
   version: '3.8'

   services:
     nextcloud-db:
       image: postgres:15-alpine
       container_name: nextcloud-db
       restart: always
       environment:
         POSTGRES_DB: nextcloud
         POSTGRES_USER: nextcloud
         POSTGRES_PASSWORD: secure_db_password_here
       volumes:
         - /mnt/tank/nextcloud/database:/var/lib/postgresql/data
       networks:
         - nextcloud-network

     nextcloud-redis:
       image: redis:alpine
       container_name: nextcloud-redis
       restart: always
       networks:
         - nextcloud-network

     nextcloud-app:
       image: nextcloud:latest
       container_name: nextcloud
       restart: always
       ports:
         - "9001:80"
         - "9443:443"
       environment:
         POSTGRES_HOST: nextcloud-db
         POSTGRES_DB: nextcloud
         POSTGRES_USER: nextcloud
         POSTGRES_PASSWORD: secure_db_password_here
         NEXTCLOUD_ADMIN_USER: admin
         NEXTCLOUD_ADMIN_PASSWORD: admin_password_here
         NEXTCLOUD_TRUSTED_DOMAINS: "192.168.1.10 cloud.yourdomain.com"
         REDIS_HOST: nextcloud-redis
         OVERWRITEPROTOCOL: https
         OVERWRITEHOST: cloud.yourdomain.com
       volumes:
         - /mnt/tank/nextcloud/html:/var/www/html
         - /mnt/tank/nextcloud/data:/var/www/html/data
         - /mnt/tank/nextcloud/config:/var/www/html/config
       depends_on:
         - nextcloud-db
         - nextcloud-redis
       networks:
         - nextcloud-network

   networks:
     nextcloud-network:
       driver: bridge

   volumes:
     nextcloud-db:
     nextcloud-html:
     nextcloud-data:
   ```

5. **Save**: Ctrl+O, Enter, Ctrl+X

### Step 10: Deploy with Docker Compose

```bash
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f nextcloud-app

# Access Nextcloud
# URL: http://192.168.1.10:9001
```

---

## Initial Nextcloud Configuration

### Step 11: Complete Setup Wizard

1. **Access Nextcloud**: http://192.168.1.10:9001

2. **Login** with admin credentials

3. **Recommended Apps** (install these):
   ```
   Productivity:
   ├─ Calendar
   ├─ Contacts
   ├─ Tasks
   └─ Notes

   Files:
   ├─ Photos
   ├─ PDF Viewer
   └─ Text Editor

   Collaboration:
   ├─ Talk (chat/video calls)
   └─ Deck (project management)

   Security:
   ├─ Two-Factor Authentication
   └─ Brute-force settings
   ```

4. **Skip** desktop/mobile app setup for now

### Step 12: Configure Basic Settings

1. **Navigate**: Settings (top-right) → Administration → Basic settings

2. **Configure**:
   ```
   Background Jobs:
   └─ Select: Cron (most reliable)
   
   Email Server:
   ├─ Server: smtp.gmail.com:587
   ├─ Security: STARTTLS
   ├─ Username: youremail@gmail.com
   ├─ Password: [App Password]
   └─ From: youremail@gmail.com
   ```

3. **Test Email**: Send test email to verify

### Step 13: Configure Cron (for Background Tasks)

**TrueNAS Apps Method** (automatic):
- Already configured by the app

**Docker Compose Method**:
```bash
# Add cron job for Nextcloud
crontab -e

# Add line:
*/5 * * * * docker exec -u www-data nextcloud php cron.php
```

### Step 14: Configure Trusted Domains

Allows access from multiple URLs.

1. **Navigate**: Settings → Administration → Overview

2. **Check for warnings** - you'll likely see:
   ```
   ⚠️  The "Strict-Transport-Security" HTTP header is not set
   ⚠️  Your web server is not properly set up to resolve "/.well-known/"
   ```

3. **Fix Trusted Domains** (if needed):
   ```bash
   # SSH to TrueNAS, then:
   docker exec -it nextcloud bash
   
   # Edit config
   vi /var/www/html/config/config.php
   
   # Add trusted domains:
   'trusted_domains' =>
   array (
     0 => '192.168.1.10',
     1 => '192.168.1.10:9001',
     2 => 'cloud.yourdomain.com',
     3 => 'truenas.home.local',
   ),
   ```

---

## External Storage Configuration

Mount TrueNAS SMB shares inside Nextcloud for unified access.

### Step 15: Enable External Storage App

1. **Navigate**: Apps → "Disabled apps"

2. **Find**: "External storage support"

3. **Click**: "Enable"

### Step 16: Add External Storage

1. **Navigate**: Settings → Administration → External storage

2. **Add Storage**:
   ```
   Folder Name: Media
   External Storage: SMB/CIFS
   
   Configuration:
   ├─ Host: 192.168.1.10
   ├─ Share: /Media
   ├─ Username: john (TrueNAS user)
   ├─ Password: [user's password]
   └─ Domain: WORKGROUP
   
   Available for: All users (or specific groups)
   ```

3. **Test**: Green checkmark appears if successful

4. **Repeat** for other shares:
   ```
   External Storage:
   ├─ Media      → /mnt/tank/media
   ├─ Documents  → /mnt/tank/documents
   └─ Photos     → /mnt/tank/photos
   ```

**Result**: Users can access NAS storage through Nextcloud web/apps!

---

## User Management

### Step 17: Create Users

1. **Navigate**: Settings → Users

2. **Click**: "+ New user"

3. **Configure**:
   ```
   Username: john
   Display Name: John Doe
   Email: john@example.com
   Password: [set password or let user set on first login]
   
   Groups:
   └─ users (or create custom groups: family, admins, etc.)
   
   Storage Quota: 100 GB (or unlimited)
   ```

4. **Repeat** for family members

### Step 18: Configure Groups

1. **Navigate**: Settings → Users → Groups tab

2. **Create Groups**:
   ```
   Groups:
   ├─ family   - All family members, limited quota
   ├─ admins   - Full access, can manage users
   └─ media    - Access to external media storage
   ```

3. **Assign group permissions**:
   - External storage visibility
   - App access
   - Storage quotas

---

## Mobile and Desktop Apps

### Step 19: Install Mobile Apps

**iOS**:
```
1. App Store → Search "Nextcloud"
2. Install "Nextcloud" by Nextcloud GmbH
3. Open app
4. Server: http://192.168.1.10:9001
5. Login: john / password
6. Enable auto-upload for photos: ✓
```

**Android**:
```
1. Play Store → Search "Nextcloud"
2. Install "Nextcloud" by Nextcloud
3. Open app
4. Server: http://192.168.1.10:9001
5. Login: john / password
6. Enable auto-upload: Settings → Auto upload
```

### Step 20: Install Desktop Sync Client

**Windows/Mac/Linux**:
```
1. Download: https://nextcloud.com/install/#install-clients
2. Install Nextcloud Desktop Client
3. Configure:
   Server: http://192.168.1.10:9001
   Login: john / password
   
4. Choose folders to sync:
   ├─ Sync all files: ~/Nextcloud
   └─ Or selective sync: Choose specific folders
   
5. Start sync
```

**Sync behavior**:
- Two-way sync (like Dropbox)
- Files added locally → uploaded to Nextcloud
- Files added to Nextcloud → downloaded locally

---

## Performance Optimization

### Step 21: Enable Redis Caching

**Already done** if using Docker Compose with Redis.

**For TrueNAS Apps**:
1. Check if Redis is included in app
2. If not, edit Nextcloud config:
   ```bash
   docker exec -it nextcloud bash
   vi /var/www/html/config/config.php
   
   # Add:
   'memcache.local' => '\OC\Memcache\APCu',
   'memcache.distributed' => '\OC\Memcache\Redis',
   'memcache.locking' => '\OC\Memcache\Redis',
   'redis' => [
     'host' => 'nextcloud-redis',
     'port' => 6379,
   ],
   ```

### Step 22: Enable Preview Generation

Pre-generates thumbnails for faster gallery loading.

```bash
# Install preview generator app
docker exec -u www-data nextcloud php occ app:install previewgenerator

# Generate existing previews
docker exec -u www-data nextcloud php occ preview:generate-all

# Add cron job for new files
*/10 * * * * docker exec -u www-data nextcloud php occ preview:pre-generate
```

### Step 23: Configure PHP Memory

1. **Edit PHP settings** (if needed):
   ```bash
   docker exec -it nextcloud bash
   vi /usr/local/etc/php/conf.d/nextcloud.ini
   
   # Add/modify:
   memory_limit = 512M
   upload_max_filesize = 16G
   post_max_size = 16G
   max_execution_time = 3600
   ```

2. **Restart container**:
   ```bash
   docker-compose restart nextcloud-app
   ```

---

## Backup and Maintenance

### Step 24: Automated ZFS Snapshots

Since Nextcloud data is on ZFS dataset, use TrueNAS snapshots:

1. **Navigate**: Data Protection → Periodic Snapshot Tasks → Add

2. **Configure**:
   ```
   Dataset: tank/nextcloud
   Recursive: ✓
   Schedule: Daily at 2:00 AM
   Keep: 30 days
   ```

3. **Repeat** for different frequencies:
   - Hourly: Keep 24 hours
   - Daily: Keep 30 days
   - Weekly: Keep 12 weeks

### Step 25: Backup to External Location

**Option A: Replication to Another TrueNAS**:
```
1. Data Protection → Replication Tasks → Add
2. Source: tank/nextcloud
3. Destination: SSH → remote-truenas:/mnt/backup/nextcloud
4. Schedule: Daily
```

**Option B: Cloud Backup**:
```
1. Data Protection → Cloud Sync Tasks → Add
2. Provider: Backblaze B2, AWS S3, etc.
3. Bucket: nextcloud-backup
4. Transfer Mode: Sync
5. Schedule: Weekly
```

### Step 26: Database Backup

```bash
# Create backup script
nano /mnt/tank/scripts/backup-nextcloud-db.sh

#!/bin/bash
BACKUP_DIR="/mnt/tank/backups/nextcloud"
DATE=$(date +%Y%m%d-%H%M)

mkdir -p $BACKUP_DIR

# Backup PostgreSQL database
docker exec nextcloud-db pg_dump -U nextcloud nextcloud | gzip > \
  $BACKUP_DIR/nextcloud-db-$DATE.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "nextcloud-db-*.sql.gz" -mtime +30 -delete

# Make executable
chmod +x /mnt/tank/scripts/backup-nextcloud-db.sh

# Add to cron (System Settings → Init/Shutdown Scripts)
# Daily at 3:00 AM
```

---

## Troubleshooting

### Issue 1: Can't Access Nextcloud

**Symptoms**: Browser shows "connection refused" or timeout

**Solutions**:
```bash
# Check if container is running
docker ps | grep nextcloud

# Check logs
docker logs nextcloud

# Restart container
docker-compose restart

# Verify port binding
netstat -tulpn | grep 9001
```

### Issue 2: Trusted Domain Error

**Symptoms**: "Access through untrusted domain"

**Solution**:
```bash
docker exec -it nextcloud bash
vi /var/www/html/config/config.php

# Add your IP/domain to trusted_domains array
'trusted_domains' =>
array (
  0 => '192.168.1.10',
  1 => '192.168.1.10:9001',
  2 => 'your-domain.com',
),

# Exit and restart
exit
docker-compose restart nextcloud-app
```

### Issue 3: Slow Upload/Download

**Solutions**:
```
1. Check network speed: iperf3 between client and TrueNAS
2. Increase PHP limits (see Step 23)
3. Enable Redis caching (see Step 21)
4. Check disk performance: iostat -x 1
5. Disable anti-virus scanning on sync folder
6. Use wired connection instead of WiFi
```

### Issue 4: Can't Login After Update

**Symptoms**: "Invalid credentials" after container update

**Solution**:
```bash
# Reset admin password
docker exec -it -u www-data nextcloud php occ user:resetpassword admin

# Or from TrueNAS shell:
docker exec -u www-data nextcloud php occ user:list
```

### Issue 5: Database Errors

**Symptoms**: "Database corruption" or slow queries

**Solution**:
```bash
# Run Nextcloud maintenance
docker exec -u www-data nextcloud php occ maintenance:mode --on
docker exec -u www-data nextcloud php occ db:add-missing-indices
docker exec -u www-data nextcloud php occ db:convert-filecache-bigint
docker exec -u www-data nextcloud php occ maintenance:mode --off

# Optimize database
docker exec nextcloud-db vacuumdb -U nextcloud -d nextcloud -f --analyze
```

---

## Advanced: Remote Access via HTTPS

### Step 27: Setup Domain and SSL

This allows access via https://cloud.yourdomain.com from anywhere.

**Requirements**:
1. Domain name (e.g., from Cloudflare, Namecheap)
2. Public IP address or DDNS
3. Router port forwarding

**Configuration**:
```
1. Domain DNS:
   A Record: cloud.yourdomain.com → [Your Public IP]

2. Router Port Forwarding:
   External Port 443 → TrueNAS IP 192.168.1.10:9443

3. TrueNAS Certificate:
   - System Settings → Certificates → Add
   - Use ACME (Let's Encrypt)
   - Domain: cloud.yourdomain.com

4. Nextcloud Config:
   'overwrite.cli.url' => 'https://cloud.yourdomain.com',
   'overwriteprotocol' => 'https',
```

---

## Summary

You now have:
- ✅ Nextcloud running on TrueNAS
- ✅ Accessible from local network
- ✅ External storage mounted (NAS shares)
- ✅ Mobile and desktop sync configured
- ✅ Automated backups via ZFS snapshots
- ✅ User management set up
- ✅ Performance optimized

**Nextcloud is your private cloud - enjoy complete control over your data!**
