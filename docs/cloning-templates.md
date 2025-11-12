# Cloning Proxmox Templates

## Overview

This guide explains how to clone Proxmox cloud-init templates created by the proxmox_template role. Cloning creates new VMs from templates that can be customized and started.

## Clone Types

Proxmox supports two clone types:

### Linked Clone (Recommended for Testing)

```bash
qm clone <template_vmid> <new_vmid> --name <vm_name> --full 0
```

**Characteristics:**
- Fast creation (seconds)
- Disk is copy-on-write reference to template
- Small disk footprint initially
- Template MUST NOT be deleted while clones exist
- Perfect for temporary test VMs

### Full Clone

```bash
qm clone <template_vmid> <new_vmid> --name <vm_name> --full 1
```

**Characteristics:**
- Slower creation (copies entire disk)
- Independent disk (template can be deleted)
- Larger disk footprint
- Suitable for production VMs

## Basic Cloning Process

### Step 1: Find Latest Template

See [vmid-numbering.md](vmid-numbering.md) for details on finding the latest template.

Quick command:
```bash
# Debian 12 (range 8000-8999)
pvesh get /cluster/resources --type vm --output-format json | \
  jq '[.[] | select(.template == 1 and .vmid >= 8000 and .vmid <= 8999)] | sort_by(.vmid) | reverse | .[0]'

# Rocky 9 (range 7000-7999)
pvesh get /cluster/resources --type vm --output-format json | \
  jq '[.[] | select(.template == 1 and .vmid >= 7000 and .vmid <= 7999)] | sort_by(.vmid) | reverse | .[0]'
```

### Step 2: Clone Template

```bash
# Create linked clone
sudo qm clone 8008 500 --name debian12-test --full 0

# Or full clone
sudo qm clone 8008 500 --name debian12-test --full 1
```

### Step 3: Customize VM (Optional)

#### Set cloud-init Password

Templates use SSH keys by default. To enable console login:

```bash
sudo qm set 500 --cipassword 'your_password_here'
```

**Security Note**: Use Ansible Vault for production passwords.

#### Resize Disk

Templates default to 8G. To resize:

1. **Find boot disk name** (varies by template):
   ```bash
   sudo qm config 500 | grep boot
   # Output: boot: order=virtio0
   ```

2. **Resize disk**:
   ```bash
   sudo qm disk resize 500 virtio0 20G
   ```

**Important**: Use `qm disk resize`, not `qm resize`.

#### Other Customizations

```bash
# Change CPU/memory
sudo qm set 500 --cores 4 --memory 4096

# Change network
sudo qm set 500 --net0 virtio,bridge=vmbr1

# Set static IP via cloud-init
sudo qm set 500 --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1
```

### Step 4: Start VM

```bash
sudo qm start 500
```

### Step 5: Access VM

#### Via SSH (if cloud-init configured)

```bash
ssh lavender@<vm_ip>
```

The template includes your SSH key from `ansible_ssh_private_key_file`.

#### Via Console (if password set)

```bash
# Web console
# Navigate to VM in Proxmox UI → Console

# Or xterm.js console
sudo qm terminal 500
```

## Dynamic Boot Disk Detection

Different templates use different disk controllers:
- Most cloud images: `virtio0`
- Some images: `scsi0`
- Others: `sata0`

**Don't hardcode the disk name.** Detect it dynamically:

```yaml
- name: Get VM configuration to find boot disk
  ansible.builtin.command:
    cmd: "qm config {{ clone_vmid }}"
  register: vm_config
  changed_when: false

- name: Extract boot disk name from configuration
  ansible.builtin.set_fact:
    boot_disk: "{{ vm_config.stdout_lines | select('match', '^boot:.*') | first | regex_search('order=([^,;]+)', '\\1') | first }}"

- name: Display boot disk
  ansible.builtin.debug:
    msg: "Boot disk: {{ boot_disk }}"

- name: Resize disk
  ansible.builtin.command:
    cmd: "qm disk resize {{ clone_vmid }} {{ boot_disk }} 20G"
  register: resize_result
```

**Example**: See [playbooks/clone-debian12-test.yml](../playbooks/clone-debian12-test.yml)

## Complete Ansible Example

The [clone-debian12-test.yml](../playbooks/clone-debian12-test.yml) playbook demonstrates the full process:

