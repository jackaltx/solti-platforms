# Solti-Platforms Collection

## Purpose

Ansible collection for managing platform infrastructure - primarily Proxmox VMs and templates, with future support for Linode instances and Kubernetes clusters.

## Key Concepts

### Template-Based VM Provisioning

This collection follows a **template-first workflow**:

1. **Build templates** from cloud images (Debian, Rocky Linux)
2. **Clone VMs** from templates for fast deployment
3. **Cloud-init** configuration for passwordless SSH access

### Unified VMID Range

**Templates**: 9000-9999 (all distributions share this range)
- First template built → VMID 9000
- Second template built → VMID 9001
- Auto-calculated based on existing templates (no per-distribution ranges)

**VMs**: User-specified (typically 100-8999)

## Management Scripts

### manage-platform.sh

Main entry point for platform operations. Uses **platform-specific state management** with composite keys.

**Architecture**: `STATE_MAP["platform:action"]="state"`

**State Variable Mapping**: Each platform has a specific variable name the role expects:
- `proxmox_template` → `template_state`
- `proxmox_vm` → `vm_state`
- Others follow pattern: `{type}_state`

**Platform:Action Mappings**:

```bash
# Templates: build/destroy
STATE_MAP["proxmox_template:build"]="present"
STATE_MAP["proxmox_template:destroy"]="absent"

# VMs: full lifecycle
STATE_MAP["proxmox_vm:create"]="create"
STATE_MAP["proxmox_vm:verify"]="verify"
STATE_MAP["proxmox_vm:start"]="start"
STATE_MAP["proxmox_vm:stop"]="stop"
STATE_MAP["proxmox_vm:shutdown"]="shutdown"
STATE_MAP["proxmox_vm:remove"]="remove"
STATE_MAP["proxmox_vm:modify"]="modify"
```

**Usage:**

```bash
# Template management
./manage-platform.sh -h magic -t rocky9 proxmox_template build
./manage-platform.sh -h magic proxmox_template build --all-distros
./manage-platform.sh -h magic -t debian12 proxmox_template destroy

# VM management (vm_template_vmid is REQUIRED - no defaults)
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_vmid=500 \
  -e vm_name=test-vm \
  -e vm_template_vmid=9000

./manage-platform.sh -h magic proxmox_vm verify -e vm_vmid=500
./manage-platform.sh -h magic proxmox_vm start -e vm_vmid=500
./manage-platform.sh -h magic proxmox_vm remove -e vm_vmid=500
```

**Key Features**:
- Platform-aware action validation
- Generates playbooks dynamically
- User confirmation before execution
- Auto-cleanup on success, preserves failures for debugging
- Batch operations with `--all-distros`

### platform-exec.sh

Execute specific role tasks directly (for debugging/testing):

```bash
# Verify template state
./platform-exec.sh -h magic proxmox_template verify -e template_distribution=rocky9

# Run specific task with sudo
./platform-exec.sh -h magic -K proxmox_template cleanup -e template_distribution=debian12
```

## Roles

### proxmox_template

**Purpose**: Build cloud-init enabled VM templates from distribution images

**States**:
- `present`: Download image, resize, install guest agent, create template
- `absent`: Destroy template and optionally remove downloaded images

**Key Variables**:
- `template_state`: `present` or `absent` (REQUIRED)
- `template_distribution`: Distribution name matching vars file (e.g., `rocky9`, `debian12`)
- `template_vmid_base`: 9000 (default, start of unified range)
- `template_vmid_max`: 9999 (default, end of unified range)
- `template_cleanup`: `true` (default, remove downloaded images after template creation)
- `template_install_guest_agent`: `true` (default, install qemu-guest-agent in image)

**Workflow**:
1. Calculate next available VMID in 9000-9999 range (unified across all distros)
2. Download cloud image (if not cached)
3. Resize image to desired size
4. Install qemu-guest-agent (modifies image before VM creation)
5. Create VM and import disk
6. Configure storage and cloud-init
7. Convert to template
8. Set metadata notes
9. Clean up downloaded images (optional)

