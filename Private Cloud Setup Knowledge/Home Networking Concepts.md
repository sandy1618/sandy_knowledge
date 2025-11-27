# Home Networking Concepts

This document covers common home networking questions regarding router setups, performance, and IP addressing.

---

## Can a Second Router Offload Processing?

### Short Answer: **No**

A home router's primary function is to *route traffic* between your local network and the internet, not to perform heavy computational processing. Adding a second router will **not** offload processing from the first one.

### What Processing Does a Router Do?

Modern home routers handle:
- **Routing**: Directing traffic between LAN and WAN (internet)
- **NAT (Network Address Translation)**: Mapping private IPs to public IP
- **DHCP**: Assigning IP addresses to devices
- **Firewall**: Blocking unauthorized connections
- **Wi-Fi Radio**: Broadcasting 2.4GHz and 5GHz signals
- **QoS (Quality of Service)**: Prioritizing certain traffic (gaming, video)

**Key Point**: For home networks with 10-50 devices, even basic routers have plenty of processing power. The bottleneck is usually your **internet speed** or **Wi-Fi coverage**, not router CPU.

### What Does Adding a Second Router Actually Do?

Instead of offloading processing, adding a second router typically achieves one of two outcomes:

#### Scenario 1: Creates a Separate Network (Double NAT)
**Default behavior when connecting router to router:**

```
Internet → Modem → Router 1 (192.168.1.x) → Router 2 (192.168.2.x)
                       ↓                           ↓
                   Devices A                   Devices B
                   (can't talk to Devices B)
```

**Problems with this setup:**
- ❌ Devices on Router 1 can't see devices on Router 2
- ❌ Double NAT causes issues with gaming, VoIP, port forwarding
- ❌ More complex troubleshooting
- ❌ No processing benefit

**When this is useful:**
- Creating an isolated guest network
- Separating IoT devices from main network for security

#### Scenario 2: Extends Wi-Fi Coverage (Access Point Mode)
**The correct way to add a second router:**

```
Internet → Modem → Router 1 (192.168.1.x)
                       ↓
                   Switch/Cable
                       ↓
                   Router 2 in AP Mode (same 192.168.1.x network)
                       ↓
                   All devices on same network
```

**How to configure:**
1. Disable DHCP on Router 2
2. Set Router 2 to "Access Point Mode" or "Bridge Mode"
3. Give Router 2 a static IP on Router 1's network (e.g., 192.168.1.2)
4. Connect Router 2's LAN port (not WAN) to Router 1

**Benefits:**
- ✅ Extended Wi-Fi coverage
- ✅ Same network - all devices can communicate
- ✅ Reduced Wi-Fi congestion (devices connect to nearest router)
- ✅ One DHCP server = simpler management

**Still no processing offload**: Router 1 still handles all routing, NAT, and DHCP.

### Better Alternatives

**For Wi-Fi Coverage:**
- **Mesh Wi-Fi System** (Google Nest, Eero, TP-Link Deco)
  - Seamless roaming between nodes
  - Single network name (SSID)
  - Self-optimizing channels
  
**For Processing Power:**
- **Upgrade to better router** with:
  - Faster CPU (quad-core 1.5GHz+)
  - More RAM (512MB+)
  - Better QoS features
  - Wi-Fi 6/6E support

**For Network Segmentation:**
- **VLAN-capable router or switch**
  - Separate networks without multiple routers
  - Enterprise-grade isolation
  - Better performance

---

## What is Assigning a Static IP via MAC Address Called?

### The Term: **DHCP Reservation** (also called Static DHCP Assignment)

This is different from a true "Static IP" - let me explain both:

### DHCP Reservation vs Static IP

| Feature | DHCP Reservation | True Static IP |
|---------|-----------------|----------------|
| **Configuration Location** | Router only | Device itself |
| **How it works** | Router assigns same IP automatically | Device claims IP without asking |
| **Easier to manage** | ✅ Yes - change in one place | ❌ No - must configure each device |
| **IP conflicts** | ✅ Router prevents conflicts | ⚠️ Can happen if misconfigured |
| **Best for** | Most home devices, servers | Routers, printers, special cases |

### How DHCP Works (Without Reservation)

```
Device boots up
    ↓
Device: "Hey router, I need an IP address!" (DHCP Request)
    ↓
Router: "Here, take 192.168.1.157" (assigns random available IP)
    ↓
Device uses 192.168.1.157
    ↓
IP lease expires (24 hours typical)
    ↓
Device might get different IP next time (192.168.1.203)
```

**Problem**: If you have a server at 192.168.1.157, and tomorrow it becomes 192.168.1.203, any bookmarks or port forwarding rules break.

### How DHCP Reservation Works

**Setup Process:**
1. Find device's **MAC Address** (e.g., `AA:BB:CC:DD:EE:FF`)
2. Log into router's admin panel
3. Go to DHCP Settings → Reservations/Static Assignments
4. Create rule: `AA:BB:CC:DD:EE:FF` → `192.168.1.10`
5. Save and reboot device

