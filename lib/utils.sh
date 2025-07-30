#!/usr/bin/env bash

# Secure Utility Functions for Ubuntu Server Setup Script
# Production-ready helper functions with proper security and error handling

# Global variables
readonly SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}"
readonly TEMP_DIR="${TEMP_DIR:-/tmp/setup-$$}"
readonly BACKUP_DIR="${BACKUP_DIR:-/var/backups/server-setup}"

# Exit codes
readonly E_SUCCESS=0
readonly E_GENERAL=1
readonly E_MISUSE=2
readonly E_PERMISSION=13
readonly E_NOTFOUND=127

# Setup cleanup and error handling
setup_error_handling() {
    set -euo pipefail
    trap 'cleanup_on_exit $?' EXIT
    trap 'log_error "Script interrupted by user"; exit 130' INT TERM
}

# Cleanup function
cleanup_on_exit() {
    local exit_code=$1
    cleanup_temp_files
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code: $exit_code"
    fi
}

# Load required dependencies with proper error handling
load_dependencies() {
    local dependencies=(
        "${SCRIPT_DIR}/../config.sh"
        "${SCRIPT_DIR}/logging.sh"
    )
    
    for dep in "${dependencies[@]}"; do
        if [[ -f "$dep" ]]; then
            # shellcheck source=/dev/null
            source "$dep"
        else
            # Don't fail hard for backward compatibility
            echo "WARNING: Dependency not found: $dep" >&2
        fi
    done
    
    # Don't require logging functions for backward compatibility
    return $E_SUCCESS
}

