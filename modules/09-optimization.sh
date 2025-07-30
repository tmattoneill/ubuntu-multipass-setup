#!/usr/bin/env bash

# Module: System Optimization
# Apply performance optimizations and system tuning

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="optimization"
readonly MODULE_DESCRIPTION="System Optimization and Performance Tuning"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    optimize_kernel_parameters
    configure_systemd_limits
    optimize_filesystem
    configure_swap_settings
    optimize_network_settings
    configure_cpu_governor
    setup_tmpfs_optimization
    optimize_services
    create_performance_profiles
    
    log_success "System optimization module completed successfully"
}

# Optimize kernel parameters
optimize_kernel_parameters() {
    log_subsection "Optimizing Kernel Parameters"
    
    local sysctl_config="/etc/sysctl.d/99-performance.conf"
    
    # Backup existing config if it exists
    [[ -f "$sysctl_config" ]] && backup_file "$sysctl_config"
    
    log_info "Creating performance kernel parameters"
    
    cat > "$sysctl_config" << EOF
# Performance optimization kernel parameters

# VM settings
vm.swappiness = $SWAPPINESS
vm.dirty_ratio = $VM_DIRTY_RATIO
vm.dirty_background_ratio = $VM_DIRTY_BACKGROUND_RATIO
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.vfs_cache_pressure = 50

# Network performance
net.core.rmem_default = 262144
net.core.rmem_max = $NET_CORE_RMEM_MAX
net.core.wmem_default = 262144
net.core.wmem_max = $NET_CORE_WMEM_MAX
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600
net.ipv4.tcp_rmem = 4096 65536 $NET_CORE_RMEM_MAX
net.ipv4.tcp_wmem = 4096 65536 $NET_CORE_WMEM_MAX
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1

# File system performance
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 256

# Kernel performance
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 0
kernel.pid_max = 4194304

# Memory management
vm.min_free_kbytes = 65536
vm.zone_reclaim_mode = 0
vm.page-cluster = 3

# I/O scheduler optimization
# Set to 'mq-deadline' for SSDs, 'bfq' for HDDs
# This will be set per-device in optimize_filesystem
EOF
    
    chmod 644 "$sysctl_config"
    
    # Apply the settings
    if sysctl --system > /dev/null 2>&1; then
        log_success "Kernel parameters optimized and applied"
    else
        log_error "Failed to apply kernel parameters"
        return 1
    fi
}

# Configure systemd limits
configure_systemd_limits() {
    log_subsection "Configuring Systemd Limits"
    
    # Configure default limits
    local system_conf="/etc/systemd/system.conf"
    local user_conf="/etc/systemd/user.conf"
    
    # Backup existing configs
    [[ -f "$system_conf" ]] && backup_file "$system_conf"
    [[ -f "$user_conf" ]] && backup_file "$user_conf"
    
    log_info "Configuring systemd system limits"
    
    # Configure system limits
    cat >> "$system_conf" << EOF

# Performance optimizations
DefaultLimitNOFILE=$SYSTEMD_DEFAULT_LIMIT_NOFILE
DefaultLimitNPROC=$SYSTEMD_DEFAULT_LIMIT_NPROC
DefaultLimitCORE=0
DefaultLimitMEMLOCK=infinity
EOF
    
    # Configure user limits
    cat >> "$user_conf" << EOF

# User performance optimizations
DefaultLimitNOFILE=$SYSTEMD_DEFAULT_LIMIT_NOFILE
DefaultLimitNPROC=$SYSTEMD_DEFAULT_LIMIT_NPROC
DefaultLimitCORE=0
EOF
    
    # Create override directory for services
    local override_dir="/etc/systemd/system/nginx.service.d"
    create_directory "$override_dir" "755"
    
    # Optimize Nginx service limits
    cat > "$override_dir/limits.conf" << EOF
[Service]
LimitNOFILE=$SYSTEMD_DEFAULT_LIMIT_NOFILE
LimitNPROC=$SYSTEMD_DEFAULT_LIMIT_NPROC
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Systemd limits configured"
}

