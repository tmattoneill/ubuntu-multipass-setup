#!/usr/bin/env bash

# Utility functions for Ubuntu Server Setup Script
# Common helper functions used throughout the setup process

# Ensure dependencies are loaded
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}"
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/logging.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/logging.sh}"

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if user exists
user_exists() {
    local username="$1"
    id "$username" &>/dev/null
}

# Check if group exists
group_exists() {
    local groupname="$1"
    getent group "$groupname" &>/dev/null
}

# Check if command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}

# Check if package is installed
package_installed() {
    local package="$1"
    dpkg -l "$package" 2>/dev/null | grep -q "^ii"
}

# Check if service is running
service_running() {
    local service="$1"
    systemctl is-active --quiet "$service"
}

# Check if service is enabled
service_enabled() {
    local service="$1"
    systemctl is-enabled --quiet "$service"
}

# Check if port is open
port_open() {
    local port="$1"
    local host="${2:-localhost}"
    timeout 5 bash -c "</dev/tcp/$host/$port" &>/dev/null
}

# Create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    local owner="${3:-}"
    local group="${4:-}"
    
    if [[ ! -d "$dir_path" ]]; then
        log_debug "Creating directory: $dir_path"
        if mkdir -p "$dir_path"; then
            chmod "$permissions" "$dir_path"
            
            if [[ -n "$owner" ]] && [[ -n "$group" ]]; then
                chown "$owner:$group" "$dir_path"
            elif [[ -n "$owner" ]]; then
                chown "$owner" "$dir_path"
            fi
            
            log_success "Directory created: $dir_path"
            return 0
        else
            log_error "Failed to create directory: $dir_path"
            return 1
        fi
    else
        log_debug "Directory already exists: $dir_path"
        return 0
    fi
}

# Create file with content and permissions
create_file() {
    local file_path="$1"
    local content="$2"
    local permissions="${3:-644}"
    local owner="${4:-}"
    local group="${5:-}"
    
    local dir_path
    dir_path=$(dirname "$file_path")
    
    # Create parent directory if needed
    if [[ ! -d "$dir_path" ]]; then
        create_directory "$dir_path"
    fi
    
    log_debug "Creating file: $file_path"
    
    if echo "$content" > "$file_path"; then
        chmod "$permissions" "$file_path"
        
        if [[ -n "$owner" ]] && [[ -n "$group" ]]; then
            chown "$owner:$group" "$file_path"
        elif [[ -n "$owner" ]]; then
            chown "$owner" "$file_path"
        fi
        
        log_success "File created: $file_path"
        return 0
    else
        log_error "Failed to create file: $file_path"
        return 1
    fi
}

# Backup file with timestamp
backup_file() {
    local file_path="$1"
    local backup_dir="${2:-$BACKUP_DIR/configs}"
    
    if [[ ! -f "$file_path" ]]; then
        log_debug "File does not exist, cannot backup: $file_path"
        return 0
    fi
    
    create_directory "$backup_dir"
    
    local filename
    filename=$(basename "$file_path")
    local backup_path="$backup_dir/${filename}.$(date +%Y%m%d-%H%M%S).bak"
    
    log_debug "Backing up file: $file_path -> $backup_path"
    
    if cp "$file_path" "$backup_path"; then
        log_success "File backed up: $backup_path"
        echo "$backup_path"
        return 0
    else
        log_error "Failed to backup file: $file_path"
        return 1
    fi
}