**Available Templates**:
- debian12, debian13
- rocky9, rocky10

Check `roles/proxmox_template/vars/*.yml` for all supported distributions.

### proxmox_vm

**Purpose**: Manage VM lifecycle - clone, configure, start, stop, remove

**Implemented States** (Phase 1):
- `create`: Clone VM from template, resize disk, configure cloud-init
- `verify`: Check VM exists and display configuration

**Planned States** (Phase 2+):
- `start`: Boot VM
- `stop`: Stop VM (non-graceful)
- `shutdown`: Graceful shutdown
- `remove`: Destroy VM
- `modify`: Change VM properties (resize disk, network, etc.)

**Required Variables**:
- `vm_state`: Action to perform (REQUIRED)
- `vm_vmid`: Target VM ID (REQUIRED)
- `vm_name`: VM name (required for `create`)
- `vm_template_vmid`: Template VMID to clone from (required for `create`, **NO DEFAULT**)

**Important**: `vm_template_vmid` has NO default value. You must specify which template to clone from:

```bash
# Find available templates
ssh magic 'qm list | grep template'

# Use the VMID from the output
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_vmid=500 \
  -e vm_name=test \
  -e vm_template_vmid=9000  # <-- REQUIRED
```

**Optional Variables**:
- `vm_disk_size`: Boot disk size (default: `20G`)
- `vm_memory`: RAM in MB (default: `4096`)
- `vm_cores`: CPU cores (default: `4`)
- `vm_linked_clone`: Use linked clone (default: `true` - faster, space-efficient)
  - Linked clones are faster and use less space but depend on template
  - Full clones are slower but independent of template
  - Override with `-e vm_linked_clone=false`
- `vm_ip_config`: Cloud-init network config (default: `ip=dhcp`)
- `vm_ssh_key_file`: SSH public key to inject (default: `~/.ssh/id_rsa.pub`)

**Workflow for `create`**:
1. Verify template exists at `vm_template_vmid`
2. Check target `vm_vmid` is not in use
3. Clone template (linked or full based on `vm_linked_clone`)
4. Extract boot disk name
5. Resize disk to `vm_disk_size`
6. Configure cloud-init (SSH key, network)

## Reference Hosts

### magic.a0a0.org

**Type**: Proxmox host (local infrastructure)
**Purpose**: Template and VM management
**Access**: SSH with sudo (user: lavender, password: `~/.secrets/lavender.pass`)

**Useful Commands**:

```bash
# Check existing templates
ssh magic 'qm list | grep template'

# Check template details
ssh magic 'qm config 9000'

# Check all VMs
ssh magic 'qm list'

# Check VM status
ssh magic 'qm status 500'
```

## Design Patterns

### Platform:Action State Management

The `manage-platform.sh` script uses **composite keys** for state mapping:

```bash
STATE_MAP["platform:action"]="state"
```

**Benefits**:
- **Semantic clarity**: `build` templates vs `create` VMs (different verbs for different resources)
- **Platform-aware validation**: Invalid combinations rejected early with helpful error messages
- **Extensible**: Easy to add new platforms with unique lifecycles
- **VM lifecycle support**: Natural fit for start/stop/shutdown/modify actions
- **Role alignment**: Matches how roles actually implement state handling

**Example Validations**:
```bash
# Valid
./manage-platform.sh -h magic proxmox_template build -t rocky9    # ✓
./manage-platform.sh -h magic proxmox_vm create ...                # ✓

# Invalid - rejected with helpful error
./manage-platform.sh -h magic proxmox_template create -t rocky9    # ✗
# Error: Action 'create' is not supported for platform 'proxmox_template'
# Supported actions for proxmox_template: build destroy
```

### Required Parameters

Parameters are validated at the **role level** during playbook execution:

- `proxmox_vm:create` requires: `vm_vmid`, `vm_name`, `vm_template_vmid`
- `proxmox_vm:verify` requires: `vm_vmid`
- `proxmox_template:build` requires: `template_distribution` (via `-t` flag)

