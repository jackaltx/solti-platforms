#!/bin/bash
#
# manage-platform - Manage platforms using dynamically generated Ansible playbooks
#
# Usage: manage-platform [-h HOST] <platform> <action> [options]
#
# Example:
#   manage-platform proxmox_template build -e template_distribution=rocky9
#   manage-platform -h magic proxmox_template build -e template_distribution=rocky9
#   manage-platform proxmox_template build --all-distros
#   manage-platform proxmox_template destroy -e template_distribution=rocky9

# Exit on error
set -e

# Configuration
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${ANSIBLE_DIR}/inventory/inventory.yml"
TEMP_DIR="${ANSIBLE_DIR}/tmp"
HOST=""

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

# Platform-specific action to state mapping
# Format: STATE_MAP["platform:action"]="state"
declare -A STATE_MAP

# proxmox_template: builds/destroys templates
STATE_MAP["proxmox_template:build"]="present"
STATE_MAP["proxmox_template:destroy"]="absent"

# proxmox_vm: manages VM lifecycle
STATE_MAP["proxmox_vm:create"]="create"
STATE_MAP["proxmox_vm:verify"]="verify"
STATE_MAP["proxmox_vm:start"]="start"
STATE_MAP["proxmox_vm:stop"]="stop"
STATE_MAP["proxmox_vm:shutdown"]="shutdown"
STATE_MAP["proxmox_vm:remove"]="remove"
STATE_MAP["proxmox_vm:modify"]="modify"

# platform_base: base platform configuration
STATE_MAP["platform_base:create"]="present"
STATE_MAP["platform_base:remove"]="absent"

# linode_instance: Linode cloud instances
STATE_MAP["linode_instance:create"]="present"
STATE_MAP["linode_instance:remove"]="absent"

# k3s_control: Kubernetes control plane
STATE_MAP["k3s_control:create"]="present"
STATE_MAP["k3s_control:remove"]="absent"

# k3s_worker: Kubernetes worker nodes
STATE_MAP["k3s_worker:create"]="present"
STATE_MAP["k3s_worker:remove"]="absent"

# Platform-specific supported actions
declare -A PLATFORM_ACTIONS
PLATFORM_ACTIONS["proxmox_template"]="build destroy"
PLATFORM_ACTIONS["proxmox_vm"]="create verify start stop shutdown remove modify"
PLATFORM_ACTIONS["platform_base"]="create remove"
PLATFORM_ACTIONS["linode_instance"]="create remove"
PLATFORM_ACTIONS["k3s_control"]="create remove"
PLATFORM_ACTIONS["k3s_worker"]="create remove"

# Platform-specific state variable names (what the role expects)
declare -A STATE_VAR_NAME
STATE_VAR_NAME["proxmox_template"]="template_state"
STATE_VAR_NAME["proxmox_vm"]="vm_state"
STATE_VAR_NAME["platform_base"]="base_state"
STATE_VAR_NAME["linode_instance"]="instance_state"
STATE_VAR_NAME["k3s_control"]="control_state"
STATE_VAR_NAME["k3s_worker"]="worker_state"

