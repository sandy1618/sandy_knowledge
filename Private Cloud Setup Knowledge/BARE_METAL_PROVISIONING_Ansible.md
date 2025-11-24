# Ansible Provisioning Guide: End-to-End Setup

This guide explains how to use **Ansible** to control your 5 bare metal servers from your local machine (laptop).

## Why Ansible?
*   **Agentless**: You don't need to install anything on the servers. It uses SSH.
*   **Parallel**: It configures all 5 servers at the same time.
*   **Idempotent**: You can run it 100 times, and it only makes changes if something is missing.

---

## Phase 1: Preparation (On Your Laptop)

### 1. Install Ansible
**Mac**:
```bash
brew install ansible
```
**Linux**:
```bash
sudo apt update
sudo apt install ansible
```

### 2. Setup SSH Access
Ansible needs to log in to your servers without a password.

1.  **Generate an SSH Key** (if you haven't already):
    ```bash
    ssh-keygen -t ed25519 -C "ansible-control"
    ```
2.  **Copy Key to ALL Servers**:
    Replace IPs with your actual server IPs.
    ```bash
    ssh-copy-id u@192.168.3.5
    ssh-copy-id u@192.168.3.6
    ssh-copy-id u@192.168.3.7
    # ... repeat for all 5
    ```
    *You will need to type the password one last time for each.*

---

## Phase 2: Configuration

Create a folder for your ansible files:
```bash
mkdir ansible-infra
cd ansible-infra
```

### 1. The Inventory (`hosts.ini`)
This file tells Ansible which servers to talk to.

**Create `hosts.ini`**:
```ini
[servers]
server1 ansible_host=192.168.3.5
server2 ansible_host=192.168.3.6
server3 ansible_host=192.168.3.7
server4 ansible_host=192.168.3.8
server5 ansible_host=192.168.3.9

[servers:vars]
ansible_user=u
# If you use a specific key:
# ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

### 2. The Playbook (`setup.yml`)
This is the "script" that defines what the servers should look like.

**Create `setup.yml`**:
```yaml
---
- name: Provision Bare Metal Servers
  hosts: servers
  become: true  # Run as sudo

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install basic dependencies
      apt:
        name:
          - curl
          - git
          - htop
          - software-properties-common
        state: present

    # --- Docker Installation ---
    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable
        state: present

    - name: Install Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-compose-plugin
        state: present

    - name: Add user to docker group
      user:
        name: "{{ ansible_user }}"
        groups: docker
        append: yes

    # --- Terraform Installation ---
    - name: Add HashiCorp GPG key
      apt_key:
        url: https://apt.releases.hashicorp.com/gpg
        state: present

    - name: Add HashiCorp repository
      apt_repository:
        repo: deb [arch=amd64] https://apt.releases.hashicorp.com {{ ansible_distribution_release }} main
        state: present

    - name: Install Terraform
      apt:
        name: terraform
        state: present
```

---

## Phase 3: Execution

### 1. Test Connection
Check if Ansible can reach all servers.
```bash
ansible -i hosts.ini all -m ping
```
**Expected Output**:
```text
server1 | SUCCESS => { "ping": "pong" }
server2 | SUCCESS => { "ping": "pong" }
...
```

### 2. Run the Playbook
This will install everything on all 5 servers.
```bash
ansible-playbook -i hosts.ini setup.yml
```

**What happens:**
1.  Ansible connects to Server 1, 2, 3, 4, 5.
2.  It updates `apt`.
3.  It installs Docker.
4.  It installs Terraform.
5.  It finishes.

## Phase 4: Maintenance
If you want to update all servers later (e.g., update Docker), just run the playbook again.
Or run a specific command:

```bash
# Reboot all servers
ansible -i hosts.ini all -a "/sbin/reboot" --become
```

This is how you manage a "fleet" of bare metal servers efficiently.