**Future Enhancement**: Early parameter validation (before playbook execution) is tracked in [issues/001-early-parameter-validation.md](issues/001-early-parameter-validation.md). This will be implemented once error patterns stabilize.

### Dynamic Playbook Generation

No static playbooks - all generated on-the-fly in `tmp/`:
- Auto-cleaned on success
- Preserved on failure for debugging
- Named with timestamp: `platform-action-timestamp.yml`

Example generated playbook:
```yaml
---
# Dynamically generated playbook
# Platform: proxmox_vm, Action: create
- name: Manage proxmox_vm Platform
  hosts: magic
  become: true
  vars:
    vm_state: create
  roles:
    - role: proxmox_vm
```

## Common Workflows

### Build a Template

```bash
# Build single template
./manage-platform.sh -h magic -t debian12 proxmox_template build

# Build all available templates
./manage-platform.sh -h magic proxmox_template build --all-distros

# Verify template was created
ssh magic 'qm list | grep template'
# Output: 9000  debian12-template  ...
```

### Create a VM

```bash
# 1. Find available template VMID
ssh magic 'qm list | grep template'
# Output: 9000  debian12-template  0  0  -  stopped

# 2. Create VM from template (linked clone - fast, default)
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_vmid=500 \
  -e vm_name=my-test-vm \
  -e vm_template_vmid=9000

# OR: Create full clone (independent of template)
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_vmid=500 \
  -e vm_name=my-test-vm \
  -e vm_template_vmid=9000 \
  -e vm_linked_clone=false

# 3. Verify VM was created
./manage-platform.sh -h magic proxmox_vm verify -e vm_vmid=500

# 4. Start VM (when implemented in Phase 2)
./manage-platform.sh -h magic proxmox_vm start -e vm_vmid=500
```

### Destroy Resources

```bash
# Remove VM
./manage-platform.sh -h magic proxmox_vm remove -e vm_vmid=500

# Destroy template
./manage-platform.sh -h magic -t debian12 proxmox_template destroy
```

### Custom VM Configuration

```bash
# Larger disk and more resources
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_vmid=501 \
  -e vm_name=beefy-vm \
  -e vm_template_vmid=9000 \
  -e vm_disk_size=100G \
  -e vm_memory=8192 \
  -e vm_cores=8
```

## Testing

Uses Molecule for role testing:

```bash
cd roles/proxmox_template
molecule test

cd roles/proxmox_vm
molecule test
```

## Known Issues

See [issues/](issues/) directory for tracked issues and future enhancements:

- **Issue #001**: Early parameter validation (low priority, future enhancement)

## Integration with Parent Repository

This collection is part of the larger **Solti Multi-Collection Project** (see parent [../CLAUDE.md](../CLAUDE.md) for overall system context).

**Architecture Position** - Layer 1: Platform Creation:
```
Layer 0: Orchestration (inventory, workflows)
Layer 1: solti-platforms (THIS - Platform creation)
Layer 2: Applications (solti-monitoring, solti-containers, solti-ensemble)
```

**Key Integration Points**:
- Uses mylab/ orchestrator for site-specific deployments
- Reports generated to ../Reports/
- Follows Solti testing philosophy and patterns
- Credentials stored in mylab/data/ (not in collection)

## Development Notes

### Adding New Platforms

1. Add platform to `SUPPORTED_PLATFORMS` array in `manage-platform.sh`
2. Define `STATE_MAP["platform:action"]` mappings for each action
3. Define `PLATFORM_ACTIONS["platform"]` list of valid actions
4. Define `STATE_VAR_NAME["platform"]` variable name the role expects
5. Create role in `roles/platform_name/`
6. Update usage examples in script and documentation

Example:
```bash
# In manage-platform.sh
SUPPORTED_PLATFORMS+=("linode_instance")

STATE_MAP["linode_instance:create"]="present"
STATE_MAP["linode_instance:remove"]="absent"

PLATFORM_ACTIONS["linode_instance"]="create remove"

STATE_VAR_NAME["linode_instance"]="instance_state"
```