# Function to discover available templates from vars directory
discover_templates() {
    local vars_dir="${ANSIBLE_DIR}/roles/proxmox_template/vars"
    local templates=()

    if [[ -d "$vars_dir" ]]; then
        for file in "$vars_dir"/*.yml; do
            if [[ -f "$file" ]]; then
                local basename=$(basename "$file" .yml)
                templates+=("$basename")
            fi
        done
    fi

    # Return sorted array
    IFS=$'\n' templates=($(sort <<<"${templates[*]}"))
    unset IFS

    echo "${templates[@]}"
}

# Distribution list for --all-distros (dynamically discovered)
ALL_DISTROS=($(discover_templates))

# Display usage information
usage() {
    local templates=($(discover_templates))

    echo "Usage: $(basename $0) [-h HOST] <platform> <action> [options]"
    echo ""
    echo "Options:"
    echo "  -h HOST          - Target specific host from inventory (REQUIRED for proxmox operations)"
    echo "  -t TEMPLATE      - Template name (for proxmox_template platform)"
    echo ""
    echo "Platforms and Actions:"
    for platform in "${SUPPORTED_PLATFORMS[@]}"; do
        echo "  $platform:"
        echo "    Actions: ${PLATFORM_ACTIONS[$platform]}"
    done
    echo ""

    if [[ ${#templates[@]} -gt 0 ]]; then
        echo "Available Templates:"
        for template in "${templates[@]}"; do
            echo "  - $template"
        done
        echo ""
    fi

    echo "Additional Options:"
    echo "  --all-distros    - Process all available templates"
    echo "  -e VAR=VALUE     - Set extra variables"
    echo ""
    echo "Examples:"
    echo "  # Template management"
    echo "  $(basename $0) -h magic -t rocky9 proxmox_template build"
    echo "  $(basename $0) -h magic proxmox_template build --all-distros"
    echo "  $(basename $0) -h magic -t debian12 proxmox_template destroy"
    echo ""
    echo "  # VM management"
    echo "  $(basename $0) -h magic proxmox_vm create -e vm_vmid=500 -e vm_name=test-vm"
    echo "  $(basename $0) -h magic proxmox_vm verify -e vm_vmid=500"
    echo "  $(basename $0) -h magic proxmox_vm start -e vm_vmid=500"
    echo "  $(basename $0) -h magic proxmox_vm remove -e vm_vmid=500"
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

# Check if an action is supported for a specific platform
is_action_supported_for_platform() {
    local platform="$1"
    local action="$2"
    local valid_actions="${PLATFORM_ACTIONS[$platform]}"

    if [[ -z "$valid_actions" ]]; then
        return 1
    fi

    [[ " $valid_actions " =~ " $action " ]]
}

# Generate playbook from template
generate_playbook() {
    local platform="$1"
    local action="$2"
    local state="${STATE_MAP["${platform}:${action}"]}"

    # Validate that this platform:action combination is supported
    if [[ -z "$state" ]]; then
        echo "Error: Action '$action' is not supported for platform '$platform'"
        echo ""
        echo "Supported actions for $platform:"
        echo "  ${PLATFORM_ACTIONS[$platform]}"
        exit 1
    fi

    # Host must be specified for proxmox operations
    if [[ "$platform" == "proxmox_template" || "$platform" == "proxmox_vm" ]]; then
        if [[ -z "$HOST" ]]; then
            echo "Error: -h HOST is required for ${platform} operations"
            echo ""
            usage
        fi
    fi

    # Determine host parameter
    local host_param
    if [[ -n "$HOST" ]]; then
        host_param="hosts: $HOST"
    else
        host_param="hosts: ${platform}_platform"
    fi

    # Get the state variable name that the role expects
    local state_var="${STATE_VAR_NAME[$platform]}"
    if [[ -z "$state_var" ]]; then
        echo "Error: No state variable name defined for platform '$platform'"
        exit 1
    fi

    # Create playbook directly with the proper substitutions
    cat > "$TEMP_PLAYBOOK" << EOF
---
# Dynamically generated playbook
# Platform: ${platform}, Action: ${action}
- name: Manage ${platform} Platform
  $host_param
  become: true
  vars:
    ${state_var}: ${state}
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
    if [[ -n "$HOST" ]]; then
        echo "Target host: $HOST"
    else
        echo "Target hosts: ${platform}_platform (from inventory)"
    fi
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

    # Ask for confirmation
    read -p "Execute this playbook? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        echo "Operation cancelled"
        exit 0
    fi

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

# Parse command line arguments
TEMPLATE=""
while getopts "h:t:" opt; do
    case ${opt} in
        h)
            HOST=$OPTARG
            ;;
        t)
            TEMPLATE=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Shift past the options
shift $((OPTIND - 1))

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

# Validate action is supported for this platform
if ! is_action_supported_for_platform "$PLATFORM" "$ACTION"; then
    echo "Error: Action '$ACTION' is not supported for platform '$PLATFORM'"
    echo ""
    echo "Supported actions for $PLATFORM:"
    echo "  ${PLATFORM_ACTIONS[$PLATFORM]}"
    exit 1
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

# For proxmox_template platform, require either -t flag or --all-distros
if [[ "$PLATFORM" == "proxmox_template" ]]; then
    if [[ -z "$TEMPLATE" && "$ALL_DISTROS_MODE" == "false" ]]; then
        echo "Error: proxmox_template requires either -t <template> or --all-distros"
        echo ""
        usage
    fi

    # Validate template exists if specified
    if [[ -n "$TEMPLATE" ]]; then
        templates=($(discover_templates))
        template_found=false

        for tmpl in "${templates[@]}"; do
            if [[ "$tmpl" == "$TEMPLATE" ]]; then
                template_found=true
                break
            fi
        done

        if [[ "$template_found" == "false" ]]; then
            echo "Error: Template '$TEMPLATE' not found"
            echo ""
            echo "Available templates:"
            for tmpl in "${templates[@]}"; do
                echo "  - $tmpl"
            done
            exit 1
        fi

        # Add template_distribution to extra args
        EXTRA_ARGS+=("-e" "template_distribution=$TEMPLATE")
    fi
fi

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