# Optimize filesystem
optimize_filesystem() {
    log_subsection "Optimizing Filesystem"
    
    # Detect storage devices and optimize I/O schedulers
    optimize_io_schedulers
    
    # Configure filesystem mount options
    optimize_mount_options
    
    # Configure filesystem cache settings
    configure_filesystem_cache
}

# Optimize I/O schedulers
optimize_io_schedulers() {
    log_info "Optimizing I/O schedulers"
    
    # Create udev rules for I/O scheduler optimization
    local udev_rules="/etc/udev/rules.d/60-ioschedulers.rules"
    
    cat > "$udev_rules" << 'EOF'
# I/O Scheduler optimization rules

# Set mq-deadline for SSDs
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

# Set bfq for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

# Optimize queue depth for SSDs
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/nr_requests}="256"

# Optimize read-ahead for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{bdi/read_ahead_kb}="128"

# Optimize read-ahead for SSDs
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{bdi/read_ahead_kb}="512"
EOF
    
    chmod 644 "$udev_rules"
    
    # Apply the rules
    udevadm control --reload-rules
    udevadm trigger
    
    log_success "I/O schedulers optimized"
}

# Optimize mount options
optimize_mount_options() {
    log_info "Configuring optimized mount options"
    
    # Create a script to check and suggest mount optimizations
    local mount_optimizer="/usr/local/bin/optimize-mounts.sh"
    
    cat > "$mount_optimizer" << 'EOF'
#!/bin/bash
# Mount optimization checker

echo "Current mount options analysis:"
echo "==============================="

while IFS= read -r line; do
    if [[ "$line" =~ ^/dev ]]; then
        device=$(echo "$line" | awk '{print $1}')
        mount_point=$(echo "$line" | awk '{print $2}')
        fs_type=$(echo "$line" | awk '{print $3}')
        options=$(echo "$line" | awk '{print $4}')
        
        echo "Device: $device"
        echo "Mount: $mount_point"
        echo "Type: $fs_type"
        echo "Options: $options"
        
        # Check if it's an SSD
        device_name=$(basename "$device" | sed 's/[0-9]*$//')
        if [[ -f "/sys/block/$device_name/queue/rotational" ]]; then
            rotational=$(cat "/sys/block/$device_name/queue/rotational")
            if [[ "$rotational" == "0" ]]; then
                echo "Type: SSD"
                echo "Recommended additional options: noatime,discard"
            else
                echo "Type: HDD"
                echo "Recommended additional options: noatime,relatime"
            fi
        fi
        echo "---"
    fi
done < /proc/mounts
EOF
    
    chmod +x "$mount_optimizer"
    
    # Run the optimizer to show current status
    log_info "Mount optimization analysis:"
    "$mount_optimizer" | while read -r line; do
        log_info "  $line"
    done
    
    log_success "Mount options analysis completed"
}

# Configure filesystem cache
configure_filesystem_cache() {
    log_info "Configuring filesystem cache settings"
    
    # Optimize directory cache
    echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null || true
    
    # Optimize inode/dentry cache
    echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    log_success "Filesystem cache configured"
}

# Configure swap settings
configure_swap_settings() {
    log_subsection "Configuring Swap Settings"
    
    # Check current swap configuration
    local swap_info
    swap_info=$(swapon --show=NAME,SIZE,USED,PRIO --noheadings 2>/dev/null || echo "No swap")
    
    log_info "Current swap configuration:"
    if [[ "$swap_info" == "No swap" ]]; then
        log_info "  No swap currently configured"
        
        # Create swap file if none exists and system has limited RAM
        local total_ram
        total_ram=$(free -m | awk 'NR==2{print $2}')
        
        if [[ $total_ram -lt 2048 ]]; then
            create_swap_file
        else
            log_info "  System has sufficient RAM, swap file not needed"
        fi
    else
        log_info "  $swap_info"
    fi
    
    # Optimize swap settings
    optimize_swap_parameters
}

