#!/usr/bin/env bash

# Module: Security Setup
# Configure firewall, fail2ban, and system hardening

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="security"
readonly MODULE_DESCRIPTION="Security Setup and Hardening"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    install_security_packages
    configure_ufw_firewall
    setup_fail2ban
    harden_ssh_configuration
    configure_automatic_updates
    apply_kernel_hardening
    remove_unnecessary_packages
    configure_file_permissions
    setup_intrusion_detection
    
    log_success "Security module completed successfully"
}

# Install security packages
install_security_packages() {
    log_subsection "Installing Security Packages"
    
    local packages=("${SECURITY_PACKAGES[@]}")
    local failed_packages=()
    
    log_info "Installing security packages: [${packages[*]}]"
    
    for package in "${packages[@]}"; do
        if package_installed "$package"; then
            log_debug "Package already installed: $package"
            continue
        fi
        
        log_info "Installing security package: $package"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" > /dev/null 2>&1; then
            log_success "Installed: $package"
        else
            log_warn "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        log_success "All security packages installed successfully"
    else
        log_warn "Some security packages failed to install: [${failed_packages[*]}]"
    fi
}

# Configure UFW firewall
configure_ufw_firewall() {
    log_subsection "Configuring UFW Firewall"
    
    # Reset UFW to defaults
    log_info "Resetting UFW to defaults"
    ufw --force reset > /dev/null 2>&1
    
    # Set default policies
    log_info "Setting UFW default policies"
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    
    # Allow SSH with rate limiting
    log_info "Configuring SSH access with rate limiting"
    ufw limit ssh > /dev/null 2>&1
    
    # Allow HTTP and HTTPS
    log_info "Allowing HTTP and HTTPS traffic"
    ufw allow http > /dev/null 2>&1
    ufw allow https > /dev/null 2>&1
    
    # Allow specific development ports if in development mode
    if [[ "${INSTALL_MODE}" == "dev-only" ]] || [[ "${INSTALL_MODE}" == "full" ]]; then
        log_info "Allowing development ports"
        ufw allow "$NODE_DEV_PORT" > /dev/null 2>&1
        ufw allow "$PYTHON_DEV_PORT" > /dev/null 2>&1
    fi
    
    # Configure logging
    log_info "Enabling UFW logging"
    ufw logging on > /dev/null 2>&1
    
    # Enable UFW
    log_info "Enabling UFW firewall"
    if ufw --force enable > /dev/null 2>&1; then
        log_success "UFW firewall enabled and configured"
    else
        log_error "Failed to enable UFW firewall"
        return 1
    fi
    
    # Display status
    log_info "UFW firewall status:"
    ufw status verbose | while read -r line; do
        log_info "  $line"
    done
}

# Setup fail2ban
setup_fail2ban() {
    log_subsection "Setting up Fail2ban"
    
    if ! package_installed "fail2ban"; then
        log_error "Fail2ban not installed"
        return 1
    fi
    
    # Configure fail2ban
    configure_fail2ban
    
    # Create custom filters
    create_fail2ban_filters
    
    # Start and enable fail2ban
    if systemctl enable fail2ban > /dev/null 2>&1; then
        log_success "Fail2ban service enabled"
    else
        log_error "Failed to enable fail2ban service"
        return 1
    fi
    
    if systemctl start fail2ban > /dev/null 2>&1; then
        log_success "Fail2ban service started"
    else
        log_error "Failed to start fail2ban service"
        return 1
    fi
    
    # Wait for service to be ready
    if wait_for_service "fail2ban" 30; then
        log_success "Fail2ban is running and ready"
    else
        log_error "Fail2ban failed to start properly"
        return 1
    fi
    
    # Display status
    if command_exists "fail2ban-client"; then
        log_info "Fail2ban status:"
        fail2ban-client status 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    fi
}

