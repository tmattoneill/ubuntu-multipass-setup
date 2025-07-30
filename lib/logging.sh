#!/usr/bin/env bash

# Logging framework for Ubuntu Server Setup Script
# Provides comprehensive logging functionality with multiple levels and output formats

# Initialize logging if not already done
if [[ -z "${LOGGING_INITIALIZED:-}" ]]; then
    LOGGING_INITIALIZED=true
    
    # Source configuration if available
    if [[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}" ]]; then
        source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../config.sh}"
    fi
    
    # Set default values if config not loaded (avoid overriding readonly vars)
    if [[ -z "${LOG_DIR:-}" ]]; then
        LOG_DIR="/var/log/setup"
    fi
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"
    fi
    DEFAULT_LOG_LEVEL="${DEFAULT_LOG_LEVEL:-INFO}"
    
    # Color codes (will be empty if SETUP_NO_COLOR is set) - avoid overriding readonly vars
    if [[ -z "${RED:-}" ]]; then RED='\033[0;31m'; fi
    if [[ -z "${GREEN:-}" ]]; then GREEN='\033[0;32m'; fi
    if [[ -z "${YELLOW:-}" ]]; then YELLOW='\033[1;33m'; fi
    if [[ -z "${BLUE:-}" ]]; then BLUE='\033[0;34m'; fi
    if [[ -z "${PURPLE:-}" ]]; then PURPLE='\033[0;35m'; fi
    if [[ -z "${CYAN:-}" ]]; then CYAN='\033[0;36m'; fi
    if [[ -z "${WHITE:-}" ]]; then WHITE='\033[1;37m'; fi
    if [[ -z "${NC:-}" ]]; then NC='\033[0m'; fi
    
    # Log levels - avoid overriding readonly vars
    if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then LOG_LEVEL_DEBUG=0; fi
    if [[ -z "${LOG_LEVEL_INFO:-}" ]]; then LOG_LEVEL_INFO=1; fi
    if [[ -z "${LOG_LEVEL_WARN:-}" ]]; then LOG_LEVEL_WARN=2; fi
    if [[ -z "${LOG_LEVEL_ERROR:-}" ]]; then LOG_LEVEL_ERROR=3; fi
fi

# Convert log level name to number
get_log_level_number() {
    local level="$1"
    case "${level^^}" in
        "DEBUG") echo $LOG_LEVEL_DEBUG ;;
        "INFO")  echo $LOG_LEVEL_INFO ;;
        "WARN")  echo $LOG_LEVEL_WARN ;;
        "ERROR") echo $LOG_LEVEL_ERROR ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

# Get current log level from environment or default
get_current_log_level() {
    get_log_level_number "${SETUP_LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
}

# Check if message should be logged based on level
should_log() {
    local message_level=$1
    local current_level
    current_level=$(get_current_log_level)
    [[ $message_level -ge $current_level ]]
}

# Initialize log file and directory
init_logging() {
    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
            echo "Warning: Cannot create log directory $LOG_DIR" >&2
            # Use temp directory for logging if we can't create the configured log dir
            # Don't override readonly variables - just use temp location
            if [[ -z "${LOG_FILE_OVERRIDE:-}" ]]; then
                export LOG_FILE_OVERRIDE="/tmp/setup-$(date +%Y%m%d-%H%M%S).log"
            fi
        fi
    fi
    
    # Set proper permissions on log directory
    if [[ -d "$LOG_DIR" ]] && [[ -w "$LOG_DIR" ]]; then
        chmod 750 "$LOG_DIR" 2>/dev/null || true
    fi
    
    # Initialize log file (use override if regular log file can't be created)
    local actual_log_file="${LOG_FILE_OVERRIDE:-$LOG_FILE}"
    if ! touch "$actual_log_file" 2>/dev/null; then
        # Final fallback to temp file
        actual_log_file="/tmp/setup-$(date +%Y%m%d-%H%M%S).log"
        export LOG_FILE_OVERRIDE="$actual_log_file"
        touch "$actual_log_file" 2>/dev/null || true
    fi
    
    # Set proper permissions on log file
    if [[ -f "$actual_log_file" ]] && [[ -w "$actual_log_file" ]]; then
        chmod 640 "$actual_log_file" 2>/dev/null || true
    fi
    
    # Log initialization
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Logging initialized: $actual_log_file" >> "$actual_log_file" 2>/dev/null || true
}

# Core logging function
log_message() {
    local level="$1"
    local message="$2"
    local color="$3"
    local level_num
    level_num=$(get_log_level_number "$level")
    
    # Check if we should log this message
    if ! should_log "$level_num"; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local formatted_message="$timestamp [$level] $message"
    
    # Write to log file (always, regardless of color settings)
    local actual_log_file="${LOG_FILE_OVERRIDE:-$LOG_FILE}"
    if [[ -n "$actual_log_file" ]] && [[ -w "$actual_log_file" ]]; then
        echo "$formatted_message" >> "$actual_log_file" 2>/dev/null || true
    fi
    
    # Write to console with color if not disabled
    if [[ -z "${SETUP_NO_COLOR:-}" ]] && [[ -n "$color" ]]; then
        echo -e "${color}[$level]${NC} $message" >&2
    else
        echo "[$level] $message" >&2
    fi
}

# Specific logging functions
log_debug() {
    log_message "DEBUG" "$1" "$CYAN"
}

log_info() {
    log_message "INFO" "$1" "$BLUE"
}

log_success() {
    log_message "INFO" "$1" "$GREEN"
}

log_warn() {
    log_message "WARN" "$1" "$YELLOW"
}