**What happens:**
```
Device boots up (MAC: AA:BB:CC:DD:EE:FF)
    ↓
Device: "Hey router, I need an IP!"
    ↓
Router checks MAC address: "Oh, this is AA:BB:CC:DD:EE:FF"
    ↓
Router: "You always get 192.168.1.10" (same IP every time)
    ↓
Device uses 192.168.1.10 permanently
```

### Key Components Explained

**MAC Address (Media Access Control Address)**
- Unique identifier burned into network hardware
- Format: `12:34:56:78:9A:BC` (6 pairs of hex digits)
- Never changes (hardware-level ID)
- How to find:
  - **Windows**: `ipconfig /all` → look for "Physical Address"
  - **Mac**: `ifconfig` or System Preferences → Network → Advanced
  - **Linux**: `ip link show` or `ifconfig`
  - **Router**: Look in connected devices list

**DHCP (Dynamic Host Configuration Protocol)**
- Service running on router
- Automatically assigns IPs to devices
- Manages IP pool (e.g., 192.168.1.100 - 192.168.1.254)
- Prevents IP conflicts
- Also provides: gateway address, DNS servers, subnet mask

### Practical Example: Setting Up TrueNAS with DHCP Reservation

**Scenario**: You want your TrueNAS server always at 192.168.1.10

**Option 1: DHCP Reservation (Recommended)**
```
1. Install TrueNAS, let it get DHCP (192.168.1.157)
2. Note MAC address: 00:11:22:33:44:55
3. Router settings:
   - Reserve 192.168.1.10 for MAC 00:11:22:33:44:55
4. Reboot TrueNAS
5. Now always gets 192.168.1.10
```

**Benefits:**
- ✅ Easy to change IP later (just edit router)
- ✅ No IP conflicts
- ✅ If you replace TrueNAS, just update MAC in router

**Option 2: Static IP on TrueNAS (Also valid)**
```
1. TrueNAS Network Settings:
   - IP: 192.168.1.10
   - Subnet: 255.255.255.0
   - Gateway: 192.168.1.1 (router)
   - DNS: 8.8.8.8, 1.1.1.1
2. Save and apply
```

**When to use:**
- Devices that need IP before router boots (rare)
- Enterprise environments with strict policies
- Devices without DHCP client

### Common Router Terms for This Feature

Different brands call it different things:
- **DHCP Reservation** ← Most common
- Static DHCP Assignment
- Address Reservation
- IP Binding
- Static Lease
- Manual Assignment

**Where to find it:**
- TP-Link: Advanced → DHCP Server → Address Reservation
- Netgear: Advanced → LAN Setup → Address Reservation
- Asus: LAN → DHCP Server → Manually Assigned IP
- Linksys: Connectivity → Local Network → DHCP Reservations
- UniFi: Settings → Networks → DHCP → Static DHCP

---

## Stability with a Second Router: The Failover Question

### The Scenario

You have two routers with DHCP reservations and wonder: "If Router 1 dies, will my devices stay stable because Router 2 has their reserved IPs?"

**The answer depends on your network topology.**

---

### Setup 1: Sequential (Router Behind Router) - COMMON

```
Internet → Modem → Router 1 (Primary) → Router 2 (Secondary)
                        ↓                        ↓
                   Some Devices            Your Critical Devices
                                          (DHCP Reservations)
```

**Router 1 Configuration:**
- Connected to modem
- DHCP enabled: 192.168.1.x network
- Gateway to internet

**Router 2 Configuration:**
- Connected to Router 1's LAN port
- DHCP enabled: 192.168.2.x network (different subnet)
- Has DHCP reservations for your TrueNAS, servers, etc.

#### What Happens if Router 1 is Removed?

| Component | Status | Explanation |
|-----------|--------|-------------|
| **Internet** | ❌ DOWN | No connection to modem |
| **Router 2's local network** | ✅ UP | Still functioning internally |
| **DHCP reservations on Router 2** | ✅ WORKING | Devices keep their IPs |
| **Devices on Router 2 talking to each other** | ✅ WORKING | Local network intact (e.g., TrueNAS ↔ Computer) |
| **Access to internet** | ❌ DOWN | No gateway |
| **Access to Router 1's devices** | ❌ DOWN | Different network, now unreachable |

**Real-World Example:**
```
Your TrueNAS (192.168.2.10) ← Reserved on Router 2
Your Computer (192.168.2.50) ← Reserved on Router 2

Router 1 fails:
✅ Computer can still access TrueNAS at 192.168.2.10 (local connection works)
❌ TrueNAS can't download updates (no internet)
❌ You can't remote access from outside (no WAN)
❌ Computer can't browse web (no gateway to internet)
```

**To Restore Internet:**
1. Disconnect Router 2 from Router 1
2. Connect Router 2's WAN port directly to modem
3. Reboot modem and Router 2
4. Router 2 becomes primary router
5. Internet restored for all devices on Router 2
6. (But devices that were on Router 1 are now orphaned)

---

### Setup 2: Parallel (Both on Same Network) - PROPER REDUNDANCY

