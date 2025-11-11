#!/bin/bash
#
# platform-exec - Execute specific tasks for platforms using dynamically generated Ansible playbooks
#
# Usage: platform-exec [-K] <platform> [entry] [options]
#
# Example:
#   platform-exec proxmox_template verify -e template_distribution=rocky9
#   platform-exec -K proxmox_template cleanup -e template_distribution=debian12
#   platform-exec proxmox_template                   # Default entry point (verify), no sudo

# Exit on error
set -e

# Configuration
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${ANSIBLE_DIR}/inventory/platforms.yml"
TEMP_DIR="${ANSIBLE_DIR}/tmp"

# Ensure temp directory exists
mkdir -p "${TEMP_DIR}"

# Supported platforms
SUPPORTED_PLATFORMS=(
    "proxmox_template"
    "proxmox_vm"
    "platform_base"
    "linode_instance"
    "k3s_control"
    "k3s_worker"
)

# Default entry point if not specified
DEFAULT_ENTRY="verify"

# Initialize variables
USE_SUDO=false
PLATFORM=""
ENTRY=""

# Display usage information
usage() {
    echo "Usage: $(basename $0) [-K] <platform> [entry] [options]"
    echo ""
    echo "Options:"
    echo "  -K      - Prompt for sudo password (needed for some operations)"
    echo ""
    echo "Parameters:"
    echo "  platform - The platform to manage"
    echo "  entry    - The entry point task (default: verify)"
    echo "  options  - Extra variables (-e VAR=VALUE)"
    echo ""
    echo "Platforms:"
    for platform in "${SUPPORTED_PLATFORMS[@]}"; do
        echo "  - $platform"
    done
    echo ""
    echo "Common Entry Points:"
    echo "  - verify           - Verify platform state (default)"
    echo "  - download_image   - Download cloud image"
    echo "  - resize_image     - Resize disk image"
    echo "  - cleanup          - Clean up temporary files"
    echo "  - create_vm        - Create VM"
    echo "  - import_disk      - Import disk"
    echo "  - configure_storage - Configure storage"
    echo "  - setup_cloudinit  - Setup cloud-init"
    echo "  - convert_template - Convert to template"
    echo ""
    echo "Examples:"
    echo "  $(basename $0) proxmox_template verify -e template_distribution=rocky9"
    echo "  $(basename $0) -K proxmox_template cleanup -e template_distribution=debian12"
    echo "  $(basename $0) proxmox_template                   # Default entry, no sudo"
    exit 1
}

# Check if a platform is supported
is_platform_supported() {
    local platform="$1"
    for plat in "${SUPPORTED_PLATFORMS[@]}"; do
        if [[ "$plat" == "$platform" ]]; then
            return 0
        fi
    done
    return 1
}

# Generate task execution playbook
generate_exec_playbook() {
    local platform="$1"
    local entry="$2"

    # Create playbook directly with proper substitutions
    cat > "$TEMP_PLAYBOOK" << EOF
---
# Dynamic execution playbook
- name: Execute ${entry} for ${platform} Platform
  hosts: ${platform}_platform
  tasks:
    - name: Include role tasks
      ansible.builtin.include_role:
        name: ${platform}
        tasks_from: ${entry}
        vars_from: main
EOF

    echo "Generated ${entry} playbook for ${platform}"
}

# Parse command line options
while getopts "K" opt; do
    case ${opt} in
        K)
            USE_SUDO=true
            ;;
        *)
            usage
            ;;
    esac
done

# Shift past the options
shift $((OPTIND - 1))

# Validate remaining arguments
if [[ $# -lt 1 ]]; then
    echo "Error: Incorrect number of arguments"
    usage
fi

# Extract platform
PLATFORM="$1"
shift

# Validate platform
if ! is_platform_supported "$PLATFORM"; then
    echo "Error: Unsupported platform '$PLATFORM'"
    usage
fi

# Check if next argument is an entry point or an option
if [[ $# -gt 0 && "$1" != -* ]]; then
    ENTRY="$1"
    shift
else
    ENTRY="$DEFAULT_ENTRY"
fi

# Remaining arguments are extra vars
EXTRA_ARGS=("$@")

# Generate timestamp for files
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TEMP_PLAYBOOK="${TEMP_DIR}/${PLATFORM}-${ENTRY}-${TIMESTAMP}.yml"

# Generate the playbook
generate_exec_playbook "$PLATFORM" "$ENTRY"

# Display execution info
echo "Executing task: ${ENTRY} for platform: ${PLATFORM}"
echo "Using generated playbook: $TEMP_PLAYBOOK"
if $USE_SUDO; then
    echo "Using sudo: Yes (will prompt for password)"
else
    echo "Using sudo: No"
fi
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    echo "Extra arguments: ${EXTRA_ARGS[*]}"
fi
echo ""

# Display playbook content
echo "Playbook content:"
echo "----------------"
cat "${TEMP_PLAYBOOK}"
echo "----------------"
echo ""

# Execute the playbook with or without sudo prompt
if $USE_SUDO; then
    echo "Executing with sudo privileges: ansible-playbook -K -i ${INVENTORY} ${TEMP_PLAYBOOK} ${EXTRA_ARGS[*]}"
    ansible-playbook -K -i "${INVENTORY}" "${TEMP_PLAYBOOK}" "${EXTRA_ARGS[@]}"
else
    echo "Executing: ansible-playbook -i ${INVENTORY} ${TEMP_PLAYBOOK} ${EXTRA_ARGS[*]}"
    ansible-playbook -i "${INVENTORY}" "${TEMP_PLAYBOOK}" "${EXTRA_ARGS[@]}"
fi

# Check execution status
EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo ""
    echo "Success: ${ENTRY} for ${PLATFORM} completed successfully"

    # Remove the temporary playbook on success
    echo "Cleaning up generated playbook"
    rm -f "${TEMP_PLAYBOOK}"

    exit 0
else
    echo ""
    echo "Error: ${ENTRY} for ${PLATFORM} failed with exit code ${EXIT_CODE}"
    echo "Generated playbook preserved for debugging: ${TEMP_PLAYBOOK}"
    exit 1
fi
