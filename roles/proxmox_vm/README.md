# proxmox_vm

Create and manage Proxmox VMs from templates. This role handles VM cloning, disk resizing, and cloud-init configuration.

## Status

**Phase 1**: Debian 12 only (template VMID 8001)

## Requirements

- Proxmox VE host with qm command-line tools
- Debian 12 template at VMID 8001 (created by `proxmox_template` role)
- SSH access to Proxmox host with sudo privileges
- Cloud-init enabled in template
- SSH public key for cloud-init injection

## Role Variables

### Required Variables

```yaml
vm_name: "test-debian"      # VM name in Proxmox
vm_vmid: 500                # Target VMID (100-8999 recommended)
```

### Optional Variables (with defaults)

```yaml
vm_state: create            # State: create or verify
vm_disk_size: "20G"         # Boot disk size
vm_memory: 4096             # RAM in MB
vm_cores: 4                 # CPU cores
vm_ip_config: "ip=dhcp"     # Cloud-init network config
vm_ansible_user: lavender   # SSH user for cloud-init
vm_ssh_key_file: "~/.ssh/id_ed25519.pub"  # SSH key to inject
vm_linked_clone: true       # Use linked clone (faster, less space)
```

### Distribution Variables (hardcoded in vars/debian12.yml)

```yaml
vm_template_vmid: 8001      # Debian 12 template VMID
vm_template_name: "debian12"
```

## Dependencies

- `proxmox_template` role (to create template 8001)
- Proxmox host inventory group with `proxmox_storage` and `proxmox_bridge` variables

## Example Usage

### Using management scripts

```bash
cd solti-platforms

# Create VM from Debian 12 template
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_name=test-debian \
  -e vm_vmid=500

# Verify VM was created
./platform-exec.sh -h magic proxmox_vm verify -e vm_vmid=500

# Start VM manually
ssh magic.a0a0.org "sudo qm start 500"
```

### Direct playbook usage

```yaml
---
- name: Create Debian VM
  hosts: magic
  become: true
  roles:
    - role: proxmox_vm
      vars:
        vm_name: "test-debian"
        vm_vmid: 500
        vm_state: create
        vm_disk_size: "20G"
```

## VM States

### create

Clones VM from template 8001, resizes disk, configures cloud-init.

Steps:
1. Verify template 8001 exists
2. Check VMID not in use
3. Clone template (linked clone by default)
4. Extract boot disk name
5. Resize disk to specified size
6. Configure cloud-init (user, SSH key, network)
7. Display creation summary

### verify

Checks VM exists and displays configuration.

Steps:
1. Check VM status
2. Display VM configuration

## Future States (Phase 2)

- `start`: Boot VM
- `stop`: Stop VM (non-graceful)
- `shutdown`: Graceful shutdown
- `remove`: Destroy VM
- `modify`: Change VM properties

## Testing

```bash
# Create test VM
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_name=test-debian \
  -e vm_vmid=500

# Verify creation
./platform-exec.sh -h magic proxmox_vm verify -e vm_vmid=500

# Start and SSH test
ssh magic.a0a0.org "sudo qm start 500"
# Wait for boot...
ssh lavender@<vm-ip>

# Cleanup
ssh magic.a0a0.org "sudo qm stop 500 && sudo qm destroy 500"
```

## VMID Allocation Strategy

- **Templates**: 9000-9999 (unified range)
- **VMs**: 100-8999 (recommended)
- **Template 8001**: Debian 12 (Phase 1 hardcoded)

## License

MIT-0

## Author Information

Part of the Solti Ansible Collections suite.
