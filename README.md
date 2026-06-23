# Solti Platforms Collection

Ansible collection for Proxmox template and VM lifecycle management.

## Workflow Evolution

The original approach passed all VM parameters as `-e` flags on the command line. The current approach uses **per-VM inventory files** instead:

| Old | New |
|-----|-----|
| `./manage-platform.sh -h magic proxmox_vm create -e vm_vmid=500 -e vm_name=foo -e vm_template_vmid=9000` | `./manage-platform.sh -h magic -i inventory/foo-vm.yml proxmox_vm create` |

The inventory file documents what's fixed by the environment (Proxmox host, storage, available bridges) separately from what's VM-specific (name, VMID, resources, cloud-init). It's gitignored so site-specific details stay private; a `.example` file is checked in as a public template.

This mirrors the pattern used in `solti-podman` (`podma.yml`) and `solti-matrix-bots` (`matrix-bot1.yml`) — the collection is self-contained and deployable without a conductor.

## Scripts

### `manage-platform.sh`

This script is used to manage platforms using dynamically generated Ansible playbooks.

**Usage:**

```bash
./manage-platform.sh [-h HOST] [-i INVENTORY] [-t TEMPLATE] <platform> <action> [options]
```

**Description:**

Manages platform infrastructure via dynamically generated Ansible playbooks. The preferred workflow uses per-VM inventory files (`-i`) rather than `-e` flags — all VM settings live in one gitignored file, making deployments reproducible and self-documenting.

**Key Features:**

* **Dynamic Playbook Generation:** Creates a temporary playbook in `tmp/` on the fly; preserved on failure for debugging.
* **VM Inventory Pattern:** `-i inventory/<hostname>-vm.yml` layers VM-specific vars on top of the base inventory. Each VM gets its own gitignored file; use the `.example` as a checked-in template.
* **Host Targeting:** `-h HOST` targets a specific Proxmox host (required for Proxmox operations).
* **Auto sudo:** Detects `~/.secrets/lavender.pass` automatically; falls back to interactive `-K`.
* **Platform and Action Validation:** Rejects invalid platform/action combinations with a helpful error.
* **"All Distros" Mode:** `--all-distros` processes all templates in a single run.
* **Extra Variables:** `-e VAR=VALUE` for ad-hoc overrides.
* **Interactive Confirmation:** Displays generated playbook before executing.

**Supported Platforms:**

* `proxmox_template`
* `proxmox_vm`
* `platform_base`
* `linode_instance`
* `k3s_control`
* `k3s_worker`

**Available Templates (for proxmox_template):**

| Distribution | Status |
|--------------|--------|
| debian12     | Ready  |
| debian13     | Ready  |
| rocky10      | Ready  |
| rocky9       | Ready  |

**Template Actions:** `build`, `destroy`

**VM Actions:** `create`, `verify`, `start`, `stop`, `shutdown`, `remove`

**Examples:**

```bash
# Build templates
./manage-platform.sh -h magic -t rocky9 proxmox_template build
./manage-platform.sh -h magic proxmox_template build --all-distros
./manage-platform.sh -h magic -t debian12 proxmox_template destroy

# VM lifecycle — inventory-based (preferred)
# All VM vars in inventory/<hostname>-vm.yml (gitignored)
# Use inventory/<hostname>-vm.yml.example as your starting point
export VM_CI_PASS="yourpassword"   # optional: sets cloud-init console password
./manage-platform.sh -h magic -i inventory/myvm.yml proxmox_vm create
./manage-platform.sh -h magic -i inventory/myvm.yml proxmox_vm start
./manage-platform.sh -h magic -i inventory/myvm.yml proxmox_vm stop
./manage-platform.sh -h magic -i inventory/myvm.yml proxmox_vm remove

# VM lifecycle — ad-hoc (quick one-offs)
./manage-platform.sh -h magic proxmox_vm verify -e vm_vmid=500
./manage-platform.sh -h magic proxmox_vm start -e vm_vmid=500
```

### `platform-exec.sh`

This script is used to execute specific tasks for platforms using dynamically generated Ansible playbooks.

**Usage:**

```bash
./platform-exec.sh [-h HOST] [-K] <platform> [entry] [options]
```

**Description:**

The `platform-exec.sh` script allows for focused execution of individual tasks or "entry points" within a platform's Ansible role. It dynamically generates a temporary Ansible playbook that includes a specific task from a role, providing fine-grained control over operations.

**Key Features:**

* **Task-Specific Execution:** Targets and executes a single task file (entry point) from an Ansible role.
* **Dynamic Playbook Generation:** Creates a temporary Ansible playbook to run the specified task.
* **Host Targeting:** Allows targeting a specific host with the `-h` flag (required for Proxmox operations).
* **Sudo Prompt:** The `-K` flag prompts for a sudo password when the task requires elevated privileges.
* **Default Entry Point:** If no entry is specified, it defaults to the `verify` task for the given platform.
* **Supported Platforms:** Supports the same platforms as `manage-platform.sh`.
* **Extra Variables:** Supports passing extra variables to the Ansible playbook using the `-e` flag.

**Common Entry Points (examples for `proxmox_template`):**

* `verify` (default) - Verify platform state
* `download_image` - Download cloud image
* `resize_image` - Resize disk image
* `cleanup` - Clean up temporary files
* `create_vm` - Create VM
* `import_disk` - Import disk
* `configure_storage` - Configure storage
* `setup_cloudinit` - Setup cloud-init
* `convert_template` - Convert to template

**Examples:**

* Verify a `rocky9` Proxmox template on the `magic` host:
    ```bash
    ./platform-exec.sh -h magic proxmox_template verify -e template_distribution=rocky9
    ```

* Clean up temporary files for a `debian12` Proxmox template on the `magic` host, prompting for sudo password:
    ```bash
    ./platform-exec.sh -h magic -K proxmox_template cleanup -e template_distribution=debian12
    ```

* Execute the default `verify` entry point for `proxmox_template` on `proxmox2` host (no sudo by default):
    ```bash
    ./platform-exec.sh -h proxmox2 proxmox_template
    ```