# Input validation functions
validate_path() {
    local path="$1"
    local allow_absolute="${2:-true}"
    
    # Check for empty path
    if [[ -z "$path" ]]; then
        log_error "Empty path provided"
        return $E_MISUSE
    fi
    
    # Prevent path traversal attacks
    if [[ "$path" =~ \.\./|\.\.\\ ]]; then
        log_error "Path traversal detected: $path"
        return $E_PERMISSION
    fi
    
    # Protect critical system files
    local restricted_paths=(
        "/etc/shadow"
        "/etc/passwd"
        "/etc/gshadow"
        "/boot/"
        "/sys/"
        "/proc/"
    )
    
    for restricted in "${restricted_paths[@]}"; do
        if [[ "$path" == "$restricted"* ]]; then
            log_error "Access to restricted path denied: $path"
            return $E_PERMISSION
        fi
    done
    
    # Check absolute path requirement
    if [[ "$allow_absolute" != "true" ]] && [[ "$path" == /* ]]; then
        log_error "Absolute paths not allowed: $path"
        return $E_MISUSE
    fi
    
    return $E_SUCCESS
}

validate_username() {
    local username="$1"
    
    # Check basic format (POSIX username rules)
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || [[ ${#username} -gt 32 ]]; then
        log_error "Invalid username format: $username"
        return $E_MISUSE
    fi
    
    # Check for reserved usernames
    local reserved_users=(
        "root" "daemon" "bin" "sys" "sync" "games" "man" "lp"
        "mail" "news" "uucp" "proxy" "www-data" "backup" "list"
        "irc" "gnats" "nobody" "systemd-network" "systemd-resolve"
    )
    
    for reserved in "${reserved_users[@]}"; do
        if [[ "$username" == "$reserved" ]]; then
            log_error "Username is reserved: $username"
            return $E_PERMISSION
        fi
    done
    
    return $E_SUCCESS
}

validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ $port -lt 1 ]] || [[ $port -gt 65535 ]]; then
        log_error "Invalid port number: $port"
        return $E_MISUSE
    fi
    
    # Check for privileged ports
    if [[ $port -lt 1024 ]] && ! is_root; then
        log_error "Privileged port requires root access: $port"
        return $E_PERMISSION
    fi
    
    return $E_SUCCESS
}

# System check functions
is_root() {
    [[ $EUID -eq 0 ]]
}

require_root() {
    if ! is_root; then
        log_error "This operation requires root privileges"
        log_info "Please run with sudo: sudo $0 $*"
        exit $E_PERMISSION
    fi
}

user_exists() {
    local username="$1"
    # Skip validation for backward compatibility - just check existence
    [[ -n "$username" ]] && id "$username" &>/dev/null
}

group_exists() {
    local groupname="$1"
    [[ -n "$groupname" ]] && getent group "$groupname" &>/dev/null
}

command_exists() {
    local cmd="$1"
    [[ -n "$cmd" ]] && command -v "$cmd" &>/dev/null
}

package_installed() {
    local package="$1"
    [[ -n "$package" ]] && dpkg -l "$package" 2>/dev/null | grep -q "^ii"
}

service_running() {
    local service="$1"
    [[ -n "$service" ]] && systemctl is-active --quiet "$service" 2>/dev/null
}

service_enabled() {
    local service="$1"
    [[ -n "$service" ]] && systemctl is-enabled --quiet "$service" 2>/dev/null
}

port_open() {
    local port="$1"
    local host="${2:-127.0.0.1}"
    
    # Skip strict validation for backward compatibility
    if [[ -n "$port" ]] && [[ "$port" =~ ^[0-9]+$ ]]; then
        timeout 5 bash -c "exec 3<>/dev/tcp/$host/$port" &>/dev/null
    else
        return 1
    fi
}

# Secure file operations
create_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    local owner="${3:-}"
    local group="${4:-}"
    
    # Convert to octal if not already
    if [[ "$permissions" =~ ^[0-9]{3}$ ]]; then
        permissions="0$permissions"
    fi
    
    validate_path "$dir_path" || return $?
    
    if [[ -d "$dir_path" ]]; then
        log_debug "Directory already exists: $dir_path"
        return $E_SUCCESS
    fi
    
    log_debug "Creating directory: $dir_path"
    
    if ! mkdir -p "$dir_path"; then
        log_error "Failed to create directory: $dir_path"
        return $E_GENERAL
    fi
    
    # Set permissions
    if ! chmod "$permissions" "$dir_path"; then
        log_error "Failed to set permissions on directory: $dir_path"
        return $E_GENERAL
    fi
    
    # Set ownership if specified
    if [[ -n "$owner" ]]; then
        local ownership="$owner"
        [[ -n "$group" ]] && ownership="$owner:$group"
        
        if ! chown "$ownership" "$dir_path"; then
            log_error "Failed to set ownership on directory: $dir_path"
            return $E_GENERAL
        fi
    fi
    
    log_success "Directory created: $dir_path"
    return $E_SUCCESS
}

create_file() {
    local file_path="$1"
    local content="$2"
    local permissions="${3:-644}"
    local owner="${4:-}"
    local group="${5:-}"
    
    # Convert to octal if not already
    if [[ "$permissions" =~ ^[0-9]{3}$ ]]; then
        permissions="0$permissions"
    fi
    
    validate_path "$file_path" || return $?
    
    local dir_path
    dir_path=$(dirname "$file_path")
    
    # Create parent directory if needed
    if [[ ! -d "$dir_path" ]]; then
        create_directory "$dir_path" || return $?
    fi
    
    # Backup existing file only if BACKUP_BEFORE_MODIFY is set
    if [[ -f "$file_path" ]] && [[ "${BACKUP_BEFORE_MODIFY:-false}" == "true" ]]; then
        log_debug "Backing up existing file: $file_path"
        backup_file "$file_path" || {
            log_warning "Failed to backup existing file: $file_path"
            # Continue anyway for backward compatibility
        }
    fi
    
    log_debug "Creating file: $file_path"
    
    # Create file atomically using temporary file
    local temp_file="${file_path}.tmp.$$"
    
    if ! echo "$content" > "$temp_file"; then
        log_error "Failed to write content to temporary file"
        rm -f "$temp_file" 2>/dev/null
        return $E_GENERAL
    fi
    
    # Set permissions on temp file
    if ! chmod "$permissions" "$temp_file"; then
        log_error "Failed to set permissions on file: $file_path"
        rm -f "$temp_file" 2>/dev/null
        return $E_GENERAL
    fi
    
    # Set ownership if specified
    if [[ -n "$owner" ]]; then
        local ownership="$owner"
        [[ -n "$group" ]] && ownership="$owner:$group"
        
        if ! chown "$ownership" "$temp_file"; then
            log_error "Failed to set ownership on file: $file_path"
            rm -f "$temp_file" 2>/dev/null
            return $E_GENERAL
        fi
    fi
    
    # Atomic move
    if ! mv "$temp_file" "$file_path"; then
        log_error "Failed to move file to final location: $file_path"
        rm -f "$temp_file" 2>/dev/null
        return $E_GENERAL
    fi
    
    log_success "File created: $file_path"
    return $E_SUCCESS
}

backup_file() {
    local file_path="$1"
    local backup_dir="${2:-$BACKUP_DIR/configs}"
    
    validate_path "$file_path" || return $?
    
    if [[ ! -f "$file_path" ]]; then
        log_debug "File does not exist, cannot backup: $file_path"
        return $E_SUCCESS
    fi
    
    create_directory "$backup_dir" || return $?
    
    local filename
    filename=$(basename "$file_path")
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="$backup_dir/${filename}.${timestamp}.bak"
    
    log_debug "Backing up file: $file_path -> $backup_path"
    
    if ! cp -p "$file_path" "$backup_path"; then
        log_error "Failed to backup file: $file_path"
        return $E_GENERAL
    fi
    
    log_success "File backed up: $backup_path"
    echo "$backup_path"
    return $E_SUCCESS
}

restore_file() {
    local backup_path="$1"
    local original_path="$2"
    
    validate_path "$backup_path" || return $?
    validate_path "$original_path" || return $?
    
    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup file not found: $backup_path"
        return $E_NOTFOUND
    fi
    
    log_debug "Restoring file: $backup_path -> $original_path"
    
    if ! cp -p "$backup_path" "$original_path"; then
        log_error "Failed to restore file: $original_path"
        return $E_GENERAL
    fi
    
    log_success "File restored: $original_path"
    return $E_SUCCESS
}

# Secure password generation with backward compatibility
generate_password() {
    local length="${1:-16}"
    local charset_or_special="${2:-true}"
    
    # Validate length
    if [[ ! "$length" =~ ^[0-9]+$ ]] || [[ $length -lt 8 ]] || [[ $length -gt 128 ]]; then
        log_error "Invalid password length: $length (must be 8-128)"
        return $E_MISUSE
    fi
    
    # Handle backward compatibility for charset parameter
    local charset
    if [[ "$charset_or_special" == "true" ]] || [[ "$charset_or_special" == "false" ]]; then
        # New boolean format
        charset="A-Za-z0-9"
        if [[ "$charset_or_special" == "true" ]]; then
            charset="${charset}@#%^&*()_+-=[]{}|;:,.<>?"
        fi
    else
        # Old charset format - use as provided
        charset="$charset_or_special"
    fi
    
    if command_exists "openssl"; then
        # Use OpenSSL for secure random generation
        openssl rand -base64 $((length * 2)) | tr -d "=+/\n" | tr -dc "$charset" | head -c "$length"
    elif [[ -r /dev/urandom ]]; then
        # Fallback to /dev/urandom
        tr -dc "$charset" < /dev/urandom | head -c "$length"
    else
        log_error "No secure random source available"
        return $E_GENERAL
    fi
    
    echo  # Add newline
    return $E_SUCCESS
}

# System checkpoint and restore
create_restore_point() {
    local checkpoint_name="$1"
    
    if [[ -z "$checkpoint_name" ]] || [[ ! "$checkpoint_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid checkpoint name: $checkpoint_name"
        return $E_MISUSE
    fi
    
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$BACKUP_DIR/checkpoints/${checkpoint_name}-${timestamp}"
    local manifest_file="$backup_dir/manifest.json"
    
    log_info "Creating restore point: $checkpoint_name"
    
    create_directory "$backup_dir" || return $?
    
    # Create manifest in JSON format for better parsing
    cat > "$manifest_file" << EOF
{
    "checkpoint_name": "$checkpoint_name",
    "timestamp": "$timestamp",
    "date": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "backed_up_files": [],
    "installed_packages": "installed-packages.txt",
    "enabled_services": "enabled-services.txt"
}
EOF
    
    # Backup critical configuration files
    local config_files=(
        "/etc/passwd"
        "/etc/group"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
        "/etc/nginx/nginx.conf"
        "/etc/systemd/system.conf"
        "/etc/crontab"
    )
    
    local backed_up_files=()
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            local backup_path
            if backup_path=$(backup_file "$file" "$backup_dir"); then
                backed_up_files+=("$file")
                log_debug "Backed up: $file"
            fi
        fi
    done
    
    # Update manifest with backed up files
    local files_json
    files_json=$(printf '%s\n' "${backed_up_files[@]}" | jq -R . | jq -s .)
    jq --argjson files "$files_json" '.backed_up_files = $files' "$manifest_file" > "$manifest_file.tmp" && mv "$manifest_file.tmp" "$manifest_file"
    
    # Record system state
    dpkg -l > "$backup_dir/installed-packages.txt" 2>/dev/null || true
    systemctl list-unit-files --type=service --state=enabled > "$backup_dir/enabled-services.txt" 2>/dev/null || true
    
    log_success "Restore point created: $backup_dir"
    echo "$backup_dir"
    return $E_SUCCESS
}

rollback_module() {
    local module_name="$1"
    
    if [[ -z "$module_name" ]]; then
        log_error "Module name required for rollback"
        return $E_MISUSE
    fi
    
    # Find most recent checkpoint for this module
    local checkpoint_dir
    checkpoint_dir=$(find "$BACKUP_DIR/checkpoints" -name "${module_name}-*" -type d | sort -r | head -1)
    
    if [[ -z "$checkpoint_dir" ]] || [[ ! -d "$checkpoint_dir" ]]; then
        log_error "No restore point found for module: $module_name"
        return $E_NOTFOUND
    fi
    
    log_warning "Rolling back module: $module_name"
    log_warning "Using checkpoint: $(basename "$checkpoint_dir")"
    
    if ! prompt_user "Continue with rollback? This cannot be undone" "n"; then
        log_info "Rollback cancelled by user"
        return $E_SUCCESS
    fi
    
    local manifest_file="$checkpoint_dir/manifest.json"
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Checkpoint manifest not found: $manifest_file"
        return $E_GENERAL
    fi
    
    # Restore files from manifest
    local files
    if command_exists "jq"; then
        files=$(jq -r '.backed_up_files[]' "$manifest_file" 2>/dev/null)
    else
        log_error "jq required for rollback operations"
        return $E_NOTFOUND
    fi
    
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            local backup_file
            backup_file=$(find "$checkpoint_dir" -name "$(basename "$file").*.bak" | head -1)
            if [[ -f "$backup_file" ]]; then
                log_info "Restoring: $file"
                restore_file "$backup_file" "$file" || log_warning "Failed to restore: $file"
            fi
        fi
    done <<< "$files"
    
    log_success "Rollback completed for module: $module_name"
    log_warning "Please verify system state and restart affected services"
    return $E_SUCCESS
}

# Secure download function
download_file() {
    local url="$1"
    local destination="$2"
    local expected_checksum="${3:-}"
    local max_retries="${4:-3}"
    
    # Handle backward compatibility - old param was 'checksum', new is 'expected_checksum'
    # But since it's the same position, no change needed
    
    validate_path "$destination" || return $?
    
    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Invalid URL format: $url"
        return $E_MISUSE
    fi
    
    # Create destination directory
    local dest_dir
    dest_dir=$(dirname "$destination")
    create_directory "$dest_dir" || return $?
    
    log_debug "Downloading: $url -> $destination"
    
    local attempt=1
    local temp_file="${destination}.tmp.$$"
    
    while [[ $attempt -le $max_retries ]]; do
        log_debug "Download attempt $attempt/$max_retries"
        
        # Download to temporary file
        if curl -fsSL --connect-timeout 30 --max-time 300 -o "$temp_file" "$url"; then
            # Verify checksum if provided
            if [[ -n "$expected_checksum" ]]; then
                local file_checksum
                file_checksum=$(sha256sum "$temp_file" | cut -d' ' -f1)
                if [[ "$file_checksum" == "$expected_checksum" ]]; then
                    # Move to final destination
                    if mv "$temp_file" "$destination"; then
                        log_success "Downloaded and verified: $destination"
                        return $E_SUCCESS
                    else
                        log_error "Failed to move downloaded file to destination"
                        rm -f "$temp_file" 2>/dev/null
                        return $E_GENERAL
                    fi
                else
                    log_error "Checksum verification failed for $destination"
                    log_error "Expected: $expected_checksum"
                    log_error "Got: $file_checksum"
                    rm -f "$temp_file" 2>/dev/null
                    return $E_GENERAL
                fi
            else
                # No checksum verification, just move file
                if mv "$temp_file" "$destination"; then
                    log_success "Downloaded: $destination"
                    return $E_SUCCESS
                else
                    log_error "Failed to move downloaded file to destination"
                    rm -f "$temp_file" 2>/dev/null
                    return $E_GENERAL
                fi
            fi
        else
            log_warning "Download attempt $attempt failed: $url"
            rm -f "$temp_file" 2>/dev/null
            
            if [[ $attempt -lt $max_retries ]]; then
                local delay=$((attempt * 5))
                log_info "Retrying in $delay seconds..."
                sleep "$delay"
            fi
            ((attempt++))
        fi
    done
    
    log_error "Failed to download after $max_retries attempts: $url"
    return $E_GENERAL
}

# Robust command execution
execute_with_retry() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local delay="${3:-5}"
    local description="${4:-command}"
    
    if [[ -z "$cmd" ]]; then
        log_error "No command provided for execution"
        return $E_MISUSE
    fi
    
    local attempt=1
    while [[ $attempt -le $max_retries ]]; do
        log_debug "Executing $description (attempt $attempt/$max_retries)"
        
        if eval "$cmd"; then
            log_success "$description completed successfully"
            return $E_SUCCESS
        else
            local exit_code=$?
            log_warning "$description failed with exit code $exit_code (attempt $attempt/$max_retries)"
            
            if [[ $attempt -lt $max_retries ]]; then
                log_info "Retrying in $delay seconds..."
                sleep "$delay"
            fi
            ((attempt++))
        fi
    done
    
    log_error "$description failed after $max_retries attempts"
    return $E_GENERAL
}

# Service management
wait_for_service() {
    local service="$1"
    local timeout="${2:-30}"  # Keep original 30s default
    local interval="${3:-2}"
    
    if [[ -z "$service" ]]; then
        log_error "Service name required"
        return $E_MISUSE
    fi
    
    log_info "Waiting for service to be ready: $service"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if service_running "$service"; then
            log_success "Service is ready: $service"
            return $E_SUCCESS
        fi
        
        sleep "$interval"
        ((elapsed += interval))
        
        if [[ $((elapsed % 15)) -eq 0 ]]; then
            log_debug "Still waiting for service: $service ($elapsed/${timeout}s)"
        fi
    done
    
    log_error "Service not ready after ${timeout}s: $service"
    systemctl status "$service" --no-pager -l || true
    return $E_GENERAL
}

wait_for_port() {
    local port="$1"
    local host="${2:-localhost}"  # Keep original localhost default
    local timeout="${3:-30}"     # Keep original 30s default
    local interval="${4:-2}"
    
    validate_port "$port" || return $?
    
    log_info "Waiting for port to be open: $host:$port"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if port_open "$port" "$host"; then
            log_success "Port is open: $host:$port"
            return $E_SUCCESS
        fi
        
        sleep "$interval"
        ((elapsed += interval))
        
        if [[ $((elapsed % 15)) -eq 0 ]]; then
            log_debug "Still waiting for port: $host:$port ($elapsed/${timeout}s)"
        fi
    done
    
    log_error "Port not open after ${timeout}s: $host:$port"
    return $E_GENERAL
}

# System information
get_system_info() {
    local info_type="$1"
    
    case "$info_type" in
        "os")
            if command_exists "lsb_release"; then
                lsb_release -si 2>/dev/null
            elif [[ -f /etc/os-release ]]; then
                grep '^NAME=' /etc/os-release | cut -d'"' -f2
            else
                echo "Unknown"
            fi
            ;;
        "version")
            if command_exists "lsb_release"; then
                lsb_release -sr 2>/dev/null
            elif [[ -f /etc/os-release ]]; then
                grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2
            else
                echo "Unknown"
            fi
            ;;
        "codename")
            if command_exists "lsb_release"; then
                lsb_release -sc 2>/dev/null
            else
                echo "Unknown"
            fi
            ;;
        "arch")
            uname -m
            ;;
        "kernel")
            uname -r
            ;;
        "hostname")
            hostname -f 2>/dev/null || hostname
            ;;
        "ip")
            ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "Unknown"
            ;;
        "memory")
            awk '/MemTotal/ {printf "%.1fGB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "Unknown"
            ;;
        "disk")
            df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "Unknown"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# User interaction
prompt_user() {
    local message="$1"
    local default="${2:-n}"
    
    # Auto-confirm if requested
    if [[ "${ASSUME_YES:-false}" == "true" ]] || [[ "${SETUP_ASSUME_YES:-false}" == "true" ]]; then
        log_info "$message [auto-confirmed: yes]"
        return $E_SUCCESS
    fi
    
    local prompt_suffix
    case "${default,,}" in
        y|yes)
            prompt_suffix=" [Y/n]"
            ;;
        *)
            prompt_suffix=" [y/N]"
            ;;
    esac
    
    while true; do
        echo -n "$message$prompt_suffix " >&2
        read -r response
        
        # Use default if empty response
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "${response,,}" in
            y|yes)
                return $E_SUCCESS
                ;;
            n|no)
                return $E_GENERAL
                ;;
            *)
                echo "Please answer 'yes' or 'no'." >&2
                ;;
        esac
    done
}

get_user_input() {
    local prompt="$1"
    local validation_regex="${2:-.*}"
    local error_message="${3:-Invalid input. Please try again.}"
    local default="${4:-}"
    local max_attempts="${5:-3}"
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if [[ -n "$default" ]]; then
            echo -n "$prompt [$default]: " >&2
        else
            echo -n "$prompt: " >&2
        fi
        
        read -r input
        
        # Use default if empty
        if [[ -z "$input" ]] && [[ -n "$default" ]]; then
            input="$default"
        fi
        
        # Validate input
        if [[ "$input" =~ $validation_regex ]]; then
            echo "$input"
            return $E_SUCCESS
        else
            echo "$error_message" >&2
            ((attempt++))
        fi
    done
    
    log_error "Maximum input attempts exceeded"
    return $E_MISUSE
}

# User and group management
add_user_to_group() {
    local username="$1"
    local groupname="$2"
    
    validate_username "$username" || return $?
    
    if ! user_exists "$username"; then
        log_error "User does not exist: $username"
        return $E_NOTFOUND
    fi
    
    if ! group_exists "$groupname"; then
        log_error "Group does not exist: $groupname"
        return $E_NOTFOUND
    fi
    
    # Check if user is already in group
    if groups "$username" | grep -q "\b$groupname\b"; then
        log_debug "User $username already in group $groupname"
        return $E_SUCCESS
    fi
    
    if usermod -a -G "$groupname" "$username"; then
        log_success "Added user $username to group $groupname"
        return $E_SUCCESS
    else
        log_error "Failed to add user $username to group $groupname"
        return $E_GENERAL
    fi
}

# Systemd service management
create_systemd_service() {
    local service_name="$1"
    local service_content="$2"
    
    if [[ -z "$service_name" ]] || [[ -z "$service_content" ]]; then
        log_error "Service name and content are required"
        return $E_MISUSE
    fi
    
    # Validate service name
    if [[ ! "$service_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid service name: $service_name"
        return $E_MISUSE
    fi
    
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log_debug "Creating systemd service: $service_name"
    
    if create_file "$service_file" "$service_content" "0644"; then
        if systemctl daemon-reload; then
            log_success "Systemd service created: $service_name"
            return $E_SUCCESS
        else
            log_error "Failed to reload systemd daemon"
            return $E_GENERAL
        fi
    else
        log_error "Failed to create systemd service file: $service_name"
        return $E_GENERAL
    fi
}

# File permission management
set_permissions_recursive() {
    local path="$1"
    local file_perms="${2:-0644}"
    local dir_perms="${3:-0755}"
    local owner="${4:-}"
    
    validate_path "$path" || return $?
    
    if [[ ! -e "$path" ]]; then
        log_error "Path does not exist: $path"
        return $E_NOTFOUND
    fi
    
    log_debug "Setting recursive permissions: $path"
    
    # Set ownership if specified
    if [[ -n "$owner" ]]; then
        if ! chown -R "$owner" "$path"; then
            log_error "Failed to set ownership: $path"
            return $E_GENERAL
        fi
    fi
    
    # Set directory permissions
    if ! find "$path" -type d -exec chmod "$dir_perms" {} \;; then
        log_error "Failed to set directory permissions: $path"
        return $E_GENERAL
    fi
    
    # Set file permissions
    if ! find "$path" -type f -exec chmod "$file_perms" {} \;; then
        log_error "Failed to set file permissions: $path"
        return $E_GENERAL
    fi
    
    log_success "Permissions set recursively: $path"
    return $E_SUCCESS
}

# System utility functions
cleanup_temp_files() {
    # Clean up our temp directory
    if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
        log_debug "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    # Clean up stale temp files older than 24 hours
    find /tmp -name "setup-*" -type f -mtime +1 -delete 2>/dev/null || true
}

bytes_to_human() {
    local bytes="$1"
    
    if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        echo "Invalid"
        return $E_MISUSE
    fi
    
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local unit=0
    local size=$bytes
    
    while [[ $size -ge 1024 ]] && [[ $unit -lt $((${#units[@]} - 1)) ]]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    printf "%.1f%s" "$size" "${units[$unit]}"
}

format_duration() {
    local duration="$1"
    
    if [[ ! "$duration" =~ ^[0-9]+$ ]]; then
        echo "Invalid duration"
        return $E_MISUSE
    fi
    
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" "$hours" "$minutes" "$seconds"
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" "$minutes" "$seconds"
    else
        printf "%ds" "$seconds"
    fi
}

# System detection
is_container() {
    [[ -f /.dockerenv ]] || \
    [[ -f /run/.containerenv ]] || \
    grep -q container /proc/1/cgroup 2>/dev/null
}

is_vm() {
    if command_exists "systemd-detect-virt"; then
        systemd-detect-virt -q
    elif [[ -f /sys/class/dmi/id/product_name ]]; then
        grep -qi "virtual\|vmware\|qemu\|kvm\|xen\|hyperv" /sys/class/dmi/id/product_name 2>/dev/null
    else
        return 1
    fi
}

get_available_memory() {
    awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0"
}

get_cpu_cores() {
    nproc 2>/dev/null || echo "1"
}

reboot_required() {
    [[ -f /var/run/reboot-required ]]
}

# Installation report generation - backward compatible
generate_final_report() {
    local start_time="$1"
    local end_time="$2"
    local duration="$3"
    shift 3
    
    # Handle both old and new argument formats
    local successful_modules=()
    local failed_modules=()
    local in_failed_section=false
    
    # Check if using new format (with --failed separator)
    local has_failed_separator=false
    for arg in "$@"; do
        if [[ "$arg" == "--failed" ]]; then
            has_failed_separator=true
            break
        fi
    done
    
    if [[ "$has_failed_separator" == true ]]; then
        # New format: mod1 mod2 --failed mod3 mod4
        for arg in "$@"; do
            if [[ "$arg" == "--failed" ]]; then
                in_failed_section=true
            elif [[ "$in_failed_section" == true ]]; then
                failed_modules+=("$arg")
            else
                successful_modules+=("$arg")
            fi
        done
    else
        # Old format: assume all modules succeeded (backward compatibility)
        successful_modules=("$@")
    fi
    
    local report_file="$BACKUP_DIR/installation-report-$(date +%Y%m%d-%H%M%S).txt"
    create_directory "$(dirname "$report_file")" || return $?
    
    # Generate comprehensive report
    {
        echo "================================================================"
        echo "             UBUNTU SERVER SETUP - INSTALLATION REPORT"
        echo "================================================================"
        echo
        echo "Installation Summary:"
        echo "  Start Time: $(date -d "@$start_time" '+%Y-%m-%d %H:%M:%S %Z')"
        echo "  End Time: $(date -d "@$end_time" '+%Y-%m-%d %H:%M:%S %Z')"
        echo "  Duration: $(format_duration "$duration")"
        echo "  Total Modules: $((${#successful_modules[@]} + ${#failed_modules[@]}))"
        echo
        
        if [[ ${#successful_modules[@]} -gt 0 ]]; then
            echo "✓ Successful Modules (${#successful_modules[@]}):"
            for module in "${successful_modules[@]}"; do
                echo "    • $module"
            done
            echo
        fi
        
        if [[ ${#failed_modules[@]} -gt 0 ]]; then
            echo "✗ Failed Modules (${#failed_modules[@]}):"
            for module in "${failed_modules[@]}"; do
                echo "    • $module"
            done
            echo
        fi
        
        echo "System Information:"
        echo "  Operating System: $(get_system_info 'os') $(get_system_info 'version')"
        echo "  Kernel: $(get_system_info 'kernel')"
        echo "  Architecture: $(get_system_info 'arch')"
        echo "  Hostname: $(get_system_info 'hostname')"
        echo "  IP Address: $(get_system_info 'ip')"
        echo "  Memory: $(get_system_info 'memory')"
        echo "  Available Disk: $(get_system_info 'disk')"
        echo "  CPU Cores: $(get_cpu_cores)"
        echo "  Container: $(is_container && echo "Yes" || echo "No")"
        echo "  Virtual Machine: $(is_vm && echo "Yes" || echo "No")"
        echo
        
        if reboot_required; then
            echo "⚠️  REBOOT REQUIRED"
            echo "   System requires reboot to complete installation"
            echo
        fi
        
        echo "Files and Logs:"
        echo "  Installation Log: ${LOG_FILE:-/var/log/server-setup.log}"
        echo "  Report File: $report_file"
        echo "  Backup Directory: $BACKUP_DIR"
        echo
        echo "Next Steps:"
        if [[ ${#failed_modules[@]} -gt 0 ]]; then
            echo "  1. Review failed modules and their logs"
            echo "  2. Address any configuration issues"
            echo "  3. Re-run failed modules if needed"
        fi
        if reboot_required; then
            echo "  4. Reboot the system: sudo reboot"
        fi
        echo "  5. Verify all services are running correctly"
        echo "  6. Update system documentation"
        echo
        echo "================================================================"
        echo "Report generated: $(date)"
        echo "================================================================"
    } | tee "$report_file"
    
    log_info "Installation report saved: $report_file"
    return $E_SUCCESS
}

# Environment validation
validate_environment() {
    local errors=0
    
    log_info "Validating environment..."
    
    # Check required commands
    local required_commands=("curl" "systemctl" "dpkg" "awk" "grep" "find")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command missing: $cmd"
            ((errors++))
        fi
    done
    
    # Check system requirements
    local min_memory=512  # MB
    local available_memory
    available_memory=$(get_available_memory)
    if [[ $available_memory -lt $min_memory ]]; then
        log_error "Insufficient memory: ${available_memory}MB (minimum: ${min_memory}MB)"
        ((errors++))
    fi
    
    # Check disk space (minimum 1GB free)
    local available_space
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # 1GB in KB
        log_error "Insufficient disk space: $(bytes_to_human $((available_space * 1024)))"
        ((errors++))
    fi
    
    # Test write permissions
    local test_file="/tmp/setup-test-$$"
    if ! touch "$test_file" 2>/dev/null; then
        log_error "Cannot write to /tmp directory"
        ((errors++))
    else
        rm -f "$test_file"
    fi
    
    # Check internet connectivity
    if ! curl -fsSL --connect-timeout 10 "https://github.com" >/dev/null 2>&1; then
        log_warning "No internet connectivity detected"
        log_warning "Some modules may fail without internet access"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors error(s)"
        return $E_GENERAL
    fi
    
    log_success "Environment validation passed"
    return $E_SUCCESS
}

# Initialize utility system (optional for backward compatibility)
init_utils() {
    # Load dependencies
    load_dependencies
    
    # Setup error handling only if not already set
    if [[ "${UTILS_ERROR_HANDLING_SET:-false}" != "true" ]]; then
        setup_error_handling
        export UTILS_ERROR_HANDLING_SET=true
    fi
    
    # Create necessary directories if they don't exist
    [[ -n "$BACKUP_DIR" ]] && create_directory "$BACKUP_DIR" "755" 2>/dev/null || true
    [[ -n "$TEMP_DIR" ]] && create_directory "$TEMP_DIR" "700" 2>/dev/null || true
    
    # Skip environment validation for backward compatibility
    
    return $E_SUCCESS
}

# Self-test function
test_utils() {
    log_info "Running utility functions self-test..."
    
    # Test system info
    log_info "System Information Test:"
    log_info "  OS: $(get_system_info "os")"
    log_info "  Version: $(get_system_info "version")"
    log_info "  Architecture: $(get_system_info "arch")"
    log_info "  Memory: $(get_system_info "memory")"
    
    # Test password generation
    local test_password
    if test_password=$(generate_password 16); then
        log_info "Password generation test: OK (length: ${#test_password})"
    else
        log_error "Password generation test: FAILED"
        return $E_GENERAL
    fi
    
    # Test duration formatting
    log_info "Duration format test: $(format_duration 3661)"
    
    # Test temporary directory creation
    local test_dir="$TEMP_DIR/test"
    if create_directory "$test_dir"; then
        log_info "Directory creation test: OK"
        rmdir "$test_dir" 2>/dev/null || true
    else
        log_error "Directory creation test: FAILED"
        return $E_GENERAL
    fi
    
    log_success "All utility function tests passed"
    return $E_SUCCESS
}

# Export functions for use by other scripts
export -f is_root require_root user_exists group_exists command_exists
export -f package_installed service_running service_enabled port_open
export -f create_directory create_file backup_file restore_file
export -f generate_password create_restore_point rollback_module
export -f download_file execute_with_retry wait_for_service wait_for_port
export -f get_system_info prompt_user get_user_input add_user_to_group
export -f create_systemd_service set_permissions_recursive cleanup_temp_files
export -f validate_environment generate_final_report

# Main execution guard - auto-initialize for backward compatibility
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    init_utils
    test_utils
    echo "Utils library is ready for use"
else
    # Being sourced - auto-load dependencies for backward compatibility
    load_dependencies 2>/dev/null || true
fi