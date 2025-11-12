# solti-platforms Documentation

## Overview

Documentation for the solti-platforms Ansible collection, which provides platform creation and provisioning for the SOLTI ecosystem.

## Documentation Files

### [vmid-numbering.md](vmid-numbering.md)

**Smart VMID numbering system for Proxmox templates**

Learn how VMIDs are automatically calculated, organized by distribution ranges, and how to find the latest template for cloning.

Key topics:
- VMID range allocation (Rocky 9 = 7000-7999, Debian 12 = 8000-8999, etc.)
- Automatic VMID calculation logic
- Finding latest template in a range
- Important note: VMID ≠ OS version
- Adding new distributions

**Use this when:**
- Understanding how templates are numbered
- Adding a new distribution
- Troubleshooting VMID conflicts
- Writing automation that needs to find templates

### [cloning-templates.md](cloning-templates.md)

**Complete guide to cloning Proxmox cloud-init templates**

Comprehensive guide for creating VMs from templates, including dynamic disk detection, password setup, and customization.

Key topics:
- Linked vs. full clones
- Finding and cloning latest template
- Dynamic boot disk detection (critical!)
- Setting cloud-init passwords
- Disk resizing
- Complete Ansible playbook example
- Security considerations

**Use this when:**
- Creating VMs from templates
- Writing playbooks that clone templates
- Troubleshooting clone or resize issues
- Setting up cloud-init passwords
- Understanding boot disk detection

## Quick Reference

### Find Latest Template

```bash
# Debian 12 (8000-8999)
pvesh get /cluster/resources --type vm --output-format json | \
  jq '[.[] | select(.template == 1 and .vmid >= 8000 and .vmid <= 8999)] | sort_by(.vmid) | reverse | .[0]'

# Rocky 9 (7000-7999)
pvesh get /cluster/resources --type vm --output-format json | \
  jq '[.[] | select(.template == 1 and .vmid >= 7000 and .vmid <= 7999)] | sort_by(.vmid) | reverse | .[0]'
```

### Clone and Customize

```bash
# Clone template (linked)
sudo qm clone 8008 500 --name test-vm --full 0

# Set password
sudo qm set 500 --cipassword 'test123'

# Find boot disk
BOOT_DISK=$(sudo qm config 500 | grep 'boot:' | sed -n 's/.*order=\([^,;]*\).*/\1/p')

# Resize disk
sudo qm disk resize 500 $BOOT_DISK 20G

# Start VM
sudo qm start 500
```

## VMID Range Reference

| Distribution | VMID Range | Base | Status |
|--------------|------------|------|--------|
| Rocky Linux 9.x | 7000-7999 | 7000 | ✅ Production |
| Debian 12 | 8000-8999 | 8000 | ✅ Production |
| Rocky Linux 10.x | 10000-10999 | 10000 | ✅ Production |

## Example Playbooks

### Build Template

```bash
# Build single distribution
./manage-platform.sh proxmox_template build -e template_distribution=debian12

# Build all distributions
./manage-platform.sh proxmox_template build --all-distros
```

### Clone Template

See [playbooks/clone-debian12-test.yml](../playbooks/clone-debian12-test.yml):

```bash
ansible-playbook -K -i inventory/inventory.yml playbooks/clone-debian12-test.yml
```

## For Claude Agents

If you're a Claude agent tasked with cloning templates or working with VMIDs:

1. **Read [vmid-numbering.md](vmid-numbering.md) first** to understand:
   - How VMIDs are organized by distribution
   - How to find the latest template in a range
   - Why VMID numbers don't indicate OS version

2. **Read [cloning-templates.md](cloning-templates.md) for implementation**:
   - Complete Ansible playbook example
   - Dynamic boot disk detection (CRITICAL - don't hardcode disk names!)
   - Security best practices for passwords

3. **Key implementation details**:
   - Use `pvesh get /cluster/resources` to find templates
   - Filter by VMID range (8000-8999 for Debian 12)
   - Sort by VMID descending, take first result
   - Dynamically detect boot disk from `qm config` output
   - Use `qm disk resize` (not `qm resize`)

4. **Working example**: [playbooks/clone-debian12-test.yml](../playbooks/clone-debian12-test.yml)

## Integration with Other Collections

### solti-containers

solti-platforms creates VMs, solti-containers deploys services to them:

```bash
# Create test VM (solti-platforms)
cd solti-platforms
./manage-platform.sh proxmox_template build -e template_distribution=rocky9

# Deploy service (solti-containers)
cd ../solti-containers
./manage-svc.sh -h test-vm telegraf deploy
```

### solti-monitoring

Monitoring services run on platforms created by solti-platforms:

```bash
# Create platform
ansible-playbook -K clone-debian12-test.yml

# Deploy monitoring
cd ../solti-monitoring
ansible-playbook -i inventory.yml deploy-telegraf.yml
```

## Related Files

- [../CLAUDE.md](../CLAUDE.md) - Collection overview for Claude Code
- [../README.md](../README.md) - User-facing README
- [../roles/proxmox_template/README.md](../roles/proxmox_template/README.md) - Role documentation
- [../roles/proxmox_template/tasks/calculate_vmid.yml](../roles/proxmox_template/tasks/calculate_vmid.yml) - VMID calculation logic
- [../playbooks/clone-debian12-test.yml](../playbooks/clone-debian12-test.yml) - Working clone example

## Contributing

When adding new documentation:

1. Keep it focused on one topic
2. Include working examples
3. Add security considerations
4. Update this README with links
5. Cross-reference related docs
