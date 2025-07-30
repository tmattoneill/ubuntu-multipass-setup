#!/usr/bin/env bash

# Module: User and Group Management
# Create application users and configure groups

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="users"
readonly MODULE_DESCRIPTION="User and Group Management"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    create_application_groups
    create_application_users
    configure_user_environments
    set_up_sudo_access
    configure_user_security
    setup_user_ssh_keys
    
    log_success "User management module completed successfully"
}

# Create application groups
create_application_groups() {
    log_subsection "Creating Application Groups"
    
    local groups=("$WEBAPP_GROUP" "$NODEJS_GROUP")
    
    for group in "${groups[@]}"; do
        if group_exists "$group"; then
            log_debug "Group already exists: $group"
        else
            log_info "Creating group: $group"
            if groupadd "$group"; then
                log_success "Created group: $group"
            else
                log_error "Failed to create group: $group"
                return 1
            fi
        fi
    done
}

# Create application users
create_application_users() {
    log_subsection "Creating Application Users"
    
    # Create app user
    create_app_user
    
    # Create deploy user
    create_deploy_user
    
    # Verify www-data user exists and configure
    configure_www_data_user
}

# Create application user
create_app_user() {
    local username="$PRIMARY_USER"
    local home_dir="$PRIMARY_USER_HOME"
    
    log_info "Creating primary application user: $username"
    
    if user_exists "$username"; then
        log_debug "User already exists: $username"
        # Ensure the user has the right shell and groups even if they exist
    else
        # Create user with home directory
        if useradd -m -d "$home_dir" -s /bin/bash -c "Primary Application User" "$username"; then
            log_success "Created user: $username"
        else
            log_error "Failed to create user: $username"
            return 1
        fi
    fi
    
    # Set up user directory structure
    create_directory "$home_dir" "755" "$username" "$username"
    create_directory "${home_dir}/.ssh" "700" "$username" "$username"
    create_directory "${home_dir}/bin" "755" "$username" "$username"
    create_directory "${home_dir}/logs" "755" "$username" "$username"
    create_directory "${home_dir}/projects" "755" "$username" "$username"
    
    # Add user to groups
    add_user_to_group "$username" "$WEBAPP_GROUP"
    add_user_to_group "$username" "$NODEJS_GROUP"
    
    log_success "Primary application user configured: $username ($home_dir)"
}

# Create deployment user
create_deploy_user() {
    local username="$DEFAULT_DEPLOY_USER"
    local home_dir="$DEPLOY_HOME"
    
    log_info "Creating deployment user: $username"
    
    if user_exists "$username"; then
        log_debug "User already exists: $username"
    else
        # Create user with home directory
        if useradd -m -d "$home_dir" -s /bin/bash -c "Deployment User" "$username"; then
            log_success "Created user: $username"
        else
            log_error "Failed to create user: $username"
            return 1
        fi
    fi
    
    # Set up user directory structure
    create_directory "$home_dir" "755" "$username" "$username"
    create_directory "${home_dir}/.ssh" "700" "$username" "$username"
    create_directory "${home_dir}/bin" "755" "$username" "$username"
    create_directory "${home_dir}/scripts" "755" "$username" "$username"
    
    # Add user to groups
    add_user_to_group "$username" "$WEBAPP_GROUP"
    
    log_success "Deployment user configured: $username"
}

# Configure www-data user
configure_www_data_user() {
    local username="www-data"
    
    log_info "Configuring www-data user"
    
    if ! user_exists "$username"; then
        log_error "www-data user does not exist"
        return 1
    fi
    
    # Add www-data to webapp group
    add_user_to_group "$username" "$WEBAPP_GROUP"
    
    # Ensure www-data has proper shell (keep as /usr/sbin/nologin for security)
    log_debug "www-data user configured"
}

# Configure user environments
configure_user_environments() {
    log_subsection "Configuring User Environments"
    
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    
    for username in "${users[@]}"; do
        configure_user_bashrc "$username"
        configure_user_profile "$username"
        configure_user_aliases "$username"
    done
}

# Configure user .bashrc
configure_user_bashrc() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local bashrc="${home_dir}/.bashrc"
    
    log_debug "Configuring .bashrc for user: $username"
    
    # Backup existing .bashrc if it exists
    [[ -f "$bashrc" ]] && backup_file "$bashrc"
    
    # Create enhanced .bashrc
    cat > "$bashrc" << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History configuration
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Add user bin to PATH
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Load aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Enable bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Custom prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Environment variables
export EDITOR=nano
export PAGER=less
export LESS='-R'

# Node.js and npm configuration
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

# Python configuration
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Ensure ubuntu user .local/bin is in PATH
export PATH="$HOME/.local/bin:/home/ubuntu/.local/bin:$PATH"

