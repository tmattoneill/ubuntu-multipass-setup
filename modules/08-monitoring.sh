#!/usr/bin/env bash

# Module: Monitoring Setup
# Install and configure system monitoring tools

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="monitoring"
readonly MODULE_DESCRIPTION="System Monitoring Setup"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    install_monitoring_packages
    configure_system_monitoring
    setup_log_monitoring
    create_monitoring_scripts
    configure_alerts
    setup_health_checks
    
    log_success "Monitoring module completed successfully"
}

# Install monitoring packages
install_monitoring_packages() {
    log_subsection "Installing Monitoring Packages"
    
    local packages=("${MONITORING_PACKAGES[@]}")
    local failed_packages=()
    
    log_info "Installing monitoring packages: [${packages[*]}]"
    
    for package in "${packages[@]}"; do
        if package_installed "$package"; then
            log_debug "Package already installed: $package"
            continue
        fi
        
        log_info "Installing monitoring package: $package"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" > /dev/null 2>&1; then
            log_success "Installed: $package"
        else
            log_warn "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        log_success "All monitoring packages installed successfully"
    else
        log_warn "Some monitoring packages failed to install: [${failed_packages[*]}]"
    fi
}

# Configure system monitoring
configure_system_monitoring() {
    log_subsection "Configuring System Monitoring"
    
    # Configure htop
    configure_htop
    
    # Configure netdata if installed
    if package_installed "netdata"; then
        configure_netdata
    fi
    
    # Configure vnstat
    if package_installed "vnstat"; then
        configure_vnstat
    fi
    
    # Configure sysstat
    if package_installed "sysstat"; then
        configure_sysstat
    fi
}

# Configure htop
configure_htop() {
    log_info "Configuring htop"
    
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    
    for username in "${users[@]}"; do
        local home_dir
        home_dir=$(getent passwd "$username" | cut -d: -f6)
        local htop_config_dir="${home_dir}/.config/htop"
        local htop_config="${htop_config_dir}/htoprc"
        
        # Create htop config directory
        create_directory "$htop_config_dir" "755" "$username" "$username"
        
        # Create htop configuration
        cat > "$htop_config" << 'EOF'
# htop configuration
fields=0 48 17 18 38 39 40 2 46 47 49 1
sort_key=46
sort_direction=1
hide_threads=0
hide_kernel_threads=1
hide_userland_threads=0
shadow_other_users=0
show_thread_names=0
show_program_path=1
highlight_base_name=0
highlight_megabytes=1
highlight_threads=1
tree_view=0
header_margin=1
detailed_cpu_time=0
cpu_count_from_zero=0
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
delay=15
left_meters=LeftCPUs Memory Swap
left_meter_modes=1 1 1
right_meters=RightCPUs Tasks LoadAverage Uptime
right_meter_modes=1 2 2 2
EOF
        
        chown "$username:$username" "$htop_config"
        chmod 644 "$htop_config"
        
        log_debug "htop configured for user: $username"
    done
    
    log_success "htop configuration completed"
}

# Configure netdata
configure_netdata() {
    log_info "Configuring netdata"
    
    local netdata_config="/etc/netdata/netdata.conf"
    
    if [[ -f "$netdata_config" ]]; then
        backup_file "$netdata_config"
        
        # Configure netdata settings
        cat > "$netdata_config" << 'EOF'
[global]
    hostname = localhost
    history = 3600
    update every = 1
    memory mode = save
    
[web]
    web files owner = root
    web files group = netdata
    bind to = 127.0.0.1
    default port = 19999
    
[plugins]
    python.d = yes
    node.d = yes
    apps = yes
    proc = yes
    diskspace = yes
    cgroups = yes
    tc = no
    
[health]
    enabled = yes
    health log size = 432000
    in memory max health log entries = 1000
EOF
        
        # Restart netdata
        systemctl restart netdata > /dev/null 2>&1 || true
        systemctl enable netdata > /dev/null 2>&1 || true
        
        log_success "netdata configured"
    else
        log_debug "netdata configuration file not found"
    fi
}

# Configure vnstat
configure_vnstat() {
    log_info "Configuring vnstat"
    
    # Initialize vnstat database for network interfaces
    local interfaces
    interfaces=$(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo)
    
    for interface in $interfaces; do
        vnstat -u -i "$interface" > /dev/null 2>&1 || true
        log_debug "vnstat initialized for interface: $interface"
    done
    
    # Enable and start vnstat service
    systemctl enable vnstat > /dev/null 2>&1 || true
    systemctl start vnstat > /dev/null 2>&1 || true
    
    log_success "vnstat configured"
}

