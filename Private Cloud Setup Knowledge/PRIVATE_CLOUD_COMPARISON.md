# Private Cloud Comparison: OpenStack vs. Proxmox vs. MaaS

## Executive Summary
For your specific hardware (mixed desktops, laptops, mini PCs) and requirements (spawning VMs, Postgres, NAS), **Proxmox VE** is the strongest candidate, likely in a "Hybrid" setup with your existing **TrueNAS**.

**OpenStack** is likely too complex and resource-heavy for the maintenance benefit in a home lab. **MaaS** is excellent for bare-metal handling but doesn't solve the "VM Management" requirement on its own.

---

## 1. The Contenders

### A. OpenStack
*   **What it is**: A set of software tools for building and managing cloud computing platforms for public and private clouds.
*   **Best for**: Large data centers, providing AWS-like APIs to users, multi-tenancy (separating users completely).
*   **Your Fit**: **Low**.
    *   *Why?* It requires significant overhead to run the "Control Plane". On your hardware, you'd spend a lot of RAM just keeping OpenStack running. It's harder to manage "pet" VMs (long-running servers like a database).

### B. Proxmox VE (Virtual Environment)
*   **What it is**: A complete open-source platform for enterprise virtualization. It tightly integrates KVM hypervisor and LXC containers, software-defined storage, and networking.
*   **Best for**: Home labs, Small-to-Medium Enterprises (SME), managing VMs and Containers easily via Web UI.
*   **Your Fit**: **High**.
    *   *Why?* It installs on bare metal. It has a fantastic Web UI. It supports Clustering (joining your MiniPCs and Desktops into one "Datacenter"). It supports LXC containers which are perfect for lightweight services.

### C. MaaS (Metal as a Service)
*   **What it is**: Cloud-style provisioning for physical servers. It turns your hardware into a flexible cloud resource.
*   **Best for**: Automating the OS installation of physical servers.
*   **Your Fit**: **Medium (Utility Role)**.
    *   *Why?* MaaS is great to *install* the OS on your laptops/desktops. But once the OS is installed, MaaS is done. It doesn't help you "spawn a new Postgres VM" easily unless you put something like OpenStack or Kubernetes on top of it.

---

## 2. Feature Comparison Matrix

| Feature | OpenStack | Proxmox VE | MaaS |
| :--- | :--- | :--- | :--- |
| **Primary Goal** | Create an AWS-like Cloud | Manage VMs & Containers | Automate Physical OS Install |
| **Ease of Use** | Hard (Steep learning curve) | Easy (Web UI out of the box) | Medium |
| **VM Management** | Excellent (via API/CLI) | Excellent (via UI/API) | None (It manages *Physical* machines) |
| **Hardware Requirements** | High (Dedicated Controller) | Low (Runs on anything) | Low |
| **Clustering** | Complex | Easy (Join Node) | Central Controller |
| **Storage** | Cinder/Swift (Complex) | ZFS/Ceph/LVM (Built-in) | Local Disk |

---

## 3. Recommended Architecture: The "Proxmox Hybrid"

Given your mix of hardware, I recommend a **Proxmox Cluster** alongside your **TrueNAS** server.

### Why this works for you:
1.  **TrueNAS (Desktop 1)**: Keeps doing what it does best—Storage (NAS) and Nextcloud.
2.  **Proxmox (Desktop 2 + Mini PCs)**: This becomes your "Compute Cluster".
    *   You can spawn VMs (Linux, Windows) in seconds.
    *   You can use **LXC Containers** for low-overhead services.
    *   **GPU Passthrough**: You can pass the RTX 3060 in Desktop 2 to a VM for AI/ML, Transcoding, or even a virtualized gaming workstation. For example, you could dedicate the RTX 3060 to a VM running a Plex Media Server to enable hardware-accelerated video transcoding, or to a Linux VM configured for deep learning tasks using TensorFlow or PyTorch. This advanced feature allows a virtual machine to have direct, exclusive access to the physical GPU, bypassing the host operating system's virtualization layer. This results in near-native performance within the VM, full compatibility with GPU drivers, and the ability to utilize the card's full potential for demanding tasks that require dedicated graphics processing.

### Meeting Your Requirements

#### 1. Manage and spawn new servers
*   **Solution**: **Proxmox Templates**.
*   **How**: You create a "Golden Image" of Ubuntu (with your preferred tools). Convert it to a template. Right-click -> Clone to create a new server in 5 seconds.
*   **Replication**: Proxmox supports replication if you use ZFS. You can replicate VMs from Desktop 2 to a Mini PC (storage permitting) for backup.