# Create restore point before module execution
create_restore_point() {
    local checkpoint_name="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="${BACKUP_DIR}/checkpoints/${checkpoint_name}"
    local manifest_file="${backup_dir}/manifest.txt"
    
    log_info "Creating restore point: $checkpoint_name"
    
    # Create checkpoint directory
    create_directory "$backup_dir"
    
    # Record system state
    cat > "$manifest_file" << EOF
Checkpoint: $checkpoint_name
Timestamp: $timestamp
Date: $(date)
Module: $checkpoint_name
EOF
    
    # Backup critical configuration files
    local config_files=(
        "/etc/passwd"
        "/etc/group"
        "/etc/sudoers"
        "/etc/nginx/nginx.conf"
        "/etc/systemd/system.conf"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            backup_file "$file" "$backup_dir"
            echo "$file" >> "$manifest_file"
        fi
    done
    
    # Record installed packages
    dpkg -l > "${backup_dir}/installed-packages.txt"
    
    # Record service states
    systemctl list-unit-files --type=service --state=enabled > "${backup_dir}/enabled-services.txt"
    
    log_success "Restore point created: $backup_dir"
    return 0
}

# Rollback module changes
rollback_module() {
    local module_name="$1"
    local backup_dir="${BACKUP_DIR}/checkpoints/${module_name}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "No restore point found for module: $module_name"
        return 1
    fi
    
    log_warning "Rolling back module: $module_name"
    log_warning "This is a basic rollback - manual intervention may be required"
    
    # Restore configuration files
    if [[ -f "${backup_dir}/manifest.txt" ]]; then
        while IFS= read -r file; do
            if [[ "$file" =~ ^/ ]] && [[ -f "${backup_dir}/$(basename "$file").*.bak" ]]; then
                local backup=$(ls -t "${backup_dir}/$(basename "$file").*.bak" | head -1)
                log_info "Restoring: $file"
                restore_file "$backup" "$file"
            fi
        done < "${backup_dir}/manifest.txt"
    fi
    
    log_warning "Rollback completed - please verify system state"
    return 0
}

# Generate final installation report
generate_final_report() {
    local start_time="$1"
    local end_time="$2"
    local duration="$3"
    shift 3
    
    local successful_modules=()
    local failed_modules=()
    local parsing_failed=false
    
    # Parse remaining arguments
    for arg in "$@"; do
        if [[ "$arg" == "${failed_modules[@]}" ]]; then
            parsing_failed=true
        elif [[ "$parsing_failed" == true ]]; then
            failed_modules+=("$arg")
        else
            successful_modules+=("$arg")
        fi
    done
    
    log_separator "=" 60
    log_info "INSTALLATION REPORT"
    log_separator "=" 60
    
    log_info "Start Time: $(date -d @"$start_time" '+%Y-%m-%d %H:%M:%S')"
    log_info "End Time: $(date -d @"$end_time" '+%Y-%m-%d %H:%M:%S')"
    log_info "Duration: $(format_duration "$duration")"
    log_info ""
    
    if [[ ${#successful_modules[@]} -gt 0 ]]; then
        log_success "Successful Modules (${#successful_modules[@]}):"
        for module in "${successful_modules[@]}"; do
            log_info "  ✓ $module"
        done
    fi
    
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        log_error "Failed Modules (${#failed_modules[@]}):"
        for module in "${failed_modules[@]}"; do
            log_info "  ✗ $module"
        done
    fi
    
    log_info ""
    log_info "System Information:"
    log_info "  OS: $(get_system_info 'os') $(get_system_info 'version')"
    log_info "  Hostname: $(get_system_info 'hostname')"
    log_info "  IP: $(get_system_info 'ip')"
    log_info "  Memory: $(get_system_info 'memory')"
    log_info "  Disk Available: $(get_system_info 'disk')"
    
    if reboot_required; then
        log_warning "REBOOT REQUIRED: System requires reboot to complete installation"
    fi
    
    log_info ""
    log_info "Log file: $LOG_FILE"
    
    log_separator "=" 60
}

# Restore file from backup
restore_file() {
    local backup_path="$1"
    local original_path="$2"
    
    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup file not found: $backup_path"
        return 1
    fi
    
    log_debug "Restoring file: $backup_path -> $original_path"
    
    if cp "$backup_path" "$original_path"; then
        log_success "File restored: $original_path"
        return 0
    else
        log_error "Failed to restore file: $original_path"
        return 1
    fi
}

# Download file with verification
download_file() {
    local url="$1"
    local destination="$2"
    local checksum="${3:-}"
    local retries="${4:-3}"
    
    log_debug "Downloading: $url -> $destination"
    
    local attempt=1
    while [[ $attempt -le $retries ]]; do
        if curl -fsSL -o "$destination" "$url"; then
            # Verify checksum if provided
            if [[ -n "$checksum" ]]; then
                local file_checksum
                file_checksum=$(sha256sum "$destination" | cut -d' ' -f1)
                if [[ "$file_checksum" == "$checksum" ]]; then
                    log_success "Downloaded and verified: $destination"
                    return 0
                else
                    log_error "Checksum mismatch for $destination"
                    rm -f "$destination"
                    return 1
                fi
            else
                log_success "Downloaded: $destination"
                return 0
            fi
        else
            log_warn "Download attempt $attempt failed: $url"
            ((attempt++))
            if [[ $attempt -le $retries ]]; then
                log_info "Retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to download after $retries attempts: $url"
    return 1
}

# Execute command with retry logic
execute_with_retry() {
    local cmd="$1"
    local retries="${2:-3}"
    local delay="${3:-5}"
    local description="${4:-command}"
    
    local attempt=1
    while [[ $attempt -le $retries ]]; do
        log_debug "Executing $description (attempt $attempt/$retries): $cmd"
        
        if eval "$cmd"; then
            log_success "$description completed successfully"
            return 0
        else
            local exit_code=$?
            log_warn "$description failed (attempt $attempt/$retries)"
            
            if [[ $attempt -lt $retries ]]; then
                log_info "Retrying in $delay seconds..."
                sleep "$delay"
            fi
            ((attempt++))
        fi
    done
    
    log_error "$description failed after $retries attempts"
    return 1
}

# Wait for service to be ready
wait_for_service() {
    local service="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    
    log_info "Waiting for service to be ready: $service"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if service_running "$service"; then
            log_success "Service is ready: $service"
            return 0
        fi
        
        sleep "$interval"
        ((elapsed += interval))
        
        if [[ $((elapsed % 10)) -eq 0 ]]; then
            log_debug "Still waiting for service: $service ($elapsed/${timeout}s)"
        fi
    done
    
    log_error "Service not ready after ${timeout}s: $service"
    return 1
}

# Wait for port to be open
wait_for_port() {
    local port="$1"
    local host="${2:-localhost}"
    local timeout="${3:-30}"
    local interval="${4:-2}"
    
    log_info "Waiting for port to be open: $host:$port"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if port_open "$port" "$host"; then
            log_success "Port is open: $host:$port"
            return 0
        fi
        
        sleep "$interval"
        ((elapsed += interval))
        
        if [[ $((elapsed % 10)) -eq 0 ]]; then
            log_debug "Still waiting for port: $host:$port ($elapsed/${timeout}s)"
        fi
    done
    
    log_error "Port not open after ${timeout}s: $host:$port"
    return 1
}

# Get system information
get_system_info() {
    local info_type="$1"
    
    case "$info_type" in
        "os")
            lsb_release -si 2>/dev/null || echo "Unknown"
            ;;
        "version")
            lsb_release -sr 2>/dev/null || echo "Unknown"
            ;;
        "codename")
            lsb_release -sc 2>/dev/null || echo "Unknown"
            ;;
        "arch")
            uname -m
            ;;
        "kernel")
            uname -r
            ;;
        "hostname")
            hostname
            ;;
        "ip")
            hostname -I | awk '{print $1}'
            ;;
        "memory")
            free -m | awk 'NR==2{printf "%.1fGB", $2/1024}'
            ;;
        "disk")
            df -h / | awk 'NR==2{print $4}'
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Generate random password
# Current fallback is predictable:
date +%s | sha256sum | base64 | head -c "$length"

