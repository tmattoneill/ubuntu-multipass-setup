#!/usr/bin/env bash

# Module: Final Validation and Cleanup
# Comprehensive system validation and cleanup

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="validation"
readonly MODULE_DESCRIPTION="Final Validation and Cleanup"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    validate_system_configuration
    validate_installed_services
    validate_security_configuration
    validate_performance_settings
    validate_user_environments
    run_comprehensive_tests
    cleanup_installation_artifacts
    generate_final_reports
    create_maintenance_tools
    
    log_success "Final validation and cleanup completed successfully"
}

# Validate system configuration
validate_system_configuration() {
    log_subsection "Validating System Configuration"
    
    local validation_failures=()
    
    # Validate basic system requirements
    log_info "Validating basic system requirements..."
    
    if ! validate_ubuntu_version; then
        validation_failures+=("Ubuntu version validation failed")
    fi
    
    if ! validate_architecture; then
        validation_failures+=("Architecture validation failed")
    fi
    
    if ! validate_disk_space; then
        validation_failures+=("Disk space validation failed")
    fi
    
    if ! validate_memory; then
        validation_failures+=("Memory validation failed")
    fi
    
    if ! validate_internet_connection; then
        validation_failures+=("Internet connection validation failed")
    fi
    
    # Report system validation results
    if [[ ${#validation_failures[@]} -eq 0 ]]; then
        log_success "System configuration validation passed"
    else
        log_error "System configuration validation failed:"
        for failure in "${validation_failures[@]}"; do
            log_error "  - $failure"
        done
        return 1
    fi
}

# Validate installed services
validate_installed_services() {
    log_subsection "Validating Installed Services"
    
    local service_failures=()
    local services_to_check=()
    
    # Add services based on installation mode
    case "$INSTALL_MODE" in
        "full")
            services_to_check=("nginx" "ssh" "fail2ban" "ufw")
            ;;
        "nginx-only")
            services_to_check=("nginx" "ssh" "fail2ban" "ufw")
            ;;
        "dev-only")
            services_to_check=("ssh")
            ;;
        "minimal")
            services_to_check=("ssh")
            ;;
    esac
    
    log_info "Validating services: [${services_to_check[*]}]"
    
    for service in "${services_to_check[@]}"; do
        log_info "Checking service: $service"
        
        # Check if service is installed
        if ! validate_service_installation "$service"; then
            service_failures+=("$service: not installed")
            continue
        fi
        
        # Check if service is enabled
        if ! service_enabled "$service"; then
            service_failures+=("$service: not enabled")
        fi
        
        # Check if service is running
        if ! service_running "$service"; then
            service_failures+=("$service: not running")
            
            # Try to start the service
            log_info "Attempting to start service: $service"
            if systemctl start "$service" > /dev/null 2>&1; then
                if wait_for_service "$service" 30; then
                    log_success "Service started successfully: $service"
                else
                    service_failures+=("$service: failed to start")
                fi
            else
                service_failures+=("$service: failed to start")
            fi
        else
            log_success "Service validation passed: $service"
        fi
    done
    
    # Report service validation results
    if [[ ${#service_failures[@]} -eq 0 ]]; then
        log_success "Service validation passed for all services"
    else
        log_warn "Service validation issues found:"
        for failure in "${service_failures[@]}"; do
            log_warn "  - $failure"
        done
    fi
}

# Validate security configuration
validate_security_configuration() {
    log_subsection "Validating Security Configuration"
    
    local security_issues=()
    
    log_info "Validating security settings..."
    
    # Check firewall status
    if ! ufw status | grep -q "Status: active"; then
        security_issues+=("UFW firewall is not active")
    else
        log_success "UFW firewall is active"
    fi
    
    # Check fail2ban status
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2ban is running"
    else
        security_issues+=("Fail2ban is not running")
    fi
    
    # Check SSH configuration
    local ssh_config="/etc/ssh/sshd_config"
    if [[ -f "$ssh_config" ]]; then
        if grep -q "PermitRootLogin no" "$ssh_config"; then
            log_success "SSH root login disabled"
        else
            security_issues+=("SSH root login not disabled")
        fi
        
        if grep -q "PasswordAuthentication no" "$ssh_config"; then
            log_success "SSH password authentication disabled"
        else
            security_issues+=("SSH password authentication not disabled")
        fi
    else
        security_issues+=("SSH configuration file not found")
    fi
    
    # Check for dangerous services
    local dangerous_services=("telnet" "rsh" "finger")
    for service in "${dangerous_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            security_issues+=("Dangerous service running: $service")
        fi
    done
    
    # Check file permissions
    local critical_files=("/etc/shadow" "/etc/ssh/sshd_config")
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(stat -c "%a" "$file")
            case "$file" in
                "/etc/shadow")
                    if [[ "$perms" != "640" ]]; then
                        security_issues+=("Incorrect permissions on $file: $perms")
                    fi
                    ;;
                "/etc/ssh/sshd_config")
                    if [[ "$perms" != "600" ]]; then
                        security_issues+=("Incorrect permissions on $file: $perms")
                    fi
                    ;;
            esac
        fi
    done
    
    # Report security validation results
    if [[ ${#security_issues[@]} -eq 0 ]]; then
        log_success "Security configuration validation passed"
    else
        log_warn "Security configuration issues found:"
        for issue in "${security_issues[@]}"; do
            log_warn "  - $issue"
        done
    fi
}

# Validate performance settings
validate_performance_settings() {
    log_subsection "Validating Performance Settings"
    
    local performance_issues=()
    
    log_info "Validating performance settings..."
    
    # Check kernel parameters
    local swappiness
    swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    if [[ $swappiness -eq $SWAPPINESS ]]; then
        log_success "Swappiness correctly set to: $swappiness"
    else
        performance_issues+=("Swappiness not optimal: $swappiness (expected: $SWAPPINESS)")
    fi
    
    # Check TCP congestion control
    local tcp_cc
    tcp_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "unknown")
    if [[ "$tcp_cc" == "bbr" ]] || [[ "$tcp_cc" == "cubic" ]]; then
        log_success "TCP congestion control: $tcp_cc"
    else
        performance_issues+=("TCP congestion control not optimal: $tcp_cc")
    fi
    
    # Check I/O schedulers
    log_info "Checking I/O schedulers..."
    for device in /sys/block/*/queue/scheduler; do
        if [[ -f "$device" ]]; then
            local device_name
            device_name=$(basename "$(dirname "$(dirname "$device")")")
            local scheduler
            scheduler=$(cat "$device" | sed 's/.*\[\(.*\)\].*/\1/')
            log_info "  $device_name: $scheduler"
        fi
    done
    
    # Check systemd limits
    if [[ -f /etc/systemd/system.conf ]]; then
        if grep -q "DefaultLimitNOFILE=$SYSTEMD_DEFAULT_LIMIT_NOFILE" /etc/systemd/system.conf; then
            log_success "Systemd file limits configured"
        else
            performance_issues+=("Systemd file limits not configured")
        fi
    fi
    
    # Report performance validation results
    if [[ ${#performance_issues[@]} -eq 0 ]]; then
        log_success "Performance settings validation passed"
    else
        log_warn "Performance settings issues found:"
        for issue in "${performance_issues[@]}"; do
            log_warn "  - $issue"
        done
    fi
}

# Validate user environments
validate_user_environments() {
    log_subsection "Validating User Environments"
    
    local user_issues=()
    local users_to_check=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    
    for username in "${users_to_check[@]}"; do
        log_info "Validating user environment: $username"
        
        if ! user_exists "$username"; then
            user_issues+=("User does not exist: $username")
            continue
        fi
        
        local home_dir
        home_dir=$(getent passwd "$username" | cut -d: -f6)
        
        # Check home directory
        if [[ ! -d "$home_dir" ]]; then
            user_issues+=("Home directory does not exist: $home_dir")
            continue
        fi
        
        # Check shell configuration
        local shell_configs=(".bashrc" ".zshrc" ".profile")
        local has_shell_config=false
        
        for config in "${shell_configs[@]}"; do
            if [[ -f "$home_dir/$config" ]]; then
                has_shell_config=true
                log_success "Shell configuration found: $home_dir/$config"
                break
            fi
        done
        
        if [[ "$has_shell_config" == "false" ]]; then
            user_issues+=("No shell configuration found for user: $username")
        fi
        
        # Check SSH directory
        if [[ -d "$home_dir/.ssh" ]]; then
            local ssh_perms
            ssh_perms=$(stat -c "%a" "$home_dir/.ssh")
            if [[ "$ssh_perms" == "700" ]]; then
                log_success "SSH directory permissions correct: $username"
            else
                user_issues+=("Incorrect SSH directory permissions for $username: $ssh_perms")
            fi
        fi
        
        # Check user groups
        local user_groups
        user_groups=$(groups "$username" 2>/dev/null || echo "")
        if echo "$user_groups" | grep -q "$WEBAPP_GROUP"; then
            log_success "User in webapp group: $username"
        else
            user_issues+=("User not in webapp group: $username")
        fi
    done
    
    # Report user validation results
    if [[ ${#user_issues[@]} -eq 0 ]]; then
        log_success "User environment validation passed"
    else
        log_warn "User environment issues found:"
        for issue in "${user_issues[@]}"; do
            log_warn "  - $issue"
        done
    fi
}

# Run comprehensive tests
run_comprehensive_tests() {
    log_subsection "Running Comprehensive Tests"
    
    # Test web server functionality
    test_web_server
    
    # Test development environments
    test_development_environments
    
    # Test security features
    test_security_features
    
    # Test monitoring and logging
    test_monitoring_logging
}

# Test web server functionality
test_web_server() {
    log_info "Testing web server functionality..."
    
    if systemctl is-active --quiet nginx; then
        # Test HTTP response
        local http_response
        http_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
        
        if [[ "$http_response" == "200" ]]; then
            log_success "Web server HTTP test passed"
        else
            log_warn "Web server HTTP test failed: HTTP $http_response"
        fi
        
        # Test health endpoint
        local health_response
        health_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health 2>/dev/null || echo "000")
        
        if [[ "$health_response" == "200" ]]; then
            log_success "Web server health endpoint test passed"
        else
            log_warn "Web server health endpoint test failed: HTTP $health_response"
        fi
        
        # Test configuration
        if nginx -t > /dev/null 2>&1; then
            log_success "Nginx configuration test passed"
        else
            log_error "Nginx configuration test failed"
        fi
    else
        log_info "Nginx not running, skipping web server tests"
    fi
}

# Test development environments
test_development_environments() {
    log_info "Testing development environments..."
    
    # Test Node.js environment
    if [[ -f "$NVM_DIR/nvm.sh" ]]; then
        # Unset NPM_CONFIG_PREFIX to avoid NVM conflicts
        unset NPM_CONFIG_PREFIX
        if source "$NVM_DIR/nvm.sh" && nvm use node > /dev/null 2>&1 && node --version > /dev/null 2>&1; then
            local node_version
            node_version=$(node --version)
            log_success "Node.js environment test passed: $node_version"
        else
            log_warn "Node.js environment test failed"
        fi
        
        if npm --version > /dev/null 2>&1; then
            local npm_version
            npm_version=$(npm --version)
            log_success "npm test passed: v$npm_version"
        else
            log_warn "npm test failed"
        fi
    else
        log_info "Node.js not installed, skipping Node.js tests"
    fi
    
    # Test Python environment
    if command_exists "python3"; then
        local python_version
        python_version=$(python3 --version)
        log_success "Python environment test passed: $python_version"
        
        if command_exists "pip3"; then
            local pip_version
            pip_version=$(pip3 --version | awk '{print $2}')
            log_success "pip test passed: v$pip_version"
        else
            log_warn "pip test failed"
        fi
    else
        log_info "Python not installed, skipping Python tests"
    fi
    
    # Test virtual environment creation
    local test_venv="/tmp/test-validation-venv-$$"
    if python3 -m venv "$test_venv" > /dev/null 2>&1; then
        log_success "Python virtual environment test passed"
        rm -rf "$test_venv"
    else
        log_warn "Python virtual environment test failed"
    fi
}

# Test security features
test_security_features() {
    log_info "Testing security features..."
    
    # Test firewall
    if ufw status | grep -q "Status: active"; then
        log_success "Firewall test passed"
    else
        log_warn "Firewall test failed: not active"
    fi
    
    # Test fail2ban
    if systemctl is-active --quiet fail2ban; then
        if command_exists "fail2ban-client"; then
            local fail2ban_status
            fail2ban_status=$(fail2ban-client status 2>/dev/null | grep "Number of jail" || echo "unknown")
            log_success "Fail2ban test passed: $fail2ban_status"
        else
            log_success "Fail2ban service test passed"
        fi
    else
        log_warn "Fail2ban test failed: not running"
    fi
    
    # Test SSH configuration
    if sshd -t > /dev/null 2>&1; then
        log_success "SSH configuration test passed"
    else
        log_warn "SSH configuration test failed"
    fi
}

# Test monitoring and logging
test_monitoring_logging() {
    log_info "Testing monitoring and logging..."
    
    # Test log directories
    local log_dirs=("/var/log" "/var/log/nginx")
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]] && [[ -w "$log_dir" ]]; then
            log_success "Log directory test passed: $log_dir"
        else
            log_warn "Log directory test failed: $log_dir"
        fi
    done
    
    # Test monitoring scripts
    local monitor_scripts=(
        "/usr/local/bin/system-health.sh"
        "/usr/local/bin/performance-monitor.sh"
    )
    
    for script in "${monitor_scripts[@]}"; do
        if [[ -x "$script" ]]; then
            log_success "Monitoring script test passed: $script"
        else
            log_warn "Monitoring script test failed: $script"
        fi
    done
    
    # Test cron jobs
    if crontab -l 2>/dev/null | grep -q "system-health"; then
        log_success "Monitoring cron jobs test passed"
    else
        log_warn "Monitoring cron jobs test failed"
    fi
}

# Cleanup installation artifacts
cleanup_installation_artifacts() {
    log_subsection "Cleaning Up Installation Artifacts"
    
    # Clean package cache
    log_info "Cleaning package cache..."
    apt-get autoremove -y > /dev/null 2>&1 || true
    apt-get autoclean > /dev/null 2>&1 || true
    apt-get clean > /dev/null 2>&1 || true
    
    # Clean temporary files
    log_info "Cleaning temporary files..."
    cleanup_temp_files
    
    # Remove old kernels (keep current and one previous)
    log_info "Cleaning old kernels..."
    local current_kernel
    current_kernel=$(uname -r)
    
    # Only remove old kernels if we have more than 2 installed
    local kernel_count
    kernel_count=$(dpkg -l | grep -c "linux-image-[0-9]" || echo "0")
    
    if [[ $kernel_count -gt 2 ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y > /dev/null 2>&1 || true
        log_success "Old kernels cleaned up"
    else
        log_debug "Kernel cleanup not needed"
    fi
    
    # Clean log files older than 30 days
    log_info "Cleaning old log files..."
    find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null || true
    
    # Clean up setup-specific temporary files
    find /tmp -name "setup-*" -type f -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "*-install-*" -type f -mtime +1 -delete 2>/dev/null || true
    
    # Clean package lists cache
    rm -rf /var/lib/apt/lists/* 2>/dev/null || true
    apt-get update > /dev/null 2>&1 || true
    
    log_success "Installation artifacts cleaned up"
}

# Generate final reports
generate_final_reports() {
    log_subsection "Generating Final Reports"
    
    # Generate system summary report
    generate_system_summary
    
    # Generate security report
    generate_security_report_final
    
    # Generate performance report
    generate_performance_report_final
    
    # Generate maintenance checklist
    generate_maintenance_checklist
}

# Generate system summary report
generate_system_summary() {
    log_info "Generating system summary report"
    
    local summary_file="${LOG_DIR}/system-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Ubuntu Server Setup - System Summary"
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "=========================================="
        echo
        
        echo "SYSTEM INFORMATION:"
        echo "OS: $(get_system_info "os") $(get_system_info "version")"
        echo "Kernel: $(get_system_info "kernel")"
        echo "Architecture: $(get_system_info "arch")"
        echo "CPU Cores: $(get_cpu_cores)"
        echo "Memory: $(get_system_info "memory")"
        echo "Disk Space: $(get_system_info "disk")"
        echo "IP Address: $(get_system_info "ip")"
        echo
        
        echo "INSTALLATION CONFIGURATION:"
        echo "Installation Mode: $INSTALL_MODE"
        echo "Primary User: $PRIMARY_USER"
        echo "Deploy User: $DEFAULT_DEPLOY_USER"
        echo "Node.js Version: $NODE_VERSION"
        echo "Python Version: $PYTHON_VERSION"
        echo "Nginx Version: $NGINX_VERSION"
        echo
        
        echo "INSTALLED SERVICES:"
        local services=("nginx" "ssh" "fail2ban" "ufw")
        for service in "${services[@]}"; do
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                local status
                if systemctl is-active --quiet "$service"; then
                    status="enabled, running"
                else
                    status="enabled, stopped"
                fi
                echo "  $service: $status"
            else
                echo "  $service: not installed/disabled"
            fi
        done
        echo
        
        echo "NETWORK CONFIGURATION:"
        echo "Firewall Status: $(ufw status | head -1 | awk '{print $2}')"
        echo "Open Ports:"
        ufw status | grep -E "^[0-9]" | awk '{print "  " $1 " " $2}' 2>/dev/null || echo "  None configured"
        echo
        
        echo "DIRECTORY STRUCTURE:"
        echo "  Web Root: $WEBAPP_ROOT"
        echo "  Application Data: $APP_DATA_DIR"
        echo "  Logs: $LOG_DIR"
        echo "  Backups: $BACKUP_DIR"
        echo
        
        echo "PERFORMANCE SETTINGS:"
        echo "  Swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null || echo 'unknown')"
        echo "  TCP Congestion Control: $(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo 'unknown')"
        echo "  File Descriptor Limit: $SYSTEMD_DEFAULT_LIMIT_NOFILE"
        echo
        
        echo "NEXT STEPS:"
        echo "1. Configure your domain and SSL certificates"
        echo "2. Deploy your applications to $WEBAPP_ROOT"
        echo "3. Set up regular backups"
        echo "4. Monitor system performance and logs"
        echo "5. Keep the system updated with security patches"
        echo
        
        echo "USEFUL COMMANDS:"
        echo "  System status: /usr/local/bin/performance-report.sh"
        echo "  Health check: /usr/local/bin/health-check-api.sh"
        echo "  Log analysis: /usr/local/bin/analyze-logs.sh"
        echo "  Security scan: lynis audit system"
        echo
        
        echo "LOG FILES:"
        echo "  Setup logs: $LOG_FILE"
        echo "  System logs: /var/log/syslog"
        echo "  Web server logs: /var/log/nginx/"
        echo "  Security logs: /var/log/auth.log"
        echo
        
        echo "=========================================="
        echo "Ubuntu Server Setup Summary Complete"
        
    } > "$summary_file"
    
    # Create symlink to latest report
    local latest_summary="${LOG_DIR}/system-summary-latest.txt"
    ln -sf "$summary_file" "$latest_summary"
    
    log_success "System summary report created: $summary_file"
}

# Generate final security report
generate_security_report_final() {
    log_info "Generating final security report"
    
    # Use the security library function
    local security_report
    security_report=$(generate_security_report)
    
    if [[ -n "$security_report" ]] && [[ -f "$security_report" ]]; then
        log_success "Final security report created: $security_report"
    else
        log_warn "Failed to create final security report"
    fi
}

# Generate final performance report
generate_performance_report_final() {
    log_info "Generating final performance report"
    
    if [[ -x "/usr/local/bin/performance-report.sh" ]]; then
        local perf_report="${LOG_DIR}/performance-report-final-$(date +%Y%m%d-%H%M%S).txt"
        /usr/local/bin/performance-report.sh > "$perf_report"
        
        # Create symlink to latest report
        local latest_perf="${LOG_DIR}/performance-report-latest.txt"
        ln -sf "$perf_report" "$latest_perf"
        
        log_success "Final performance report created: $perf_report"
    else
        log_warn "Performance report script not available"
    fi
}

# Generate maintenance checklist
generate_maintenance_checklist() {
    log_info "Generating maintenance checklist"
    
    local checklist_file="${LOG_DIR}/maintenance-checklist.txt"
    
    cat > "$checklist_file" << 'EOF'
Ubuntu Server Maintenance Checklist
====================================

DAILY TASKS:
□ Check system health: /usr/local/bin/system-health.sh
□ Review security logs: tail -f /var/log/auth.log
□ Monitor disk space: df -h
□ Check service status: systemctl status nginx ssh fail2ban

WEEKLY TASKS:
□ Review performance reports: /usr/local/bin/performance-report.sh
□ Analyze web server logs: /usr/local/bin/analyze-logs.sh
□ Check for failed services: systemctl --failed
□ Review fail2ban status: fail2ban-client status
□ Clean up old log files: find /var/log -name "*.log" -mtime +7 -delete
□ Check disk usage by directory: du -sh /var/log/* /var/www/* /home/*

MONTHLY TASKS:
□ Update system packages: apt update && apt upgrade
□ Review and rotate logs: logrotate -f /etc/logrotate.conf
□ Check SSL certificate expiration: openssl x509 -in cert.pem -noout -dates
□ Review user accounts and permissions
□ Update security tools: rkhunter --update; lynis update info
□ Run security scan: lynis audit system
□ Review backup integrity
□ Clean up old kernels: apt autoremove
□ Review firewall rules: ufw status verbose
□ Check for rootkits: rkhunter --check

QUARTERLY TASKS:
□ Review and update backup strategy
□ Audit user access and remove unused accounts
□ Review and update firewall rules
□ Performance tuning review
□ Security policy review
□ Update system documentation
□ Test disaster recovery procedures

ANNUAL TASKS:
□ Full security audit
□ Hardware health check
□ Capacity planning review
□ Update emergency contact information
□ Review and update security policies
□ Plan for major OS upgrades

EMERGENCY PROCEDURES:
□ High CPU usage: htop, check top processes
□ High memory usage: free -h, check memory-hungry processes
□ Disk space full: ncdu /, clean up large files
□ Service down: systemctl status <service>, check logs
□ Security breach: disconnect network, preserve logs, notify admin
□ System unresponsive: check console access, plan reboot

USEFUL COMMANDS:
- System monitoring: htop, iotop, iftop
- Log analysis: grep, tail -f, journalctl
- Network debugging: ss -tuln, netstat -i
- Process management: ps aux, kill, systemctl
- File operations: find, du, df, lsof
- Security: fail2ban-client, ufw, last

CONFIGURATION FILES:
- Nginx: /etc/nginx/nginx.conf
- SSH: /etc/ssh/sshd_config
- Firewall: /etc/ufw/
- Fail2ban: /etc/fail2ban/
- System limits: /etc/security/limits.conf
- Kernel parameters: /etc/sysctl.d/

LOG LOCATIONS:
- System: /var/log/syslog
- Authentication: /var/log/auth.log
- Web server: /var/log/nginx/
- Application: /var/log/webapps/
- Setup: /var/log/setup/
- Security: /var/log/security-*.log

EOF
    
    chmod 644 "$checklist_file"
    log_success "Maintenance checklist created: $checklist_file"
}

# Create maintenance tools
create_maintenance_tools() {
    log_subsection "Creating Maintenance Tools"
    
    # Create system status script
    create_system_status_script
    
    # Create quick setup verification script
    create_setup_verification_script
    
    # Create troubleshooting guide
    create_troubleshooting_guide
}

# Create system status script
create_system_status_script() {
    log_info "Creating system status script"
    
    local status_script="/usr/local/bin/system-status.sh"
    
    cat > "$status_script" << 'EOF'
#!/bin/bash
# Quick system status script

echo "=== System Status Overview ==="
echo "Timestamp: $(date)"
echo "Uptime: $(uptime -p)"
echo

echo "=== Service Status ==="
services=("nginx" "ssh" "fail2ban" "ufw")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "✓ $service: running"
    else
        echo "✗ $service: stopped"
    fi
done
echo

echo "=== System Resources ==="
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory Usage: $(free -h | awk 'NR==2{printf "%s/%s (%.1f%%)", $3,$2,$3*100/$2 }')"
echo "Disk Usage:"
df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev' | awk '{print "  " $6 ": " $3 "/" $2 " (" $5 ")"}'
echo

echo "=== Network Status ==="
echo "Active Connections: $(ss -tuln | wc -l)"
echo "Firewall Status: $(ufw status | head -1 | awk '{print $2}')"
echo

echo "=== Recent Alerts ==="
if [[ -f /var/log/monitoring-alerts.log ]]; then
    tail -5 /var/log/monitoring-alerts.log 2>/dev/null || echo "No recent alerts"
else
    echo "No alert log found"
fi

echo
echo "=== System Status Complete ==="
EOF
    
    chmod +x "$status_script"
    log_success "System status script created: $status_script"
}

# Create setup verification script
create_setup_verification_script() {
    log_info "Creating setup verification script"
    
    local verify_script="/usr/local/bin/verify-setup.sh"
    
    cat > "$verify_script" << 'EOF'
#!/bin/bash
# Setup verification script

echo "=== Ubuntu Server Setup Verification ==="
echo "Timestamp: $(date)"
echo

total_checks=0
passed_checks=0

check_item() {
    local description="$1"
    local command="$2"
    
    ((total_checks++))
    echo -n "Checking $description... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo "✓ PASS"
        ((passed_checks++))
    else
        echo "✗ FAIL"
    fi
}

echo "=== System Requirements ==="
check_item "Operating System" "grep -q 'Ubuntu' /etc/os-release"
check_item "Architecture" "uname -m | grep -E 'x86_64|aarch64'"
check_item "Memory (minimum 1GB)" "[[ \$(free -m | awk 'NR==2{print \$2}') -ge 1024 ]]"
check_item "Disk Space (minimum 10GB)" "[[ \$(df / | awk 'NR==2{print int(\$4/1024/1024)}') -ge 10 ]]"

echo
echo "=== Essential Services ==="
check_item "SSH service" "systemctl is-active --quiet ssh"
check_item "UFW firewall" "ufw status | grep -q 'Status: active'"
check_item "Fail2ban service" "systemctl is-active --quiet fail2ban"

echo
echo "=== Web Server ==="
if systemctl is-active --quiet nginx; then
    check_item "Nginx service" "systemctl is-active --quiet nginx"
    check_item "Nginx configuration" "nginx -t"
    check_item "HTTP response" "[[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost/) == '200' ]]"
else
    echo "Nginx not installed/running - skipping web server checks"
fi

echo
echo "=== Development Environment ==="
if [[ -f /opt/nvm/nvm.sh ]]; then
    check_item "Node.js environment" "source /opt/nvm/nvm.sh && node --version"
    check_item "npm package manager" "source /opt/nvm/nvm.sh && npm --version"
else
    echo "Node.js not installed - skipping Node.js checks"
fi

if command -v python3 >/dev/null 2>&1; then
    check_item "Python 3" "python3 --version"
    check_item "pip package manager" "pip3 --version"
else
    echo "Python not installed - skipping Python checks"
fi

echo
echo "=== Security Configuration ==="
check_item "SSH root login disabled" "grep -q 'PermitRootLogin no' /etc/ssh/sshd_config"
check_item "SSH password auth disabled" "grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config"
check_item "Correct shadow permissions" "[[ \$(stat -c '%a' /etc/shadow) == '640' ]]"

echo
echo "=== User Environment ==="
check_item "Primary user exists" "id $PRIMARY_USER"
check_item "Deploy user exists" "id $DEFAULT_DEPLOY_USER"
check_item "Primary user home directory" "[[ -d /home/$PRIMARY_USER ]]"
check_item "Deploy user home directory" "[[ -d /home/$DEFAULT_DEPLOY_USER ]]"

echo
echo "=== Monitoring ==="
check_item "System health script" "[[ -x /usr/local/bin/system-health.sh ]]"
check_item "Performance monitor script" "[[ -x /usr/local/bin/performance-monitor.sh ]]"
check_item "Health check cron job" "crontab -l | grep -q system-health"

echo
echo "=== Verification Summary ==="
echo "Total checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed: $((total_checks - passed_checks))"

if [[ $passed_checks -eq $total_checks ]]; then
    echo "✓ All checks passed - setup is complete and working correctly!"
    exit 0
else
    echo "✗ Some checks failed - please review the setup"
    exit 1
fi
EOF
    
    chmod +x "$verify_script"
    log_success "Setup verification script created: $verify_script"
}

# Create troubleshooting guide
create_troubleshooting_guide() {
    log_info "Creating troubleshooting guide"
    
    local guide_file="${LOG_DIR}/troubleshooting-guide.txt"
    
    cat > "$guide_file" << 'EOF'
Ubuntu Server Setup - Troubleshooting Guide
============================================

COMMON ISSUES AND SOLUTIONS:

1. SERVICE WON'T START
   Problem: Service fails to start or keeps stopping
   
   Solutions:
   - Check service status: systemctl status <service>
   - Check service logs: journalctl -u <service> -n 50
   - Verify configuration: <service> -t (for nginx, apache, etc.)
   - Check for port conflicts: ss -tuln | grep <port>
   - Restart service: systemctl restart <service>
   
   Example:
   systemctl status nginx
   journalctl -u nginx -n 50
   nginx -t
   systemctl restart nginx

2. WEB SERVER NOT ACCESSIBLE
   Problem: Cannot access website from browser
   
   Solutions:
   - Check if nginx is running: systemctl status nginx
   - Check nginx configuration: nginx -t
   - Check firewall rules: ufw status
   - Check if port 80/443 is open: ss -tuln | grep :80
   - Test locally: curl http://localhost/
   - Check error logs: tail -f /var/log/nginx/error.log
   
3. HIGH RESOURCE USAGE
   Problem: Server running slowly or high CPU/memory usage
   
   Solutions:
   - Check top processes: htop or top
   - Check memory usage: free -h
   - Check disk usage: df -h and du -sh /*
   - Check I/O activity: iotop
   - Check network activity: iftop
   - Review recent changes in logs
   
4. DISK SPACE FULL
   Problem: No space left on device
   
   Solutions:
   - Find large files: du -sh /* | sort -hr
   - Clean log files: find /var/log -name "*.log" -mtime +7 -delete
   - Clean package cache: apt clean && apt autoremove
   - Clean temporary files: rm -rf /tmp/* /var/tmp/*
   - Check for core dumps: find / -name "core.*" -delete 2>/dev/null
   
5. SSH ACCESS ISSUES
   Problem: Cannot connect via SSH
   
   Solutions:
   - Check SSH service: systemctl status ssh
   - Check SSH configuration: sshd -t
   - Check firewall: ufw status | grep ssh
   - Check fail2ban: fail2ban-client status sshd
   - Review auth logs: tail -f /var/log/auth.log
   - Test from localhost: ssh localhost
   
6. SSL/TLS CERTIFICATE ISSUES
   Problem: SSL certificate expired or invalid
   
   Solutions:
   - Check certificate validity: openssl x509 -in cert.pem -noout -dates
   - Renew Let's Encrypt: certbot renew
   - Check nginx SSL config: nginx -t
   - Restart nginx after renewal: systemctl restart nginx
   - Check certificate chain: openssl s_client -connect domain.com:443
   
7. DATABASE CONNECTION ISSUES
   Problem: Cannot connect to database
   
   Solutions:
   - Check database service: systemctl status mysql/postgresql
   - Check database logs: tail -f /var/log/mysql/error.log
   - Test connection: mysql -u user -p / psql -U user -d database
   - Check database configuration files
   - Verify user permissions and passwords
   
8. APPLICATION WON'T START
   Problem: Node.js/Python application fails to start
   
   Solutions:
   - Check application logs in /var/log/webapps/
   - Verify environment variables
   - Check file permissions: ls -la /var/www/
   - Test manually: cd /var/www/app && npm start
   - Check PM2 status: pm2 status
   - Review systemd service: systemctl status app-name
   
9. FIREWALL BLOCKING TRAFFIC
   Problem: Legitimate traffic being blocked
   
   Solutions:
   - Check UFW rules: ufw status verbose
   - Check fail2ban: fail2ban-client status
   - Unban IP: fail2ban-client set sshd unbanip IP_ADDRESS
   - Review UFW logs: grep UFW /var/log/syslog
   - Temporarily disable: ufw disable (re-enable after testing!)
   
10. PERFORMANCE DEGRADATION
    Problem: Server running slower than usual
    
    Solutions:
    - Check system load: uptime
    - Monitor resources: htop, iotop, iftop
    - Check for swap usage: free -h
    - Review recent logs for errors
    - Check disk I/O: iostat -x 1
    - Review running processes: ps aux --sort=-%cpu
    
DIAGNOSTIC COMMANDS:

System Information:
- uname -a                    # System information
- lsb_release -a             # OS version
- df -h                      # Disk usage
- free -h                    # Memory usage
- lscpu                      # CPU information

Process Monitoring:
- htop                       # Interactive process viewer
- ps aux                     # List all processes
- pgrep -f process_name      # Find process by name
- kill -9 PID               # Force kill process

Network Diagnostics:
- ss -tuln                   # List listening ports
- netstat -i                # Network interface statistics
- ping google.com           # Test connectivity
- nslookup domain.com       # DNS lookup
- traceroute domain.com     # Trace network path

Log Analysis:
- tail -f /var/log/syslog   # Follow system log
- grep -i error /var/log/syslog  # Search for errors
- journalctl -f             # Follow systemd logs
- journalctl -u service     # Service-specific logs

Service Management:
- systemctl status service  # Check service status
- systemctl restart service # Restart service
- systemctl enable service  # Enable at boot
- systemctl disable service # Disable at boot

File Operations:
- find / -name filename     # Find file by name
- find / -size +100M       # Find large files
- lsof | grep filename     # Show what's using a file
- chmod 755 file           # Change permissions

EMERGENCY PROCEDURES:

If system is unresponsive:
1. Try SSH connection
2. Check console access if available
3. Review recent changes
4. Consider graceful reboot: shutdown -r now
5. If necessary, force reboot via console

If security breach suspected:
1. Disconnect from network immediately
2. Preserve current state for analysis
3. Check fail2ban logs: fail2ban-client status
4. Review auth logs: grep -i "failed\|invalid" /var/log/auth.log
5. Change all passwords
6. Update and patch system
7. Review and strengthen security

GETTING HELP:

1. Check setup logs: /var/log/setup/
2. Run verification script: /usr/local/bin/verify-setup.sh
3. Check system status: /usr/local/bin/system-status.sh
4. Review this troubleshooting guide
5. Search Ubuntu community forums
6. Contact system administrator

Remember: Always backup before making significant changes!
EOF
    
    chmod 644 "$guide_file"
    log_success "Troubleshooting guide created: $guide_file"
}

# Module cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Final validation module failed with exit code: $exit_code"
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"