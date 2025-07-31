#!/usr/bin/env bash

# Module: Shell Environment Setup
# Install and configure Zsh with Oh My Zsh

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# Module configuration
readonly MODULE_NAME="shell"
readonly MODULE_DESCRIPTION="Shell Environment Setup (Zsh + Oh My Zsh)"

main() {
    log_section "Module: $MODULE_DESCRIPTION"
    
    install_zsh
    install_oh_my_zsh
    configure_zsh_for_users
    set_default_shells
    
    log_success "Shell environment module completed successfully"
}

# Install Zsh
install_zsh() {
    log_subsection "Installing Zsh"
    
    if package_installed "zsh"; then
        log_debug "Zsh is already installed"
        local zsh_version
        zsh_version=$(zsh --version | awk '{print $2}')
        log_info "Zsh version: $zsh_version"
    else
        log_info "Installing Zsh..."
        if DEBIAN_FRONTEND=noninteractive apt-get install -y zsh; then
            log_success "Zsh installed successfully"
        else
            log_error "Failed to install Zsh"
            return 1
        fi
    fi
    
    # Verify Zsh is available
    if ! command_exists "zsh"; then
        log_error "Zsh command not found after installation"
        return 1
    fi
    
    local zsh_path
    zsh_path=$(which zsh)
    log_info "Zsh installed at: $zsh_path"
    
    # Ensure Zsh is in /etc/shells
    if ! grep -q "$zsh_path" /etc/shells; then
        echo "$zsh_path" >> /etc/shells
        log_info "Added Zsh to /etc/shells"
    fi
}

# Install Oh My Zsh
install_oh_my_zsh() {
    log_subsection "Installing Oh My Zsh"
    
    # Include ubuntu user and primary user (avoiding duplicates)
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    if user_exists "ubuntu" && [[ "$PRIMARY_USER" != "ubuntu" ]]; then
        users+=("ubuntu")
    fi
    
    for username in "${users[@]}"; do
        install_oh_my_zsh_for_user "$username"
    done
}

# Install Oh My Zsh for specific user
install_oh_my_zsh_for_user() {
    local username="$1"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_warn "User $username does not exist, skipping Oh My Zsh installation"
        return 0
    fi
    
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local oh_my_zsh_dir="${home_dir}/.oh-my-zsh"
    
    log_info "Installing Oh My Zsh for user: $username"
    
    if [[ -d "$oh_my_zsh_dir" ]]; then
        log_debug "Oh My Zsh already installed for user: $username"
        return 0
    fi
    
    # Create temporary directory for installation
    local temp_dir="/tmp/oh-my-zsh-install-$$"
    create_directory "$temp_dir"
    
    # Download Oh My Zsh installer
    local installer="$temp_dir/install.sh"
    if ! download_file "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "$installer"; then
        log_error "Failed to download Oh My Zsh installer"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Make installer executable
    chmod +x "$installer"
    
    # Install Oh My Zsh as the user (non-interactive)
    log_debug "Running Oh My Zsh installer for user: $username"
    
    # Set environment variables for non-interactive installation
    local install_cmd="cd '$home_dir' && RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh '$installer'"
    
    if sudo -u "$username" bash -c "$install_cmd" > /dev/null 2>&1; then
        log_success "Oh My Zsh installed for user: $username"
    else
        log_error "Failed to install Oh My Zsh for user: $username"
        log_debug "Trying alternative installation method..."
        
        # Alternative installation method - clone directly
        if sudo -u "$username" bash -c "cd '$home_dir' && git clone https://github.com/ohmyzsh/ohmyzsh.git .oh-my-zsh" > /dev/null 2>&1; then
            log_success "Oh My Zsh installed via git clone for user: $username"
        else
            log_warn "Oh My Zsh installation failed for user: $username, continuing anyway"
            rm -rf "$temp_dir"
            return 0  # Don't fail the entire module
        fi
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ -d "$oh_my_zsh_dir" ]]; then
        log_success "Oh My Zsh installation verified for user: $username"
    else
        log_error "Oh My Zsh installation verification failed for user: $username"
        return 1
    fi
}

# Configure Zsh for users
configure_zsh_for_users() {
    log_subsection "Configuring Zsh"
    
    # Include ubuntu user and primary user (avoiding duplicates)
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    if user_exists "ubuntu" && [[ "$PRIMARY_USER" != "ubuntu" ]]; then
        users+=("ubuntu")
    fi
    
    for username in "${users[@]}"; do
        configure_zsh_for_user "$username"
    done
}

