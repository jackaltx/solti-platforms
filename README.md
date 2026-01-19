# Ansible Collection - jackaltx.solti_platforms

**Platform creation and provisioning for the SOLTI ecosystem**

This is an expriment to see if I can find a comment pattern in the
Virtual Machine api's that I currently use,  Proxmox and Linode.
Phased developments are a good tool for identifying how a technology
can be harnessed for use over time.

I gave Claude a broader goal of K3s, but that is in the future.
I blew through my free Linode time. Learned quite a bit, and will
focuse on making Proxmox better for me.  

Why Proxmox? Simple, community popular and it works is the only good answer.
It was a toss up between Proxmox and Xen XCP.

I gave Claude his full head on this ansible role. It uses Ansible tasks like entry
points into a FORTRAN program.  Invoking the entry points allow acces to the complete set of
configuration variables. Almost like a "class variable" that the "methods" have access to.
What this means is that have the least insight into how this works than the rest of my work.

  Jackal

## Overview

This collection manages platform creation (VMs, K3s clusters) for the SOLTI testing and development environment. It provides:

- **Proxmox VM template building** - Rocky 9+, Debian 12+
- **Proxmox VM lifecycle** - Clone, configure, start/stop, destroy (planned)
- **Linode instance management** - Create, provision, destroy (planned)
- **K3s cluster deployment** - Control plane + worker nodes (planned)
- **Platform base provisioning** - User setup, SSH, packages (planned)

## Quick Start

### Configure Inventory

**IMPORTANT**: Templates are built ON the Proxmox server, not localhost.

These use an user account on the server with sudo privileges, not the proxmox api.

1. Edit `inventory/inventory.yml`
2. Add your Proxmox host to the `platforms` registry
3. Add host to `proxmox_template_platform` capability group

### Build Proxmox Templates

CLAUDE TODO: Static lists suck, lets read: roles/proxmox_template/vars
and pull the template_name. and allow them to do a -t <template_name>
if they forget the -t, then present the list and this help.
This should simplify adding new distros.

however I do like the --all-distros

```bash
# Build single template (runs on Proxmox host)
./manage-platform.sh proxmox_template build -e template_distribution=rocky9

# Build all templates (Rocky 9, Rocky 10, Debian 12)
./manage-platform.sh proxmox_template build --all-distros

# Destroy template
./manage-platform.sh proxmox_template destroy -e template_distribution=rocky9

# Check for image updates
./platform-exec.sh proxmox_template check_for_update -e template_distribution=rocky9

# Verify template
./platform-exec.sh proxmox_template verify -e template_distribution=rocky9

# Force rebuild with same image version
./manage-platform.sh proxmox_template build -e template_distribution=rocky9 -e template_force_download=true
```

### Supported Distributions

CLAUDE:  rebuild this list...

- **Rocky Linux 9.x** - Starting at VMID 7000
- **Rocky Linux 10.x** - Startung at VMID 10001
- **Debian 12** - Starting at VMID 9001

## Roles

### proxmox_template ✅ READY

Builds Proxmox VM templates from cloud images.

**Features**:

- Downloads cloud images (with caching)
- Configures VM hardware (CPU, memory, disk)
- Sets up cloud-init (SSH keys, network)
- Converts to reusable template
- Supports Rocky 9+, Debian 12+

**Variables**:

Claude gnerate a clickable list of what template files are in that vars dir

```yaml
template_distribution: rocky9     # rocky9, rocky10, or debian12
proxmox_storage: local-lvm        # Proxmox storage backend
proxmox_bridge: vmbr0             # Network bridge
template_memory: 4096             # RAM in MB
template_cores: 4                 # CPU cores
template_disk_size: 8G            # Disk size
```

**Usage**:

The two script manage-platorm.sh and platform-exec.sh create dynamic ansible playbooks.
It keeps the playbook creep to a minimum. At the core, all of this is ansible and can
be used in your playbooks.

```bash
# State-based management (uses manage-platform.sh)
./manage-platform.sh proxmox_template build -e template_distribution=rocky9
./manage-platform.sh proxmox_template destroy -e template_distribution=debian12

# Task execution (uses platform-exec.sh)
./platform-exec.sh proxmox_template verify -e template_distribution=rocky9
./platform-exec.sh -K proxmox_template cleanup -e template_distribution=debian12
```