```
Internet → Modem → Switch → Router 1 (192.168.1.1)
                      ↓
                  Router 2 (192.168.1.2, DHCP disabled)
                      ↓
                  All Devices (192.168.1.x)
```

**Router 1 Configuration:**
- DHCP enabled (handles IP assignments)
- Acts as gateway (192.168.1.1)

**Router 2 Configuration:**
- DHCP **disabled** (Router 1 handles it)
- Acts as Access Point only
- Static IP: 192.168.1.2

#### What Happens if Router 1 is Removed?

| Component | Status | Explanation |
|-----------|--------|-------------|
| **Internet** | ❌ DOWN | No gateway (unless Router 2 promoted) |
| **Local network** | ⚠️ PARTIALLY UP | Existing connections work |
| **Existing DHCP leases** | ✅ OK | Devices keep IPs temporarily |
| **New DHCP requests** | ❌ FAIL | No DHCP server running |
| **Static IPs / DHCP reservations** | ⚠️ STALE | Last assigned IPs work until lease expires |

**Problem**: Router 2 has no DHCP server, so:
- Devices that reboot lose their IP
- New devices can't join network
- After lease expires (24h typical), devices lose connectivity

**To Make This Redundant:**
1. Enable DHCP on Router 2 (but use different IP range)
2. Router 1: assign 192.168.1.100 - 192.168.1.199
3. Router 2: assign 192.168.1.200 - 192.168.1.254
4. Both active simultaneously (not recommended - can cause conflicts)

**OR use proper failover solution** (see below)

---

### Setup 3: True Failover (Enterprise Solution)

For automatic failover, you need:

**Option A: Router with HA (High Availability)**
- Enterprise routers (Ubiquiti EdgeRouter, pfSense)
- Two routers configured as HA pair
- Shared virtual IP (192.168.1.1)
- If primary fails, secondary takes over automatically

**Option B: Dual WAN Router**
```
Internet (ISP 1) ↘
                  → Dual WAN Router → Your Network
Internet (ISP 2) ↗
```
- One router with two internet connections
- Automatic failover if one ISP dies
- Devices unaffected (same router, same IPs)

**Option C: Managed Switch with Redundancy**
- Layer 3 switch handles routing
- Multiple routers as redundant gateways
- VRRP or HSRP protocols for failover

---

### The Key Insight: DHCP Reservations ≠ Device Stability

**What DHCP Reservations Actually Do:**
- Guarantee same IP from *that specific DHCP server*
- Have no effect if DHCP server is offline
- Don't provide failover or redundancy

**What You Actually Need for Stability:**

| Goal | Solution |
|------|----------|
| Devices keep working locally if router dies | Static IPs on devices (not DHCP) |
| Automatic internet failover | Dual WAN router or HA pair |
| Simple backup internet | Manually swap Router 2 to modem (5 min downtime) |
| Distributed Wi-Fi coverage | Mesh system or AP mode (not second router) |

---

### Practical Recommendations for Your Home Lab

**For TrueNAS and Critical Servers:**

**Option 1: DHCP Reservation (Simplest)**
```
Router: DHCP reservation
TrueNAS: Leave on DHCP
Result: TrueNAS always gets 192.168.1.10
Backup: If router dies, set TrueNAS to static 192.168.1.10 manually
```

**Option 2: Static IP on Device (Most Reliable)**
```
Router: Nothing needed
TrueNAS: Configure static 192.168.1.10
Result: Works even if router DHCP fails
Backup: Plug router directly to modem if primary fails
```

**For Internet Redundancy:**
- Use cellular hotspot as backup (manual failover)
- Invest in dual WAN router (~$100-300)
- Get second ISP for critical uptime

**For Wi-Fi Coverage:**
- Use second router in AP Mode (not separate network)
- Or upgrade to mesh system (Eero, Google Nest)

---

### Quick Decision Tree

```
Do you need devices to talk locally even if internet dies?
├─ YES → Use Static IPs on devices
│         (or DHCP reservations, but understand they fail with router)
└─ NO → Regular DHCP is fine

Do you need automatic internet failover?
├─ YES → Invest in dual WAN router or enterprise setup
└─ NO → Manual swap to backup router is acceptable

Do you need better Wi-Fi coverage?
├─ YES → Second router in AP Mode OR mesh system
└─ NO → One router is sufficient
```

---

### Summary: Your Original Questions Answered

**Q: Will second router offload processing?**
**A:** No. Routers don't "offload" to each other. Use AP Mode for Wi-Fi coverage, not processing.

**Q: What's the term for static IP by MAC?**
**A:** DHCP Reservation (or Static DHCP Assignment). Different from true static IP.

**Q: If Router 1 dies, will Router 2's DHCP reservations keep system stable?**
**A:** 
- ✅ Local network on Router 2 stays up
- ✅ Reserved IPs still work on Router 2's network
- ❌ No internet until Router 2 connected to modem
- ❌ Devices on Router 1's network become unreachable

**Better approach:** Configure Router 2 in AP Mode (same network), use DHCP reservations on Router 1, and have a plan to swap Router 2 to modem if needed (5 minute manual process).