# Configure Zsh for specific user
configure_zsh_for_user() {
    local username="$1"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_warn "User $username does not exist, skipping Zsh configuration"
        return 0
    fi
    
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local zshrc="${home_dir}/.zshrc"
    
    log_info "Configuring Zsh for user: $username"
    
    # Backup existing .zshrc if it exists
    [[ -f "$zshrc" ]] && backup_file "$zshrc"
    
    # Create custom .zshrc
    create_zshrc_config "$username" "$zshrc"
    
    # Set proper ownership
    chown "$username:$username" "$zshrc"
    chmod 644 "$zshrc"
    
    # Install additional plugins
    install_zsh_plugins "$username"
    
    log_success "Zsh configured for user: $username"
}

# Create .zshrc configuration
create_zshrc_config() {
    local username="$1"
    local zshrc="$2"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    log_debug "Creating .zshrc configuration for user: $username"
    
    cat > "$zshrc" << EOF
# ~/.zshrc - Zsh configuration generated by setup script

# Path to Oh My Zsh installation
export ZSH="$home_dir/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="$ZSH_THEME"

# Plugins to load
plugins=(
$(printf '    %s\n' "${ZSH_PLUGINS[@]}")
)

# Load Oh My Zsh
source \$ZSH/oh-my-zsh.sh

# User configuration

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Completion system
setopt COMPLETE_ALIASES
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END

# Environment variables
export EDITOR=nano
export PAGER=less
export LESS='-R'

# Language environment
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Node.js configuration (Note: NPM_CONFIG_PREFIX conflicts with NVM, handled by NVM setup)
# export NPM_CONFIG_PREFIX="\$HOME/.npm-global"
# export PATH="\$NPM_CONFIG_PREFIX/bin:\$PATH"

# Python configuration
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Add user bin directories to PATH (including ubuntu user)
export PATH="\$HOME/bin:\$HOME/.local/bin:/home/ubuntu/.local/bin:\$PATH"

# NVM (Node Version Manager) configuration
# Unset NPM_CONFIG_PREFIX to avoid conflicts with NVM
unset NPM_CONFIG_PREFIX
export NVM_DIR="/opt/nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Add node and npm to PATH if default version exists
if [ -f "\$NVM_DIR/alias/default" ]; then
    DEFAULT_NODE_VERSION=\$(cat "\$NVM_DIR/alias/default" 2>/dev/null || echo "")
    if [ -n "\$DEFAULT_NODE_VERSION" ] && [ -d "\$NVM_DIR/versions/node/\$DEFAULT_NODE_VERSION" ]; then
        export PATH="\$NVM_DIR/versions/node/\$DEFAULT_NODE_VERSION/bin:\$PATH"
    fi
fi

# Python alias for convenience
alias python='python3'

# Custom aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# System aliases
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias psg='ps aux | grep'

# Network aliases
alias ports='netstat -tulanp'
alias listening='ss -tlnp'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# npm aliases
alias ni='npm install'
alias ns='npm start'
alias nt='npm test'
alias nr='npm run'
alias nu='npm update'

# Development aliases
alias edit='\$EDITOR'
alias reload='source ~/.zshrc'

# Service management aliases (if user has sudo)
if groups \$USER | grep -q sudo; then
    alias start='sudo systemctl start'
    alias stop='sudo systemctl stop'
    alias restart='sudo systemctl restart'
    alias status='sudo systemctl status'
    alias enable='sudo systemctl enable'
    alias disable='sudo systemctl disable'
fi

# Custom functions
mkcd() {
    mkdir -p "\$1" && cd "\$1"
}

extract() {
    if [ -f "\$1" ]; then
        case "\$1" in
            *.tar.bz2)   tar xjf "\$1"     ;;
            *.tar.gz)    tar xzf "\$1"     ;;
            *.bz2)       bunzip2 "\$1"    ;;
            *.rar)       unrar x "\$1"    ;;
            *.gz)        gunzip "\$1"     ;;
            *.tar)       tar xf "\$1"     ;;
            *.tbz2)      tar xjf "\$1"    ;;
            *.tgz)       tar xzf "\$1"    ;;
            *.zip)       unzip "\$1"      ;;
            *.Z)         uncompress "\$1" ;;
            *.7z)        7z x "\$1"       ;;
            *)           echo "'\$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'\$1' is not a valid file"
    fi
}

# Load local customizations if they exist
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Setup-specific configuration
export SETUP_SHELL_CONFIGURED=1
EOF

    log_debug "Created .zshrc configuration for user: $username"
}

# Install additional Zsh plugins
install_zsh_plugins() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local custom_plugins_dir="${home_dir}/.oh-my-zsh/custom/plugins"
    
    log_debug "Installing additional Zsh plugins for user: $username"
    
    # Create custom plugins directory
    create_directory "$custom_plugins_dir" "755" "$username" "$username"
    
    # Install zsh-syntax-highlighting
    install_syntax_highlighting_plugin "$username" "$custom_plugins_dir"
    
    # Install zsh-autosuggestions
    install_autosuggestions_plugin "$username" "$custom_plugins_dir"
    
    log_success "Additional Zsh plugins installed for user: $username"
}

