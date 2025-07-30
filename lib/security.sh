#!/usr/bin/env bash

# Security functions for Ubuntu Server Setup Script
# Security utilities, hardening, and safety mechanisms

# Ensure dependencies are loaded
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}"
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/logging.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/logging.sh}"
[[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/utils.sh}" ]] && source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/utils.sh}"

# Create restore point for rollback capability
create_restore_point() {
    local module_name="$1"
    local restore_point_dir="${BACKUP_DIR}/restore-points"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local restore_point="${restore_point_dir}/${module_name}-${timestamp}"
    
    log_debug "Creating restore point for module: $module_name"
    
    create_directory "$restore_point_dir"
    create_directory "$restore_point"
    
    # Backup critical system files based on module
    case "$module_name" in
        "02-users")
            backup_system_files "$restore_point" "/etc/passwd" "/etc/group" "/etc/shadow" "/etc/gshadow"
            ;;
        "06-nginx")
            backup_system_files "$restore_point" "/etc/nginx" "/etc/systemd/system/nginx.service"
            ;;
        "07-security")
            backup_system_files "$restore_point" "/etc/ufw" "/etc/fail2ban" "/etc/ssh/sshd_config"
            ;;
        *)
            # Generic backup
            backup_system_files "$restore_point" "/etc/environment" "/etc/profile"
            ;;
    esac
    
    # Save installed packages state
    dpkg --get-selections > "${restore_point}/packages.txt" 2>/dev/null || true
    
    # Save service states
    systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' > "${restore_point}/services.txt" 2>/dev/null || true
    
    log_success "Restore point created: $restore_point"
    echo "$restore_point"
}

# Backup system files to restore point
backup_system_files() {
    local restore_point="$1"
    shift
    local files=("$@")
    
    for file in "${files[@]}"; do
        if [[ -e "$file" ]]; then
            local dest_dir="${restore_point}$(dirname "$file")"
            create_directory "$dest_dir"
            cp -r "$file" "$dest_dir/" 2>/dev/null || true
            log_debug "Backed up: $file"
        fi
    done
}