# Replace with:
generate_password() {
    local length="${1:-16}"
    
    if command_exists "openssl"; then
        openssl rand -base64 $((length * 2)) | tr -d "=+/\n" | head -c "$length"
    elif [[ -f /dev/urandom ]]; then
        tr -dc 'A-Za-z0-9!@#$%^&*()_+{}|:<>?-=[]\\;,./' < /dev/urandom | head -c "$length"
    else
        log_error "No secure random source available"
        return 1
    fi
}

# Prompt user for confirmation
prompt_user() {
    local message="$1"
    local default="${2:-n}"
    
    # Check if we should assume yes
    if [[ "${ASSUME_YES:-false}" == "true" ]] || [[ -n "${SETUP_ASSUME_YES:-}" ]]; then
        log_info "$message [auto: yes]"
        return 0
    fi
    
    local prompt_suffix
    if [[ "$default" == "y" ]]; then
        prompt_suffix=" [Y/n]"
    else
        prompt_suffix=" [y/N]"
    fi
    
    while true; do
        echo -n "$message$prompt_suffix " >&2
        read -r response
        
        # Use default if empty response
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "${response,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please answer yes or no." >&2
                ;;
        esac
    done
}

# Get user input with validation
get_user_input() {
    local prompt="$1"
    local validation_regex="${2:-.*}"
    local error_message="${3:-Invalid input}"
    local default="${4:-}"
    
    while true; do
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
            return 0
        else
            echo "$error_message" >&2
        fi
    done
}