# Create swap file
create_swap_file() {
    log_info "Creating swap file"
    
    local swap_file="/swapfile"
    local swap_size="1G"
    
    # Check if swap file already exists
    if [[ -f "$swap_file" ]]; then
        log_debug "Swap file already exists"
        return 0
    fi
    
    # Create swap file
    if fallocate -l "$swap_size" "$swap_file" 2>/dev/null || dd if=/dev/zero of="$swap_file" bs=1M count=1024 > /dev/null 2>&1; then
        chmod 600 "$swap_file"
        mkswap "$swap_file" > /dev/null 2>&1
        swapon "$swap_file"
        
        # Add to fstab
        if ! grep -q "$swap_file" /etc/fstab; then
            echo "$swap_file none swap sw 0 0" >> /etc/fstab
        fi
        
        log_success "Swap file created: $swap_file ($swap_size)"
    else
        log_error "Failed to create swap file"
        return 1
    fi
}

# Optimize swap parameters
optimize_swap_parameters() {
    log_info "Optimizing swap parameters"
    
    # Set swappiness (already set in kernel parameters)
    echo "$SWAPPINESS" > /proc/sys/vm/swappiness 2>/dev/null || true
    
    # Configure swap cache pressure
    echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null || true
    
    log_success "Swap parameters optimized"
}

# Optimize network settings
optimize_network_settings() {
    log_subsection "Optimizing Network Settings"
    
    # Network interface optimizations
    optimize_network_interfaces
    
    # Configure TCP congestion control
    configure_tcp_optimization
    
    # Optimize network buffer sizes
    optimize_network_buffers
}

# Optimize network interfaces
optimize_network_interfaces() {
    log_info "Optimizing network interfaces"
    
    # Get active network interfaces
    local interfaces
    interfaces=$(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo)
    
    for interface in $interfaces; do
        if [[ -d "/sys/class/net/$interface" ]]; then
            # Enable Generic Receive Offload
            ethtool -K "$interface" gro on 2>/dev/null || true
            
            # Enable TCP Segmentation Offload
            ethtool -K "$interface" tso on 2>/dev/null || true
            
            # Optimize ring buffer sizes
            ethtool -G "$interface" rx 4096 tx 4096 2>/dev/null || true
            
            log_debug "Optimized network interface: $interface"
        fi
    done
    
    log_success "Network interfaces optimized"
}

# Configure TCP optimization
configure_tcp_optimization() {
    log_info "Configuring TCP optimization"
    
    # Enable BBR congestion control if available
    if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true
        log_success "BBR congestion control enabled"
    else
        log_debug "BBR not available, using default congestion control"
    fi
    
    # Optimize TCP window scaling
    echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null || true
    
    # Enable TCP timestamps
    echo 1 > /proc/sys/net/ipv4/tcp_timestamps 2>/dev/null || true
    
    log_success "TCP optimization configured"
}

# Optimize network buffers
optimize_network_buffers() {
    log_info "Optimizing network buffers"
    
    # These settings are already in the sysctl configuration
    # Just verify they're applied
    local current_rmem_max
    current_rmem_max=$(cat /proc/sys/net/core/rmem_max 2>/dev/null || echo "0")
    
    if [[ $current_rmem_max -ge $NET_CORE_RMEM_MAX ]]; then
        log_success "Network buffer optimization verified"
    else
        log_warn "Network buffer optimization may not be fully applied"
    fi
}

# Configure CPU governor
configure_cpu_governor() {
    log_subsection "Configuring CPU Governor"
    
    # Check if cpufrequtils is available
    if ! package_installed "cpufrequtils"; then
        log_info "Installing cpufrequtils"
        DEBIAN_FRONTEND=noninteractive apt-get install -y cpufrequtils > /dev/null 2>&1 || true
    fi
    
    # Configure CPU governor
    configure_cpu_performance
}

