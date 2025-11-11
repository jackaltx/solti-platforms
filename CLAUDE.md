# CLAUDE.md - solti-platforms Collection

## Purpose

Platform creation and provisioning for the SOLTI ecosystem. Creates VMs, K3s clusters, and manages platform lifecycle.

## Quick Commands

```bash
# Build all templates
ansible-playbook playbooks/build-all-templates.yml -K

# Build single template
ansible-playbook playbooks/build-single-template.yml -e template_distribution=rocky9 -K

# Verify templates
sudo qm list | grep template
```

## Architecture Position

**Layer 1: Platform Creation** in the SOLTI ecosystem:

```
Layer 0: solti-conductor      (Orchestration - inventory, workflows)
Layer 1: solti-platforms      (THIS - Platform creation)
Layer 2: solti-monitoring     (Applications run ON platforms)
         solti-containers
         solti-ensemble
```

## Current Status

### Phase 1: Proxmox Templates ✅ COMPLETE
- proxmox_template role fully implemented
- Supports Rocky 9.x, Rocky 10.x, Debian 12
- Based on existing shell scripts (build_templates_original/)

### Next Phases
- Phase 2: proxmox_vm (clone, configure, destroy)
- Phase 3: platform_base (common provisioning)
- Phase 4: linode_instance
- Phase 5: k3s_control and k3s_worker

## Key Patterns

### CREATE → PROVISION Pattern

All platforms follow two-phase model:

1. **CREATE**: Bring platform into existence (API calls, localhost)
2. **PROVISION**: Configure platform for use (SSH, remote)

Examples:
- Proxmox: qm create → cloud-init setup
- Linode: API create → user setup + packages
- K3s: Install binary → cluster bootstrap

### Distribution Handling

Distribution-specific vars in `vars/<distro>.yml`:
- rocky9.yml - VMID 7000
- rocky10.yml - VMID 7001
- debian12.yml - VMID 9001

### Reused from solti-containers

- Distribution-specific vars files
- Per-role verification tasks
- Comprehensive documentation
- Base role pattern (platform_base)

## Roles

### proxmox_template (READY)

Converts cloud images to Proxmox templates.

**Based on**: `build_templates_original/build-rocky9-cloud-init.sh`, `build-deb12-cloud-init.sh`

**Tasks**:
1. download_image.yml - Get cloud image
2. resize_image.yml - Resize to 8G
3. create_vm.yml - qm create with hardware
4. import_disk.yml - qm importdisk
5. configure_storage.yml - Boot order, cloud-init drive
6. setup_cloudinit.yml - SSH keys, user, network
7. convert_template.yml - qm template
8. cleanup.yml - Remove downloaded image
9. verify.yml - Check template exists

**Variables**: See roles/proxmox_template/README.md

### platform_base (Planned)

Common provisioning for all platforms:
- User creation (lavender)
- SSH key setup
- Hostname configuration
- /etc/hosts update
- Base packages (vim, git, curl, htop)

**Based on**: `build_templates_original/fleur-create.yml` lines 88-154

## Integration with Other Collections

### With solti-conductor
Conductor orchestrates multi-collection workflows:
```yaml
- Create platform (solti-platforms)
- Deploy monitoring (solti-monitoring)
- Run tests
- Collect results
```

### With solti-monitoring
Platforms creates test VMs, monitoring deploys to them:
```bash
# solti-platforms
./manage-platform.sh proxmox_vm create --name test-rocky9

# solti-monitoring
cd ../solti-monitoring
./manage-svc.sh telegraf deploy --target test-rocky9
```

## Important Files

### Collection Root
- **README.md** - Overview, quick start, roadmap
- **CLAUDE.md** - This file
- **ansible.cfg** - Collection configuration
- **galaxy.yml** - Collection metadata

### Roles
- **roles/proxmox_template/** - Template builder (READY)
  - vars/rocky9.yml, rocky10.yml, debian12.yml
  - tasks/*.yml - Individual task files
  - defaults/main.yml - Role defaults
  - README.md - Role documentation

### Playbooks
- **playbooks/build-all-templates.yml** - Build all 3 distributions
- **playbooks/build-single-template.yml** - Build one distribution

### Inventory
- **inventory/proxmox.yml** - Template configuration

### Context Documentation
- **../../.claude/project-contexts/solti-platforms-decision.md** - Architectural decisions
- **../../.claude/project-contexts/solti-containers-context.md** - Pattern reference

## Common Tasks

### Add New Distribution

1. Create vars file:
```bash
cat > roles/proxmox_template/vars/ubuntu24.yml <<EOF
---
template_vmid: 9002
template_name: ubuntu24-template
template_os_type: l26
template_image_url: "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
template_image_file: "noble-server-cloudimg-amd64.img"
template_tags: "ubuntu-template,ubuntu24,cloudinit"
EOF
```

2. Update inventory, playbooks, documentation

3. Test:
```bash
ansible-playbook playbooks/build-single-template.yml \
  -e template_distribution=ubuntu24 -K
```

### Debug Template Build

```bash
# Disable cleanup to inspect downloaded image
ansible-playbook playbooks/build-single-template.yml \
  -e template_distribution=rocky9 \
  -e template_cleanup=false -K

# Check downloaded image
ls -lh /tmp/proxmox-templates/

# Manual cleanup
rm -rf /tmp/proxmox-templates/
```

### Destroy and Rebuild

```bash
# Destroy template
sudo qm destroy 7000

# Rebuild
ansible-playbook playbooks/build-single-template.yml \
  -e template_distribution=rocky9 -K
```

## Development Guidelines

### When Adding New Roles

1. Follow CREATE → PROVISION pattern
2. Create distribution-specific vars if applicable
3. Include verify.yml task file
4. Document in role README.md
5. Add example playbook
6. Update collection README.md

### Code Style

- Use descriptive task names
- Include debug messages for key steps
- Handle errors gracefully (ignore_errors where appropriate)
- Document variables thoroughly
- Maintain idempotency where possible

### Testing

Currently manual testing:
```bash
# Test build
ansible-playbook playbooks/build-single-template.yml -e template_distribution=rocky9 -K

# Verify
sudo qm list | grep rocky9-template

# Test clone
sudo qm clone 7000 100 --name test-vm
sudo qm start 100
```

Future: Molecule testing framework

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

### Image download slow

- Images are cached in template_work_dir
- Disable cleanup to reuse: `-e template_cleanup=false`
- Pre-download manually if needed

### cloud-init not working on cloned VM

- Ensure qemu-guest-agent in image
- Check SSH keys path is correct
- Verify network configuration

## References

### Internal
- `.claude/project-contexts/solti-platforms-decision.md` - Architecture
- `build_templates_original/` - Original shell scripts
- `../solti-containers/` - Pattern reference

### External
- [Proxmox qm Command](https://pve.proxmox.com/pve-docs/qm.1.html)
- [cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Rocky Linux Cloud Images](https://dl.rockylinux.org/pub/rocky/)
- [Debian Cloud Images](https://cloud.debian.org/images/cloud/)

## Notes for Claude Code

- This collection is new (Phase 1 complete)
- proxmox_template role is production-ready
- Next priority: proxmox_vm role
- Follow patterns from solti-containers
- Maintain compatibility with existing collections
- CREATE → PROVISION pattern is fundamental

## Changelog

**2025-11-10**: Initial collection created
- Initialized collection structure
- Implemented proxmox_template role
- Added support for Rocky 9.x, Rocky 10.x, Debian 12
- Created playbooks and inventory examples
- Documentation complete
