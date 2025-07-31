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

# Function to get current value from YAML
get_current_value() {
    local profile="$1"
    local key="$2"
    grep -A 20 "^${profile}:" "$CONFIG_FILE" | grep "^\s*${key}:" | head -1 | sed 's/.*:\s*//' | sed 's/^"//' | sed 's/"$//' | tr -d '"'
}

# Function to update YAML value
update_yaml_value() {
    local profile="$1"
    local key="$2" 
    local new_value="$3"
    
    # Create backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    
    # Use sed to update the value within the profile section
    awk -v profile="$profile" -v key="$key" -v value="$new_value" '
    BEGIN { in_profile = 0; updated = 0 }
    /^[a-z]/ { 
        if ($0 ~ "^" profile ":") {
            in_profile = 1
        } else {
            in_profile = 0
        }
    }
    in_profile && /^[[:space:]]+/ && $0 ~ key ":" {
        gsub(/^([[:space:]]+' $key '[[:space:]]*:[[:space:]]*).*/, "\\1\"" value "\"")
        updated = 1
    }
    { print }
    END { if (!updated && in_profile) print "Warning: Key not found in profile" > "/dev/stderr" }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

# Get current values
current_git_name=$(get_current_value "$PROFILE" "git_name")
current_git_email=$(get_current_value "$PROFILE" "git_email")
current_primary_user=$(get_current_value "$PROFILE" "primary_user")
current_timezone=$(get_current_value "$PROFILE" "timezone")

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
echo "Configuration updated successfully!"
echo "Profile '$PROFILE' is now ready to use."
echo ""
echo "Next steps:"
echo "  make show-config PROFILE=$PROFILE    # Review updated configuration"
echo "  make all-config NAME=myserver PROFILE=$PROFILE    # Deploy with new settings"