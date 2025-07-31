#!/bin/bash

# Script to load configuration from multipass-config.yaml
# Usage: source scripts/load-config.sh [profile_name]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/multipass-config.yaml"

# Default profile name
PROFILE="${1:-default}"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Warning: Configuration file not found: $CONFIG_FILE"
    echo "Using built-in defaults"
    return 1
fi

# Function to extract value from YAML config
get_config_value() {
    local profile="$1"
    local key="$2"
    local default_value="$3"
    
    # Try to get value from specified profile first
    local value
    value=$(grep -A 20 "^${profile}:" "$CONFIG_FILE" | grep "^\s*${key}:" | head -1 | sed 's/.*:\s*//' | sed 's/^"//' | sed 's/"$//' | tr -d '"')
    
    # If not found and profile isn't default, try default profile
    if [[ -z "$value" && "$profile" != "default" ]]; then
        value=$(grep -A 20 "^default:" "$CONFIG_FILE" | grep "^\s*${key}:" | head -1 | sed 's/.*:\s*//' | sed 's/^"//' | sed 's/"$//' | tr -d '"')
    fi
    
    # Use provided default if still empty
    if [[ -z "$value" ]]; then
        value="$default_value"
    fi
    
    echo "$value"
}

# Load configuration values
export MULTIPASS_CPUS=$(get_config_value "$PROFILE" "cpus" "2")
export MULTIPASS_MEMORY=$(get_config_value "$PROFILE" "memory" "4G")
export MULTIPASS_DISK=$(get_config_value "$PROFILE" "disk" "20G")

export SETUP_PRIMARY_USER=$(get_config_value "$PROFILE" "primary_user" "ubuntu")
export SETUP_GIT_NAME=$(get_config_value "$PROFILE" "git_name" "")
export SETUP_GIT_EMAIL=$(get_config_value "$PROFILE" "git_email" "")
export SETUP_HOSTNAME=$(get_config_value "$PROFILE" "hostname" "auto")
export SETUP_TIMEZONE=$(get_config_value "$PROFILE" "timezone" "UTC")
export SETUP_MODE=$(get_config_value "$PROFILE" "installation_mode" "full")
export SETUP_SSH_KEY_PATH=$(get_config_value "$PROFILE" "ssh_key_path" "~/.ssh/id_rsa.pub")

# Expand tilde in SSH key path
if [[ "$SETUP_SSH_KEY_PATH" =~ ^~ ]]; then
    SETUP_SSH_KEY_PATH="${SETUP_SSH_KEY_PATH/#\~/$HOME}"
fi

# Load SSH public key content if file exists
if [[ -f "$SETUP_SSH_KEY_PATH" ]]; then
    export SETUP_SSH_PUBLIC_KEY=$(cat "$SETUP_SSH_KEY_PATH" 2>/dev/null || echo "")
    SSH_KEY_STATUS="✓ Found"
else
    # Check for any SSH keys in ~/.ssh/
    found_key=""
    key_types=("id_ed25519" "id_rsa" "id_ecdsa")
    
    for key_type in "${key_types[@]}"; do
        key_path="${HOME}/.ssh/${key_type}.pub"
        if [[ -f "$key_path" ]]; then
            export SETUP_SSH_PUBLIC_KEY=$(cat "$key_path" 2>/dev/null || echo "")
            export SETUP_SSH_KEY_PATH="$key_path"
            SSH_KEY_STATUS="✓ Found alternative ($key_type)"
            found_key="yes"
            break
        fi
    done
    
    if [[ -z "$found_key" ]]; then
        export SETUP_SSH_PUBLIC_KEY=""
        SSH_KEY_STATUS="⚠ Not found"
    fi
fi

# Show loaded configuration
echo "Loaded configuration profile: $PROFILE"
echo "  CPUs: $MULTIPASS_CPUS"
echo "  Memory: $MULTIPASS_MEMORY" 
echo "  Disk: $MULTIPASS_DISK"
echo "  Primary User: $SETUP_PRIMARY_USER"
echo "  Git Name: $SETUP_GIT_NAME"
echo "  Git Email: $SETUP_GIT_EMAIL"
echo "  Hostname: $SETUP_HOSTNAME"
echo "  Timezone: $SETUP_TIMEZONE"
echo "  Mode: $SETUP_MODE"
echo "  SSH Key: $SETUP_SSH_KEY_PATH ($SSH_KEY_STATUS)"