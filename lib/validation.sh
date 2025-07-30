#!/usr/bin/env bash

# Validation functions for Ubuntu Server Setup Script
# System and configuration validation utilities

# Ensure dependencies are loaded
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}"
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/logging.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/logging.sh}"
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/utils.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/utils.sh}"

# Validate Ubuntu version
validate_ubuntu_version() {
    local current_version
    current_version=$(get_system_info "version")
    local min_version="${MIN_UBUNTU_VERSION:-20.04}"
    
    log_debug "Validating Ubuntu version: $current_version (minimum: $min_version)"
    
    # Convert versions to comparable format
    local current_major current_minor min_major min_minor
    IFS='.' read -r current_major current_minor <<< "$current_version"
    IFS='.' read -r min_major min_minor <<< "$min_version"
    
    # Handle missing minor version
    current_minor="${current_minor:-0}"
    min_minor="${min_minor:-0}"
    
    # Compare versions
    if [[ $current_major -gt $min_major ]] || 
       [[ $current_major -eq $min_major && $current_minor -ge $min_minor ]]; then
        log_success "Ubuntu version validation passed: $current_version"
        return 0
    else
        log_error "Ubuntu version validation failed: $current_version < $min_version"
        return 1
    fi
}

# Validate system architecture
validate_architecture() {
    local arch
    arch=$(get_system_info "arch")
    local supported_archs=("${SUPPORTED_ARCHITECTURES[@]}")
    
    log_debug "Validating architecture: $arch"
    
    for supported_arch in "${supported_archs[@]}"; do
        if [[ "$arch" == "$supported_arch" ]]; then
            log_success "Architecture validation passed: $arch"
            return 0
        fi
    done
    
    log_error "Architecture validation failed: $arch not in [${supported_archs[*]}]"
    return 1
}

# Validate available disk space
validate_disk_space() {
    local required_space="${MIN_DISK_SPACE:-10}"  # GB
    local available_space
    
    # Get available space in GB
    available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    log_debug "Validating disk space: ${available_space}GB available (minimum: ${required_space}GB)"
    
    if [[ $available_space -ge $required_space ]]; then
        log_success "Disk space validation passed: ${available_space}GB available"
        return 0
    else
        log_warn "Disk space warning: ${available_space}GB < ${required_space}GB recommended"
        log_warn "Installation may fail if disk space runs out during setup"
        return 0  # Don't fail - just warn
    fi
}

# Validate internet connectivity
validate_internet_connection() {
    local test_urls=("${CONNECTIVITY_TEST_URLS[@]}")
    
    log_debug "Validating internet connectivity..."
    
    for url in "${test_urls[@]}"; do
        log_debug "Testing connectivity to: $url"
        if curl -s --connect-timeout 10 --max-time 30 "$url" > /dev/null 2>&1; then
            log_success "Internet connectivity validation passed: $url"
            return 0
        fi
    done
    
    log_error "Internet connectivity validation failed: no reachable test URLs"
    return 1
}

# Validate memory requirements
validate_memory() {
    local min_memory="${MIN_MEMORY:-1024}"  # MB
    local total_memory
    
    total_memory=$(free -m | awk 'NR==2{print $2}')
    
    log_debug "Validating memory: ${total_memory}MB total (minimum: ${min_memory}MB)"
    
    if [[ $total_memory -ge $min_memory ]]; then
        log_success "Memory validation passed: ${total_memory}MB total"
        return 0
    else
        log_error "Memory validation failed: ${total_memory}MB < ${min_memory}MB"
        return 1
    fi
}

# Validate CPU requirements
validate_cpu() {
    local min_cores="${MIN_CPU_CORES:-1}"
    local cpu_cores
    
    cpu_cores=$(get_cpu_cores)
    
    log_debug "Validating CPU cores: $cpu_cores cores (minimum: $min_cores)"
    
    if [[ $cpu_cores -ge $min_cores ]]; then
        log_success "CPU validation passed: $cpu_cores cores"
        return 0
    else
        log_error "CPU validation failed: $cpu_cores < $min_cores cores"
        return 1
    fi
}

# Validate DNS resolution
validate_dns() {
    local test_domains=("google.com" "github.com" "ubuntu.com")
    
    log_debug "Validating DNS resolution..."
    
    for domain in "${test_domains[@]}"; do
        log_debug "Testing DNS resolution for: $domain"
        if nslookup "$domain" > /dev/null 2>&1; then
            log_success "DNS validation passed: $domain"
            return 0
        fi
    done
    
    log_error "DNS validation failed: cannot resolve test domains"
    return 1
}