# Configure CPU performance
configure_cpu_performance() {
    log_info "Configuring CPU performance settings"
    
    # Check available governors
    local available_governors
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then
        available_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
        log_info "Available CPU governors: $available_governors"
        
        # Set performance governor if available
        if echo "$available_governors" | grep -q "performance"; then
            local cpus
            cpus=$(nproc)
            for ((i=0; i<cpus; i++)); do
                echo performance > "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" 2>/dev/null || true
            done
            log_success "CPU performance governor set"
        elif echo "$available_governors" | grep -q "ondemand"; then
            local cpus
            cpus=$(nproc)
            for ((i=0; i<cpus; i++)); do
                echo ondemand > "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" 2>/dev/null || true
            done
            log_success "CPU ondemand governor set"
        fi
        
        # Configure CPU frequency scaling
        if [[ -f /etc/default/cpufrequtils ]]; then
            backup_file "/etc/default/cpufrequtils"
            
            cat > "/etc/default/cpufrequtils" << 'EOF'
# CPU frequency scaling configuration
ENABLE="true"
GOVERNOR="performance"
MAX_SPEED="0"
MIN_SPEED="0"
EOF
            log_success "CPU frequency scaling configured"
        fi
    else
        log_debug "CPU frequency scaling not available"
    fi
}

# Setup tmpfs optimization
setup_tmpfs_optimization() {
    log_subsection "Setting up Tmpfs Optimization"
    
    # Configure tmpfs for frequently accessed directories
    configure_tmpfs_mounts
    
    # Optimize tmpfs settings
    optimize_tmpfs_settings
}