# Setup-specific environment
export SETUP_USER=1
EOF

    chown "$username:$username" "$bashrc"
    chmod 644 "$bashrc"
    
    log_success "Configured .bashrc for user: $username"
}

# Configure user .profile
configure_user_profile() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local profile="${home_dir}/.profile"
    
    log_debug "Configuring .profile for user: $username"
    
    # Backup existing .profile if it exists
    [[ -f "$profile" ]] && backup_file "$profile"
    
    # Create .profile
    cat > "$profile" << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.

# If running bash and .bashrc exists, source it
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# Set PATH to include user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Set PATH to include user's private .local/bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF

    chown "$username:$username" "$profile"
    chmod 644 "$profile"
    
    log_success "Configured .profile for user: $username"
}

# Configure user aliases
configure_user_aliases() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local aliases="${home_dir}/.bash_aliases"
    
    log_debug "Configuring aliases for user: $username"
    
    # Create .bash_aliases
    cat > "$aliases" << 'EOF'
# ~/.bash_aliases

# Enhanced ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Utility aliases
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# System aliases
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias psg='ps aux | grep'

# Network aliases
alias ports='netstat -tulanp'
alias listening='ss -tlnp'

# Git aliases (if git is available)
if command -v git >/dev/null 2>&1; then
    alias gs='git status'
    alias ga='git add'
    alias gc='git commit'
    alias gp='git push'
    alias gl='git log --oneline'
fi

# npm aliases (if npm is available)
if command -v npm >/dev/null 2>&1; then
    alias ni='npm install'
    alias ns='npm start'
    alias nt='npm test'
    alias nr='npm run'
fi

# Development aliases
alias edit='$EDITOR'
alias nano='nano -w'
alias reload='source ~/.bashrc'

# Service management aliases
alias start='sudo systemctl start'
alias stop='sudo systemctl stop'
alias restart='sudo systemctl restart'
alias status='sudo systemctl status'
alias enable='sudo systemctl enable'
alias disable='sudo systemctl disable'
EOF

    chown "$username:$username" "$aliases"
    chmod 644 "$aliases"
    
    log_success "Configured aliases for user: $username"
}

# Set up sudo access
set_up_sudo_access() {
    log_subsection "Configuring Sudo Access"
    
    # Configure deploy user with limited sudo access
    setup_deploy_sudo
    
    # Configure app user (limited or no sudo based on security requirements)
    if [[ "${ALLOW_APP_SUDO:-false}" == "true" ]]; then
        setup_app_sudo
    else
        log_info "App user sudo access disabled for security"
    fi
}

# Configure deploy user sudo access
setup_deploy_sudo() {
    local username="$DEFAULT_DEPLOY_USER"
    local sudoers_file="/etc/sudoers.d/${username}"
    
    log_info "Configuring sudo access for deploy user: $username"
    
    # Create sudoers file for deploy user
    cat > "$sudoers_file" << EOF
# Sudo configuration for deploy user
$username ALL=(root) NOPASSWD: /bin/systemctl restart nginx
$username ALL=(root) NOPASSWD: /bin/systemctl reload nginx
$username ALL=(root) NOPASSWD: /bin/systemctl start nginx
$username ALL=(root) NOPASSWD: /bin/systemctl stop nginx
$username ALL=(root) NOPASSWD: /bin/systemctl status nginx
$username ALL=(root) NOPASSWD: /bin/systemctl restart pm2-*
$username ALL=(root) NOPASSWD: /usr/bin/certbot renew
$username ALL=(root) NOPASSWD: /usr/sbin/ufw status
EOF

    chmod 440 "$sudoers_file"
    
    # Validate sudoers file
    if visudo -c -f "$sudoers_file"; then
        log_success "Sudo access configured for deploy user: $username"
    else
        log_error "Invalid sudoers file for deploy user: $username"
        rm -f "$sudoers_file"
        return 1
    fi
}

# Configure app user sudo access (if allowed)
setup_app_sudo() {
    local username="$PRIMARY_USER"
    local sudoers_file="/etc/sudoers.d/${username}"
    
    log_info "Configuring limited sudo access for app user: $username"
    
    # Very limited sudo access for app user
    cat > "$sudoers_file" << EOF
# Limited sudo configuration for app user
$username ALL=(root) NOPASSWD: /bin/systemctl status *
$username ALL=(root) NOPASSWD: /usr/bin/pm2 *
EOF

    chmod 440 "$sudoers_file"
    
    # Validate sudoers file
    if visudo -c -f "$sudoers_file"; then
        log_success "Limited sudo access configured for app user: $username"
    else
        log_error "Invalid sudoers file for app user: $username"
        rm -f "$sudoers_file"
        return 1
    fi
}

