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

These use a user account on the server with sudo privileges, not the proxmox api.

1. Edit `inventory/inventory.yml`
2. Add your Proxmox hosts to the `proxmox_hosts` group
3. (Optional) Create `inventory/host_vars/{hostname}.yml` for host-specific overrides

### Build Proxmox Templates

Templates are auto-discovered from [roles/proxmox_template/vars/](roles/proxmox_template/vars/). Just add a new `.yml` file to support a new distribution.

```bash
# Build single template (runs on Proxmox host) - REQUIRES -h HOST
./manage-platform.sh -h magic -t rocky9 proxmox_template build

# Build all templates on specific host (auto-discovers all templates in vars/)
./manage-platform.sh -h magic proxmox_template build --all-distros

# Destroy template on specific host
./manage-platform.sh -h magic -t rocky9 proxmox_template destroy

# Check for image updates
./platform-exec.sh -h magic proxmox_template check_for_update -e template_distribution=rocky9

# Verify template
./platform-exec.sh -h magic proxmox_template verify -e template_distribution=rocky9

# Force rebuild with same image version
./manage-platform.sh -h magic -t rocky9 proxmox_template build -e template_force_download=true

# Forgot which templates are available?
./manage-platform.sh
```

### Supported Distributions

Templates are defined in [roles/proxmox_template/vars/](roles/proxmox_template/vars/):

- [rocky9.yml](roles/proxmox_template/vars/rocky9.yml) - **Rocky Linux 9.x**
- [rocky10.yml](roles/proxmox_template/vars/rocky10.yml) - **Rocky Linux 10.x**
- [debian12.yml](roles/proxmox_template/vars/debian12.yml) - **Debian 12 (Bookworm)**
- [debian13.yml](roles/proxmox_template/vars/debian13.yml) - **Debian 13 (Trixie)**

**VMID Assignment**: All templates use unified range 9000-9999 (auto-assigned sequentially)

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

Common variables (set in inventory or command line):

```yaml
proxmox_storage: local-lvm        # Proxmox storage backend
proxmox_bridge: vmbr0             # Network bridge
template_memory: 4096             # RAM in MB
template_cores: 4                 # CPU cores
template_disk_size: 8G            # Disk size
```

Distribution-specific variables (in [roles/proxmox_template/vars/](roles/proxmox_template/vars/)):

- [rocky9.yml](roles/proxmox_template/vars/rocky9.yml) - Rocky Linux 9.x configuration
- [rocky10.yml](roles/proxmox_template/vars/rocky10.yml) - Rocky Linux 10.x configuration
- [debian12.yml](roles/proxmox_template/vars/debian12.yml) - Debian 12 configuration
- [debian13.yml](roles/proxmox_template/vars/debian13.yml) - Debian 13 configuration

**Usage**:

The two scripts [manage-platform.sh](manage-platform.sh) and [platform-exec.sh](platform-exec.sh) create dynamic ansible playbooks.
It keeps the playbook creep to a minimum. At the core, all of this is ansible and can
be used in your playbooks.

```bash
# State-based management (uses manage-platform.sh) - REQUIRES -h HOST
./manage-platform.sh -h magic -t rocky9 proxmox_template build
./manage-platform.sh -h proxmox2 -t debian12 proxmox_template destroy

# Task execution (uses platform-exec.sh) - REQUIRES -h HOST
./platform-exec.sh -h magic proxmox_template verify -e template_distribution=rocky9
./platform-exec.sh -h magic -K proxmox_template cleanup -e template_distribution=debian12
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

### Inventory Structure

The inventory uses a simplified host-centric pattern:

```yaml
# inventory/inventory.yml
proxmox_hosts:
  hosts:
    magic:            # First Proxmox server
    proxmox2:         # Second Proxmox server (optional)
  vars:
    # Common defaults for ALL hosts
    proxmox_storage: local-lvm
    proxmox_bridge: vmbr0
    template_vmid_base: 9000    # Unified range for all templates
    template_vmid_max: 9999
```

### Host-Specific Overrides

Create `inventory/host_vars/{hostname}.yml` for per-host customization:

```yaml
# inventory/host_vars/proxmox2.yml
proxmox_storage: local-ssd      # Different storage
proxmox_bridge: vmbr1           # Different bridge
template_memory: 8192           # More RAM
```

### Distribution Settings

Distribution-specific settings (image URLs, names) are in [roles/proxmox_template/vars/](roles/proxmox_template/vars/)

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
# Build Rocky 9 template on specific host
./manage-platform.sh -h magic -t rocky9 proxmox_template build

# Verify template exists
./platform-exec.sh -h magic proxmox_template verify -e template_distribution=rocky9
# Or directly on the host:
ssh magic sudo qm list | grep rocky9-template

# Build all templates on specific host (auto-discovers from vars/)
./manage-platform.sh -h magic proxmox_template build --all-distros

# Run specific tasks
./platform-exec.sh -h magic -K proxmox_template cleanup -e template_distribution=rocky9
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