# Alias for compatibility
log_warning() {
    log_warn "$1"
}

log_error() {
    log_message "ERROR" "$1" "$RED"
}

# Log with custom color
log_custom() {
    local level="$1"
    local message="$2"
    local color="$3"
    log_message "$level" "$message" "$color"
}

# Log separator line
log_separator() {
    local char="${1:--}"
    local length="${2:-50}"
    local separator=""
    for ((i=0; i<length; i++)); do
        separator+="$char"
    done
    log_info "$separator"
}

# Log a command before execution
log_command() {
    local cmd="$1"
    log_debug "Executing: $cmd"
}

# Log command result
log_command_result() {
    local cmd="$1"
    local exit_code="$2"
    if [[ $exit_code -eq 0 ]]; then
        log_debug "Command succeeded: $cmd"
    else
        log_error "Command failed (exit $exit_code): $cmd"
    fi
}

# Log file operations
log_file_operation() {
    local operation="$1"
    local file="$2"
    log_debug "File $operation: $file"
}

# Log section headers
log_section() {
    local title="$1"
    log_separator "=" 60
    log_info "SECTION: $title"
    log_separator "=" 60
}

# Log subsection headers
log_subsection() {
    local title="$1"
    log_separator "-" 40
    log_info "$title"
    log_separator "-" 40
}

# Progress logging with percentage
log_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percentage=$((current * 100 / total))
    log_info "Progress: $percentage% ($current/$total) - $description"
}

# Log system information
log_system_info() {
    log_info "System Information:"
    log_info "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    log_info "  Kernel: $(uname -r)"
    log_info "  Architecture: $(uname -m)"
    log_info "  Hostname: $(hostname)"
    log_info "  User: $(whoami)"
    log_info "  Working Directory: $(pwd)"
    log_info "  Script: ${BASH_SOURCE[1]:-Unknown}"
}

# Log environment variables (filtered for security)
log_environment() {
    log_debug "Relevant Environment Variables:"
    local env_vars=("SETUP_LOG_LEVEL" "SETUP_NO_COLOR" "SETUP_ASSUME_YES" 
                   "PRIMARY_USER" "INSTALL_MODE" "DRY_RUN" "VERBOSE")
    
    for var in "${env_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_debug "  $var=${!var}"
        fi
    done
}

# Log disk space information
log_disk_space() {
    log_info "Disk Space Information:"
    df -h / /tmp /var 2>/dev/null | while read -r line; do
        log_info "  $line"
    done
}

# Log memory information
log_memory_info() {
    log_info "Memory Information:"
    free -h | while read -r line; do
        log_info "  $line"
    done
}

# Create a log checkpoint (useful for debugging)
log_checkpoint() {
    local checkpoint_name="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    log_separator "*" 60
    log_info "CHECKPOINT: $checkpoint_name at $timestamp"
    log_separator "*" 60
}

# Log array contents
log_array() {
    local array_name="$1"
    local -n array_ref="$1"
    log_debug "$array_name contents:"
    local i=0
    for item in "${array_ref[@]}"; do
        log_debug "  [$i] $item"
        ((i++))
    done
}

# Log file contents with line numbers (for debugging)
log_file_contents() {
    local file_path="$1"
    local max_lines="${2:-50}"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "File not found for logging: $file_path"
        return 1
    fi
    
    log_debug "Contents of $file_path (first $max_lines lines):"
    head -n "$max_lines" "$file_path" 2>/dev/null | nl -ba | while read -r line; do
        log_debug "  $line"
    done
    
    local total_lines
    total_lines=$(wc -l < "$file_path" 2>/dev/null || echo "0")
    if [[ $total_lines -gt $max_lines ]]; then
        log_debug "  ... (showing first $max_lines of $total_lines total lines)"
    fi
}

# Rotate log files if they get too large
rotate_logs() {
    local max_size="${MAX_LOG_SIZE:-100M}"
    
    if [[ -f "$LOG_FILE" ]]; then
        # Check if log file is larger than max size
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        local max_bytes
        
        # Convert max_size to bytes (simple conversion for M suffix)
        if [[ "$max_size" =~ ^([0-9]+)M$ ]]; then
            max_bytes=$((${BASH_REMATCH[1]} * 1024 * 1024))
        else
            max_bytes=104857600  # 100M default
        fi
        
        if [[ $size -gt $max_bytes ]]; then
            local rotated_log="${LOG_FILE}.$(date +%Y%m%d-%H%M%S)"
            mv "$LOG_FILE" "$rotated_log" 2>/dev/null || true
            touch "$LOG_FILE" 2>/dev/null || true
            chmod 640 "$LOG_FILE" 2>/dev/null || true
            log_info "Log rotated: $rotated_log"
        fi
    fi
}

# Clean up old log files
cleanup_old_logs() {
    local retention_days="${LOG_RETENTION_DAYS:-30}"
    
    if [[ -d "$LOG_DIR" ]]; then
        # Remove log files older than retention period
        find "$LOG_DIR" -name "setup-*.log*" -type f -mtime "+$retention_days" -delete 2>/dev/null || true
        log_info "Cleaned up log files older than $retention_days days"
    fi
}

# Get current log file path
get_log_file() {
    echo "$LOG_FILE"
}

# Get current log directory
get_log_dir() {
    echo "$LOG_DIR"
}

# Test logging functionality
test_logging() {
    log_info "Testing logging functionality..."
    log_debug "This is a debug message"
    log_info "This is an info message"
    log_success "This is a success message"
    log_warn "This is a warning message"
    log_error "This is an error message"
    log_info "Logging test completed"
}

# Initialize logging when this file is sourced
init_logging