# Configure user security
configure_user_security() {
    log_subsection "Configuring User Security"
    
    # Set password policies (if required)
    configure_password_policies
    
    # Set up SSH keys if provided
    setup_ssh_keys
    
    # Configure user limits
    configure_user_limits
}

# Configure password policies
configure_password_policies() {
    log_info "Configuring password policies"
    
    # Install libpam-pwquality if not present
    if ! package_installed "libpam-pwquality"; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-pwquality > /dev/null 2>&1
    fi
    
    # Configure password quality
    local pwquality_conf="/etc/security/pwquality.conf"
    
    backup_file "$pwquality_conf"
    
    # Set password requirements
    cat >> "$pwquality_conf" << 'EOF'

# Setup script password policies
minlen = 12
minclass = 3
maxrepeat = 2
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
EOF
    
    log_success "Password policies configured"
}

# Set up SSH keys for users
setup_ssh_keys() {
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    
    for username in "${users[@]}"; do
        if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
            log_info "Setting up SSH key for user: $username"
            setup_ssh_key_auth "$username" "$SSH_PUBLIC_KEY"
        else
            log_debug "No SSH public key provided for user: $username"
        fi
    done
}

# Configure user limits
configure_user_limits() {
    log_info "Configuring user limits"
    
    local limits_conf="/etc/security/limits.d/99-setup-limits.conf"
    
    cat > "$limits_conf" << EOF
# Setup script user limits
$PRIMARY_USER        soft    nproc           4096
$PRIMARY_USER        hard    nproc           8192
$PRIMARY_USER        soft    nofile          65536
$PRIMARY_USER        hard    nofile          65536

$DEFAULT_DEPLOY_USER soft    nproc           2048
$DEFAULT_DEPLOY_USER hard    nproc           4096
$DEFAULT_DEPLOY_USER soft    nofile          32768
$DEFAULT_DEPLOY_USER hard    nofile          32768

www-data             soft    nofile          32768
www-data             hard    nofile          32768
EOF

    chmod 644 "$limits_conf"
    
    log_success "User limits configured"
}

# Verify user configuration
verify_user_setup() {
    log_subsection "Verifying User Setup"
    
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER" "www-data")
    local failed_users=()
    
    for username in "${users[@]}"; do
        if validate_user_environment "$username"; then
            log_success "User verification passed: $username"
        else
            failed_users+=("$username")
        fi
    done
    
    if [[ ${#failed_users[@]} -eq 0 ]]; then
        log_success "All user configurations verified"
        return 0
    else
        log_error "User verification failed for: [${failed_users[*]}]"
        return 1
    fi
}

# Set up SSH keys for users
setup_user_ssh_keys() {
    log_subsection "Setting up SSH Keys"
    
    # Skip if no SSH key provided
    if [[ -z "${USER_SSH_PUBLIC_KEY:-}" ]]; then
        log_info "No SSH public key provided, skipping SSH key setup"
        return 0
    fi
    
    log_info "Setting up SSH public key for users"
    
    # Users to set up SSH keys for - include ubuntu and primary user (avoiding duplicates)
    local users=("ubuntu" "$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    # Remove duplicates in case PRIMARY_USER is ubuntu
    local unique_users=()
    for user in "${users[@]}"; do
        if [[ ! " ${unique_users[*]} " =~ " ${user} " ]]; then
            unique_users+=("$user")
        fi
    done
    users=("${unique_users[@]}")
    
    for username in "${users[@]}"; do
        # Skip if user doesn't exist
        if ! user_exists "$username"; then
            log_debug "User $username does not exist, skipping SSH key setup"
            continue
        fi
        
        local home_dir
        home_dir=$(getent passwd "$username" | cut -d: -f6)
        local ssh_dir="${home_dir}/.ssh"
        local authorized_keys="${ssh_dir}/authorized_keys"
        
        log_info "Setting up SSH key for user: $username"
        
        # Create .ssh directory
        create_directory "$ssh_dir" "700" "$username" "$username"
        
        # Add the public key to authorized_keys
        echo "$USER_SSH_PUBLIC_KEY" >> "$authorized_keys"
        
        # Set proper permissions
        chmod 600 "$authorized_keys"
        chown "$username:$username" "$authorized_keys"
        
        # Remove duplicate keys
        sort "$authorized_keys" | uniq > "${authorized_keys}.tmp"
        mv "${authorized_keys}.tmp" "$authorized_keys"
        chmod 600 "$authorized_keys"
        chown "$username:$username" "$authorized_keys"
        
        log_success "SSH key configured for user: $username"
    done
    
    log_success "SSH key setup completed"
}

# Module cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "User management module failed with exit code: $exit_code"
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"