# Bare Metal Provisioning: From USB to Network Boot

You asked two very advanced questions about controlling bare metal infrastructure.

## 1. Creating a Custom ISO (The "USB Method")
**Goal**: Create a custom Ubuntu ISO on your laptop that has Docker/Terraform pre-installed, burn it to USB, and install it on your server.

**Tool: Cubic (Custom Ubuntu ISO Creator)**
1.  **Install Cubic** on your local Linux machine (or VM).
2.  **Load Base ISO**: Load the standard Ubuntu Server ISO.
3.  **Chroot Environment**: Cubic opens a terminal *inside* the ISO.
    *   Run `apt install docker.io terraform`.
    *   Copy your `setup_server.sh`.
    *   Configure `autoinstall` (user-data) to auto-partition the disk and set the password.
4.  **Generate**: Cubic spits out a `custom-ubuntu.iso`.
5.  **Burn & Boot**: Flash to USB, plug into server, boot. It installs your custom OS.

---

## 2. Controlling Bare Metal Remotely (The "Data Center Method")
**Goal**: You have 5 servers with fixed IPs connected to a router. You want to install/reinstall OS on them *without* touching them (no USB).

**The Solution: PXE Boot (Preboot eXecution Environment)**
This is how data centers do it.

### How it works
1.  **The Setup**:
    *   You run a **PXE Server** (TFTP + DHCP) on your network (e.g., on a Raspberry Pi or your laptop).
2.  **The Boot**:
    *   You turn on the bare metal server.
    *   BIOS checks Network Boot.
    *   It finds your PXE Server.
    *   It downloads a tiny OS kernel over the network.
3.  **The Install**:
    *   The kernel boots and runs an **Auto-Installer** (using a `user-data` file you host).
    *   It wipes the disk, installs Ubuntu, installs Docker, and reboots.

### The Tool: MaaS (Metal as a Service) by Canonical
Since you are using Ubuntu, **MaaS** is the industry standard for this.
*   You install MaaS on one computer.
*   It detects your other 5 servers.
*   You click "Deploy" in the UI.
*   MaaS wakes them up (via Wake-on-LAN), installs Ubuntu, and turns them into a "Cloud".

### The "Poor Man's" Version (SSH + Ansible)
If you already have Ubuntu installed on them manually:
1.  **SSH Key**: Put your SSH key on all 5 servers.
2.  **Ansible**: On your laptop, write an `inventory` file with the 5 IPs.
3.  **Run**: `ansible-playbook setup.yml -i inventory`.
    *   Ansible connects to all 5 simultaneously.
    *   Installs Docker/Terraform.
    *   Configures them exactly how you want.

## Summary Recommendation

| Scenario | Recommended Tool |
| :--- | :--- |
| **I want to plug a USB stick in and walk away** | **Cubic** (Custom ISO) |
| **I want to reinstall OS remotely (wipe & reload)** | **MaaS** or **PXE Server** |
| **I just want to configure existing Ubuntu servers** | **Ansible** (Easiest & Best for you) |

Since you have fixed IPs and existing Ubuntu, **Ansible** is your best friend here. It allows you to "control install" from your local machine over SSH.
