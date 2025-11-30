# OpenStack Home Lab Setup Guide

## 1. Can You Use OpenStack?
**Yes, absolutely.** You can run OpenStack on your mix of hardware (Laptops, MiniPC, Desktops).

However, you must know:
*   **Complexity**: OpenStack is "Data Center" software. It is significantly more complex than Proxmox or simple Docker.
*   **Networking**: **CRITICAL**. OpenStack relies heavily on networking. **You really should use wired Ethernet.** Wi-Fi is extremely difficult to make work with OpenStack's networking component (Neutron) because of how it handles virtual MAC addresses.
*   **Resources**: The "Control Plane" (the brain) eats RAM.

## 2. Hardware Strategy & Recommendations

Given your hardware:
*   **1x MiniPC**
*   **2x Desktops**
*   **Multiple Laptops**

### Recommended Role Assignment

| Node Role | Recommended Hardware | Why? |
| :--- | :--- | :--- |
| **Controller Node** | **MiniPC** | The "Brain" (API, Dashboard, Scheduler). Needs to be always-on, but doesn't need massive CPU. 8GB+ RAM required. |
| **Compute Node 1** | **Desktop 1** | Where your VMs will actually run. Needs CPU cores and RAM. |
| **Compute Node 2** | **Desktop 2** | Additional capacity for VMs. |
| **Storage Node** | **Desktop 1 & 2** | Use the hard drives in your desktops for Block Storage (Cinder). |
| **Compute Node 3+** | **Laptops** | **ONLY IF WIRED.** Laptops can be compute nodes, but they must be plugged into Ethernet. |

> **[!IMPORTANT]**
> Do not try to run OpenStack Compute nodes on Wi-Fi. It will fail because virtual machines need to bridge to the network, and Wi-Fi radios generally reject packets with MAC addresses that don't match their own.

---

## 3. Choose Your Deployment Method

For a home lab, "Manual" installation is too hard. Use a deployment tool.

### Option A: MicroStack (The "Apple" Way)
*   **Best for**: Beginners, quick start.
*   **Pros**: Installs via `snap`. Very easy.
*   **Cons**: Less flexible, multi-node can be tricky in beta versions.
*   **Verdict**: Try this first on a single machine to see if you like OpenStack.

### Option B: Kolla-Ansible (The "Pro" Home Lab Way)
*   **Best for**: Building a real, permanent private cloud.
*   **Pros**: Deploys OpenStack as Docker containers. Easy to upgrade, very stable, industry standard.
*   **Cons**: Requires editing YAML config files.
*   **Verdict**: **Recommended for your multi-node setup.**

---

## 4. Step-by-Step Guide: Building the Cloud (Kolla-Ansible Method)

This guide assumes you are using **Ubuntu 22.04 LTS** on all machines.

### Phase 1: Prerequisite Setup (On All Nodes)

1.  **Install Ubuntu Server** on all machines.
2.  **Network Setup**:
    *   **Management Interface**: The primary IP (e.g., `192.168.1.x`).
    *   **Neutron Interface**: Ideally a second network card. If you only have one, you must use a "VLAN" or a specific configuration.
    *   *Tip*: For a home lab with 1 ethernet port per machine, we will use a "Flat" network on the main interface.
3.  **SSH Keys**: Generate an SSH key on your **Controller (MiniPC)** and copy it to all other nodes (`ssh-copy-id`).
4.  **Install Dependencies** (On Controller):
    ```bash
    sudo apt update
    sudo apt install -y python3-dev libffi-dev gcc libssl-dev python3-venv git
    ```

### Phase 2: Install Kolla-Ansible (On Controller)

1.  **Create a Virtual Environment**:
    ```bash
    python3 -m venv openstack-venv
    source openstack-venv/bin/activate
    ```
2.  **Install Ansible & Kolla**:
    ```bash
    pip install -U pip
    pip install ansible kolla-ansible
    ```
3.  **Copy Configs**:
    ```bash
    sudo mkdir -p /etc/kolla
    sudo chown $USER:$USER /etc/kolla
    cp -r openstack-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
    cp openstack-venv/share/kolla-ansible/ansible/inventory/multinode .
    ```

### Phase 3: Configure Your Cloud

1.  **Edit Inventory (`multinode`)**:
    Define which machine does what.
    ```ini
    [control]
    minipc-ip

    [network]
    minipc-ip

    [compute]
    desktop1-ip
    desktop2-ip
    laptop1-ip

    [monitoring]
    minipc-ip

    [storage]
    desktop1-ip
    desktop2-ip
    ```

2.  **Edit Globals (`/etc/kolla/globals.yml`)**:
    This is the most important file.
    ```yaml
    # Distro
    kolla_base_distro: "ubuntu"
    kolla_install_type: "source"
    openstack_release: "master" # or specific version like "bobcat"

    # Networking (The Tricky Part)
    network_interface: "eth0" # Your management interface
    neutron_external_interface: "eth1" # Your second NIC. If single NIC, requires special setup.
    kolla_internal_vip_address: "192.168.1.200" # A free IP on your network for the API
    
    # Enable Services
    enable_cinder: "yes" # Block storage
    enable_horizon: "yes" # Web UI
    ```

### Phase 4: Deploy

Run these commands from the Controller:

1.  **Bootstrap Servers** (Installs Docker, etc.):
    ```bash
    kolla-ansible -i multinode bootstrap-servers
    ```
2.  **Pre-checks**:
    ```bash
    kolla-ansible -i multinode prechecks
    ```
3.  **Deploy**:
    ```bash
    kolla-ansible -i multinode deploy
    ```

### Phase 5: Use Your Cloud

1.  **Install CLI Client**:
    ```bash
    pip install python-openstackclient
    ```
2.  **Generate Credentials**:
    ```bash
    kolla-ansible post-deploy
    source /etc/kolla/admin-openrc.sh
    ```
3.  **Launch a VM**:
    ```bash
    openstack server create --flavor m1.tiny --image cirros --network demo-net my-first-vm
    ```
4.  **Access Dashboard**:
    Go to `http://192.168.1.200` (your VIP) and log in.

---

## 5. Alternative: The "MaaS + Juju" Way (Canonical Stack)

Since you have looked at **MaaS**, you can use the official Ubuntu stack.
1.  **MaaS**: Provisions the bare metal (installs Ubuntu).
2.  **Juju**: The "Service Orchestrator". You tell Juju "Deploy OpenStack", and it talks to MaaS to get machines.
3.  **OpenStack**: Runs on top.

**Pros**: Extremely powerful, "Model Driven".
**Cons**: Juju is complex and resource-heavy. It might be overkill for a home lab unless you want to learn "The Canonical Way".

## Summary Recommendation

1.  **Start Small**: Install **MicroStack** on one Desktop just to play with the UI and CLI.
    ```bash
    sudo snap install microstack --beta
    sudo microstack.init --auto
    ```
2.  **Go Big**: Once you understand the components (Nova, Neutron, Keystone), wipe the machines and set up **Kolla-Ansible** using the MiniPC as the controller and Desktops as compute nodes.
