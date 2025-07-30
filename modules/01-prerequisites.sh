#!/usr/bin/env bash

# Module: Prerequisites
# System updates and essential build tools installation

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="prerequisites"
readonly MODULE_DESCRIPTION="System updates and essential build tools"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    # Skip updates if requested
    if [[ "${SKIP_UPDATES:-false}" != "true" ]]; then
        update_system_packages
    else
        log_info "Skipping system updates as requested"
    fi
    
    install_essential_packages
    install_development_packages
    configure_package_manager
    configure_git_global_settings
    cleanup_packages
    
    log_success "Prerequisites module completed successfully"
}

# Update system packages
update_system_packages() {
    log_subsection "Updating System Packages"
    
    log_info "Updating package lists..."
    execute_with_retry "apt-get update" 3 5 "package list update"
    
    log_info "Upgrading existing packages..."
    execute_with_retry "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y" 3 10 "package upgrade"
    
    log_info "Installing security updates..."
    execute_with_retry "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y" 3 10 "security updates"
    
    log_success "System packages updated successfully"
}

# Install essential packages
install_essential_packages() {
    log_subsection "Installing Essential Packages"
    
    local packages=("${ESSENTIAL_PACKAGES[@]}")
    local failed_packages=()
    
    log_info "Installing essential packages: [${packages[*]}]"
    
    for package in "${packages[@]}"; do
        if package_installed "$package"; then
            log_debug "Package already installed: $package"
            continue
        fi
        
        log_info "Installing package: $package"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" > /dev/null 2>&1; then
            log_success "Installed: $package"
        else
            log_error "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        log_success "All essential packages installed successfully"
    else
        log_error "Failed to install essential packages: [${failed_packages[*]}]"
        return 1
    fi
}

# Install development packages
install_development_packages() {
    log_subsection "Installing Development Packages"
    
    local packages=("${DEV_PACKAGES[@]}")
    local failed_packages=()
    
    log_info "Installing development packages: [${packages[*]}]"
    
    for package in "${packages[@]}"; do
        if package_installed "$package"; then
            log_debug "Package already installed: $package"
            continue
        fi
        
        log_info "Installing package: $package"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" > /dev/null 2>&1; then
            log_success "Installed: $package"
        else
            log_warn "Failed to install development package: $package"
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        log_success "All development packages installed successfully"
    else
        log_warn "Some development packages failed to install: [${failed_packages[*]}]"
        # Don't fail the module for dev packages
    fi
}

# Configure package manager
configure_package_manager() {
    log_subsection "Configuring Package Manager"
    
    # Configure APT to keep downloaded packages for a shorter time
    local apt_config="/etc/apt/apt.conf.d/99-setup-config"
    
    cat > "$apt_config" << 'EOF'
// Setup script APT configuration
APT::Clean-Installed "true";
APT::AutoRemove::SuggestsImportant "false";
APT::AutoRemove::RecommendsImportant "false";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Dpkg::Progress-Fancy "true";
APT::Color "true";
EOF
    
    chmod 644 "$apt_config"
    log_success "APT configuration updated"
    
    # Update package database
    apt-get update > /dev/null 2>&1
    log_success "Package database updated"
}

# Clean up packages
cleanup_packages() {
    log_subsection "Cleaning Up Packages"
    
    log_info "Removing unnecessary packages..."
    apt-get autoremove -y > /dev/null 2>&1 || true
    
    log_info "Cleaning package cache..."
    apt-get autoclean > /dev/null 2>&1 || true
    
    log_info "Cleaning downloaded package files..."
    apt-get clean > /dev/null 2>&1 || true
    
    log_success "Package cleanup completed"
}

# Verify installation
verify_prerequisites() {
    log_subsection "Verifying Prerequisites"
    
    local required_commands=("curl" "wget" "git" "make" "gcc" "g++")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -eq 0 ]]; then
        log_success "All required commands are available"
        return 0
    else
        log_error "Missing required commands: [${missing_commands[*]}]"
        return 1
    fi
}

# Configure Git global settings
configure_git_global_settings() {
    log_subsection "Configuring Git Global Settings"
    
    # Skip if no git credentials provided
    if [[ -z "${GIT_USER_NAME:-}" ]] || [[ -z "${GIT_USER_EMAIL:-}" ]]; then
        log_info "No Git credentials provided, skipping Git configuration"
        return 0
    fi
    
    log_info "Configuring Git with user: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    
    # Set global Git configuration
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    
    # Set some useful Git defaults
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.autocrlf input
    git config --global core.editor nano
    
    # Verify configuration
    local configured_name
    local configured_email
    configured_name=$(git config --global user.name)
    configured_email=$(git config --global user.email)
    
    if [[ "$configured_name" == "$GIT_USER_NAME" ]] && [[ "$configured_email" == "$GIT_USER_EMAIL" ]]; then
        log_success "Git global configuration set successfully"
        log_info "Git user: $configured_name <$configured_email>"
    else
        log_warn "Git configuration may not have been set correctly"
    fi
}

# Module cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Prerequisites module failed with exit code: $exit_code"
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"