# Create custom fail2ban filters
create_fail2ban_filters() {
    log_info "Creating custom fail2ban filters"
    
    local filter_dir="/etc/fail2ban/filter.d"
    
    # Create Node.js application filter
    cat > "$filter_dir/nodejs-app.conf" << 'EOF'
# Fail2ban filter for Node.js applications
[Definition]
failregex = ^.*\[<HOST>\].*"(GET|POST|PUT|DELETE).*" (4[0-9]{2}|5[0-9]{2}) .*$
            ^.*Invalid login attempt from <HOST>.*$
            ^.*Authentication failed for <HOST>.*$

ignoreregex =
EOF
    
    # Create Python application filter
    cat > "$filter_dir/python-app.conf" << 'EOF'
# Fail2ban filter for Python applications
[Definition]
failregex = ^.*\[<HOST>\].*"(GET|POST|PUT|DELETE).*" (4[0-9]{2}|5[0-9]{2}) .*$
            ^.*Failed login attempt from <HOST>.*$
            ^.*Invalid credentials from <HOST>.*$

ignoreregex =
EOF
    
    log_success "Custom fail2ban filters created"
}

# Harden SSH configuration
harden_ssh_configuration() {
    log_subsection "Hardening SSH Configuration"
    
    # Use the security library function
    if harden_ssh_config; then
        log_success "SSH configuration hardened"
    else
        log_error "Failed to harden SSH configuration"
        return 1
    fi
    
    # Restart SSH service to apply changes
    if systemctl restart ssh > /dev/null 2>&1 || systemctl restart sshd > /dev/null 2>&1; then
        log_success "SSH service restarted"
    else
        log_error "Failed to restart SSH service"
        return 1
    fi
}

# Configure automatic security updates
configure_automatic_updates() {
    log_subsection "Configuring Automatic Security Updates"
    
    # Use the security library function
    if configure_automatic_updates; then
        log_success "Automatic security updates configured"
    else
        log_error "Failed to configure automatic security updates"
        return 1
    fi
    
    # Configure update notifications
    configure_update_notifications
}

# Configure update notifications
configure_update_notifications() {
    log_info "Configuring update notifications"
    
    local update_motd="/etc/update-motd.d/95-updates"
    
    cat > "$update_motd" << 'EOF'
#!/bin/sh
# Show available updates in MOTD

if [ -x /usr/lib/update-notifier/update-motd-updates-available ]; then
    /usr/lib/update-notifier/update-motd-updates-available
fi

if [ -f /var/run/reboot-required ]; then
    echo ""
    echo "*** System restart required ***"
fi
EOF
    
    chmod +x "$update_motd"
    log_success "Update notifications configured"
}

# Apply kernel hardening
apply_kernel_hardening() {
    log_subsection "Applying Kernel Hardening"
    
    # Use the security library function
    if harden_kernel_parameters; then
        log_success "Kernel parameters hardened"
    else
        log_error "Failed to harden kernel parameters"
        return 1
    fi
    
    # Configure additional security settings
    configure_additional_security_settings
}

# Configure additional security settings
configure_additional_security_settings() {
    log_info "Configuring additional security settings"
    
    # Configure core dump restrictions
    local limits_conf="/etc/security/limits.d/99-security.conf"
    
    cat > "$limits_conf" << 'EOF'
# Security limits
* hard core 0
* soft nproc 65536
* hard nproc 65536
* soft nofile 65536
* hard nofile 65536
EOF
    
    chmod 644 "$limits_conf"
    
    # Disable core dumps in profile
    echo "ulimit -c 0" >> /etc/profile
    
    # Configure systemd to not store core dumps
    if [[ -d /etc/systemd ]]; then
        mkdir -p /etc/systemd/coredump.conf.d
        cat > /etc/systemd/coredump.conf.d/disable.conf << 'EOF'
[Coredump]
Storage=none
ProcessSizeMax=0
EOF
    fi
    
    log_success "Additional security settings configured"
}

