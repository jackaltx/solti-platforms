# Solti Platforms Collection

This collection provides Ansible roles for managing various service platforms.

## Scripts

### `manage-platform.sh`

This script is used to manage platforms using dynamically generated Ansible playbooks.

**Usage:**

```bash
./manage-platform.sh [-h HOST] <platform> <action> [options]
```

**Description:**

The `manage-platform.sh` script is a wrapper that simplifies the execution of Ansible roles for building, destroying, creating, and removing various service platforms. It dynamically generates a temporary Ansible playbook based on the specified platform and action, and then executes it.

**Key Features:**

*   **Dynamic Playbook Generation:** Automatically creates an Ansible playbook in the `tmp/` directory tailored to the specified platform and action.
*   **Host Targeting:** Allows targeting a specific host from the inventory using the `-h` flag, which is mandatory for Proxmox operations.
*   **Platform and Action Validation:** Checks if the specified platform and action are supported before execution. The supported platforms and actions are defined within the script.
*   **Template Discovery:** For the `proxmox_template` platform, it can discover available templates from the `roles/proxmox_template/vars` directory.
*   **"All Distros" Mode:** The `--all-distros` flag allows processing all discovered distributions for the `proxmox_template` platform in a single run.
*   **Extra Variables:** Supports passing extra variables to the Ansible playbook using the `-e` flag.
*   **Interactive Confirmation:** Prompts for confirmation before executing the generated playbook, displaying the playbook's content for review.
*   **Cleanup:** Automatically removes the temporary playbook upon successful execution.

**Supported Platforms:**

*   `proxmox_template`
*   `proxmox_vm`
*   `platform_base`
*   `linode_instance`
*   `k3s_control`
*   `k3s_worker`

**Available Templates (for proxmox_template):**

| Distribution | Status |
|--------------|--------|
| debian12     | Ready  |
| debian13     | Ready  |
| rocky10      | Ready  |
| rocky9       | Ready  |

**Supported Actions:**

*   `build`
*   `destroy`
*   `create`
*   `remove`

**Examples:**

*   Build a `rocky9` Proxmox template on the `magic` host:
    ```bash
    ./manage-platform.sh -h magic -t rocky9 proxmox_template build
    ```

*   Build all Proxmox templates on the `magic` host:
    ```bash
    ./manage-platform.sh -h magic proxmox_template build --all-distros
    ```

*   Destroy a `debian12` Proxmox template on the `proxmox2` host:
    ```bash
    ./manage-platform.sh -h proxmox2 -t debian12 proxmox_template destroy
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

*   **Task-Specific Execution:** Targets and executes a single task file (entry point) from an Ansible role.
*   **Dynamic Playbook Generation:** Creates a temporary Ansible playbook to run the specified task.
*   **Host Targeting:** Allows targeting a specific host with the `-h` flag (required for Proxmox operations).
*   **Sudo Prompt:** The `-K` flag prompts for a sudo password when the task requires elevated privileges.
*   **Default Entry Point:** If no entry is specified, it defaults to the `verify` task for the given platform.
*   **Supported Platforms:** Supports the same platforms as `manage-platform.sh`.
*   **Extra Variables:** Supports passing extra variables to the Ansible playbook using the `-e` flag.

**Common Entry Points (examples for `proxmox_template`):**

*   `verify` (default) - Verify platform state
*   `download_image` - Download cloud image
*   `resize_image` - Resize disk image
*   `cleanup` - Clean up temporary files
*   `create_vm` - Create VM
*   `import_disk` - Import disk
*   `configure_storage` - Configure storage
*   `setup_cloudinit` - Setup cloud-init
*   `convert_template` - Convert to template

**Examples:**

*   Verify a `rocky9` Proxmox template on the `magic` host:
    ```bash
    ./platform-exec.sh -h magic proxmox_template verify -e template_distribution=rocky9
    ```

*   Clean up temporary files for a `debian12` Proxmox template on the `magic` host, prompting for sudo password:
    ```bash
    ./platform-exec.sh -h magic -K proxmox_template cleanup -e template_distribution=debian12
    ```

*   Execute the default `verify` entry point for `proxmox_template` on `proxmox2` host (no sudo by default):
    ```bash
    ./platform-exec.sh -h proxmox2 proxmox_template
    ```
