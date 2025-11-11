# proxmox_template Role

Builds Proxmox VM templates from cloud images for Rocky Linux and Debian.

## Purpose

Creates reusable VM templates on Proxmox VE by:
1. Downloading cloud images
2. Configuring VM hardware
3. Setting up cloud-init
4. Converting to template

Based on existing shell scripts:
- `build_templates_original/build-rocky9-cloud-init.sh`
- `build_templates_original/build-deb12-cloud-init.sh`

## Supported Distributions

| Distribution | VMID | cloud-init | Status |
|--------------|------|------------|--------|
| Rocky Linux 9.x | 7000 | ✅ | Ready |
| Rocky Linux 10.x | 7001 | ✅ | Ready |
| Debian 12 | 9001 | ✅ | Ready |

## Requirements

- Proxmox VE 8.x
- `qemu-img` utility
- sudo access for `qm` commands
- Internet access to download images

## Role Variables

### Required

```yaml
template_distribution: rocky9  # rocky9, rocky10, or debian12
```

### Proxmox Configuration

```yaml
proxmox_storage: local-lvm    # Storage backend
proxmox_bridge: vmbr0         # Network bridge
```

### VM Hardware

```yaml
template_memory: 4096         # RAM in MB
template_balloon: 1           # Memory balloon
template_cores: 4             # CPU cores
template_cpu_type: host       # CPU type
template_numa: 1              # NUMA
template_bios: ovmf           # BIOS type
template_machine: q35         # Machine type
```

### Disk Configuration

```yaml
template_disk_size: 8G                    # Disk size
template_disk_controller: virtio-scsi-pci # Disk controller
template_disk_options: discard=on         # Disk options
```

### Network

```yaml
template_network_model: virtio  # Network model
template_network_mtu: 1         # MTU
```

### cloud-init

```yaml
template_ci_user: "{{ ansible_user_id }}"                    # Default user
template_ci_sshkeys: "{{ ansible_user_dir }}/.ssh/authorized_keys"  # SSH keys
template_ci_ipconfig: "ip=dhcp"                              # Network config
template_qemu_agent: 1                                       # QEMU agent
```

### Other

```yaml
template_work_dir: "/tmp/proxmox-templates"  # Download directory
template_cleanup: true                        # Remove images after build
```

## Distribution-Specific Variables

Located in `vars/<distribution>.yml`:

### Rocky 9.x (`vars/rocky9.yml`)
```yaml
template_vmid: 7000
template_name: rocky9-template
template_image_url: "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
```

### Rocky 10.x (`vars/rocky10.yml`)
```yaml
template_vmid: 7001
template_name: rocky10-template
template_image_url: "https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud.latest.x86_64.qcow2"
```

### Debian 12 (`vars/debian12.yml`)
```yaml
template_vmid: 9001
template_name: debian12-template
template_image_url: "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
```

## Dependencies

None

## Example Playbook

### Build Single Template

```yaml
---
- name: Build Rocky 9 template
  hosts: localhost
  gather_facts: true
  roles:
    - role: proxmox_template
      vars:
        template_distribution: rocky9
```

### Build All Templates

```yaml
---
- name: Build all templates
  hosts: localhost
  gather_facts: true
  vars:
    distributions:
      - rocky9
      - rocky10
      - debian12
  tasks:
    - name: Build template for {{ item }}
      include_role:
        name: proxmox_template
      vars:
        template_distribution: "{{ item }}"
      loop: "{{ distributions }}"
```

### Custom Configuration

```yaml
---
- name: Build custom template
  hosts: localhost
  gather_facts: true
  roles:
    - role: proxmox_template
      vars:
        template_distribution: debian12
        template_memory: 8192
        template_cores: 8
        proxmox_storage: local-zfs
```

## Tasks

The role executes the following tasks in order:

1. **download_image.yml** - Download cloud image (with caching)
2. **resize_image.yml** - Resize disk to specified size
3. **create_vm.yml** - Create VM with hardware config
4. **import_disk.yml** - Import disk image to Proxmox
5. **configure_storage.yml** - Configure storage and boot
6. **setup_cloudinit.yml** - Configure cloud-init settings
7. **convert_template.yml** - Convert VM to template
8. **cleanup.yml** - Remove downloaded images (optional)
9. **verify.yml** - Verify template exists

## Usage

```bash
# Build single template
ansible-playbook playbooks/build-single-template.yml \
  -e template_distribution=rocky9 -K

# Build all templates
ansible-playbook playbooks/build-all-templates.yml -K

# Custom storage
ansible-playbook playbooks/build-single-template.yml \
  -e template_distribution=debian12 \
  -e proxmox_storage=local-zfs -K
```

## Verification

After role execution:

```bash
# List templates
sudo qm list | grep template

# Should show:
# 7000 rocky9-template    ...
# 7001 rocky10-template   ...
# 9001 debian12-template  ...

# Test cloning
sudo qm clone 7000 100 --name test-vm
sudo qm start 100
```

## Troubleshooting

### Image download fails
- Check internet connectivity
- Verify image URL is accessible
- Check disk space in `template_work_dir`

### Template creation fails
- Ensure VMID not already in use
- Verify sudo access for `qm` commands
- Check Proxmox storage is available

### cloud-init not working
- Verify SSH keys path exists
- Check user permissions
- Ensure `qemu-guest-agent` in cloud image

## Files Created

### Temporary
- `{{ template_work_dir }}/{{ template_image_file }}` - Downloaded image (removed if cleanup enabled)

### Proxmox
- VM template with specified VMID
- EFI disk on `{{ proxmox_storage }}`
- Main disk on `{{ proxmox_storage }}`
- cloud-init drive on `{{ proxmox_storage }}`

## Tags

None currently defined.

## License

MIT

## Author

SOLTI Project - jackaltx