# Configure sysstat
configure_sysstat() {
    log_info "Configuring sysstat"
    
    local sysstat_config="/etc/default/sysstat"
    
    if [[ -f "$sysstat_config" ]]; then
        backup_file "$sysstat_config"
        
        # Enable sysstat
        sed -i 's/ENABLED="false"/ENABLED="true"/' "$sysstat_config"
        
        # Configure data collection interval
        local cron_config="/etc/cron.d/sysstat"
        if [[ -f "$cron_config" ]]; then
            backup_file "$cron_config"
            
            # Update to collect data every 5 minutes
            sed -i 's/5-55\/10/\*\/5/' "$cron_config"
        fi
        
        # Start sysstat service
        systemctl enable sysstat > /dev/null 2>&1 || true
        systemctl start sysstat > /dev/null 2>&1 || true
        
        log_success "sysstat configured"
    fi
}

# Setup log monitoring
setup_log_monitoring() {
    log_subsection "Setting up Log Monitoring"
    
    # Configure rsyslog
    configure_rsyslog
    
    # Setup log analysis tools
    setup_log_analysis
    
    # Configure log rotation
    configure_monitoring_log_rotation
}

# Configure rsyslog
configure_rsyslog() {
    log_info "Configuring rsyslog"
    
    local rsyslog_config="/etc/rsyslog.d/50-monitoring.conf"
    
    cat > "$rsyslog_config" << 'EOF'
# Monitoring log configuration

# Separate authentication logs
auth,authpriv.*                  /var/log/auth.log

# Separate mail logs
mail.*                          /var/log/mail.log

# Separate cron logs
cron.*                          /var/log/cron.log

# Kernel messages
kern.*                          /var/log/kern.log

# High priority messages to console
*.emerg                         :omusrmsg:*

# Log all messages to a central log file
*.*                             /var/log/messages

# Security and authorization messages
*.info;mail.none;authpriv.none;cron.none    /var/log/messages
authpriv.*                      /var/log/secure

# Stop processing after these rules
& stop
EOF
    
    chmod 644 "$rsyslog_config"
    
    # Restart rsyslog
    systemctl restart rsyslog > /dev/null 2>&1 || true
    
    log_success "rsyslog configured"
}

# Setup log analysis tools
setup_log_analysis() {
    log_info "Setting up log analysis tools"
    
    # Create log analysis script
    local log_analyzer="/usr/local/bin/analyze-logs.sh"
    
    cat > "$log_analyzer" << 'EOF'
#!/bin/bash
# Log analysis script

REPORT_FILE="/var/log/log-analysis-$(date +%Y%m%d).log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting log analysis" > "$REPORT_FILE"

# Analyze authentication logs
echo "=== Authentication Analysis ===" >> "$REPORT_FILE"
if [[ -f /var/log/auth.log ]]; then
    echo "Failed SSH logins today:" >> "$REPORT_FILE"
    grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l >> "$REPORT_FILE"
    
    echo "Successful SSH logins today:" >> "$REPORT_FILE"
    grep "Accepted password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l >> "$REPORT_FILE"
    
    echo "Top failed login attempts:" >> "$REPORT_FILE"
    grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | \
    awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -10 >> "$REPORT_FILE"
fi

# Analyze system logs
echo "=== System Analysis ===" >> "$REPORT_FILE"
if [[ -f /var/log/syslog ]]; then
    echo "Error messages today:" >> "$REPORT_FILE"
    grep -i error /var/log/syslog | grep "$(date '+%b %d')" | wc -l >> "$REPORT_FILE"
    
    echo "Warning messages today:" >> "$REPORT_FILE"
    grep -i warning /var/log/syslog | grep "$(date '+%b %d')" | wc -l >> "$REPORT_FILE"
fi

# Analyze web server logs if nginx is running
if systemctl is-active --quiet nginx && [[ -f /var/log/nginx/access.log ]]; then
    echo "=== Web Server Analysis ===" >> "$REPORT_FILE"
    echo "HTTP requests today:" >> "$REPORT_FILE"
    grep "$(date '+%d/%b/%Y')" /var/log/nginx/access.log | wc -l >> "$REPORT_FILE"
    
    echo "Top IP addresses:" >> "$REPORT_FILE"
    grep "$(date '+%d/%b/%Y')" /var/log/nginx/access.log | \
    awk '{print $1}' | sort | uniq -c | sort -rn | head -10 >> "$REPORT_FILE"
    
    echo "HTTP status codes:" >> "$REPORT_FILE"
    grep "$(date '+%d/%b/%Y')" /var/log/nginx/access.log | \
    awk '{print $9}' | sort | uniq -c | sort -rn >> "$REPORT_FILE"
fi

echo "[$DATE] Log analysis completed" >> "$REPORT_FILE"
EOF
    
    chmod +x "$log_analyzer"
    
    # Schedule log analysis to run daily
    (crontab -l 2>/dev/null; echo "0 6 * * * $log_analyzer") | crontab -
    
    log_success "Log analysis tools configured"
}

