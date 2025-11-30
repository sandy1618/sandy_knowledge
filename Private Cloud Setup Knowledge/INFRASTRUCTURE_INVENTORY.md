# Infrastructure Inventory

## Hardware Assets

### Desktops (Compute & Storage Powerhouses)
1.  **Desktop 1 (The "NAS" Node)**
    *   **RAM**: 32 GB
    *   **OS**: TrueNAS Scale
    *   **Current Workload**:
        *   Nextcloud (Private Cloud)
        *   SMB Service (NAS)
    *   **Role**: Storage, Backups, Lightweight Apps.

2.  **Desktop 2 (The "Compute/AI" Node)**
    *   **RAM**: 64 GB
    *   **GPU**: NVIDIA RTX 3060 (12 GB VRAM)
    *   **Role Potential**: AI/ML workloads, Heavy Virtualization, Database Host.

### Compact Compute
3.  **Mini PC 1**
    *   **Role Potential**: Cluster Controller, Always-on Service Node (DNS, Routing).
4.  **Mini PC 2**
    *   **Role Potential**: Cluster node, HA pair for Mini PC 1.

### Portable/Legacy
5.  **MacBook Pro 2016**
    *   **Role**: Management Console, or lightweight compute node (if running Linux).
6.  **Laptop 1**
    *   **Role**: Auxiliary Compute (Best if wired via Ethernet).
7.  **Laptop 2**
    *   **Role**: Auxiliary Compute (Best if wired via Ethernet).

---

## Current Software Services
*   **Storage**: TrueNAS Scale (ZFS)
*   **Cloud File Sync**: Nextcloud
*   **Networking**: SMB (Internal File Sharing)

## Requirements Checklist
- [ ] **VM/Image Management**: Ability to spawn new servers/images easily.
- [ ] **Database**: PostgreSQL with redundancy/backups.
- [ ] **Private Cloud**: Nextcloud (Already met, but needs integration).
- [ ] **NAS**: SMB (Already met).
