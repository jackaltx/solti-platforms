# VMID Numbering System

## Overview

The solti-platforms collection uses a **smart VMID numbering system** for Proxmox templates. VMIDs are automatically calculated based on distribution-specific ranges, ensuring no conflicts and providing logical organization.

## VMID Ranges

Each distribution has a dedicated 1000-number range:

| Distribution | VMID Range | Base | Example VMIDs |
|--------------|------------|------|---------------|
| Rocky Linux 9.x | 7000-7999 | 7000 | 7001, 7002, 7003... |
| Debian 12 | 8000-8999 | 8000 | 8001, 8002, 8003... |
| Rocky Linux 10.x | 10000-10999 | 10000 | 10001, 10002, 10003... |

## How VMID Calculation Works

### Configuration

Each distribution has a vars file defining its `template_vmid_base`:

```yaml
# roles/proxmox_template/vars/debian12.yml
template_vmid_base: 8000  # Base for VMID range (8000-8999)
```

### Calculation Logic

When building a template, the system:

1. **Queries existing VMs** using Proxmox API:
   ```bash
   pvesh get /cluster/resources --type vm --output-format json
   ```

2. **Filters VMIDs in range** for the specific distribution:
   - Range: `template_vmid_base` to `template_vmid_base + 999`
   - Example: Debian 12 searches 8000-8999

3. **Finds highest existing VMID** in that range

4. **Increments by 1** to get next available VMID:
   - If no templates exist: `base + 1` (e.g., 8001)
   - If templates exist: `max_vmid + 1` (e.g., 8008 → 8009)

### Implementation

See [roles/proxmox_template/tasks/calculate_vmid.yml](../roles/proxmox_template/tasks/calculate_vmid.yml):

```yaml
- name: Find existing VMIDs in range for this distribution
  ansible.builtin.set_fact:
    existing_vmids: >-
      {{ vm_list
         | selectattr('vmid', 'defined')
         | map(attribute='vmid')
         | map('int')
         | select('>=', vmid_range_start | int)
         | select('<=', vmid_range_end | int)
         | list
         | sort }}

- name: Calculate next VMID
  ansible.builtin.set_fact:
    calculated_vmid: "{{ (vmid_range_start | int + 1) if (existing_vmids | length == 0) else ((existing_vmids | max) + 1) }}"
```

## Important Notes

### VMID ≠ OS Version

**The VMID number does NOT indicate the OS version.**

- VMID 8008 = 8th Debian 12 template build
- VMID 8008 ≠ Debian 12.8
- All templates pull "latest" from upstream

To determine OS version, inspect the template's notes field or image metadata.

**GitHub Issue**: [#1 - VMID Not Coupled to OS Version](https://github.com/jackaltx/solti-platforms/issues/1)

### Sequential Building

VMIDs increment sequentially with each build:

```
1st build: 8001
2nd build: 8002
3rd build: 8003
...
```

This provides an audit trail of template generations.

### Template Cleanup

Old templates are **not automatically removed**. Manual cleanup required:

```bash
# List templates in range
sudo qm list | grep template

# Destroy old template
sudo qm destroy 8001
```

## Finding Latest Template

To find the latest template for a distribution:

### Method 1: Via pvesh (Recommended)

```bash
pvesh get /cluster/resources --type vm --output-format json | \
  jq '[.[] | select(.template == 1 and .vmid >= 8000 and .vmid <= 8999)] | sort_by(.vmid) | reverse | .[0]'
```

### Method 2: Via qm list

```bash
# List all templates
sudo qm list | grep template

# Filter by range and find highest
sudo qm list | grep template | awk '$1 >= 8000 && $1 <= 8999' | sort -n | tail -1
```

### Method 3: In Ansible Playbook

See [playbooks/clone-debian12-test.yml](../playbooks/clone-debian12-test.yml) for example:

```yaml
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
```

## Adding New Distributions

To add a new distribution (e.g., Ubuntu 24):

1. **Choose VMID range** (avoid conflicts):
   - Example: Ubuntu 24 = 9000-9999

2. **Create vars file**:
   ```bash
   cat > roles/proxmox_template/vars/ubuntu24.yml <<EOF
   ---
   template_vmid_base: 9000  # Base for VMID range (9000-9999)
   template_name: ubuntu24-template
   # ... other vars
   EOF
   ```

3. **Update manage-platform.sh**:
   ```bash
   ALL_DISTROS=(
       "rocky9"
       "rocky10"
       "debian12"
       "ubuntu24"  # Add here
   )
   ```

4. **Update this documentation** with new range

## References

- [calculate_vmid.yml](../roles/proxmox_template/tasks/calculate_vmid.yml) - VMID calculation logic
- [proxmox_template role README](../roles/proxmox_template/README.md) - Role documentation
- [clone-debian12-test.yml](../playbooks/clone-debian12-test.yml) - Example of finding latest template
- [GitHub Issue #1](https://github.com/jackaltx/solti-platforms/issues/1) - VMID versioning limitation