#### 2. PostgreSQL Service (Redundancy)
*   **Solution**: **VM on Proxmox + Backups to TrueNAS**.
*   **Primary**: Run Postgres in a Linux VM on Desktop 2 (Fast NVMe/SSD).
*   **Backup**: Configure the VM to dump backups via NFS/SMB to your TrueNAS (Desktop 1).
*   **Redundancy**: For high availability, you could run a secondary Postgres replica on one of the Mini PCs.

#### 3. Private Cloud (Nextcloud)
*   **Solution**: Keep on **TrueNAS**.
*   **Status**: Already done. It's stable and has direct access to your storage pool.

#### 4. SMB Service (NAS)
*   **Solution**: Keep on **TrueNAS**.
*   **Status**: Already done.

---

## 4. What about the Laptops?
Laptops are tricky in a cluster because:
1.  **Power**: They go to sleep or run out of battery.
2.  **Network**: Wi-Fi is bad for server clustering.
3.  **Thermals**: Not designed for 24/7 load.

**Recommendation**:
*   Do **NOT** add them to the main HA Cluster (it will cause stability issues).
*   **Use Case**: Use them as "Test Nodes" or "Client Nodes".
*   **Or**: Install **Proxmox** on them as standalone nodes (not clustered), and use them for non-critical experiments.

## 5. Critical Decision: Networking (Ethernet vs. Wi-Fi)

**Short Answer**: You **MUST** use wired Ethernet for your core Cluster (Desktops + Mini PCs). Wi-Fi is **NOT** supported for Proxmox Clustering.

### Why Wi-Fi Fails for Proxmox
1.  **Bridging Issues (The Main Blocker)**:
    *   Proxmox uses a "Network Bridge" (vmbr0) to give VMs their own IP addresses.
    *   Wi-Fi hardware (802.11) strictly enforces that traffic must come from the Wi-Fi card's own MAC address.
    *   When a VM tries to send a packet with its *own* virtual MAC address, the Wi-Fi card drops it.
    *   *Result*: Your VMs will have no network access.
2.  **Cluster Stability**:
    *   Proxmox Cluster (Corosync) requires low-latency (< 2ms) stable connections.
    *   Wi-Fi jitter/latency spikes will cause the cluster to think a node is dead.
    *   *Result*: The cluster will "Fence" (force reboot) your machines randomly.

### The Workaround for Laptops (If you MUST use Wi-Fi)
If you cannot wire the laptops/MacBook:
1.  **Do NOT Cluster them**: Run them as "Standalone" Proxmox nodes.
2.  **Use NAT instead of Bridging**: You will have to configure a complex NAT setup so all VM traffic looks like it comes from the host's IP. This breaks the ability to easily access VMs from other computers.

**Verdict**: Buy a cheap 8-port Gigabit Switch and run cables to the Desktops and Mini PCs. Use USB-Ethernet adapters for the Laptops if you want them in the cluster.

## 6. Power Management: Turning Servers On Remotely

You asked: *"If a machine switches off, can I switch it on via Proxmox?"*

**Yes, but it requires specific setup.** Consumer hardware (like Mini PCs and Gaming Desktops) lacks the dedicated "IPMI" chips found in enterprise servers, so you must use **Wake-on-LAN (WoL)**.

### Method A: Wake-on-LAN (The Standard Way)
*   **How it works**: The network card stays "awake" even when the PC is off. Proxmox sends a "Magic Packet" to wake it up.
*   **Requirement**:
    1.  **Wired Ethernet**: WoL rarely works over Wi-Fi.
    2.  **BIOS Setting**: You must enable "Wake on LAN" or "Power on by PCI-E" in the BIOS of each machine.
*   **In Proxmox**: You can right-click a node in the cluster and select "Wake-on-LAN".

### Method B: The "Smart Plug" Hack (Highly Recommended)
Since consumer PCs can sometimes freeze or fail to wake via WoL:
1.  **BIOS Setting**: Set "Restore on AC Power Loss" to **"Power On"** (Always On).
2.  **Hardware**: Buy a smart plug (e.g., Kasa, Tapo) for each server.
3.  **Workflow**: If a server is stuck or off, toggle the smart plug Off -> On from your phone. The PC will detect power and boot up automatically.

## 7. Implementation Plan (Summary)

1.  **Inventory**: (Done in `INFRASTRUCTURE_INVENTORY.md`)
2.  **Desktop 2**: Install Proxmox VE.
3.  **Mini PCs**: Install Proxmox VE.
4.  **Cluster**: Join Mini PCs to Desktop 2 to form a cluster.
5.  **Storage Mount**: Mount TrueNAS SMB/NFS shares into Proxmox for ISO storage and Backup targets.
6.  **Templates**: Create your standard Ubuntu Cloud-Init template.
