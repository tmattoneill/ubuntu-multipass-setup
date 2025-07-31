#!/bin/bash

# Script to interactively update multipass-config.yaml
# Usage: scripts/update-config.sh [profile_name]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/multipass-config.yaml"
PROFILE="${1:-personal}"

echo "Interactive Configuration Update"
echo "================================"
echo "Profile: $PROFILE"
echo ""

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Function to get current value from YAML (fixed to handle comments)
get_current_value() {
    local profile="$1"
    local key="$2"
    # Extract value and remove comments, quotes, and extra whitespace
    grep -A 20 "^${profile}:" "$CONFIG_FILE" | grep "^\s*${key}:" | head -1 | sed 's/.*:\s*//' | sed 's/#.*//' | sed 's/^"//; s/"$//' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr -d '"'
}

# Function to update YAML value (simplified approach)
update_yaml_value() {
    local profile="$1"
    local key="$2" 
    local new_value="$3"
    
    # Create backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    
    # Use Python for more reliable YAML handling if available, otherwise use sed
    if command -v python3 >/dev/null 2>&1; then
        python3 << EOF
import re
import sys

# Read the file
with open('$CONFIG_FILE', 'r') as f:
    content = f.read()

# Find the profile section and update the key
lines = content.split('\n')
in_profile = False
updated = False

for i, line in enumerate(lines):
    # Check if we're entering the target profile
    if re.match(r'^$profile:', line):
        in_profile = True
        continue
    # Check if we're leaving the profile (entering another top-level key)
    elif re.match(r'^[a-z]', line) and in_profile:
        in_profile = False
        
    # If we're in the target profile and find the key
    if in_profile and re.match(r'^\s*$key:', line):
        # Preserve indentation
        indent = re.match(r'^(\s*)', line).group(1)
        lines[i] = f'{indent}$key: "$new_value"'
        updated = True
        break

if updated:
    with open('$CONFIG_FILE', 'w') as f:
        f.write('\n'.join(lines))
    print(f"Updated {key} in profile {profile}")
else:
    print(f"Warning: Could not find {key} in profile {profile}", file=sys.stderr)
EOF
    else
        # Fallback to sed (less reliable but works without Python)
        sed -i.bak "/^${profile}:/,/^[a-z]/ s/^\(\s*${key}:\s*\).*/\1\"${new_value}\"/" "$CONFIG_FILE"
    fi
}

# Get current values
current_git_name=$(get_current_value "$PROFILE" "git_name")
current_git_email=$(get_current_value "$PROFILE" "git_email")
current_primary_user=$(get_current_value "$PROFILE" "primary_user")
current_timezone=$(get_current_value "$PROFILE" "timezone")

# Set defaults to ubuntu to avoid issues
current_primary_user="${current_primary_user:-ubuntu}"
current_timezone="${current_timezone:-UTC}"

echo "Current values:"
echo "  Git Name: $current_git_name"
echo "  Git Email: $current_git_email"
echo "  Primary User: $current_primary_user"
echo "  Timezone: $current_timezone"
echo ""

# Interactive prompts
read -p "Enter your full name for Git commits [$current_git_name]: " new_git_name
new_git_name="${new_git_name:-$current_git_name}"

read -p "Enter your email for Git commits [$current_git_email]: " new_git_email
new_git_email="${new_git_email:-$current_git_email}"

read -p "Enter primary username [$current_primary_user]: " new_primary_user
new_primary_user="${new_primary_user:-$current_primary_user}"

read -p "Enter timezone [$current_timezone]: " new_timezone
new_timezone="${new_timezone:-$current_timezone}"

echo ""
echo "Updating configuration..."

# Update values
if [[ "$new_git_name" != "$current_git_name" ]]; then
    update_yaml_value "$PROFILE" "git_name" "$new_git_name"
    echo "✓ Updated git_name: $new_git_name"
fi

if [[ "$new_git_email" != "$current_git_email" ]]; then
    update_yaml_value "$PROFILE" "git_email" "$new_git_email"
    echo "✓ Updated git_email: $new_git_email"
fi

if [[ "$new_primary_user" != "$current_primary_user" ]]; then
    update_yaml_value "$PROFILE" "primary_user" "$new_primary_user"
    echo "✓ Updated primary_user: $new_primary_user"
fi

if [[ "$new_timezone" != "$current_timezone" ]]; then
    update_yaml_value "$PROFILE" "timezone" "$new_timezone"
    echo "✓ Updated timezone: $new_timezone"