### Adding New VM Actions

1. Add action to `PLATFORM_ACTIONS["proxmox_vm"]` in `manage-platform.sh`
2. Add `STATE_MAP["proxmox_vm:action"]` mapping
3. Implement task file in `roles/proxmox_vm/tasks/action.yml`
4. Add validation in `roles/proxmox_vm/tasks/main.yml`
5. Update role documentation header

Example for implementing `start` action:
```bash
# 1. Already in PLATFORM_ACTIONS and STATE_MAP (defined but not implemented)

# 2. Create roles/proxmox_vm/tasks/start.yml
---
- name: Start VM {{ vm_vmid }}
  ansible.builtin.command:
    cmd: "qm start {{ vm_vmid }}"
  become: true

# 3. Add to main.yml
- name: Execute start tasks
  ansible.builtin.include_tasks:
    file: start.yml
  when: vm_state == 'start'
```

### Code Style

- Use descriptive task names
- Include debug messages for key steps
- Handle errors gracefully (`ignore_errors` where appropriate)
- Document variables thoroughly in role header
- Maintain idempotency where possible
- Follow Ansible best practices

## Troubleshooting

### Template build fails

1. Check sudo access:
```bash
sudo qm list
```

2. Verify storage:
```bash
pvesm status
```

3. Check internet access:
```bash
curl -I https://dl.rockylinux.org/
```

4. Check disk space:
```bash
df -h /tmp
```

### VM creation fails - "template not found"

The `vm_template_vmid` parameter is required with no default:

```bash
# Check which templates exist
ssh magic 'qm list | grep template'

# Use the correct VMID
./manage-platform.sh -h magic proxmox_vm create \
  -e vm_template_vmid=9000 \  # Use actual VMID
  -e vm_vmid=500 \
  -e vm_name=test
```

### Image download slow

- Images are cached in `template_work_dir`
- Disable cleanup to reuse: `-e template_cleanup=false`
- Pre-download manually if needed

### Cloud-init not working on cloned VM

- Ensure qemu-guest-agent is installed (enabled by default in templates)
- Check SSH keys path is correct (`~/.ssh/id_rsa.pub` on Proxmox host)
- Verify network configuration
- Check VM console for cloud-init logs

## References

### Internal
- Parent project: [../CLAUDE.md](../CLAUDE.md)
- Issues: [issues/](issues/)
- Original shell scripts: `build_templates_original/`
- Pattern reference: `../solti-containers/`

### External
- [Proxmox qm Command](https://pve.proxmox.com/pve-docs/qm.1.html)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Rocky Linux Cloud Images](https://dl.rockylinux.org/pub/rocky/)
- [Debian Cloud Images](https://cloud.debian.org/images/cloud/)

## Changelog

**2026-01-23**: Platform-specific state management refactoring
- Implemented composite key state mapping: `STATE_MAP["platform:action"]="state"`
- Added `PLATFORM_ACTIONS` for platform-aware validation
- Added `STATE_VAR_NAME` mapping for role-specific variable names
- Made `vm_template_vmid` required parameter (no defaults)
- Removed hardcoded template VMIDs from `proxmox_vm` role
- Updated usage examples and documentation
- Created issue tracking for future enhancements

**2025-11-11**: Converged inventory and script patterns
- Added `-h HOST` option for targeting individual hosts
- Added user confirmation prompts
- Renamed `inventory/platforms.yml` → `inventory/inventory.yml`
- Implemented central host registry pattern
- Updated all documentation references

**2025-11-11**: Dynamic playbook pattern implemented
- Created `manage-platform.sh` for state-based management
- Created `platform-exec.sh` for task execution
- Removed static playbooks
- Added `--all-distros` flag for batch operations
- Documentation updated for dynamic pattern

**2025-11-10**: Initial collection created
- Initialized collection structure
- Implemented proxmox_template role
- Added support for Rocky 9.x, Rocky 10.x, Debian 12
- Created initial playbooks and inventory
- Documentation complete
