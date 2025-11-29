# Exposing Nextcloud via Public Domain on TrueNAS SCALE

## Overview

This guide walks you through setting up a public domain (e.g., `cloud.sandeepknayak.com`) to access your Nextcloud instance running on TrueNAS SCALE using Cloudflare Tunnel. This method is secure and doesn't require opening ports on your router.

## Prerequisites

- ✅ TrueNAS SCALE with Nextcloud installed and running
- ✅ Cloudflare account (free tier works)
- ✅ Domain name managed by Cloudflare
- ✅ Nextcloud accessible locally (e.g., `https://192.168.3.138:30027`)

---

## Part 1: Create Cloudflare Tunnel

### Step 1: Access Cloudflare Zero Trust Dashboard

1. Log in to your [Cloudflare account](https://dash.cloudflare.com)
2. Navigate to **Zero Trust** (from the left sidebar)
3. Go to **Networks** → **Tunnels**

### Step 2: Create a New Tunnel

1. Click **Create a tunnel**
2. Select **Cloudflared** as the connector type
3. Give your tunnel a name (e.g., `truenas-tunnel`)
4. Click **Save tunnel**

### Step 3: Copy the Tunnel Token

After creating the tunnel, Cloudflare will show installation instructions with a command like:

```bash
cloudflared service install eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwIiwidCI6IjEyMzQ1Njc4LWFiY2QtZWZnaC1pamt...
```

**Copy the long string after `service install`** - this is your **Tunnel Token**. You'll need it in the next section.

> [!IMPORTANT]
> Keep this token secure! It's like a password for your tunnel.

---

## Part 2: Install Cloudflared on TrueNAS

### Step 4: Install the Cloudflared App

1. In TrueNAS web UI, go to **Apps** → **Discover Apps**
2. Search for **"cloudflared"**
3. Click **Install** on the Cloudflared app
4. Configure the app:
   - **Application Name**: `cloudflared` (default)
   - **Tunnel Token**: Paste the token you copied from Cloudflare
   - **Network Configuration**: Leave defaults (Port: 8053, Port Bind Mode: None)
5. Click **Save**

### Step 5: Verify Tunnel Connection

1. Wait for the app to start (status should show **Running**)
2. Go back to the Cloudflare Zero Trust dashboard
3. Navigate to **Networks** → **Tunnels**
4. Your tunnel should now show status: **Healthy** or **Connected**

> [!TIP]
> If the tunnel shows as "Down", check the cloudflared app logs in TrueNAS (Apps → cloudflared → Logs)

---

## Part 3: Configure Public Hostname

### Step 6: Add Public Hostname in Cloudflare

1. In Cloudflare Zero Trust, go to your tunnel
2. Click **Configure** → **Public Hostname** tab (or **Published application routes**)
3. Click **Add a public hostname**
4. Configure the hostname:
   - **Subdomain**: `cloud` (or your preferred subdomain)
   - **Domain**: Select your domain (e.g., `sandeepknayak.com`)
   - **Path**: Leave empty
   - **Service Type**: `HTTPS`
   - **URL**: `192.168.3.138:30027` (your Nextcloud local IP and port)

### Step 7: Configure TLS Settings

> [!WARNING]
> This step is critical! Without it, you'll get SSL errors.

1. Scroll down to **Additional application settings**
2. Click **TLS** from the dropdown
3. Enable **No TLS Verify**
   - This is required because Nextcloud uses a self-signed certificate internally
4. Click **Save hostname**

Your configuration should look like:
```
Public hostname: cloud.sandeepknayak.com
Service: https://192.168.3.138:30027
TLS: No TLS Verify ✓
```

---

## Part 4: Configure Nextcloud Trusted Domains

Nextcloud has a security feature that only allows access from pre-approved domains. You need to add your new public domain to the trusted list.

### Step 8: Access TrueNAS Shell

1. In TrueNAS web UI, go to **System** → **Shell**

### Step 9: Find Nextcloud Container

Run this command to list all Nextcloud containers:

```bash
docker ps | grep nextcloud
```

You'll see output like:
```
13a8c89317bf   ix-nextcloud:32.0.2...   Up 31 minutes   ix-nextcloud-nextcloud-1
```

The container name is **`ix-nextcloud-nextcloud-1`** (or use the ID `13a8c89317bf`).

### Step 10: Enter the Nextcloud Container

```bash
docker exec -it ix-nextcloud-nextcloud-1 bash
```

You should now see a different prompt like `root@13a8c89317bf:/#`

### Step 11: Install Text Editor (if needed)

```bash
apt-get update && apt-get install -y nano
```

### Step 12: Edit Nextcloud Configuration

```bash
nano config/config.php
```

### Step 13: Add Trusted Domain

Find the `trusted_domains` section (usually near the top):

```php
'trusted_domains' =>
array (
  0 => '192.168.3.138',
),
```

Add your public domain as a new entry:

```php
'trusted_domains' =>
array (
  0 => '192.168.3.138',
  1 => 'cloud.sandeepknayak.com',
),
```

> [!NOTE]
> - Each domain must be on a separate line with a unique index (0, 1, 2, etc.)
> - Don't forget the comma after each entry except the last one
> - Include only the domain name, no `https://` or port numbers

### Step 14: Save and Exit

1. Press **Ctrl + O** to save
2. Press **Enter** to confirm
3. Press **Ctrl + X** to exit nano
4. Type `exit` to leave the container

---

## Part 5: Test Your Setup

### Step 15: Access Nextcloud via Public Domain

1. Open a web browser
2. Navigate to `https://cloud.sandeepknayak.com`
3. You should see the Nextcloud login page

> [!TIP]
> The first load might take 10-20 seconds as Cloudflare establishes the connection.

### Step 16: Verify SSL Certificate

1. Click the padlock icon in your browser's address bar
2. You should see a valid SSL certificate issued by Cloudflare
3. The connection should show as "Secure"

---

## Part 6: Exposing Multiple Services (Advanced)

### Using One Tunnel for Multiple Subdomains

The beauty of Cloudflare Tunnel is that **one tunnel can handle multiple services**. You don't need to create a new tunnel for each subdomain - just add more public hostnames!

### Example: Expose TrueNAS Web UI

Let's add `truenas.sandeepknayak.com` to access your TrueNAS management interface.

#### Step 17: Add TrueNAS Public Hostname

1. In Cloudflare Zero Trust, go to your existing tunnel
2. Click **Configure** → **Public Hostname** tab
3. Click **Add a public hostname**
4. Configure:
   - **Subdomain**: `truenas`
   - **Domain**: `sandeepknayak.com`
   - **Path**: Leave empty
   - **Service Type**: `HTTPS`
   - **URL**: `192.168.3.138:443` (TrueNAS default HTTPS port)
5. **Additional settings** → **TLS** → Enable **No TLS Verify**
6. Click **Save hostname**

#### Step 18: Verify TrueNAS Port

TrueNAS typically runs on:
- **HTTPS**: Port `443` (default)
- **HTTP**: Port `80` (if HTTPS disabled)

To verify your TrueNAS port:
1. Check how you currently access it locally
2. If you use `https://192.168.3.138`, it's port `443`
3. If you use `http://192.168.3.138`, it's port `80`

#### Step 19: Test Access

Navigate to `https://truenas.sandeepknayak.com` - you should see your TrueNAS login page!

### Your Complete Setup

After adding both services, your tunnel configuration looks like:

```
Cloudflare Tunnel: "truenas-tunnel"
│
├─ Public Hostname 1: cloud.sandeepknayak.com
│  └─ Service: https://192.168.3.138:30027 (Nextcloud)
│
└─ Public Hostname 2: truenas.sandeepknayak.com
   └─ Service: https://192.168.3.138:443 (TrueNAS Web UI)
```

### Common TrueNAS Services You Can Expose

| Service | Default Port | Subdomain Example | Service Type |
|---------|--------------|-------------------|--------------|
| **TrueNAS Web UI** | 443 (HTTPS) | `truenas.yourdomain.com` | HTTPS |
| **Nextcloud** | 30027 (varies) | `cloud.yourdomain.com` | HTTPS |
| **Plex** | 32400 | `plex.yourdomain.com` | HTTPS |
| **Jellyfin** | 8096 | `jellyfin.yourdomain.com` | HTTP |
| **Home Assistant** | 8123 | `home.yourdomain.com` | HTTP |
| **Portainer** | 9443 | `portainer.yourdomain.com` | HTTPS |

### Best Practices for Multiple Services

1. **Use Descriptive Subdomains**: 
   - ✅ `cloud.yourdomain.com`, `truenas.yourdomain.com`
   - ❌ `app1.yourdomain.com`, `service2.yourdomain.com`

2. **Enable "No TLS Verify" for Self-Signed Certs**:
   - Most TrueNAS apps use self-signed certificates
   - Always enable this option to avoid SSL errors

3. **Document Your Ports**:
   - Keep a list of which service uses which port
   - Example:
     ```
     30027 → Nextcloud
     443   → TrueNAS Web UI
     32400 → Plex
     ```

4. **Use Cloudflare Access Policies**:
   - Add authentication for sensitive services (TrueNAS UI)
   - Keep public services (like Nextcloud) accessible

### When to Create a Separate Tunnel

You only need multiple tunnels if:
- ❌ You have services on different physical servers
- ❌ You have services on different networks/locations
- ❌ You need organizational separation (work vs personal)

For everything on **one TrueNAS server**, **one tunnel is perfect**!

---

## Troubleshooting

### Issue: "Access through untrusted domain" Error

**Cause**: The domain is not in Nextcloud's `trusted_domains` list.

**Solution**: 
1. Repeat Steps 9-14 to add the domain
2. Make sure there are no typos in the domain name
3. Restart Nextcloud container if needed:
   ```bash
   docker restart ix-nextcloud-nextcloud-1
   ```

### Issue: Tunnel Shows "Down" in Cloudflare

**Cause**: Cloudflared app is not running or token is incorrect.

**Solution**:
1. Check cloudflared app status in TrueNAS (Apps → cloudflared)
2. If stopped, click the Play button to start it
3. Check logs for errors (Apps → cloudflared → Logs)
4. Verify the tunnel token is correct (Edit app → check Tunnel Token field)

### Issue: "502 Bad Gateway" Error

**Cause**: Cloudflare can't reach your Nextcloud instance.

**Solution**:
1. Verify Nextcloud is running: `docker ps | grep nextcloud`
2. Check the IP and port in Cloudflare tunnel settings
3. Ensure "No TLS Verify" is enabled in Cloudflare tunnel TLS settings
4. Test local access: `curl -k https://192.168.3.138:30027`

### Issue: "SSL Handshake Failed"

**Cause**: TLS verification is enabled in Cloudflare tunnel.

**Solution**:
1. Go to Cloudflare tunnel → Public Hostname → Edit
2. Under Additional settings → TLS
3. Enable **No TLS Verify**
4. Save changes

### Issue: Can't Find `docker` Command

**Cause**: You're on an older TrueNAS version using Kubernetes (k3s).

**Solution**:
Use these commands instead:
```bash
# Find pod name
sudo k3s kubectl get pods -A | grep nextcloud

# Enter pod (replace pod-name and namespace)
sudo k3s kubectl exec -it -n ix-nextcloud [pod-name] -- bash
```

---

## Security Considerations

### Enable Cloudflare Access Policies (Optional)

For additional security, you can restrict who can access your Nextcloud:

1. In Cloudflare Zero Trust, go to **Access** → **Applications**
2. Click **Add an application**
3. Select **Self-hosted**
4. Configure:
   - **Application name**: Nextcloud
   - **Session duration**: 24 hours (or your preference)
   - **Application domain**: `cloud.sandeepknayak.com`
5. Add policies:
   - **Allow**: Emails ending in `@yourdomain.com`
   - Or use **One-time PIN** for email-based authentication

### Enable Two-Factor Authentication in Nextcloud

1. Log in to Nextcloud as admin
2. Go to **Settings** → **Security**
3. Enable **Two-Factor TOTP Provider**
4. Install an authenticator app (Google Authenticator, Authy, etc.)
5. Scan the QR code and save backup codes

---

## Summary

You've successfully set up:
- ✅ Cloudflare Tunnel for secure external access
- ✅ Cloudflared app running on TrueNAS
- ✅ Public hostname pointing to Nextcloud
- ✅ Nextcloud configured to accept the public domain
- ✅ SSL encryption via Cloudflare

Your Nextcloud is now accessible from anywhere at `https://cloud.sandeepknayak.com` without opening any ports on your router!

---

## Quick Reference Commands

### TrueNAS SCALE (Electric Eel / Docker-based)

```bash
# List Nextcloud containers
docker ps | grep nextcloud

# Enter Nextcloud container
docker exec -it ix-nextcloud-nextcloud-1 bash

# Edit config inside container
nano config/config.php

# Restart Nextcloud container
docker restart ix-nextcloud-nextcloud-1

# View container logs
docker logs ix-nextcloud-nextcloud-1
```

### TrueNAS SCALE (Older versions with k3s)

```bash
# List Nextcloud pods
sudo k3s kubectl get pods -A | grep nextcloud

# Enter Nextcloud pod
sudo k3s kubectl exec -it -n ix-nextcloud [pod-name] -- bash

# Edit config inside pod
nano config/config.php
```

---

## Additional Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Nextcloud Trusted Domains](https://docs.nextcloud.com/server/latest/admin_manual/installation/installation_wizard.html#trusted-domains)
- [TrueNAS SCALE Apps Documentation](https://www.truenas.com/docs/scale/scaletutorials/apps/)
