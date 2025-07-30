#!/usr/bin/env bash

# Module: Node.js Environment
# Install NVM and Node.js with global packages

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="nodejs"
readonly MODULE_DESCRIPTION="Node.js Environment Setup"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    install_nvm
    install_nodejs
    configure_npm
    install_global_packages
    configure_pm2
    
    log_success "Node.js environment module completed successfully"
}

# Install NVM (Node Version Manager)
install_nvm() {
    log_subsection "Installing NVM (Node Version Manager)"
    
    # Check if NVM is already installed
    if [[ -d "$NVM_DIR" ]]; then
        log_debug "NVM directory already exists: $NVM_DIR"
        # Check if it's a valid NVM installation
        if [[ -f "$NVM_DIR/nvm.sh" ]]; then
            log_info "NVM already installed"
            return 0
        fi
    fi
    
    log_info "Installing NVM version: $NVM_VERSION"
    
    # Create NVM directory
    create_directory "$NVM_DIR" "755" "root" "root"
    
    # Download and install NVM
    local nvm_install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
    local temp_installer="/tmp/nvm-install-$$.sh"
    
    if ! download_file "$nvm_install_url" "$temp_installer"; then
        log_error "Failed to download NVM installer"
        return 1
    fi
    
    # Make installer executable
    chmod +x "$temp_installer"
    
    # Install NVM to system location
    if PROFILE="$NVM_PROFILE" NVM_DIR="$NVM_DIR" bash "$temp_installer" > /dev/null 2>&1; then
        log_success "NVM installed to: $NVM_DIR"
    else
        log_error "Failed to install NVM"
        rm -f "$temp_installer"
        return 1
    fi
    
    # Clean up installer
    rm -f "$temp_installer"
    
    # Create NVM profile script
    create_nvm_profile
    
    # Verify NVM installation
    if [[ -f "$NVM_DIR/nvm.sh" ]]; then
        log_success "NVM installation verified"
    else
        log_error "NVM installation verification failed"
        return 1
    fi
}

# Create NVM profile script
create_nvm_profile() {
    log_info "Creating NVM profile script"
    
    cat > "$NVM_PROFILE" << EOF
#!/bin/bash
# NVM configuration for all users

export NVM_DIR="$NVM_DIR"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && . "\$NVM_DIR/bash_completion"

# Lazy load NVM for better shell startup performance
if [ -s "\$NVM_DIR/nvm.sh" ] && [ ! "\$(type -w nvm)" = "nvm: function" ]; then
  export PATH="\$NVM_DIR/versions/node/\$(cat \$NVM_DIR/alias/default 2>/dev/null || echo 'system')/bin:\$PATH"
fi
EOF
    
    chmod 644 "$NVM_PROFILE"
    log_success "NVM profile script created: $NVM_PROFILE"
}

# Install Node.js
install_nodejs() {
    log_subsection "Installing Node.js"
    
    # Source NVM
    if ! source_nvm; then
        log_error "Failed to source NVM"
        return 1
    fi
    
    # Install Node.js
    local node_version="$NODE_VERSION"
    log_info "Installing Node.js version: $node_version"
    
    if nvm install "$node_version" > /dev/null 2>&1; then
        log_success "Node.js installed: $node_version"
    else
        log_error "Failed to install Node.js: $node_version"
        return 1
    fi
    
    # Set as default
    if nvm alias default "$node_version" > /dev/null 2>&1; then
        log_success "Node.js set as default: $node_version"
    else
        log_error "Failed to set Node.js as default: $node_version"
        return 1
    fi
    
    # Use the installed version
    if nvm use "$node_version" > /dev/null 2>&1; then
        log_success "Using Node.js version: $node_version"
    else
        log_error "Failed to use Node.js version: $node_version"
        return 1
    fi
    
    # Verify installation
    verify_nodejs_installation
}

