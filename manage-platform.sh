#!/bin/bash
#
# manage-platform - Manage platforms using dynamically generated Ansible playbooks
#
# Usage: manage-platform <platform> <action> [options]
#
# Example:
#   manage-platform proxmox_template build -e template_distribution=rocky9
#   manage-platform proxmox_template build --all-distros
#   manage-platform proxmox_template destroy -e template_distribution=rocky9

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

# Supported actions
SUPPORTED_ACTIONS=(
    "build"
    "destroy"
    "create"
    "remove"
)

# Map actions to state values
declare -A STATE_MAP
STATE_MAP["build"]="present"
STATE_MAP["destroy"]="absent"
STATE_MAP["create"]="present"
STATE_MAP["remove"]="absent"

# Distribution list for --all-distros
ALL_DISTROS=(
    "rocky9"
    "rocky10"
    "debian12"
)

# Display usage information
usage() {
    echo "Usage: $(basename $0) <platform> <action> [options]"
    echo ""
    echo "Platforms:"
    for platform in "${SUPPORTED_PLATFORMS[@]}"; do
        echo "  - $platform"
    done
    echo ""
    echo "Actions:"
    for action in "${SUPPORTED_ACTIONS[@]}"; do
        echo "  - $action"
    done
    echo ""
    echo "Options:"
    echo "  --all-distros    - Process all distributions (rocky9, rocky10, debian12)"
    echo "  -e VAR=VALUE     - Set extra variables (e.g., -e template_distribution=rocky9)"
    echo ""
    echo "Examples:"
    echo "  $(basename $0) proxmox_template build -e template_distribution=rocky9"
    echo "  $(basename $0) proxmox_template build --all-distros"
    echo "  $(basename $0) proxmox_template destroy -e template_distribution=rocky9"
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

# Check if an action is supported
is_action_supported() {
    local action="$1"
    for act in "${SUPPORTED_ACTIONS[@]}"; do
        if [[ "$act" == "$action" ]]; then
            return 0
        fi
    done
    return 1
}

# Claude:
# I think this is really cool but is put it to ALL hosts of that type. 
# I do want the details to be in the inventory, but I want to be able to target a single host.
# The trick is to get all the required configuration variables from an inventory that is focused on capability.
# for example  vmid  1001  and 1002 both have a client,  but 1002 has service. when I rerun to install the client...both are run. 

# Generate playbook from template
generate_playbook() {
    local platform="$1"
    local action="$2"
    local state="${STATE_MAP[$action]}"

    # Create playbook directly with the proper substitutions
    cat > "$TEMP_PLAYBOOK" << EOF
---
# Works for: build, destroy, create, remove
- name: Manage ${platform} Platform
  hosts: ${platform}_platform
  vars:
    ${platform}_state: ${state}
  roles:
    - role: ${platform}
EOF

    echo "Generated playbook for ${platform} ${action}"
}

# Execute playbook with extra vars
execute_playbook() {
    local platform="$1"
    local action="$2"
    shift 2
    local extra_args=("$@")

    # Generate the playbook
    generate_playbook "$platform" "$action"

    # Display execution info
    echo "Managing platform: $platform"
    echo "Action: $action"
    echo "Using generated playbook: $TEMP_PLAYBOOK"
    if [[ ${#extra_args[@]} -gt 0 ]]; then
        echo "Extra arguments: ${extra_args[*]}"
    fi
    echo ""

    # Display playbook content
    echo "Playbook content:"
    echo "----------------"
    cat "${TEMP_PLAYBOOK}"
    echo "----------------"
    echo ""

    # Always use sudo for all states
    echo "Executing with sudo privileges: ansible-playbook -K -i ${INVENTORY} ${TEMP_PLAYBOOK} ${extra_args[*]}"
    ansible-playbook -K -i "${INVENTORY}" "${TEMP_PLAYBOOK}" "${extra_args[@]}"

    # Check execution status
    EXIT_CODE=$?
    if [[ ${EXIT_CODE} -eq 0 ]]; then
        echo ""
        echo "Success: ${platform} ${action} completed successfully"

        # Remove the temporary playbook on success
        echo "Cleaning up generated playbook"
        rm -f "${TEMP_PLAYBOOK}"

        return 0
    else
        echo ""
        echo "Error: ${platform} ${action} failed with exit code ${EXIT_CODE}"
        echo "Generated playbook preserved for debugging: ${TEMP_PLAYBOOK}"
        return 1
    fi
}

# Validate minimum arguments
if [[ $# -lt 2 ]]; then
    echo "Error: Incorrect number of arguments"
    usage
fi

# Extract platform and action
PLATFORM="$1"
ACTION="$2"
shift 2

# Validate platform
if ! is_platform_supported "$PLATFORM"; then
    echo "Error: Unsupported platform '$PLATFORM'"
    usage
fi

# Validate action
if ! is_action_supported "$ACTION"; then
    echo "Error: Unsupported action '$ACTION'"
    usage
fi

# Check for --all-distros flag
ALL_DISTROS_MODE=false
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all-distros)
            ALL_DISTROS_MODE=true
            shift
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# Generate timestamp for files
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TEMP_PLAYBOOK="${TEMP_DIR}/${PLATFORM}-${ACTION}-${TIMESTAMP}.yml"

# Execute based on mode
if $ALL_DISTROS_MODE; then
    echo "Processing all distributions: ${ALL_DISTROS[*]}"
    echo ""

    FAILED_DISTROS=()

    for distro in "${ALL_DISTROS[@]}"; do
        echo "========================================"
        echo "Processing distribution: $distro"
        echo "========================================"
        echo ""

        # Update timestamp and playbook path for each distro
        TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
        TEMP_PLAYBOOK="${TEMP_DIR}/${PLATFORM}-${ACTION}-${distro}-${TIMESTAMP}.yml"

        if ! execute_playbook "$PLATFORM" "$ACTION" "${EXTRA_ARGS[@]}" -e "template_distribution=$distro"; then
            FAILED_DISTROS+=("$distro")
        fi

        echo ""
    done

    # Summary
    echo "========================================"
    echo "All distributions processing complete"
    echo "========================================"

    if [[ ${#FAILED_DISTROS[@]} -eq 0 ]]; then
        echo "Success: All distributions processed successfully"
        exit 0
    else
        echo "Error: The following distributions failed:"
        for distro in "${FAILED_DISTROS[@]}"; do
            echo "  - $distro"
        done
        exit 1
    fi
else
    # Single execution
    execute_playbook "$PLATFORM" "$ACTION" "${EXTRA_ARGS[@]}"
    exit $?
fi