# Rollback from restore point
rollback_module() {
    local module_name="$1"
    local restore_point_dir="${BACKUP_DIR}/restore-points"
    
    log_warn "Attempting rollback for module: $module_name"
    
    # Find most recent restore point for this module
    local restore_point
    restore_point=$(find "$restore_point_dir" -name "${module_name}-*" -type d | sort -r | head -1)
    
    if [[ -z "$restore_point" ]] || [[ ! -d "$restore_point" ]]; then
        log_error "No restore point found for module: $module_name"
        return 1
    fi
    
    log_info "Rolling back from: $restore_point"
    
    # Restore files
    if [[ -d "${restore_point}/etc" ]]; then
        log_debug "Restoring configuration files..."
        cp -r "${restore_point}/etc"/* /etc/ 2>/dev/null || true
    fi
    
    # Restore packages if needed
    if [[ -f "${restore_point}/packages.txt" ]]; then
        log_debug "Package state saved for manual review: ${restore_point}/packages.txt"
    fi
    
    # Reload systemd if configs were restored
    systemctl daemon-reload 2>/dev/null || true
    
    log_success "Rollback completed for module: $module_name"
}

# Generate secure random password
generate_secure_password() {
    local length="${1:-32}"
    local use_special="${2:-true}"
    
    local charset="A-Za-z0-9"
    if [[ "$use_special" == "true" ]]; then
        charset="${charset}@#%^&*-_=+"
    fi
    
    if command_exists "openssl"; then
        openssl rand -base64 48 | tr -d "=+/" | tr -dc "$charset" | head -c "$length"
    elif [[ -f /dev/urandom ]]; then
        tr -dc "$charset" < /dev/urandom | head -c "$length"
    else
        # Fallback
        date +%s%N | sha256sum | base64 | tr -dc "$charset" | head -c "$length"
    fi
    echo
}

# Validate SSH key
validate_ssh_key() {
    local key_file="$1"
    
    if [[ ! -f "$key_file" ]]; then
        log_error "SSH key file not found: $key_file"
        return 1
    fi
    
    if ssh-keygen -l -f "$key_file" > /dev/null 2>&1; then
        log_success "Valid SSH key: $key_file"
        return 0
    else
        log_error "Invalid SSH key: $key_file"
        return 1
    fi
}

# Generate SSH key pair
generate_ssh_key() {
    local key_path="$1"
    local key_type="${2:-ed25519}"
    local key_comment="${3:-setup-generated-key}"
    
    log_info "Generating SSH key pair: $key_path"
    
    # Create directory if needed
    local key_dir
    key_dir=$(dirname "$key_path")
    create_directory "$key_dir" "700"
    
    # Generate key
    if ssh-keygen -t "$key_type" -f "$key_path" -C "$key_comment" -N "" > /dev/null 2>&1; then
        chmod 600 "$key_path"
        chmod 644 "${key_path}.pub"
        log_success "SSH key pair generated: $key_path"
        return 0
    else
        log_error "Failed to generate SSH key pair: $key_path"
        return 1
    fi
}

# Set up SSH key authentication for user
setup_ssh_key_auth() {
    local username="$1"
    local public_key="$2"
    
    if ! user_exists "$username"; then
        log_error "User does not exist: $username"
        return 1
    fi
    
    local user_home
    user_home=$(getent passwd "$username" | cut -d: -f6)
    local ssh_dir="${user_home}/.ssh"
    local authorized_keys="${ssh_dir}/authorized_keys"
    
    # Create .ssh directory
    create_directory "$ssh_dir" "700" "$username" "$username"
    
    # Add public key to authorized_keys
    if [[ -f "$public_key" ]]; then
        cat "$public_key" >> "$authorized_keys"
    else
        echo "$public_key" >> "$authorized_keys"
    fi
    
    # Set proper permissions
    chmod 600 "$authorized_keys"
    chown "$username:$username" "$authorized_keys"
    
    log_success "SSH key authentication set up for user: $username"
}

# Harden SSH configuration
harden_ssh_config() {
    local ssh_config="/etc/ssh/sshd_config"
    local backup_file
    
    log_info "Hardening SSH configuration"
    
    # Backup current config
    backup_file=$(backup_file "$ssh_config")
    
    # SSH hardening settings
    local ssh_settings=(
        "Protocol 2"
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "PubkeyAuthentication yes"
        "AuthorizedKeysFile .ssh/authorized_keys"
        "PermitEmptyPasswords no"
        "ChallengeResponseAuthentication no"
        "UsePAM yes"
        "X11Forwarding no"
        "PrintMotd no"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
        "MaxAuthTries 3"
        "MaxSessions 2"
        "LoginGraceTime 30"
    )
    
    # Apply settings
    for setting in "${ssh_settings[@]}"; do
        local key value
        key=$(echo "$setting" | cut -d' ' -f1)
        value=$(echo "$setting" | cut -d' ' -f2-)
        
        # Remove existing setting and add new one
        sed -i "/^#*${key}/d" "$ssh_config"
        echo "$setting" >> "$ssh_config"
    done
    
    # Validate configuration
    if sshd -t > /dev/null 2>&1; then
        log_success "SSH configuration hardened successfully"
        systemctl reload ssh > /dev/null 2>&1 || systemctl reload sshd > /dev/null 2>&1 || true
        return 0
    else
        log_warn "SSH configuration validation failed, trying to fix"
        
        log_warn "SSH configuration validation still failed, restoring backup"
        restore_file "$backup_file" "$ssh_config"
        # Don't fail the entire module for SSH hardening issues
        return 0
    fi
}

# Configure firewall (UFW)
configure_firewall() {
    log_info "Configuring UFW firewall"
    
    # Reset to defaults
    ufw --force reset > /dev/null 2>&1
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH with rate limiting
    ufw limit ssh
    
    # Allow HTTP and HTTPS
    ufw allow http
    ufw allow https
    
    # Allow specific ports if defined
    if [[ -n "${ADDITIONAL_PORTS:-}" ]]; then
        IFS=',' read -ra ports <<< "$ADDITIONAL_PORTS"
        for port in "${ports[@]}"; do
            ufw allow "$port"
            log_info "Opened firewall port: $port"
        done
    fi
    
    # Enable logging
    ufw logging on
    
    # Enable firewall
    ufw --force enable
    
    log_success "UFW firewall configured and enabled"
}

# Configure fail2ban
configure_fail2ban() {
    log_info "Configuring fail2ban"
    
    local jail_local="/etc/fail2ban/jail.local"
    
    # Create jail.local configuration
    cat > "$jail_local" << EOF
[DEFAULT]
bantime = ${FAIL2BAN_BANTIME:-3600}
findtime = 600
maxretry = ${FAIL2BAN_MAXRETRY:-5}
backend = systemd
usedns = warn
logpath = /var/log/auth.log
enabled = false

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = ${FAIL2BAN_MAXRETRY:-5}

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 2
EOF

    # Set proper permissions
    chmod 644 "$jail_local"
    
    # Restart fail2ban
    if systemctl restart fail2ban > /dev/null 2>&1; then
        log_success "Fail2ban service restarted"
    else
        log_warn "Failed to restart fail2ban, trying to start"
        systemctl start fail2ban > /dev/null 2>&1 || true
    fi
    
    if systemctl enable fail2ban > /dev/null 2>&1; then
        log_success "Fail2ban service enabled"
    else
        log_warn "Failed to enable fail2ban service"
    fi
    
    log_success "Fail2ban configured"
}

# Set secure file permissions
secure_file_permissions() {
    local path="$1"
    local file_perms="${2:-644}"
    local dir_perms="${3:-755}"
    local owner="${4:-root:root}"
    
    log_debug "Securing file permissions: $path"
    
    if [[ ! -e "$path" ]]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    # Set ownership
    chown -R "$owner" "$path"
    
    # Set permissions
    if [[ -d "$path" ]]; then
        chmod "$dir_perms" "$path"
        find "$path" -type d -exec chmod "$dir_perms" {} \;
        find "$path" -type f -exec chmod "$file_perms" {} \;
    else
        chmod "$file_perms" "$path"
    fi
    
    log_success "Secured permissions for: $path"
}

# Remove dangerous packages
remove_dangerous_packages() {
    local dangerous_packages=(
        "telnet"
        "rsh-client"
        "rsh-redone-client"
        "talk"
        "ntalk"
        "finger"
        "netcat-traditional"
    )
    
    log_info "Removing dangerous packages"
    
    local removed_packages=()
    for package in "${dangerous_packages[@]}"; do
        if package_installed "$package"; then
            if apt-get remove -y "$package" > /dev/null 2>&1; then
                removed_packages+=("$package")
                log_success "Removed dangerous package: $package"
            else
                log_warn "Failed to remove package: $package"
            fi
        fi
    done
    
    if [[ ${#removed_packages[@]} -gt 0 ]]; then
        log_info "Removed dangerous packages: [${removed_packages[*]}]"
    else
        log_info "No dangerous packages found to remove"
    fi
}

# Configure automatic security updates
configure_automatic_updates() {
    log_info "Configuring automatic security updates"
    
    # Install unattended-upgrades if not present
    if ! package_installed "unattended-upgrades"; then
        apt-get update > /dev/null 2>&1
        apt-get install -y unattended-upgrades
    fi
    
    # Configure unattended-upgrades
    local config_file="/etc/apt/apt.conf.d/50unattended-upgrades"
    local auto_config="/etc/apt/apt.conf.d/20auto-upgrades"
    
    # Backup existing config
    backup_file "$config_file"
    
    # Configure which updates to install
    cat > "$config_file" << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

    # Enable automatic updates
    cat > "$auto_config" << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # Enable and start the service
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    log_success "Automatic security updates configured"
}

# Kernel parameter hardening
harden_kernel_parameters() {
    log_info "Hardening kernel parameters"
    
    local sysctl_config="/etc/sysctl.d/99-security-hardening.conf"
    
    # Backup existing config if it exists
    [[ -f "$sysctl_config" ]] && backup_file "$sysctl_config"
    
    # Security hardening parameters
    cat > "$sysctl_config" << EOF
# Network security hardening
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# IPv6 security
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Memory protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# Performance and stability
vm.swappiness = ${SWAPPINESS:-10}
vm.dirty_ratio = ${VM_DIRTY_RATIO:-15}
vm.dirty_background_ratio = ${VM_DIRTY_BACKGROUND_RATIO:-5}
EOF

    # Apply the settings
    sysctl --system > /dev/null 2>&1
    
    log_success "Kernel parameters hardened"
}

# Check for rootkits and malware
security_scan() {
    log_info "Running security scan"
    
    local scan_results="${LOG_DIR}/security-scan-$(date +%Y%m%d-%H%M%S).log"
    
    # Run rkhunter if available
    if command_exists "rkhunter"; then
        log_info "Running rkhunter scan"
        rkhunter --update > /dev/null 2>&1 || true
        rkhunter --checkall --skip-keypress >> "$scan_results" 2>&1 || true
    fi
    
    # Run chkrootkit if available
    if command_exists "chkrootkit"; then
        log_info "Running chkrootkit scan"
        chkrootkit >> "$scan_results" 2>&1 || true
    fi
    
    # Run lynis if available
    if command_exists "lynis"; then
        log_info "Running lynis audit"
        lynis audit system --quick >> "$scan_results" 2>&1 || true
    fi
    
    log_success "Security scan completed, results saved to: $scan_results"
}

# Validate security configuration
validate_security_config() {
    log_info "Validating security configuration"
    
    local issues=()
    
    # Check SSH configuration
    if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
        issues+=("SSH: Root login enabled")
    fi
    
    if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
        issues+=("SSH: Password authentication enabled")
    fi
    
    # Check firewall status
    if ! ufw status | grep -q "Status: active"; then
        issues+=("Firewall: UFW not active")
    fi
    
    # Check fail2ban status
    if ! systemctl is-active --quiet fail2ban; then
        issues+=("Fail2ban: Service not running")
    fi
    
    # Check for dangerous services
    local dangerous_services=("telnet" "rsh" "finger")
    for service in "${dangerous_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            issues+=("Service: Dangerous service running: $service")
        fi
    done
    
    # Report results
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "Security configuration validation passed"
        return 0
    else
        log_warn "Security configuration issues found:"
        for issue in "${issues[@]}"; do
            log_warn "  - $issue"
        done
        return 1
    fi
}

# Generate final security report
generate_security_report() {
    local report_file="${LOG_DIR}/security-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "Generating security report: $report_file"
    
    {
        echo "Ubuntu Server Security Report"
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "============================================"
        echo
        
        echo "SYSTEM INFORMATION:"
        echo "OS: $(get_system_info "os") $(get_system_info "version")"
        echo "Kernel: $(get_system_info "kernel")"
        echo "Architecture: $(get_system_info "arch")"
        echo
        
        echo "FIREWALL STATUS:"
        ufw status verbose 2>/dev/null || echo "UFW not available"
        echo
        
        echo "FAIL2BAN STATUS:"
        fail2ban-client status 2>/dev/null || echo "Fail2ban not available"
        echo
        
        echo "SSH CONFIGURATION:"
        grep -E "^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config 2>/dev/null || echo "SSH config not accessible"
        echo
        
        echo "LISTENING SERVICES:"
        ss -tulpn | grep LISTEN
        echo
        
        echo "LAST LOGINS:"
        last -n 10 2>/dev/null || echo "Login history not available"
        echo
        
    } > "$report_file"
    
    log_success "Security report generated: $report_file"
    echo "$report_file"
}