# Source NVM function
source_nvm() {
    if [[ -f "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
        return 0
    else
        log_error "NVM script not found: $NVM_DIR/nvm.sh"
        return 1
    fi
}

# Verify Node.js installation
verify_nodejs_installation() {
    log_debug "Verifying Node.js installation"
    
    # Source NVM first
    source_nvm
    
    # Check Node.js
    if command -v node > /dev/null 2>&1; then
        local node_version
        node_version=$(node --version)
        log_success "Node.js verified: $node_version"
    else
        log_error "Node.js command not found"
        return 1
    fi
    
    # Check npm
    if command -v npm > /dev/null 2>&1; then
        local npm_version
        npm_version=$(npm --version)
        log_success "npm verified: v$npm_version"
    else
        log_error "npm command not found"
        return 1
    fi
    
    return 0
}

# Configure npm
configure_npm() {
    log_subsection "Configuring npm"
    
    # Source NVM
    source_nvm
    
    # Configure npm settings
    configure_npm_settings
    
    # Create cache directories
    create_npm_cache_directories
    
    # Set up npm directories for users
    setup_npm_user_directories
}

# Configure npm settings
configure_npm_settings() {
    log_info "Configuring npm settings"
    
    # Update npm to latest version
    log_info "Updating npm to latest version"
    if npm install -g npm@latest > /dev/null 2>&1; then
        local npm_version
        npm_version=$(npm --version)
        log_success "npm updated to: v$npm_version"
    else
        log_warn "Failed to update npm"
    fi
    
    # Configure npm settings
    npm config set fund false --global > /dev/null 2>&1 || true
    npm config set audit-level moderate --global > /dev/null 2>&1 || true
    npm config set save-exact true --global > /dev/null 2>&1 || true
    npm config set progress false --global > /dev/null 2>&1 || true
    
    log_success "npm settings configured"
}

# Create npm cache directories
create_npm_cache_directories() {
    log_info "Creating npm cache directories"
    
    create_directory "$NPM_CACHE_DIR" "755" "root" "root"
    
    # Set npm cache location
    npm config set cache "$NPM_CACHE_DIR" --global > /dev/null 2>&1 || true
    
    log_success "npm cache directory configured: $NPM_CACHE_DIR"
}

# Set up npm directories for users
setup_npm_user_directories() {
    log_info "Setting up npm directories for users"
    
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    
    for username in "${users[@]}"; do
        setup_npm_for_user "$username"
    done
}

# Set up npm for specific user
setup_npm_for_user() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local npm_global_dir="${home_dir}/.npm-global"
    
    log_info "Setting up npm for user: $username"
    
    # Create npm global directory
    create_directory "$npm_global_dir" "755" "$username" "$username"
    
    # Configure npm for user
    sudo -u "$username" bash -c "
        source $NVM_PROFILE
        npm config set prefix '$npm_global_dir'
        npm config set fund false
        npm config set audit-level moderate
    " > /dev/null 2>&1 || true
    
    log_success "npm configured for user: $username"
}

# Install global packages
install_global_packages() {
    log_subsection "Installing Global npm Packages"
    
    # Source NVM
    source_nvm
    
    local packages=("${GLOBAL_NPM_PACKAGES[@]}")
    local failed_packages=()
    
    log_info "Installing global packages: [${packages[*]}]"
    
    for package in "${packages[@]}"; do
        log_info "Installing global package: $package"
        if npm install -g "$package" > /dev/null 2>&1; then
            log_success "Installed: $package"
        else
            log_warn "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        log_success "All global packages installed successfully"
    else
        log_warn "Some global packages failed to install: [${failed_packages[*]}]"
        # Don't fail the module for failed global packages
    fi
    
    # List installed global packages
    log_info "Installed global packages:"
    npm list -g --depth=0 2>/dev/null | grep -E "├──|└──" | while read -r line; do
        log_info "  $line"
    done
}

# Configure PM2
configure_pm2() {
    log_subsection "Configuring PM2 Process Manager"
    
    # Source NVM
    source_nvm
    
    # Check if PM2 is installed
    if ! command -v pm2 > /dev/null 2>&1; then
        log_warn "PM2 not installed, skipping configuration"
        return 0
    fi
    
    # Configure PM2 for users
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    
    for username in "${users[@]}"; do
        configure_pm2_for_user "$username"
    done
    
    # Create PM2 systemd service
    create_pm2_systemd_service
}

# Configure PM2 for specific user
configure_pm2_for_user() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    log_info "Configuring PM2 for user: $username"
    
    # Set up PM2 for user
    sudo -u "$username" bash -c "
        source $NVM_PROFILE
        if command -v pm2 > /dev/null 2>&1; then
            pm2 install pm2-logrotate > /dev/null 2>&1 || true
            pm2 set pm2-logrotate:max_size 10M > /dev/null 2>&1 || true
            pm2 set pm2-logrotate:retain 7 > /dev/null 2>&1 || true
            pm2 startup > /dev/null 2>&1 || true
        fi
    " || true
    
    log_success "PM2 configured for user: $username"
}