fi

echo ""

# SSH Key configuration
echo "=== SSH Key Configuration ==="
echo "Note: If you're running this on a remote server, you'll want to specify"
echo "      your LOCAL machine's public key path to access the multipass instance."
echo ""

# Check current SSH key configuration
current_ssh_key_path=$(get_current_value "$PROFILE" "ssh_key_path")
echo "Current SSH key path: ${current_ssh_key_path:-[not set]}"

# Check if current path exists and is valid
if [[ -n "$current_ssh_key_path" && -f "${current_ssh_key_path/#\~/$HOME}" ]]; then
    local expanded_path="${current_ssh_key_path/#\~/$HOME}"
    local key_content=$(cat "$expanded_path" 2>/dev/null || echo "")
    if [[ -n "$key_content" ]]; then
        local key_comment=$(echo "$key_content" | cut -d' ' -f3 2>/dev/null || echo "[no comment]")
        echo "✅ Current SSH key is valid: $key_comment"
    fi
fi

echo ""
read -p "Do you want to update the SSH key configuration? (y/n): " update_ssh_key

if [[ "$update_ssh_key" =~ ^[Yy] ]]; then
    echo ""
    echo "SSH Key Options:"
    echo "1. Enter path to your SSH public key (e.g., ~/.ssh/id_rsa.pub)"
    echo "2. Find and use a key from this machine"
    echo "3. Generate a new SSH key pair on this machine"
    echo "4. Keep current configuration"
    
    read -p "Choose option (1/2/3/4): " ssh_key_option
    
    case "$ssh_key_option" in
        1)
            echo "Common SSH key locations:"
            echo "  ~/.ssh/id_rsa.pub"
            echo "  ~/.ssh/id_ed25519.pub"
            echo "  ~/.ssh/id_ecdsa.pub"
            read -p "Enter SSH public key path: " new_ssh_key_path
            if [[ -n "$new_ssh_key_path" ]]; then
                update_yaml_value "$PROFILE" "ssh_key_path" "$new_ssh_key_path"
                echo "✓ Updated ssh_key_path: $new_ssh_key_path"
            fi
            ;;
        2)
            # Find keys on this machine
            local key_types=("id_ed25519" "id_rsa" "id_ecdsa")
            local found_keys=()
            
            for key_type in "${key_types[@]}"; do
                if [[ -f "$HOME/.ssh/${key_type}.pub" ]]; then
                    found_keys+=("${key_type}.pub")
                fi
            done
            
            if [[ ${#found_keys[@]} -gt 0 ]]; then
                echo "Found SSH public keys on this machine:"
                for i in "${!found_keys[@]}"; do
                    echo "  $((i+1)). ~/.ssh/${found_keys[$i]}"
                done
                
                read -p "Choose key (1-${#found_keys[@]}): " key_choice
                
                if [[ "$key_choice" -ge 1 && "$key_choice" -le ${#found_keys[@]} ]]; then
                    local selected_key="~/.ssh/${found_keys[$((key_choice-1))]}"
                    update_yaml_value "$PROFILE" "ssh_key_path" "$selected_key"
                    echo "✓ Updated ssh_key_path: $selected_key"
                fi
            else
                echo "No SSH keys found on this machine."
            fi
            ;;
        3)
            echo "Generating new SSH key pair..."
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"
            
            local new_key_path="$HOME/.ssh/id_ed25519"
            local key_comment="${new_git_email:-$USER@$(hostname)}"
            
            if ssh-keygen -t ed25519 -f "$new_key_path" -C "$key_comment" -N "" > /dev/null 2>&1; then
                echo "✅ SSH key pair generated successfully!"
                echo "   Private key: ${new_key_path}"
                echo "   Public key: ${new_key_path}.pub"
                
                update_yaml_value "$PROFILE" "ssh_key_path" "${new_key_path}.pub"
                echo "✓ Updated ssh_key_path to use new key"
            else
                echo "❌ Failed to generate SSH key"
            fi
            ;;
        4)
            echo "Keeping current SSH key configuration"
            ;;
        *)
            echo "Invalid option. Keeping current configuration."
            ;;
    esac
fi

echo ""
echo "Configuration updated successfully!"
echo "Profile '$PROFILE' is now ready to use."
echo ""
echo "Next steps:"
echo "  make show-config PROFILE=$PROFILE    # Review updated configuration"
echo "  make all-config NAME=myserver PROFILE=$PROFILE    # Deploy with new settings"