See [roles/proxmox_template/README.md](roles/proxmox_template/README.md) for details.

### platform_base (Planned)

Common provisioning tasks for all platforms.

## Collection Structure

```
jackaltx/solti_platforms/
├── roles/
│   ├── proxmox_template/     # Template builder (READY)
│   ├── proxmox_vm/           # VM lifecycle (planned)
│   ├── linode_instance/      # Linode management (planned)
│   └── platform_base/        # Common provisioning (planned)
├── manage-platform.sh        # State-based management script
├── platform-exec.sh          # Task execution script
├── inventory/platforms.yml   # Platform inventory
├── tmp/                      # Generated playbooks (auto-cleaned)
└── docs/                     # Documentation
```

## Architecture

Part of the SOLTI ecosystem:

```
Layer 0: solti-conductor      (Orchestration)
Layer 1: solti-platforms      (This collection - Platform creation)
Layer 2: solti-monitoring     (Application services)
         solti-containers
         solti-ensemble
```

**solti-platforms** creates the compute platforms (VMs, K3s clusters) where other collections deploy their applications.

## Requirements

- Ansible >= 2.15
- Proxmox VE 8.x
- `qemu-img` utility
- sudo access for `qm` commands

## Installation

```bash
# From source
ansible-galaxy collection build
ansible-galaxy collection install jackaltx-solti_platforms-1.0.0.tar.gz

# Or use locally
cd /path/to/collections
git clone <repo-url> ansible_collections/jackaltx/solti_platforms
```

## Configuration

Edit [inventory/platforms.yml](inventory/platforms.yml) to customize:

- Storage backend (`proxmox_storage`)
- Network bridge (`proxmox_bridge`)
- Hardware specs (memory, cores, disk)

Distribution-specific settings (VMIDs, image URLs) are in [roles/proxmox_template/vars/](roles/proxmox_template/vars/)

## Develoment Roadmap

### Phase 1: Proxmox Templates ✅ COMPLETE

- [x] Template builder role
- [x] Rocky 9.x support
- [x] Rocky 10.x support
- [x] Debian 12 support
- [x] cloud-init configuration
- [x] Verification tasks

### Phase 2: Proxmox VMs (Starting Jan 2026)

- [ ] Clone from template
- [ ] VM configuration
- [ ] Start/stop/destroy
- [ ] Integration with platform_base

### Phase 3: Base Provisioning

This would be bringing an OS up to some "standard", could STIG, HIPPA,....

- [ ] User management
- [ ] SSH key setup
- [ ] Hostname configuration
- [ ] Base package installation

### Phase 4: Linode Integration

- [ ] Instance creation
- [ ] Provisioning
- [ ] Destroy

### Phase 5: K3s Deployment

- [ ] Control plane role
- [ ] Worker node role
- [ ] Cluster bootstrap

## Testing

### Manual Testing

```bash
# Build Rocky 9 template
./manage-platform.sh proxmox_template build -e template_distribution=rocky9

# Verify template exists
./platform-exec.sh proxmox_template verify -e template_distribution=rocky9
# Or directly:
sudo qm list | grep rocky9-template

# Build all templates
./manage-platform.sh proxmox_template build --all-distros

# Run specific tasks
./platform-exec.sh -K proxmox_template cleanup -e template_distribution=rocky9
```

### Dynamic Playbooks

Both scripts generate playbooks on-the-fly in `tmp/`:

- **Success**: Playbook auto-deleted
- **Failure**: Playbook preserved for debugging

### Future: Molecule Testing

After role stabilization, Molecule tests will be added.

## License

MIT

## Author

SOLTI Project - jackaltx

## Related Collections

- [solti-monitoring](https://github.com/jackaltx/solti-monitoring) - Monitoring stack
- [solti-containers](https://github.com/jackaltx/solti-containers) - Testing containers
- [solti-ensemble](https://github.com/jackaltx/solti-ensemble) - Shared services
