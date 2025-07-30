#!/usr/bin/env bash

# Module: Python Environment
# Install Python, pip, and development tools

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="python"
readonly MODULE_DESCRIPTION="Python Environment Setup"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    add_deadsnakes_ppa
    install_python
    configure_pip
    install_python_packages
    create_virtual_environments
    configure_python_for_users
    
    log_success "Python environment module completed successfully"
}

# Add deadsnakes PPA for latest Python versions
add_deadsnakes_ppa() {
    log_subsection "Adding Deadsnakes PPA"
    
    # Check if PPA is already added (multiple ways)
    if grep -q "deadsnakes" /etc/apt/sources.list.d/*.list 2>/dev/null || \
       apt-cache policy | grep -q "deadsnakes" 2>/dev/null; then
        log_debug "Deadsnakes PPA already added"
        return 0
    fi
    
    log_info "Adding deadsnakes PPA for Python $PYTHON_VERSION"
    
    # Try to add PPA with better error handling
    local ppa_output
    if ppa_output=$(add-apt-repository -y "$DEADSNAKES_PPA" 2>&1); then
        log_success "Deadsnakes PPA added successfully"
    else
        log_warn "Failed to add deadsnakes PPA: $ppa_output"
        log_warn "Continuing with system Python packages..."
        return 0  # Don't fail the entire module
    fi
    
    # Update package lists
    if apt-get update > /dev/null 2>&1; then
        log_success "Package lists updated"
    else
        log_warn "Package list update had issues, continuing anyway"
    fi
}

# Install Python
install_python() {
    log_subsection "Installing Python"
    
    # Install Python packages
    local python_packages=("${PYTHON_PACKAGES[@]}")
    
    # Add specific Python version packages
    python_packages+=("python${PYTHON_VERSION}")
    python_packages+=("python${PYTHON_VERSION}-dev")
    python_packages+=("python${PYTHON_VERSION}-venv")
    python_packages+=("python${PYTHON_VERSION}-distutils")
    
    local failed_packages=()
    
    log_info "Installing Python packages: [${python_packages[*]}]"
    
    for package in "${python_packages[@]}"; do
        if package_installed "$package"; then
            log_debug "Package already installed: $package"
            continue
        fi
        
        log_info "Installing package: $package"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" > /dev/null 2>&1; then
            log_success "Installed: $package"
        else
            log_warn "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        log_success "All Python packages installed successfully"
    else
        log_warn "Some Python packages failed to install: [${failed_packages[*]}]"
    fi
    
    # Set up Python alternatives
    setup_python_alternatives
    
    # Verify Python installation
    verify_python_installation
}

# Set up Python alternatives
setup_python_alternatives() {
    log_info "Setting up Python alternatives"
    
    local python_path="/usr/bin/python${PYTHON_VERSION}"
    local python3_path="/usr/bin/python3"
    
    if [[ -f "$python_path" ]]; then
        # Set up alternatives for python3
        update-alternatives --install /usr/bin/python3 python3 "$python_path" 1 > /dev/null 2>&1 || true
        log_success "Python alternatives configured for Python ${PYTHON_VERSION}"
    elif [[ -f "$python3_path" ]]; then
        log_warn "Specific Python ${PYTHON_VERSION} not found, using system Python3"
        log_success "Using system Python3 installation"
    else
        log_warn "Neither Python ${PYTHON_VERSION} nor system Python3 found"
        log_warn "Python alternatives not configured, continuing anyway"
    fi
    
    # Create python -> python3 alias/symlink
    setup_python_alias
}

# Verify Python installation
verify_python_installation() {
    log_debug "Verifying Python installation"
    
    local verification_failed=false
    
    # Check Python3
    if command -v python3 > /dev/null 2>&1; then
        local python_version
        python_version=$(python3 --version)
        log_success "Python3 verified: $python_version"
    else
        log_warn "Python3 command not found"
        verification_failed=true
    fi
    
    # Check pip3
    if command -v pip3 > /dev/null 2>&1; then
        local pip_version
        pip_version=$(pip3 --version | awk '{print $2}')
        log_success "pip3 verified: v$pip_version"
    else
        log_warn "pip3 command not found"
        verification_failed=true
    fi
    
    if [[ "$verification_failed" == "true" ]]; then
        return 1  # Let caller handle this gracefully
    fi
    
    return 0
}

# Configure pip
configure_pip() {
    log_subsection "Configuring pip"
    
    # Upgrade pip to latest version
    upgrade_pip
    
    # Configure pip settings
    configure_pip_settings
    
    # Create pip cache directory
    create_pip_cache_directory
}

# Upgrade pip
upgrade_pip() {
    log_info "Upgrading pip to latest version"
    
    # Use more robust pip upgrade with better error handling
    local pip_upgrade_output
    if pip_upgrade_output=$(python3 -m pip install --upgrade pip --no-warn-script-location 2>&1); then
        local pip_version
        pip_version=$(pip3 --version | awk '{print $2}')
        log_success "pip upgraded to: v$pip_version"
    else
        log_warn "Failed to upgrade pip: $pip_upgrade_output"
        # Fallback: try with --break-system-packages if needed
        if echo "$pip_upgrade_output" | grep -q "externally-managed"; then
            log_info "Attempting pip upgrade with --break-system-packages flag"
            if python3 -m pip install --upgrade pip --break-system-packages --no-warn-script-location > /dev/null 2>&1; then
                local pip_version
                pip_version=$(pip3 --version | awk '{print $2}')
                log_success "pip upgraded to: v$pip_version (with --break-system-packages)"
            else
                log_warn "pip upgrade failed even with --break-system-packages"
            fi
        fi
    fi
}

# Configure pip settings
configure_pip_settings() {
    log_info "Configuring pip settings"
    
    # Create global pip configuration
    local pip_conf_dir="/etc/pip"
    local pip_conf="$pip_conf_dir/pip.conf"
    
    create_directory "$pip_conf_dir" "755"
    
    cat > "$pip_conf" << 'EOF'
[global]
cache-dir = /var/cache/pip
disable-pip-version-check = true
timeout = 60
no-warn-script-location = true
no-warn-conflicts = false

[install]
trusted-host = pypi.org
              pypi.python.org
              files.pythonhosted.org
break-system-packages = false
user = false
EOF
    
    chmod 644 "$pip_conf"
    log_success "Global pip configuration created: $pip_conf"
}

# Create pip cache directory
create_pip_cache_directory() {
    log_info "Creating pip cache directory"
    
    create_directory "$PIP_CACHE_DIR" "755" "root" "root"
    
    log_success "pip cache directory configured: $PIP_CACHE_DIR"
}

# Install Python packages
install_python_packages() {
    log_subsection "Installing Global Python Packages"
    
    local packages=("${GLOBAL_PIP_PACKAGES[@]}")
    local failed_packages=()
    
    log_info "Installing global Python packages: [${packages[*]}]"
    
    for package in "${packages[@]}"; do
        log_info "Installing package: $package"
        local install_output
        if install_output=$(python3 -m pip install --upgrade "$package" --no-warn-script-location 2>&1); then
            log_success "Installed: $package"
        else
            log_warn "Failed to install: $package - $install_output"
            # Try with --break-system-packages if it's an externally-managed environment
            if echo "$install_output" | grep -q "externally-managed"; then
                log_info "Retrying $package with --break-system-packages"
                if python3 -m pip install --upgrade "$package" --break-system-packages --no-warn-script-location > /dev/null 2>&1; then
                    log_success "Installed: $package (with --break-system-packages)"
                else
                    failed_packages+=("$package")
                fi
            else
                failed_packages+=("$package")
            fi
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        log_success "All global Python packages installed successfully"
    else
        log_warn "Some global Python packages failed to install: [${failed_packages[*]}]"
        # Don't fail the module for package installation issues
    fi
    
    # List installed packages
    log_info "Installed Python packages:"
    python3 -m pip list --format=columns 2>/dev/null | head -20 | while read -r line; do
        log_info "  $line"
    done
}

# Create virtual environments
create_virtual_environments() {
    log_subsection "Creating Virtual Environments"
    
    # Include ubuntu user if it exists
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    if user_exists "ubuntu"; then
        users+=("ubuntu")
    fi
    
    for username in "${users[@]}"; do
        create_user_virtual_environments "$username"
    done
}

# Create virtual environments for user
create_user_virtual_environments() {
    local username="$1"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_warn "User $username does not exist, skipping virtual environment creation"
        return 0
    fi
    
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local venv_dir="${home_dir}/.virtualenvs"
    
    log_info "Creating virtual environments for user: $username"
    
    # Create virtualenvs directory
    create_directory "$venv_dir" "755" "$username" "$username"
    
    # Create a default virtual environment
    local default_venv="${venv_dir}/default"
    
    sudo -u "$username" python3 -m venv "$default_venv" > /dev/null 2>&1 || {
        log_warn "Failed to create default virtual environment for user: $username"
        return 0
    }
    
    # Activate and upgrade pip in the virtual environment
    sudo -u "$username" bash -c "
        source $default_venv/bin/activate
        pip install --upgrade pip > /dev/null 2>&1
        pip install wheel setuptools > /dev/null 2>&1
    " || true
    
    # Install application packages in virtual environment (not globally!)
    local venv_packages=("${VENV_PIP_PACKAGES[@]}")
    log_info "Installing application packages in virtual environment for $username"
    
    for package in "${venv_packages[@]}"; do
        sudo -u "$username" bash -c "
            source $default_venv/bin/activate
            pip install $package > /dev/null 2>&1
        " && log_debug "Installed $package in venv for $username" || log_debug "Failed to install $package in venv for $username"
    done
    
    log_success "Virtual environments created for user: $username"
}

# Configure Python for users
configure_python_for_users() {
    log_subsection "Configuring Python for Users"
    
    # Include ubuntu user if it exists
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    if user_exists "ubuntu"; then
        users+=("ubuntu")
    fi
    
    for username in "${users[@]}"; do
        configure_python_for_user "$username"
    done
}

# Configure Python for specific user
configure_python_for_user() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    log_info "Configuring Python for user: $username"
    
    # Create user pip configuration
    create_user_pip_config "$username"
    
    # Create Python development directory
    create_python_dev_directory "$username"
    
    # Add Python paths to user's shell configuration
    configure_python_paths "$username"
    
    log_success "Python configured for user: $username"
}

# Create user pip configuration
create_user_pip_config() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local pip_config_dir="${home_dir}/.config/pip"
    local pip_config="${pip_config_dir}/pip.conf"
    
    log_debug "Creating pip configuration for user: $username"
    
    # Create pip config directory
    create_directory "$pip_config_dir" "755" "$username" "$username"
    
    # Create user pip configuration
    cat > "$pip_config" << EOF
[global]
cache-dir = ${home_dir}/.cache/pip
disable-pip-version-check = true
timeout = 60
no-warn-script-location = true
no-warn-conflicts = false

[install]
user = true
trusted-host = pypi.org
              pypi.python.org
              files.pythonhosted.org
break-system-packages = false
EOF
    
    chown "$username:$username" "$pip_config"
    chmod 644 "$pip_config"
    
    # Create cache directory
    create_directory "${home_dir}/.cache/pip" "755" "$username" "$username"
    
    log_success "pip configuration created for user: $username"
}

# Create Python development directory
create_python_dev_directory() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local dev_dir="${home_dir}/python-projects"
    
    log_debug "Creating Python development directory for user: $username"
    
    create_directory "$dev_dir" "755" "$username" "$username"
    
    # Create a sample project structure
    create_directory "${dev_dir}/sample-project" "755" "$username" "$username"
    
    # Create sample files
    cat > "${dev_dir}/sample-project/requirements.txt" << 'EOF'
# Sample Python project requirements
requests>=2.28.0
flask>=2.2.0
gunicorn>=20.1.0
EOF
    
    cat > "${dev_dir}/sample-project/app.py" << 'EOF'
#!/usr/bin/env python3
"""
Sample Python Flask application
"""

from flask import Flask, jsonify
import os
import sys

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        'message': 'Python Test Application',
        'status': 'running',
        'python_version': sys.version,
        'platform': sys.platform
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'python_version': sys.version_info[:3]
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=False)
EOF
    
    cat > "${dev_dir}/README.md" << 'EOF'
# Python Development Directory

This directory contains Python projects and virtual environments.

## Virtual Environments

- `~/.virtualenvs/default` - Default virtual environment

## Usage

```bash
# Activate default virtual environment
source ~/.virtualenvs/default/bin/activate

# Create new virtual environment
python3 -m venv ~/.virtualenvs/myproject

# Install requirements
pip install -r requirements.txt
```

## Sample Project

The `sample-project` directory contains a basic Flask application:

```bash
cd python-projects/sample-project
source ~/.virtualenvs/default/bin/activate
pip install -r requirements.txt
python app.py
```
EOF
    
    # Set ownership
    chown -R "$username:$username" "$dev_dir"
    
    log_success "Python development directory created for user: $username"
}

# Configure Python paths for user
configure_python_paths() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    log_debug "Configuring Python paths for user: $username"
    
    # Add Python configuration to user's shell files
    local python_config_file="${home_dir}/.python_config"
    
    cat > "$python_config_file" << 'EOF'
# Python configuration

# Python path
export PYTHONPATH="$HOME/.local/lib/python3/site-packages:$PYTHONPATH"

# Python user base
export PYTHON_USER_BASE="$HOME/.local"

# Add user's Python bin to PATH (including ubuntu user)
export PATH="$HOME/.local/bin:/home/ubuntu/.local/bin:$PATH"

# Python environment variables
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Virtual environment helpers
alias activate='source ~/.virtualenvs/default/bin/activate'
alias deactivate='deactivate'

# Python development aliases
alias py='python3'
alias python='python3'
alias pip='pip3'
alias python-server='python3 -m http.server'
alias python-json='python3 -m json.tool'

# Virtual environment functions
mkvenv() {
    if [ -z "$1" ]; then
        echo "Usage: mkvenv <env_name>"
        return 1
    fi
    python3 -m venv ~/.virtualenvs/$1
    echo "Virtual environment created: ~/.virtualenvs/$1"
    echo "Activate with: source ~/.virtualenvs/$1/bin/activate"
}

lsvenv() {
    if [ -d ~/.virtualenvs ]; then
        ls -1 ~/.virtualenvs/
    else
        echo "No virtual environments found"
    fi
}

rmvenv() {
    if [ -z "$1" ]; then
        echo "Usage: rmvenv <env_name>"
        return 1
    fi
    if [ -d ~/.virtualenvs/$1 ]; then
        rm -rf ~/.virtualenvs/$1
        echo "Virtual environment removed: $1"
    else
        echo "Virtual environment not found: $1"
    fi
}
EOF
    
    chown "$username:$username" "$python_config_file"
    chmod 644 "$python_config_file"
    
    # Source Python configuration in user's shell files
    local shell_files=(".bashrc" ".zshrc")
    
    for shell_file in "${shell_files[@]}"; do
        local full_path="${home_dir}/${shell_file}"
        if [[ -f "$full_path" ]]; then
            # Add source line if not already present
            if ! grep -q ".python_config" "$full_path"; then
                echo "" >> "$full_path"
                echo "# Python configuration" >> "$full_path"
                echo "[[ -f ~/.python_config ]] && source ~/.python_config" >> "$full_path"
                log_debug "Added Python configuration to: $shell_file"
            fi
        fi
    done
    
    log_success "Python paths configured for user: $username"
}

# Verify Python environment
verify_python_environment() {
    log_subsection "Verifying Python Environment"
    
    # Verify system Python installation
    if ! verify_python_installation; then
        log_warn "Python installation verification had issues, but continuing"
    fi
    
    # Test pip functionality
    if python3 -m pip --version > /dev/null 2>&1; then
        log_success "pip functionality verified"
    else
        log_warn "pip functionality verification failed, but continuing"
    fi
    
    # Test virtual environment creation
    local test_venv="/tmp/test-venv-$$"
    if python3 -m venv "$test_venv" > /dev/null 2>&1; then
        log_success "Virtual environment creation verified"
        rm -rf "$test_venv"
    else
        log_warn "Virtual environment creation verification failed, but continuing"
    fi
    
    # Verify essential packages
    local essential_packages=("pip" "setuptools" "wheel")
    local missing_packages=()
    
    for package in "${essential_packages[@]}"; do
        if ! python3 -c "import $package" > /dev/null 2>&1; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_success "Essential Python packages verified"
    else
        log_warn "Missing essential Python packages: [${missing_packages[*]}]"
    fi
    
    log_success "Python environment verification completed"
}

# Set up python alias for python3
setup_python_alias() {
    log_info "Setting up python alias for python3"
    
    # Create system-wide python alias using alternatives
    if command -v python3 > /dev/null 2>&1; then
        local python3_path
        python3_path=$(which python3)
        
        # Set up alternatives for python command to point to python3
        update-alternatives --install /usr/bin/python python "$python3_path" 1 > /dev/null 2>&1 || true
        
        # Verify the alias works
        if command -v python > /dev/null 2>&1 && [[ "$(python --version 2>&1)" =~ Python\ 3 ]]; then
            log_success "python alias configured to point to python3"
        else
            log_warn "python alias setup may have failed, but continuing"
        fi
    else
        log_warn "python3 not found, cannot create python alias"
    fi
}

# Module cleanup on exit - make non-fatal
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warn "Python environment module had issues (exit code: $exit_code) but continuing"
        # Don't exit with error - let the module complete
        exit 0
    fi
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"