# Remove unnecessary packages and services
remove_unnecessary_packages() {
    log_subsection "Removing Unnecessary Packages"
    
    # Use the security library function
    remove_dangerous_packages
    
    # Remove additional unnecessary packages
    local unnecessary_packages=(
        "whoopsie"
        "apport"
        "popularity-contest"
        "ubuntu-report"
        "snapd"
    )
    
    local removed_packages=()
    
    for package in "${unnecessary_packages[@]}"; do
        if package_installed "$package"; then
            log_info "Removing unnecessary package: $package"
            if DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "$package" > /dev/null 2>&1; then
                removed_packages+=("$package")
                log_success "Removed: $package"
            else
                log_warn "Failed to remove: $package"
            fi
        fi
    done
    
    # Clean up after removals
    apt-get autoremove -y > /dev/null 2>&1 || true
    apt-get autoclean > /dev/null 2>&1 || true
    
    if [[ ${#removed_packages[@]} -gt 0 ]]; then
        log_info "Removed unnecessary packages: [${removed_packages[*]}]"
    else
        log_info "No unnecessary packages found to remove"
    fi
}

# Configure file permissions
configure_file_permissions() {
    log_subsection "Configuring File Permissions"
    
    # Secure important system files
    local files_to_secure=(
        "/etc/passwd:644"
        "/etc/group:644"
        "/etc/shadow:640"
        "/etc/gshadow:640"
        "/etc/ssh/sshd_config:600"
        "/etc/crontab:600"
        "/boot/grub/grub.cfg:600"
    )
    
    for file_perm in "${files_to_secure[@]}"; do
        local file_path="${file_perm%:*}"
        local perm="${file_perm#*:}"
        
        if [[ -f "$file_path" ]]; then
            chmod "$perm" "$file_path"
            log_debug "Secured file permissions: $file_path ($perm)"
        fi
    done
    
    # Secure directories
    local directories_to_secure=(
        "/etc/ssh:755"
        "/etc/ssl:755"
        "/var/log:755"
    )
    
    for dir_perm in "${directories_to_secure[@]}"; do
        local dir_path="${dir_perm%:*}"
        local perm="${dir_perm#*:}"
        
        if [[ -d "$dir_path" ]]; then
            chmod "$perm" "$dir_path"
            log_debug "Secured directory permissions: $dir_path ($perm)"
        fi
    done
    
    # Set umask for better default permissions
    echo "umask 027" >> /etc/profile
    
    log_success "File permissions configured"
}

# Setup intrusion detection
setup_intrusion_detection() {
    log_subsection "Setting up Intrusion Detection"
    
    # Configure rkhunter if installed
    if package_installed "rkhunter"; then
        configure_rkhunter
    fi
    
    # Configure chkrootkit if installed
    if package_installed "chkrootkit"; then
        configure_chkrootkit
    fi
    
    # Configure lynis if installed
    if package_installed "lynis"; then
        configure_lynis
    fi
    
    # Setup log monitoring
    setup_log_monitoring
}

# Configure rkhunter
configure_rkhunter() {
    log_info "Configuring rkhunter"
    
    local rkhunter_conf="/etc/rkhunter.conf"
    
    if [[ -f "$rkhunter_conf" ]]; then
        backup_file "$rkhunter_conf"
        
        # Update configuration
        sed -i 's/^#UPDATE_MIRRORS=1/UPDATE_MIRRORS=1/' "$rkhunter_conf"
        sed -i 's/^#MIRRORS_MODE=0/MIRRORS_MODE=1/' "$rkhunter_conf"
        sed -i 's/^#WEB_CMD=.*$/WEB_CMD="\/usr\/bin\/curl -s"/' "$rkhunter_conf"
        
        # Initialize database
        rkhunter --update > /dev/null 2>&1 || true
        rkhunter --propupd > /dev/null 2>&1 || true
        
        log_success "rkhunter configured"
    fi
}

# Configure chkrootkit
configure_chkrootkit() {
    log_info "Configuring chkrootkit"
    
    local chkrootkit_conf="/etc/chkrootkit.conf"
    
    cat > "$chkrootkit_conf" << 'EOF'
RUN_DAILY="true"
RUN_DAILY_OPTS="-q"
DIFF_MODE="true"
EOF
    
    chmod 644 "$chkrootkit_conf"
    log_success "chkrootkit configured"
}

# Configure lynis
configure_lynis() {
    log_info "Configuring lynis"
    
    # Update lynis database
    if command_exists "lynis"; then
        lynis update info > /dev/null 2>&1 || true
        log_success "lynis configured"
    fi
}

# Setup log monitoring
setup_log_monitoring() {
    log_info "Setting up log monitoring"
    
    # Create log monitoring script
    local monitor_script="/usr/local/bin/monitor-logs.sh"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# Log monitoring script

LOG_FILE="/var/log/security-monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting log monitoring check" >> "$LOG_FILE"

# Check for failed SSH logins
FAILED_SSH=$(grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)
if [ "$FAILED_SSH" -gt 10 ]; then
    echo "[$DATE] WARNING: $FAILED_SSH failed SSH attempts today" >> "$LOG_FILE"
fi

# Check for suspicious network activity
SUSPICIOUS_CONNECTIONS=$(ss -tuln | grep -v "127.0.0.1\|::1" | wc -l)
if [ "$SUSPICIOUS_CONNECTIONS" -gt 50 ]; then
    echo "[$DATE] INFO: $SUSPICIOUS_CONNECTIONS network connections active" >> "$LOG_FILE"
fi

echo "[$DATE] Log monitoring check completed" >> "$LOG_FILE"
EOF
    
    chmod +x "$monitor_script"
    
    # Add to crontab to run every hour
    (crontab -l 2>/dev/null; echo "0 * * * * $monitor_script") | crontab -
    
    log_success "Log monitoring configured"
}

# Create security report
create_security_report() {
    log_subsection "Creating Security Report"
    
    # Use the security library function
    local report_file
    report_file=$(generate_security_report)
    
    if [[ -n "$report_file" ]] && [[ -f "$report_file" ]]; then
        log_success "Security report created: $report_file"
        
        # Create symlink to latest report
        local latest_report="${LOG_DIR}/security-report-latest.txt"
        ln -sf "$report_file" "$latest_report"
        log_info "Latest security report: $latest_report"
    else
        log_warn "Failed to create security report"
    fi
}

# Verify security configuration
verify_security_configuration() {
    log_subsection "Verifying Security Configuration"
    
    local issues=()
    
    # Check UFW status
    if ! ufw status | grep -q "Status: active"; then
        issues+=("UFW firewall not active")
    fi
    
    # Check fail2ban status
    if ! systemctl is-active --quiet fail2ban; then
        issues+=("Fail2ban service not running")
    fi
    
    # Check SSH configuration
    if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        issues+=("SSH root login enabled")
    fi
    
    if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        issues+=("SSH password authentication enabled")
    fi
    
    # Check for unnecessary services
    local dangerous_services=("telnet" "ftp" "rsh" "finger")
    for service in "${dangerous_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            issues+=("Dangerous service running: $service")
        fi
    done
    
    # Check file permissions
    if [[ $(stat -c "%a" /etc/shadow 2>/dev/null) != "640" ]]; then
        issues+=("Incorrect permissions on /etc/shadow")
    fi
    
    # Report results
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "Security configuration verification passed"
        return 0
    else
        log_warn "Security configuration issues found:"
        for issue in "${issues[@]}"; do
            log_warn "  - $issue"
        done
        return 1
    fi
}

# Run security scan
run_security_scan() {
    log_subsection "Running Security Scan"
    
    # Use the security library function
    security_scan
    
    log_success "Security scan completed"
}

# Module cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Security module failed with exit code: $exit_code"
        
        # Try to ensure basic security is in place
        if command_exists "ufw"; then
            ufw --force enable > /dev/null 2>&1 || true
        fi
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"