```yaml
---
# Clone latest Debian 12 template and resize disk to 20G
- name: Clone latest Debian 12 template
  hosts: proxmox_vm_platform
  become: true

  vars:
    clone_vmid: 500
    clone_name: "debian12-test"
    clone_disk_size: "20G"
    template_vmid_range_start: 8000
    template_vmid_range_end: 8999

  tasks:
    # Find latest template in range
    - name: Get all VMs and templates from Proxmox API
      ansible.builtin.command:
        cmd: pvesh get /cluster/resources --type vm --output-format json
      register: pvesh_output
      changed_when: false

    - name: Parse JSON to find latest Debian 12 template
      ansible.builtin.set_fact:
        vm_list: "{{ pvesh_output.stdout | from_json }}"

    - name: Find latest Debian 12 template in VMID range
      ansible.builtin.set_fact:
        debian_templates: >-
          {{
            vm_list
            | selectattr('template', 'equalto', 1)
            | selectattr('vmid', '>=', template_vmid_range_start)
            | selectattr('vmid', '<=', template_vmid_range_end)
            | selectattr('tags', 'defined')
            | selectattr('tags', 'search', 'debian')
            | sort(attribute='vmid', reverse=true)
          }}

    - name: Get latest template VMID
      ansible.builtin.set_fact:
        latest_debian_template: "{{ debian_templates[0].vmid }}"
        latest_template_name: "{{ debian_templates[0].name }}"

    # Clone template
    - name: Clone template to new VMID (linked clone)
      ansible.builtin.command:
        cmd: "qm clone {{ latest_debian_template }} {{ clone_vmid }} --name {{ clone_name }} --full 0"
      register: clone_result
      changed_when: clone_result.rc == 0

    # Set cloud-init password for console access
    - name: Set cloud-init password for console access
      ansible.builtin.command:
        cmd: "qm set {{ clone_vmid }} --cipassword 'test123'"
      register: password_result
      changed_when: password_result.rc == 0

    # Detect boot disk dynamically
    - name: Get VM configuration to find boot disk
      ansible.builtin.command:
        cmd: "qm config {{ clone_vmid }}"
      register: vm_config_pre
      changed_when: false

    - name: Extract boot disk name from configuration
      ansible.builtin.set_fact:
        boot_disk: "{{ vm_config_pre.stdout_lines | select('match', '^boot:.*') | first | regex_search('order=([^,;]+)', '\\1') | first }}"

    # Resize disk
    - name: Resize disk to {{ clone_disk_size }}
      ansible.builtin.command:
        cmd: "qm disk resize {{ clone_vmid }} {{ boot_disk }} {{ clone_disk_size }}"
      register: resize_result
      changed_when: resize_result.rc == 0

    # Display results
    - name: Display clone information
      ansible.builtin.debug:
        msg:
          - "Cloned from template: {{ latest_template_name }} ({{ latest_debian_template }})"
          - "New VM ID: {{ clone_vmid }}"
          - "New VM name: {{ clone_name }}"
          - "Boot disk: {{ boot_disk }}"
          - "Disk size: {{ clone_disk_size }}"
```

## Manual Cloning Commands

For quick testing without Ansible:

```bash
# Find latest Debian 12 template
LATEST=$(sudo qm list | grep template | awk '$1 >= 8000 && $1 <= 8999' | sort -n | tail -1 | awk '{print $1}')

# Clone it
sudo qm clone $LATEST 500 --name test-vm --full 0

# Set password
sudo qm set 500 --cipassword 'test123'

# Find boot disk
BOOT_DISK=$(sudo qm config 500 | grep 'boot:' | sed -n 's/.*order=\([^,;]*\).*/\1/p')

# Resize disk
sudo qm disk resize 500 $BOOT_DISK 20G

# Start VM
sudo qm start 500

# Get IP (wait for cloud-init to complete)
sudo qm guest cmd 500 network-get-interfaces
```

## Cleanup

### Stop and Remove VM

```bash
# Stop gracefully
sudo qm stop 500

# Or force stop
sudo qm stop 500 --skiplock

# Remove VM
sudo qm destroy 500
```

### Ansible Cleanup

```bash
ssh root@magic "qm stop 500 && qm destroy 500"
```

## Common Issues

### Clone Fails: "VM already exists"

**Solution**: Choose different VMID or destroy existing VM:
```bash
sudo qm destroy 500
```

### Disk Resize Fails: "No such disk"

**Cause**: Wrong disk name (hardcoded instead of detected)

**Solution**: Use dynamic boot disk detection (see above)

### Can't Login to Console: "Login incorrect"

**Cause**: No password set (cloud-init templates use SSH keys only)

**Solution**: Set password with `qm set <vmid> --cipassword`

### VM Won't Start: "linked clone... parent missing"

**Cause**: Template was deleted but linked clones still exist

**Solution**: Create full clones or keep template

## Security Considerations

### Passwords in Playbooks

**Never commit plaintext passwords to git.**

Options:

1. **Ansible Vault** (Recommended for production):
   ```bash
   # Create encrypted file
   ansible-vault create vars/vm_passwords.yml

   # Add password variable
   clone_password: "secure_password_here"

   # Use in playbook
   - include_vars: vars/vm_passwords.yml
   - name: Set password
     command: "qm set {{ clone_vmid }} --cipassword '{{ clone_password }}'"
   ```

2. **Prompt at runtime**:
   ```yaml
   vars_prompt:
     - name: clone_password
       prompt: "Enter VM password"
       private: yes
   ```

3. **Environment variable**:
   ```yaml
   vars:
     clone_password: "{{ lookup('env', 'VM_PASSWORD') }}"
   ```

4. **Hardcoded for testing ONLY** (current approach):
   ```yaml
   # WARNING: For testing only! Remove before commit!
   - name: Set test password
     command: "qm set {{ clone_vmid }} --cipassword 'test123'"
   ```

### SSH Key Security

Templates include SSH public key from:
```yaml
template_ci_sshkeys: "{{ lookup('file', ansible_ssh_private_key_file + '.pub') }}"
```

Ensure private key `~/.ssh/id_ed25519` is protected:
```bash
chmod 600 ~/.ssh/id_ed25519
```

## References

- [vmid-numbering.md](vmid-numbering.md) - VMID system and finding latest templates
- [playbooks/clone-debian12-test.yml](../playbooks/clone-debian12-test.yml) - Complete working example
- [Proxmox qm Command](https://pve.proxmox.com/pve-docs/qm.1.html) - Official documentation
- [cloud-init Documentation](https://cloudinit.readthedocs.io/) - Cloud-init reference
