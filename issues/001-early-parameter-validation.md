# Issue #001: Early Parameter Validation in manage-platform.sh

**Status**: Open
**Priority**: Low
**Created**: 2026-01-23

## Problem

Currently, `manage-platform.sh` generates playbooks without validating required parameters. The validation only happens when Ansible executes the role, which means:

1. User runs command without required parameter
2. Script generates playbook successfully
3. User confirms execution
4. Ansible starts running
5. **THEN** validation fails with Ansible error message

**Example:**
```bash
$ ./manage-platform.sh -h magic proxmox_vm create -e vm_vmid=500 -e vm_name=test
# Missing -e vm_template_vmid=9000

Generated playbook for proxmox_vm create
...
Execute this playbook? [Y/n]: Y
# Runs ansible-playbook
# FAILS at role validation step
```

## Desired Behavior

Validate required parameters **before** generating playbook:

```bash
$ ./manage-platform.sh -h magic proxmox_vm create -e vm_vmid=500 -e vm_name=test

Error: proxmox_vm create requires -e vm_template_vmid=XXXX

Example:
  ./manage-platform.sh -h magic proxmox_vm create \
    -e vm_vmid=500 \
    -e vm_name=test \
    -e vm_template_vmid=9000
```

## Requirements

### Platform-Specific Validation

Each platform:action combination may require different parameters:

- `proxmox_vm:create` requires: `vm_vmid`, `vm_name`, `vm_template_vmid`
- `proxmox_vm:verify` requires: `vm_vmid`
- `proxmox_template:build` requires: `template_distribution` (via `-t` flag)
- Future actions will have their own requirements

### Implementation Approach

Add `validate_required_params()` function that:
1. Takes platform, action, and extra_args
2. Checks for required parameters based on platform:action
3. Exits with helpful error message if validation fails
4. Called after action validation, before `--all-distros` parsing

### Example Validation Logic

```bash
validate_required_params() {
    local platform="$1"
    local action="$2"
    shift 2
    local extra_args=("$@")

    case "$platform:$action" in
        proxmox_vm:create)
            # Check for vm_template_vmid
            if [[ ! " ${extra_args[*]} " =~ " vm_template_vmid=" ]]; then
                echo "Error: proxmox_vm create requires -e vm_template_vmid=XXXX"
                # Show helpful example
                exit 1
            fi
            ;;
        proxmox_vm:start|proxmox_vm:stop|proxmox_vm:shutdown|proxmox_vm:remove)
            # These might need vm_vmid validation
            ;;
        # Add more cases as needed
    esac
}
```

## Why Not Now?

During active development, error handling should mature organically as we add new platforms and actions. Premature validation logic might:
- Create maintenance burden
- Not anticipate future patterns
- Add complexity before stabilization

Better to:
1. Let users hit role validation errors
2. Identify common pain points
3. Add validation when patterns emerge
4. Implement comprehensively when stable

## When to Implement

Implement when:
- Platform actions stabilize (no frequent changes)
- Common user errors identified through usage
- Clear patterns emerge for parameter requirements
- All planned VM lifecycle actions implemented

## Related

- Commit 020117a: Made `vm_template_vmid` required parameter
- Role validation: `roles/proxmox_vm/tasks/main.yml:22-29`
- Script location: `manage-platform.sh:278-285` (action validation)
