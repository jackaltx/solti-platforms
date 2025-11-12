#!/bin/bash
#
# Setup passwordless sudo for Proxmox commands
# Run this on your Proxmox server to enable automation without password prompts
#
# Usage:
#   ssh root@magic "bash -s" < docs/setup-passwordless-sudo.sh

set -e

USER="${1:-lavender}"
SUDOERS_FILE="/etc/sudoers.d/${USER}-proxmox"

echo "Setting up passwordless sudo for Proxmox commands..."
echo "User: $USER"
echo "File: $SUDOERS_FILE"

# Create sudoers file
cat > "$SUDOERS_FILE" << EOF
# Allow $USER to run Proxmox commands without password for automation
# This enables molecule testing and CI/CD workflows
# Created: $(date)
$USER ALL=(root) NOPASSWD: /usr/bin/pvesh, /usr/sbin/qm
EOF

# Set correct permissions
chmod 0440 "$SUDOERS_FILE"

# Validate sudoers syntax
if visudo -c -f "$SUDOERS_FILE"; then
    echo "✓ Sudoers file created and validated successfully"
    echo ""
    echo "Test with:"
    echo "  ssh $USER@$(hostname) 'sudo pvesh get /cluster/resources --type vm'"
else
    echo "✗ Sudoers file has syntax errors, removing..."
    rm -f "$SUDOERS_FILE"
    exit 1
fi