# Validate system time
validate_system_time() {
    local time_tolerance=300  # 5 minutes
    
    log_debug "Validating system time..."
    
    # Get current system time and NTP reference time
    local system_time ntp_time time_diff
    system_time=$(date +%s)
    
    # Try to get NTP time (fallback gracefully if not available)
    if command_exists "ntpdate"; then
        ntp_time=$(ntpdate -q pool.ntp.org 2>/dev/null | grep "server" | head -1 | awk '{print $10}' | cut -d',' -f1)
    elif command_exists "chrony"; then
        ntp_time=$(chronyc tracking 2>/dev/null | grep "System time" | awk '{print $4}')
    fi
    
    if [[ -n "$ntp_time" ]]; then
        time_diff=$(echo "$system_time - $ntp_time" | bc 2>/dev/null || echo "0")
        time_diff=${time_diff%.*}  # Remove decimal part
        time_diff=${time_diff#-}   # Remove negative sign
        
        if [[ $time_diff -le $time_tolerance ]]; then
            log_success "System time validation passed (diff: ${time_diff}s)"
            return 0
        else
            log_warn "System time validation failed (diff: ${time_diff}s > ${time_tolerance}s)"
            return 1
        fi
    else
        log_warn "Cannot validate system time - NTP tools not available"
        return 0  # Don't fail if we can't check
    fi
}

# Validate package manager state
validate_package_manager() {
    log_debug "Validating package manager state..."
    
    # Check if dpkg is locked
    if lsof /var/lib/dpkg/lock-frontend > /dev/null 2>&1; then
        log_error "Package manager validation failed: dpkg is locked"
        return 1
    fi
    
    # Check if apt is running
    if pgrep -x "apt" > /dev/null 2>&1; then
        log_error "Package manager validation failed: apt is running"
        return 1
    fi
    
    # Test basic apt functionality
    if apt list --installed > /dev/null 2>&1; then
        log_success "Package manager validation passed"
        return 0
    else
        log_error "Package manager validation failed: apt not functioning"
        return 1
    fi
}

# Validate essential commands are available
validate_essential_commands() {
    local essential_commands=("curl" "wget" "git" "systemctl" "ufw" "iptables")
    local missing_commands=()
    
    log_debug "Validating essential commands..."
    
    for cmd in "${essential_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -eq 0 ]]; then
        log_success "Essential commands validation passed"
        return 0
    else
        log_error "Essential commands validation failed: missing [${missing_commands[*]}]"
        return 1
    fi
}

# Validate file system permissions
validate_filesystem_permissions() {
    local test_dirs=("/tmp" "/var/log" "/etc")
    
    log_debug "Validating filesystem permissions..."
    
    for dir in "${test_dirs[@]}"; do
        if [[ ! -w "$dir" ]]; then
            log_error "Filesystem permissions validation failed: cannot write to $dir"
            return 1
        fi
    done
    
    # Test creating temporary file
    local test_file="/tmp/setup-test-$$"
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        log_success "Filesystem permissions validation passed"
        return 0
    else
        log_error "Filesystem permissions validation failed: cannot create test file"
        return 1
    fi
}

# Validate network ports are available
validate_network_ports() {
    local required_ports=("${HTTP_PORT}" "${HTTPS_PORT}")
    local occupied_ports=()
    
    log_debug "Validating network ports..."
    
    for port in "${required_ports[@]}"; do
        if ss -tlnp | grep -q ":$port "; then
            occupied_ports+=("$port")
        fi
    done
    
    if [[ ${#occupied_ports[@]} -eq 0 ]]; then
        log_success "Network ports validation passed"
        return 0
    else
        log_warn "Network ports validation warning: occupied ports [${occupied_ports[*]}]"
        # Don't fail - might be intentional
        return 0
    fi
}

# Validate SELinux/AppArmor status
validate_security_modules() {
    log_debug "Validating security modules..."
    
    # Check SELinux (unlikely on Ubuntu but possible)
    if command_exists "getenforce"; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
        log_info "SELinux status: $selinux_status"
    fi
    
    # Check AppArmor
    if command_exists "aa-status"; then
        local apparmor_status
        apparmor_status=$(aa-status --enabled 2>/dev/null && echo "Enabled" || echo "Disabled")
        log_info "AppArmor status: $apparmor_status"
    fi
    
    log_success "Security modules validation completed"
    return 0
}

# Validate systemd is running
validate_systemd() {
    log_debug "Validating systemd..."
    
    if [[ ! -d /run/systemd/system ]]; then
        log_error "Systemd validation failed: not running under systemd"
        return 1
    fi
    
    if ! command_exists "systemctl"; then
        log_error "Systemd validation failed: systemctl not available"
        return 1
    fi
    
    if systemctl status > /dev/null 2>&1; then
        log_success "Systemd validation passed"
        return 0
    else
        log_error "Systemd validation failed: systemctl not responding"
        return 1
    fi
}

# Validate locale settings
validate_locale() {
    log_debug "Validating locale settings..."
    
    local current_locale
    current_locale=$(locale | grep "LANG=" | cut -d'=' -f2)
    
    if [[ -n "$current_locale" ]]; then
        log_success "Locale validation passed: $current_locale"
        return 0
    else
        log_warn "Locale validation warning: no LANG setting found"
        return 0  # Don't fail, just warn
    fi
}

# Validate user environment
validate_user_environment() {
    local username="$1"
    
    log_debug "Validating user environment for: $username"
    
    if ! user_exists "$username"; then
        log_error "User validation failed: user does not exist: $username"
        return 1
    fi
    
    local user_home
    user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [[ ! -d "$user_home" ]]; then
        log_error "User validation failed: home directory does not exist: $user_home"
        return 1
    fi
    
    if [[ ! -w "$user_home" ]]; then
        log_error "User validation failed: home directory not writable: $user_home"
        return 1
    fi
    
    log_success "User environment validation passed: $username"
    return 0
}

# Validate service installation
validate_service_installation() {
    local service_name="$1"
    
    log_debug "Validating service installation: $service_name"
    
    # Check if service file exists
    if [[ ! -f "/etc/systemd/system/${service_name}.service" ]] && 
       [[ ! -f "/lib/systemd/system/${service_name}.service" ]] &&
       [[ ! -f "/usr/lib/systemd/system/${service_name}.service" ]]; then
        log_error "Service validation failed: service file not found: $service_name"
        return 1
    fi
    
    # Check if systemd knows about the service
    if ! systemctl status "$service_name" > /dev/null 2>&1; then
        log_error "Service validation failed: systemctl cannot find service: $service_name"
        return 1
    fi
    
    log_success "Service installation validation passed: $service_name"
    return 0
}

# Validate configuration file
validate_config_file() {
    local config_file="$1"
    local config_type="${2:-generic}"
    
    log_debug "Validating configuration file: $config_file ($config_type)"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Config validation failed: file does not exist: $config_file"
        return 1
    fi
    
    if [[ ! -r "$config_file" ]]; then
        log_error "Config validation failed: file not readable: $config_file"
        return 1
    fi
    
    # Type-specific validation
    case "$config_type" in
        "nginx")
            if command_exists "nginx"; then
                if nginx -t -c "$config_file" > /dev/null 2>&1; then
                    log_success "Nginx config validation passed: $config_file"
                    return 0
                else
                    log_error "Nginx config validation failed: $config_file"
                    return 1
                fi
            fi
            ;;
        "json")
            if command_exists "jq"; then
                if jq . "$config_file" > /dev/null 2>&1; then
                    log_success "JSON config validation passed: $config_file"
                    return 0
                else
                    log_error "JSON config validation failed: $config_file"
                    return 1
                fi
            fi
            ;;
        "yaml")
            if command_exists "python3"; then
                if python3 -c "import yaml; yaml.safe_load(open('$config_file'))" > /dev/null 2>&1; then
                    log_success "YAML config validation passed: $config_file"
                    return 0
                else
                    log_error "YAML config validation failed: $config_file"
                    return 1
                fi
            fi
            ;;
    esac
    
    log_success "Config file validation passed: $config_file"
    return 0
}

# Comprehensive pre-installation validation
validate_pre_installation() {
    log_section "Pre-Installation Validation"
    
    local validations=(
        "validate_ubuntu_version"
        "validate_architecture"
        "validate_disk_space"
        "validate_memory"
        "validate_internet_connection"
        "validate_dns"
        "validate_package_manager"
        "validate_filesystem_permissions"
        "validate_systemd"
        "validate_network_ports"
    )
    
    local failed_validations=()
    
    for validation in "${validations[@]}"; do
        if ! $validation; then
            failed_validations+=("$validation")
        fi
    done
    
    if [[ ${#failed_validations[@]} -eq 0 ]]; then
        log_success "All pre-installation validations passed"
        return 0
    else
        log_error "Pre-installation validation failed: [${failed_validations[*]}]"
        return 1
    fi
}

# Comprehensive post-installation validation
validate_post_installation() {
    log_section "Post-Installation Validation"
    
    local services_to_check=("${SERVICES_TO_ENABLE[@]}")
    local failed_services=()
    
    # Validate services
    for service in "${services_to_check[@]}"; do
        if validate_service_installation "$service"; then
            if service_running "$service"; then
                log_success "Service running: $service"
            else
                log_warn "Service not running: $service"
            fi
        else
            failed_services+=("$service")
        fi
    done
    
    # Validate ports
    validate_network_ports
    
    # Validate configuration files
    local config_files=(
        "/etc/nginx/nginx.conf:nginx"
        "/etc/fail2ban/jail.local:generic"
    )
    
    for config_entry in "${config_files[@]}"; do
        IFS=':' read -r config_file config_type <<< "$config_entry"
        if [[ -f "$config_file" ]]; then
            validate_config_file "$config_file" "$config_type"
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_success "Post-installation validation completed successfully"
        return 0
    else
        log_error "Post-installation validation failed for services: [${failed_services[*]}]"
        return 1
    fi
}

# Test all validation functions
test_validation() {
    log_info "Testing validation functions..."
    
    validate_ubuntu_version
    validate_architecture
    validate_disk_space
    validate_internet_connection
    validate_package_manager
    
    log_success "Validation functions test completed"
}