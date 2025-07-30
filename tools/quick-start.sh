#!/usr/bin/env bash

# Quick Start Installer for Ubuntu Setup Script
# Supports both local and remote installation modes

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"
readonly GITHUB_USER="tmattoneill"
readonly GITHUB_REPO="ubuntu-multipass-setup"
readonly GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default options
LOCAL_MODE=false
INSTALL_MODE="full"
VERBOSE=false
DRY_RUN=false
TEMP_DIR=""

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Show banner
show_banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                Ubuntu Setup Quick Start Installer            ║
║                          Version 1.0.0                       ║
║                                                               ║
║  https://github.com/tmattoneill/ubuntu-multipass-setup       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Ubuntu Setup Quick Start Installer v${SCRIPT_VERSION}

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

OPTIONS:
    -l, --local             Use local files (current directory)
    -r, --remote            Download from GitHub (default)
    -m, --mode MODE         Installation mode: full, nginx-only, dev-only, minimal
    -v, --verbose           Enable verbose output
    -n, --dry-run          Show what would be done without executing
    -h, --help             Show this help message

INSTALLATION MODES:
    full                   Complete server setup (default)
    nginx-only            Web server only
    dev-only              Development tools only
    minimal               Basic setup only

EXAMPLES:
    ${SCRIPT_NAME}                          # Remote install, full mode
    ${SCRIPT_NAME} --local                  # Local install from current directory
    ${SCRIPT_NAME} --mode nginx-only        # Remote install, nginx only
    ${SCRIPT_NAME} --local --verbose        # Local install with verbose output
    ${SCRIPT_NAME} --dry-run                # Preview what would be downloaded/run

EOF
}

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}

# Set up signal handlers
trap cleanup EXIT
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--local)
                LOCAL_MODE=true
                shift
                ;;
            -r|--remote)
                LOCAL_MODE=false
                shift
                ;;
            -m|--mode)
                INSTALL_MODE="$2"
                if [[ ! "$INSTALL_MODE" =~ ^(full|nginx-only|dev-only|minimal)$ ]]; then
                    log_error "Invalid mode: $INSTALL_MODE"
                    log_error "Valid modes: full, nginx-only, dev-only, minimal"
                    exit 1
                fi
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running on Ubuntu
    if ! command -v lsb_release >/dev/null 2>&1 || ! lsb_release -d | grep -qi ubuntu; then
        log_warning "This installer is designed for Ubuntu systems"
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this installer as root"
        log_error "The setup script will use sudo when necessary"
        exit 1
    fi
    
    # Check required tools for remote mode
    if [[ "$LOCAL_MODE" == "false" ]]; then
        local required_tools=("curl" "wget")
        for tool in "${required_tools[@]}"; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                log_error "Required tool '$tool' not found"
                log_error "Please install: sudo apt update && sudo apt install $tool"
                exit 1
            fi
        done
    fi
    
    log_success "Prerequisites checked"
}

# Download files from GitHub
download_remote_files() {
    log_info "Downloading setup files from GitHub..."
    
    TEMP_DIR=$(mktemp -d)
    local download_success=true
    
    # List of files to download
    local files=(
        "setup.sh"
        "config.sh"
    )
    
    local directories=(
        "lib"
        "modules"
    )
    
    # Download main files
    for file in "${files[@]}"; do
        local url="${GITHUB_RAW_URL}/${file}"
        log_info "Downloading $file..."
        
        if ! curl -fsSL "$url" -o "${TEMP_DIR}/${file}"; then
            log_error "Failed to download $file"
            download_success=false
        fi
    done
    
    # Download directory contents
    for dir in "${directories[@]}"; do
        log_info "Creating directory $dir..."
        mkdir -p "${TEMP_DIR}/${dir}"
        
        # For simplicity, we'll download known files
        case $dir in
            "lib")
                local lib_files=("logging.sh" "utils.sh" "validation.sh" "security.sh")
                for lib_file in "${lib_files[@]}"; do
                    local url="${GITHUB_RAW_URL}/${dir}/${lib_file}"
                    if ! curl -fsSL "$url" -o "${TEMP_DIR}/${dir}/${lib_file}"; then
                        log_warning "Failed to download ${dir}/${lib_file}"
                    fi
                done
                ;;
            "modules")
                local module_files=(
                    "01-prerequisites.sh" "02-users.sh" "03-shell.sh" "04-nodejs.sh" "05-python.sh"
                    "06-nginx.sh" "07-security.sh" "08-monitoring.sh" "09-optimization.sh" "10-validation.sh"
                )
                for module_file in "${module_files[@]}"; do
                    local url="${GITHUB_RAW_URL}/${dir}/${module_file}"
                    if ! curl -fsSL "$url" -o "${TEMP_DIR}/${dir}/${module_file}"; then
                        log_warning "Failed to download ${dir}/${module_file}"
                    fi
                done
                ;;
        esac
    done
    
    if [[ "$download_success" == "true" ]]; then
        log_success "Files downloaded successfully to $TEMP_DIR"
        return 0
    else
        log_error "Some files failed to download"
        return 1
    fi
}

# Validate local files
validate_local_files() {
    log_info "Validating local files..."
    
    local required_files=("setup.sh" "config.sh")
    local required_dirs=("lib" "modules")
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            log_error "Make sure you're running this from the project root directory"
            exit 1
        fi
    done
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Required directory not found: $dir"
            log_error "Make sure you're running this from the project root directory"
            exit 1
        fi
    done
    
    log_success "Local files validated"
}

# Execute setup script
execute_setup() {
    local setup_script
    local script_args=()
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        setup_script="./setup.sh"
    else
        setup_script="${TEMP_DIR}/setup.sh"
    fi
    
    # Build arguments
    script_args+=("--mode" "$INSTALL_MODE")
    
    if [[ "$VERBOSE" == "true" ]]; then
        script_args+=("--verbose")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        script_args+=("--dry-run")
    fi
    
    # Make script executable
    chmod +x "$setup_script"
    
    log_info "Executing setup script with mode: $INSTALL_MODE"
    log_info "Command: sudo $setup_script ${script_args[*]}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: sudo $setup_script ${script_args[*]}"
        return 0
    fi
    
    # Execute with sudo
    if sudo "$setup_script" "${script_args[@]}"; then
        log_success "Setup completed successfully!"
        return 0
    else
        log_error "Setup failed"
        return 1
    fi
}

# Main function
main() {
    show_banner
    
    parse_arguments "$@"
    
    log_info "Quick Start Installer Configuration:"
    log_info "  Mode: $(if [[ "$LOCAL_MODE" == "true" ]]; then echo "Local"; else echo "Remote"; fi)"
    log_info "  Install Mode: $INSTALL_MODE"
    log_info "  Verbose: $VERBOSE"
    log_info "  Dry Run: $DRY_RUN"
    echo ""
    
    check_prerequisites
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        validate_local_files
    else
        download_remote_files
    fi
    
    execute_setup
    
    log_success "Quick start installation completed!"
    echo ""
    log_info "Next steps:"
    log_info "1. Verify installation: sudo /usr/local/bin/verify-setup.sh"
    log_info "2. Check system status: sudo /usr/local/bin/system-status.sh"
    log_info "3. Review logs: tail -f /var/log/setup/setup-latest.log"
}

# Execute main function with all arguments
main "$@"