# Clean up temporary files
cleanup_temp_files() {
    if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
        log_debug "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    # Clean up any temp files in /tmp with our pattern
    find /tmp -name "setup-*" -type f -mtime +1 -delete 2>/dev/null || true
}

# Convert bytes to human readable format
bytes_to_human() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $bytes -ge 1024 ]] && [[ $unit -lt $((${#units[@]} - 1)) ]]; do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    
    echo "${bytes}${units[$unit]}"
}

# Check if running in container
is_container() {
    [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || grep -q container /proc/1/cgroup 2>/dev/null
}

# Check if running in VM
is_vm() {
    if command_exists "systemd-detect-virt"; then
        systemd-detect-virt -q
    elif [[ -f /sys/class/dmi/id/product_name ]]; then
        grep -qi "virtual\|vmware\|qemu\|kvm\|xen" /sys/class/dmi/id/product_name
    else
        return 1
    fi
}

# Get available memory in MB
get_available_memory() {
    free -m | awk 'NR==2{print $7}'
}

# Get CPU core count
get_cpu_cores() {
    nproc
}

# Check if reboot is required
reboot_required() {
    [[ -f /var/run/reboot-required ]]
}

# Format duration in seconds to human readable
format_duration() {
    local duration="$1"
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

# Create systemd service file
create_systemd_service() {
    local service_name="$1"
    local service_content="$2"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log_debug "Creating systemd service: $service_name"
    
    if create_file "$service_file" "$service_content" "644"; then
        systemctl daemon-reload
        log_success "Systemd service created: $service_name"
        return 0
    else
        log_error "Failed to create systemd service: $service_name"
        return 1
    fi
}

# Add user to group
add_user_to_group() {
    local username="$1"
    local groupname="$2"
    
    if ! user_exists "$username"; then
        log_error "User does not exist: $username"
        return 1
    fi
    
    if ! group_exists "$groupname"; then
        log_error "Group does not exist: $groupname"
        return 1
    fi
    
    if usermod -a -G "$groupname" "$username"; then
        log_success "Added user $username to group $groupname"
        return 0
    else
        log_error "Failed to add user $username to group $groupname"
        return 1
    fi
}

# Set file permissions recursively
set_permissions_recursive() {
    local path="$1"
    local file_perms="$2"
    local dir_perms="$3"
    local owner="${4:-}"
    
    if [[ ! -e "$path" ]]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    log_debug "Setting recursive permissions: $path"
    
    # Set ownership if specified
    if [[ -n "$owner" ]]; then
        chown -R "$owner" "$path"
    fi
    
    # Set directory permissions
    find "$path" -type d -exec chmod "$dir_perms" {} \;
    
    # Set file permissions
    find "$path" -type f -exec chmod "$file_perms" {} \;
    
    log_success "Permissions set recursively: $path"
}

# Test function to validate utilities
test_utils() {
    log_info "Testing utility functions..."
    
    # Test system info
    log_info "OS: $(get_system_info "os")"
    log_info "Version: $(get_system_info "version")"
    log_info "Architecture: $(get_system_info "arch")"
    
    # Test password generation
    local test_password
    test_password=$(generate_password 12)
    log_info "Generated password length: ${#test_password}"
    
    # Test duration formatting
    log_info "Duration format test: $(format_duration 3661)"
    
    log_success "Utility functions test completed"
}