# Configure monitoring log rotation
configure_monitoring_log_rotation() {
    log_info "Configuring monitoring log rotation"
    
    local logrotate_config="/etc/logrotate.d/monitoring"
    
    cat > "$logrotate_config" << 'EOF'
/var/log/monitoring/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        /bin/kill -HUP `cat /var/run/rsyslogd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}

/var/log/log-analysis-*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}

/var/log/system-health-*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
    
    chmod 644 "$logrotate_config"
    log_success "Monitoring log rotation configured"
}

# Create monitoring scripts
create_monitoring_scripts() {
    log_subsection "Creating Monitoring Scripts"
    
    # Create system health check script
    create_health_check_script
    
    # Create resource monitoring script
    create_resource_monitor_script
    
    # Create service monitoring script
    create_service_monitor_script
    
    # Create disk space monitoring script
    create_disk_monitor_script
}

# Create health check script
create_health_check_script() {
    log_info "Creating system health check script"
    
    local health_script="/usr/local/bin/system-health.sh"
    
    cat > "$health_script" << 'EOF'
#!/bin/bash
# System health check script

HEALTH_LOG="/var/log/system-health-$(date +%Y%m%d).log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=80
ALERT_THRESHOLD_DISK=90

echo "[$DATE] System health check started" >> "$HEALTH_LOG"

# Check CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
CPU_USAGE_INT=${CPU_USAGE%.*}
echo "[$DATE] CPU Usage: ${CPU_USAGE}%" >> "$HEALTH_LOG"

if [[ $CPU_USAGE_INT -gt $ALERT_THRESHOLD_CPU ]]; then
    echo "[$DATE] ALERT: High CPU usage: ${CPU_USAGE}%" >> "$HEALTH_LOG"
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
MEMORY_USAGE_INT=${MEMORY_USAGE%.*}
echo "[$DATE] Memory Usage: ${MEMORY_USAGE}%" >> "$HEALTH_LOG"

if [[ $MEMORY_USAGE_INT -gt $ALERT_THRESHOLD_MEMORY ]]; then
    echo "[$DATE] ALERT: High memory usage: ${MEMORY_USAGE}%" >> "$HEALTH_LOG"
fi

# Check disk usage
while IFS= read -r line; do
    FILESYSTEM=$(echo "$line" | awk '{print $1}')
    USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    MOUNT=$(echo "$line" | awk '{print $6}')
    
    echo "[$DATE] Disk Usage $MOUNT: ${USAGE}%" >> "$HEALTH_LOG"
    
    if [[ $USAGE -gt $ALERT_THRESHOLD_DISK ]]; then
        echo "[$DATE] ALERT: High disk usage on $MOUNT: ${USAGE}%" >> "$HEALTH_LOG"
    fi
done < <(df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev')

# Check load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
echo "[$DATE] Load Average:$LOAD_AVG" >> "$HEALTH_LOG"

# Check running processes
PROCESS_COUNT=$(ps aux | wc -l)
echo "[$DATE] Running Processes: $PROCESS_COUNT" >> "$HEALTH_LOG"

# Check network connections
NETWORK_CONNECTIONS=$(ss -tuln | wc -l)
echo "[$DATE] Network Connections: $NETWORK_CONNECTIONS" >> "$HEALTH_LOG"

echo "[$DATE] System health check completed" >> "$HEALTH_LOG"
EOF
    
    chmod +x "$health_script"
    
    # Schedule to run every 15 minutes
    (crontab -l 2>/dev/null; echo "*/15 * * * * $health_script") | crontab -
    
    log_success "System health check script created"
}

# Create resource monitoring script
create_resource_monitor_script() {
    log_info "Creating resource monitoring script"
    
    local resource_script="/usr/local/bin/resource-monitor.sh"
    
    cat > "$resource_script" << 'EOF'
#!/bin/bash
# Resource monitoring script

MONITOR_LOG="/var/log/resource-monitor-$(date +%Y%m%d).log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Resource monitoring check" >> "$MONITOR_LOG"

# Monitor top CPU consuming processes
echo "Top CPU processes:" >> "$MONITOR_LOG"
ps aux --sort=-%cpu | head -6 | tail -5 >> "$MONITOR_LOG"

# Monitor top memory consuming processes
echo "Top Memory processes:" >> "$MONITOR_LOG"
ps aux --sort=-%mem | head -6 | tail -5 >> "$MONITOR_LOG"

# Monitor disk I/O
if command -v iotop >/dev/null 2>&1; then
    echo "Disk I/O activity:" >> "$MONITOR_LOG"
    iotop -a -o -d 1 -n 3 2>/dev/null | tail -10 >> "$MONITOR_LOG" || true
fi

# Monitor network activity
if command -v iftop >/dev/null 2>&1; then
    echo "Network activity:" >> "$MONITOR_LOG"
    timeout 5 iftop -t -s 5 2>/dev/null | tail -20 >> "$MONITOR_LOG" || true
fi

# Monitor open files
OPEN_FILES=$(lsof | wc -l)
echo "Open files: $OPEN_FILES" >> "$MONITOR_LOG"

echo "[$DATE] Resource monitoring completed" >> "$MONITOR_LOG"
EOF
    
    chmod +x "$resource_script"
    
    # Schedule to run every 30 minutes
    (crontab -l 2>/dev/null; echo "*/30 * * * * $resource_script") | crontab -
    
    log_success "Resource monitoring script created"
}

# Create service monitoring script
create_service_monitor_script() {
    log_info "Creating service monitoring script"
    
    local service_script="/usr/local/bin/service-monitor.sh"
    
    cat > "$service_script" << 'EOF'
#!/bin/bash
# Service monitoring script

SERVICE_LOG="/var/log/service-monitor-$(date +%Y%m%d).log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Services to monitor
SERVICES=("nginx" "ssh" "fail2ban" "ufw")

echo "[$DATE] Service monitoring check" >> "$SERVICE_LOG"

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "[$DATE] $service: RUNNING" >> "$SERVICE_LOG"
    else
        echo "[$DATE] $service: STOPPED" >> "$SERVICE_LOG"
        # Try to restart the service
        if systemctl restart "$service" 2>/dev/null; then
            echo "[$DATE] $service: RESTARTED" >> "$SERVICE_LOG"
        else
            echo "[$DATE] $service: RESTART FAILED" >> "$SERVICE_LOG"
        fi
    fi
done

# Check if any services have failed
FAILED_SERVICES=$(systemctl --failed --no-legend | wc -l)
if [[ $FAILED_SERVICES -gt 0 ]]; then
    echo "[$DATE] ALERT: $FAILED_SERVICES failed services detected" >> "$SERVICE_LOG"
    systemctl --failed --no-legend >> "$SERVICE_LOG"
fi

echo "[$DATE] Service monitoring completed" >> "$SERVICE_LOG"
EOF
    
    chmod +x "$service_script"
    
    # Schedule to run every 10 minutes
    (crontab -l 2>/dev/null; echo "*/10 * * * * $service_script") | crontab -
    
    log_success "Service monitoring script created"
}

# Create disk space monitoring script
create_disk_monitor_script() {
    log_info "Creating disk space monitoring script"
    
    local disk_script="/usr/local/bin/disk-monitor.sh"
    
    cat > "$disk_script" << 'EOF'
#!/bin/bash
# Disk space monitoring script

DISK_LOG="/var/log/disk-monitor-$(date +%Y%m%d).log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
ALERT_THRESHOLD=85

echo "[$DATE] Disk space monitoring check" >> "$DISK_LOG"

# Check disk usage for all mounted filesystems
df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev' | while read output; do
    USAGE=$(echo "$output" | awk '{print $5}' | sed 's/%//g')
    PARTITION=$(echo "$output" | awk '{print $1}')
    
    echo "[$DATE] $PARTITION: ${USAGE}%" >> "$DISK_LOG"
    
    if [[ $USAGE -ge $ALERT_THRESHOLD ]]; then
        echo "[$DATE] ALERT: $PARTITION usage is ${USAGE}%" >> "$DISK_LOG"
        
        # Show largest directories
        du -h "$(echo "$output" | awk '{print $6}')" --max-depth=1 2>/dev/null | \
        sort -hr | head -5 >> "$DISK_LOG"
    fi
done

# Check inode usage
df -i | grep -vE '^Filesystem|tmpfs|cdrom|udev' | while read output; do
    USAGE=$(echo "$output" | awk '{print $5}' | sed 's/%//g')
    PARTITION=$(echo "$output" | awk '{print $1}')
    
    if [[ $USAGE -ge $ALERT_THRESHOLD ]]; then
        echo "[$DATE] ALERT: $PARTITION inode usage is ${USAGE}%" >> "$DISK_LOG"
    fi
done

echo "[$DATE] Disk space monitoring completed" >> "$DISK_LOG"
EOF
    
    chmod +x "$disk_script"
    
    # Schedule to run every hour
    (crontab -l 2>/dev/null; echo "0 * * * * $disk_script") | crontab -
    
    log_success "Disk space monitoring script created"
}

# Configure alerts
configure_alerts() {
    log_subsection "Configuring Monitoring Alerts"
    
    # Create alert configuration
    create_alert_config
    
    # Create alert notification script
    create_alert_script
}

# Create alert configuration
create_alert_config() {
    log_info "Creating alert configuration"
    
    local alert_config="/etc/monitoring/alerts.conf"
    create_directory "/etc/monitoring" "755"
    
    cat > "$alert_config" << 'EOF'
# Monitoring alerts configuration

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=90
LOAD_THRESHOLD=5.0

# Alert methods
ALERT_EMAIL=""
ALERT_LOG="/var/log/monitoring-alerts.log"

# Services to monitor
CRITICAL_SERVICES="nginx ssh fail2ban"

# Alert intervals (minutes)
ALERT_INTERVAL=30
EOF
    
    chmod 644 "$alert_config"
    log_success "Alert configuration created"
}

# Create alert notification script
create_alert_script() {
    log_info "Creating alert notification script"
    
    local alert_script="/usr/local/bin/send-alert.sh"
    
    cat > "$alert_script" << 'EOF'
#!/bin/bash
# Alert notification script

ALERT_TYPE="$1"
ALERT_MESSAGE="$2"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Load configuration
source /etc/monitoring/alerts.conf 2>/dev/null || true

# Log alert
echo "[$DATE] $ALERT_TYPE: $ALERT_MESSAGE" >> "${ALERT_LOG:-/var/log/monitoring-alerts.log}"

# Send email if configured
if [[ -n "$ALERT_EMAIL" ]] && command -v mail >/dev/null 2>&1; then
    echo "$ALERT_MESSAGE" | mail -s "[$ALERT_TYPE] $(hostname)" "$ALERT_EMAIL"
fi

# Log to syslog
logger -t "monitoring-alert" "$ALERT_TYPE: $ALERT_MESSAGE"
EOF
    
    chmod +x "$alert_script"
    log_success "Alert notification script created"
}

# Setup health checks
setup_health_checks() {
    log_subsection "Setting up Health Checks"
    
    # Create web-based health check
    create_web_health_check
    
    # Create API health check
    create_api_health_check
}

# Create web-based health check
create_web_health_check() {
    log_info "Creating web-based health check"
    
    local health_check_dir="/var/www/health"
    create_directory "$health_check_dir" "755" "$NGINX_USER" "$WEBAPP_GROUP"
    
    # Create health check endpoint
    cat > "$health_check_dir/index.php" << 'EOF'
<?php
header('Content-Type: application/json');

$health = [
    'status' => 'healthy',
    'timestamp' => date('c'),
    'hostname' => gethostname(),
    'uptime' => shell_exec('uptime -s'),
    'load' => sys_getloadavg(),
    'memory' => [
        'total' => (int) shell_exec("free -b | grep '^Mem:' | awk '{print $2}'"),
        'used' => (int) shell_exec("free -b | grep '^Mem:' | awk '{print $3}'"),
        'free' => (int) shell_exec("free -b | grep '^Mem:' | awk '{print $4}'")
    ],
    'disk' => [
        'total' => disk_total_space('/'),
        'free' => disk_free_space('/')
    ]
];

// Check critical services
$services = ['nginx', 'ssh', 'fail2ban'];
$health['services'] = [];

foreach ($services as $service) {
    $output = shell_exec("systemctl is-active $service 2>/dev/null");
    $health['services'][$service] = trim($output) === 'active';
}

// Overall health status
$healthy = true;
foreach ($health['services'] as $status) {
    if (!$status) {
        $healthy = false;
        break;
    }
}

if (!$healthy) {
    $health['status'] = 'unhealthy';
    http_response_code(503);
}

echo json_encode($health, JSON_PRETTY_PRINT);
?>
EOF
    
    # Create simple HTML health check
    cat > "$health_check_dir/status.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>System Health Status</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .healthy { color: green; }
        .unhealthy { color: red; }
        .status-box { border: 1px solid #ccc; padding: 15px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>System Health Status</h1>
    <div class="status-box">
        <h2>Server Information</h2>
        <p><strong>Hostname:</strong> <?php echo gethostname(); ?></p>
        <p><strong>Current Time:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
        <p><strong>Uptime:</strong> <?php echo shell_exec('uptime -p'); ?></p>
    </div>
    
    <div class="status-box">
        <h2>System Resources</h2>
        <p><strong>Load Average:</strong> <?php echo implode(', ', sys_getloadavg()); ?></p>
        <p><strong>Memory Usage:</strong> <?php 
            $mem_total = shell_exec("free -m | grep '^Mem:' | awk '{print $2}'");
            $mem_used = shell_exec("free -m | grep '^Mem:' | awk '{print $3}'");
            echo $mem_used . 'MB / ' . $mem_total . 'MB';
        ?></p>
        <p><strong>Disk Space:</strong> <?php 
            echo round((disk_total_space('/') - disk_free_space('/')) / 1024 / 1024 / 1024, 2) . 'GB / ';
            echo round(disk_total_space('/') / 1024 / 1024 / 1024, 2) . 'GB';
        ?></p>
    </div>
</body>
</html>
EOF
    
    chown -R "$NGINX_USER:$WEBAPP_GROUP" "$health_check_dir"
    log_success "Web-based health check created"
}

# Create API health check
create_api_health_check() {
    log_info "Creating API health check"
    
    local api_script="/usr/local/bin/health-check-api.sh"
    
    cat > "$api_script" << 'EOF'
#!/bin/bash
# API health check script

# Check HTTP endpoint
check_http() {
    local url="$1"
    local expected_code="${2:-200}"
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [[ "$response_code" == "$expected_code" ]]; then
        echo "OK: $url ($response_code)"
        return 0
    else
        echo "FAIL: $url ($response_code)"
        return 1
    fi
}

# Check service
check_service() {
    local service="$1"
    
    if systemctl is-active --quiet "$service"; then
        echo "OK: $service (active)"
        return 0
    else
        echo "FAIL: $service (inactive)"
        return 1
    fi
}

echo "=== Health Check Report ==="
echo "Timestamp: $(date)"
echo

echo "=== HTTP Endpoints ==="
check_http "http://localhost/"
check_http "http://localhost/health"

echo
echo "=== Services ==="
check_service "nginx"
check_service "ssh"
check_service "fail2ban"

echo
echo "=== System Resources ==="
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"

echo
echo "=== Health Check Completed ==="
EOF
    
    chmod +x "$api_script"
    log_success "API health check script created"
}

# Verify monitoring setup
verify_monitoring_setup() {
    log_subsection "Verifying Monitoring Setup"
    
    local issues=()
    
    # Check if monitoring scripts exist and are executable
    local scripts=(
        "/usr/local/bin/system-health.sh"
        "/usr/local/bin/resource-monitor.sh"
        "/usr/local/bin/service-monitor.sh"
        "/usr/local/bin/disk-monitor.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            issues+=("Monitoring script not executable: $script")
        fi
    done
    
    # Check if cron jobs are set up
    if ! crontab -l 2>/dev/null | grep -q "system-health.sh"; then
        issues+=("System health cron job not configured")
    fi
    
    # Check log directories
    if [[ ! -d "/var/log" ]] || [[ ! -w "/var/log" ]]; then
        issues+=("Log directory not writable")
    fi
    
    # Report results
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "Monitoring setup verification passed"
        return 0
    else
        log_warn "Monitoring setup issues found:"
        for issue in "${issues[@]}"; do
            log_warn "  - $issue"
        done
        return 1
    fi
}

# Module cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Monitoring module failed with exit code: $exit_code"
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"