# Install zsh-syntax-highlighting plugin
install_syntax_highlighting_plugin() {
    local username="$1"
    local plugins_dir="$2"
    local plugin_dir="${plugins_dir}/zsh-syntax-highlighting"
    
    if [[ -d "$plugin_dir" ]]; then
        log_debug "zsh-syntax-highlighting already installed for user: $username"
        return 0
    fi
    
    log_info "Installing zsh-syntax-highlighting plugin for user: $username"
    
    if sudo -u "$username" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir" > /dev/null 2>&1; then
        log_success "zsh-syntax-highlighting installed for user: $username"
    else
        log_warn "Failed to install zsh-syntax-highlighting for user: $username"
    fi
}

# Install zsh-autosuggestions plugin
install_autosuggestions_plugin() {
    local username="$1"
    local plugins_dir="$2"
    local plugin_dir="${plugins_dir}/zsh-autosuggestions"
    
    if [[ -d "$plugin_dir" ]]; then
        log_debug "zsh-autosuggestions already installed for user: $username"
        return 0
    fi
    
    log_info "Installing zsh-autosuggestions plugin for user: $username"
    
    if sudo -u "$username" git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugin_dir" > /dev/null 2>&1; then
        log_success "zsh-autosuggestions installed for user: $username"
    else
        log_warn "Failed to install zsh-autosuggestions for user: $username"
    fi
}

# Set default shells
set_default_shells() {
    log_subsection "Setting Default Shells"
    
    # Include ubuntu user and primary user (avoiding duplicates)
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    if user_exists "ubuntu" && [[ "$PRIMARY_USER" != "ubuntu" ]]; then
        users+=("ubuntu")
    fi
    
    local zsh_path
    zsh_path=$(which zsh)
    
    for username in "${users[@]}"; do
        set_user_shell "$username" "$zsh_path"
    done
}

# Set shell for specific user
set_user_shell() {
    local username="$1"
    local shell_path="$2"
    
    log_info "Setting default shell for user $username to: $shell_path"
    
    # Get current shell
    local current_shell
    current_shell=$(getent passwd "$username" | cut -d: -f7)
    
    if [[ "$current_shell" == "$shell_path" ]]; then
        log_debug "User $username already has shell: $shell_path"
        return 0
    fi
    
    # Change shell
    if chsh -s "$shell_path" "$username"; then
        log_success "Changed shell for user $username to: $shell_path"
    else
        log_warn "Failed to change shell for user $username"
        # Don't fail the module for this
    fi
}

# Verify shell configuration
verify_shell_setup() {
    log_subsection "Verifying Shell Setup"
    
    # Include ubuntu user and primary user (avoiding duplicates)
    local users=("$PRIMARY_USER" "$DEFAULT_DEPLOY_USER")
    if user_exists "ubuntu" && [[ "$PRIMARY_USER" != "ubuntu" ]]; then
        users+=("ubuntu")
    fi
    
    local failed_users=()
    
    for username in "${users[@]}"; do
        if verify_user_shell_config "$username"; then
            log_success "Shell verification passed for user: $username"
        else
            failed_users+=("$username")
        fi
    done
    
    if [[ ${#failed_users[@]} -eq 0 ]]; then
        log_success "All shell configurations verified"
        return 0
    else
        log_warn "Shell verification issues for users: [${failed_users[*]}]"
        # Don't fail the module for shell issues
        return 0
    fi
}

# Verify shell configuration for user
verify_user_shell_config() {
    local username="$1"
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    local zshrc="${home_dir}/.zshrc"
    local oh_my_zsh_dir="${home_dir}/.oh-my-zsh"
    
    # Check if .zshrc exists and is readable
    if [[ ! -f "$zshrc" ]] || [[ ! -r "$zshrc" ]]; then
        log_error "Shell verification failed: .zshrc missing or not readable for user: $username"
        return 1
    fi
    
    # Check if Oh My Zsh is installed
    if [[ ! -d "$oh_my_zsh_dir" ]]; then
        log_error "Shell verification failed: Oh My Zsh not installed for user: $username"
        return 1
    fi
    
    # Check if Zsh is set as default shell
    local current_shell
    current_shell=$(getent passwd "$username" | cut -d: -f7)
    local zsh_path
    zsh_path=$(which zsh)
    
    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_warn "Shell verification warning: Zsh not set as default for user: $username"
    fi
    
    return 0
}

# Module cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Shell environment module failed with exit code: $exit_code"
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT

# Execute main function
main "$@"