# Create PM2 systemd service
create_pm2_systemd_service() {
    log_info "Creating PM2 systemd service"
    
    local username="$PRIMARY_USER"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    # Get PM2 startup command
    local pm2_startup_cmd
    pm2_startup_cmd=$(sudo -u "$username" bash -c "
        source $NVM_PROFILE
        if command -v pm2 > /dev/null 2>&1; then
            pm2 startup systemd -u $username --hp $home_dir 2>/dev/null | grep 'sudo'
        fi
    " 2>/dev/null || echo "")
    
    if [[ -n "$pm2_startup_cmd" ]]; then
        # Execute the startup command
        eval "$pm2_startup_cmd" > /dev/null 2>&1 || true
        log_success "PM2 systemd service created"
    else
        log_debug "PM2 startup command not available"
    fi
}

# Create Node.js test application
create_test_application() {
    log_subsection "Creating Node.js Test Application"
    
    local username="$PRIMARY_USER"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local app_dir="${home_dir}/test-app"
    
    # Create test application directory
    create_directory "$app_dir" "755" "$username" "$username"
    
    # Create package.json
    cat > "${app_dir}/package.json" << 'EOF'
{
  "name": "nodejs-test-app",
  "version": "1.0.0",
  "description": "Test Node.js application",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.0"
  }
}
EOF
    
    # Create simple Express app
    cat > "${app_dir}/app.js" << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Node.js Test Application',
    status: 'running',
    timestamp: new Date().toISOString(),
    version: process.version,
    platform: process.platform
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

app.listen(port, () => {
  console.log(`Test app listening at http://localhost:${port}`);
});
EOF
    
    # Set ownership
    chown -R "$username:$username" "$app_dir"
    
    # Install dependencies
    sudo -u "$username" bash -c "
        source $NVM_PROFILE
        cd $app_dir
        npm install > /dev/null 2>&1
    " || true
    
    log_success "Node.js test application created: $app_dir"
}

# Verify Node.js environment
verify_nodejs_environment() {
    log_subsection "Verifying Node.js Environment"
    
    # Source NVM
    if ! source_nvm; then
        log_error "Failed to source NVM for verification"
        return 1
    fi
    
    # Verify Node.js
    if ! verify_nodejs_installation; then
        log_error "Node.js installation verification failed"
        return 1
    fi
    
    # Test npm functionality
    if npm --version > /dev/null 2>&1; then
        log_success "npm functionality verified"
    else
        log_error "npm functionality verification failed"
        return 1
    fi
    
    # Verify global packages
    local essential_packages=("pm2" "npm-check-updates")
    local missing_packages=()
    
    for package in "${essential_packages[@]}"; do
        if ! command -v "$package" > /dev/null 2>&1; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_success "Essential global packages verified"
    else
        log_warn "Missing essential global packages: [${missing_packages[*]}]"
    fi
    
    # Create test application for verification
    create_test_application
    
    log_success "Node.js environment verification completed"
}

# Module cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Node.js environment module failed with exit code: $exit_code"
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"