# Configure tmpfs mounts
configure_tmpfs_mounts() {
    log_info "Configuring tmpfs mounts"
    
    # Check current tmpfs usage
    local tmp_usage
    tmp_usage=$(df -h /tmp 2>/dev/null | tail -1 | awk '{print $5}' || echo "N/A")
    log_info "Current /tmp usage: $tmp_usage"
    
    # Add tmpfs optimization to fstab if not already present
    local fstab_additions=()
    
    # Optimize /tmp with tmpfs if not already mounted as tmpfs
    if ! mount | grep -q "tmpfs.*on /tmp"; then
        if ! grep -q "tmpfs.*/tmp" /etc/fstab; then
            fstab_additions+=("tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=$TMPDIR_SIZE 0 0")
        fi
    fi
    
    # Add log tmpfs for high-frequency logs
    if ! grep -q "tmpfs.*/var/log/nginx" /etc/fstab; then
        create_directory "/var/log/nginx" "755" "www-data" "adm"
        fstab_additions+=("tmpfs /var/log/nginx tmpfs defaults,noatime,mode=755,size=100M,uid=www-data,gid=adm 0 0")
    fi
    
    # Add the entries to fstab
    for addition in "${fstab_additions[@]}"; do
        echo "$addition" >> /etc/fstab
        log_info "Added to fstab: $addition"
    done
    
    if [[ ${#fstab_additions[@]} -gt 0 ]]; then
        log_success "Tmpfs optimization configured (will be active after reboot)"
    else
        log_debug "Tmpfs already optimally configured"
    fi
}

# Optimize tmpfs settings
optimize_tmpfs_settings() {
    log_info "Optimizing tmpfs settings"
    
    # Configure tmpfs-specific optimizations in sysctl
    cat >> /etc/sysctl.d/99-performance.conf << 'EOF'

# Tmpfs optimizations
vm.dirty_background_bytes = 16777216
vm.dirty_bytes = 50331648
EOF
    
    log_success "Tmpfs settings optimized"
}

# Optimize services
optimize_services() {
    log_subsection "Optimizing Services"
    
    # Optimize Nginx
    if systemctl is-active --quiet nginx; then
        optimize_nginx_performance
    fi
    
    # Optimize system services
    optimize_system_services
    
    # Disable unnecessary services
    disable_unnecessary_services
}

# Optimize Nginx performance
optimize_nginx_performance() {
    log_info "Optimizing Nginx performance"
    
    local nginx_conf="/etc/nginx/nginx.conf"
    
    if [[ -f "$nginx_conf" ]]; then
        # The performance optimizations are already included in the nginx module
        # Just ensure nginx is using optimized settings
        
        # Test configuration
        if nginx -t > /dev/null 2>&1; then
            systemctl reload nginx > /dev/null 2>&1 || true
            log_success "Nginx performance configuration reloaded"
        else
            log_warn "Nginx configuration test failed"
        fi
    fi
}

# Optimize system services
optimize_system_services() {
    log_info "Optimizing system services"
    
    # Configure systemd for better performance
    local systemd_config="/etc/systemd/system.conf"
    
    if [[ -f "$systemd_config" ]]; then
        # Add performance tuning to systemd
        cat >> "$systemd_config" << 'EOF'

# Performance tuning
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultRestartSec=100ms
DefaultLimitMEMLOCK=infinity
EOF
        
        systemctl daemon-reload
        log_success "System services optimized"
    fi
}

# Disable unnecessary services
disable_unnecessary_services() {
    log_info "Disabling unnecessary services"
    
    local services_to_disable=("${SERVICES_TO_DISABLE[@]}")
    local disabled_services=()
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            if systemctl disable "$service" > /dev/null 2>&1; then
                systemctl stop "$service" > /dev/null 2>&1 || true
                disabled_services+=("$service")
                log_success "Disabled service: $service"
            else
                log_warn "Failed to disable service: $service"
            fi
        fi
    done
    
    if [[ ${#disabled_services[@]} -gt 0 ]]; then
        log_info "Disabled unnecessary services: [${disabled_services[*]}]"
    else
        log_info "No unnecessary services found to disable"
    fi
}

# Create performance profiles
create_performance_profiles() {
    log_subsection "Creating Performance Profiles"
    
    # Create performance tuning script
    create_performance_tuning_script
    
    # Create performance monitoring script
    create_performance_monitoring_script
    
    # Create performance report script
    create_performance_report_script
}

# Create performance tuning script
create_performance_tuning_script() {
    log_info "Creating performance tuning script"
    
    local tuning_script="/usr/local/bin/performance-tune.sh"
    
    cat > "$tuning_script" << 'EOF'
#!/bin/bash
# Performance tuning script

echo "=== System Performance Tuning ==="
echo "Timestamp: $(date)"
echo

# Apply kernel parameters
echo "Applying kernel parameters..."
sysctl --system >/dev/null 2>&1
echo "✓ Kernel parameters applied"

# Optimize CPU governor
echo "Optimizing CPU governor..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [[ -w "$cpu" ]]; then
        echo performance > "$cpu" 2>/dev/null || echo ondemand > "$cpu" 2>/dev/null || true
    fi
done
echo "✓ CPU governor optimized"

# Optimize I/O scheduler
echo "Optimizing I/O schedulers..."
for device in /sys/block/*/queue/scheduler; do
    if [[ -w "$device" ]]; then
        device_name=$(basename "$(dirname "$(dirname "$device")")")
        if [[ -f "/sys/block/$device_name/queue/rotational" ]]; then
            rotational=$(cat "/sys/block/$device_name/queue/rotational")
            if [[ "$rotational" == "0" ]]; then
                echo mq-deadline > "$device" 2>/dev/null || true
            else
                echo bfq > "$device" 2>/dev/null || true
            fi
        fi
    fi
done
echo "✓ I/O schedulers optimized"

# Optimize network settings
echo "Optimizing network settings..."
for interface in $(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo); do
    ethtool -K "$interface" gro on 2>/dev/null || true
    ethtool -K "$interface" tso on 2>/dev/null || true
done
echo "✓ Network settings optimized"

echo
echo "=== Performance Tuning Completed ==="
EOF
    
    chmod +x "$tuning_script"
    
    # Schedule to run at boot
    cat > /etc/systemd/system/performance-tune.service << EOF
[Unit]
Description=System Performance Tuning
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$tuning_script
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable performance-tune.service > /dev/null 2>&1 || true
    
    log_success "Performance tuning script created"
}

# Create performance monitoring script
create_performance_monitoring_script() {
    log_info "Creating performance monitoring script"
    
    local monitor_script="/usr/local/bin/performance-monitor.sh"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# Performance monitoring script

PERF_LOG="/var/log/performance-$(date +%Y%m%d).log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Performance monitoring check" >> "$PERF_LOG"

# CPU information
echo "CPU Usage:" >> "$PERF_LOG"
top -bn1 | grep "Cpu(s)" >> "$PERF_LOG"

# Memory information
echo "Memory Usage:" >> "$PERF_LOG"
free -h >> "$PERF_LOG"

# Disk I/O
echo "Disk I/O:" >> "$PERF_LOG"
iostat -x 1 1 2>/dev/null | tail -n +4 >> "$PERF_LOG" || echo "iostat not available" >> "$PERF_LOG"

# Network statistics
echo "Network Statistics:" >> "$PERF_LOG"
cat /proc/net/dev | head -3 >> "$PERF_LOG"

# Load average
echo "Load Average:" >> "$PERF_LOG"
uptime >> "$PERF_LOG"

# Process count
echo "Process Count: $(ps aux | wc -l)" >> "$PERF_LOG"

# Open files
echo "Open Files: $(lsof 2>/dev/null | wc -l)" >> "$PERF_LOG"

echo "[$DATE] Performance monitoring completed" >> "$PERF_LOG"
EOF
    
    chmod +x "$monitor_script"
    
    # Schedule to run every hour
    (crontab -l 2>/dev/null; echo "0 * * * * $monitor_script") | crontab -
    
    log_success "Performance monitoring script created"
}

# Create performance report script
create_performance_report_script() {
    log_info "Creating performance report script"
    
    local report_script="/usr/local/bin/performance-report.sh"
    
    cat > "$report_script" << 'EOF'
#!/bin/bash
# Performance report script

echo "=== System Performance Report ==="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo

echo "=== System Information ==="
echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | awk 'NR==2{print $2}')"
echo

echo "=== Current Performance ==="
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')"
echo "Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "Disk Usage:"
df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev' | awk '{print "  " $6 ": " $5}'

echo
echo "=== Configuration Status ==="
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "TCP Congestion Control: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
echo "I/O Schedulers:"
for device in /sys/block/*/queue/scheduler; do
    device_name=$(basename "$(dirname "$(dirname "$device")")")
    scheduler=$(cat "$device" | sed 's/.*\[\(.*\)\].*/\1/')
    echo "  $device_name: $scheduler"
done

echo
echo "=== Service Status ==="
systemctl is-active nginx ssh fail2ban 2>/dev/null | while read -r status; do
    echo "Service status: $status"
done

echo
echo "=== Network Interfaces ==="
ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo | while read -r interface; do
    speed=$(ethtool "$interface" 2>/dev/null | grep Speed | awk '{print $2}' || echo "Unknown")
    echo "  $interface: $speed"
done

echo
echo "=== Performance Report Completed ==="
EOF
    
    chmod +x "$report_script"
    
    log_success "Performance report script created"
}

# Verify optimization setup
verify_optimization_setup() {
    log_subsection "Verifying Optimization Setup"
    
    local issues=()
    
    # Check if sysctl parameters are applied
    local swappiness
    swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "0")
    if [[ $swappiness -ne $SWAPPINESS ]]; then
        issues+=("Swappiness not set correctly (expected: $SWAPPINESS, actual: $swappiness)")
    fi
    
    # Check if performance tuning service is enabled
    if ! systemctl is-enabled --quiet performance-tune.service 2>/dev/null; then
        issues+=("Performance tuning service not enabled")
    fi
    
    # Check if optimization scripts exist
    local scripts=(
        "/usr/local/bin/performance-tune.sh"
        "/usr/local/bin/performance-monitor.sh"
        "/usr/local/bin/performance-report.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            issues+=("Optimization script not executable: $script")
        fi
    done
    
    # Report results
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "System optimization verification passed"
        return 0
    else
        log_warn "System optimization issues found:"
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
        log_error "System optimization module failed with exit code: $exit_code"
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"