#!/usr/bin/env bash

# Configuration file for Ubuntu Server Setup Script
# All configurable parameters and version numbers

# Script configuration
readonly SETUP_NAME="Ubuntu Server Setup for Multipass VM"
readonly SETUP_VERSION="1.0.1a"
readonly SETUP_AUTHOR="Matt O'Neill"

# System requirements
readonly MIN_UBUNTU_VERSION="20.04"
readonly MIN_DISK_SPACE=10  # GB
readonly SUPPORTED_ARCHITECTURES=("x86_64" "aarch64" "arm64")

# Directory structure
readonly BASE_DIR="/opt/setup"
readonly LOG_DIR="/var/log/setup"
readonly BACKUP_DIR="/var/backups/setup"
readonly TEMP_DIR="/tmp/setup-$$"

# Log configuration
readonly LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"
readonly MAX_LOG_SIZE="10M"
readonly LOG_RETENTION_DAYS=30

# User configuration
readonly DEFAULT_APP_USER="ubuntu"
readonly DEFAULT_DEPLOY_USER="deploy"
readonly WEBAPP_GROUP="webapps"
readonly NODEJS_GROUP="nodejs"

# Runtime user configuration (fallback if not set by setup.sh)
# Default to 'ubuntu' for better compatibility, but can be overridden
PRIMARY_USER="${PRIMARY_USER:-ubuntu}"
export PRIMARY_USER

# User directories
readonly APP_HOME="/home/${DEFAULT_APP_USER}"
readonly DEPLOY_HOME="/home/${DEFAULT_DEPLOY_USER}"
PRIMARY_USER_HOME="/home/${PRIMARY_USER}"
readonly WEBAPP_ROOT="/var/www"
readonly APP_DATA_DIR="/var/lib/apps"

# Export dynamic directories
export PRIMARY_USER_HOME

# Software versions
readonly NODE_VERSION="lts"  # Latest LTS version
readonly PYTHON_VERSION="3.12"
readonly NGINX_VERSION="stable"
readonly ZSH_VERSION="latest"

# Package repositories
readonly NGINX_REPO="http://nginx.org/packages/ubuntu"
readonly NODEJS_REPO="https://deb.nodesource.com/node_lts.x"
readonly DEADSNAKES_PPA="ppa:deadsnakes/ppa"

# Network configuration
readonly HTTP_PORT=80
readonly HTTPS_PORT=443
readonly SSH_PORT=22
readonly NODE_DEV_PORT=3000
readonly PYTHON_DEV_PORT=8000

# Nginx configuration
readonly NGINX_USER="www-data"
readonly NGINX_WORKER_PROCESSES="auto"
readonly NGINX_WORKER_CONNECTIONS=1024
readonly NGINX_CLIENT_MAX_BODY_SIZE="64M"
readonly NGINX_KEEPALIVE_TIMEOUT=65

# SSL/TLS configuration
readonly SSL_PROTOCOLS="TLSv1.2 TLSv1.3"
readonly SSL_CIPHERS="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
readonly SSL_SESSION_CACHE="shared:SSL:1m"
readonly SSL_SESSION_TIMEOUT="10m"

# Security configuration
readonly FAIL2BAN_MAXRETRY=5
readonly FAIL2BAN_BANTIME=3600
readonly UFW_SSH_RATE_LIMIT="6/30"

# System optimization
readonly SWAPPINESS=10
readonly VM_DIRTY_RATIO=15
readonly VM_DIRTY_BACKGROUND_RATIO=5
readonly NET_CORE_RMEM_MAX=16777216
readonly NET_CORE_WMEM_MAX=16777216

# Backup configuration
readonly BACKUP_RETENTION_DAYS=2
readonly CONFIG_BACKUP_DIR="${BACKUP_DIR}/configs"
readonly DB_BACKUP_DIR="${BACKUP_DIR}/databases"

# Essential packages
readonly ESSENTIAL_PACKAGES=(
    "curl"
    "wget"
    "git"
    "unzip"
    "tar"
    "gzip"
    "software-properties-common"
    "apt-transport-https"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "build-essential"
    "make"
    "gcc"
    "g++"
)

# Development packages
readonly DEV_PACKAGES=(
    "vim"
    "nano"
    "htop"
    "tree"
    "jq"
    "httpie"
    "ncdu"
    "iotop"
    "iftop"
    "bash-completion"
    "ncurses-term"
    "sqlite3"
    "redis-tools"
    "postgresql-client"
)

# Python packages
readonly PYTHON_PACKAGES=(
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "python3-setuptools"
)

# Global npm packages
readonly GLOBAL_NPM_PACKAGES=(
    "npm-check-updates"
    "pm2"
    "yarn"
    "nodemon"
    "@vue/cli"
    "create-react-app"
    "typescript"
    "ts-node"
)

# Global pip packages (only essential tools, not application packages)
readonly GLOBAL_PIP_PACKAGES=(
    "pip"
    "setuptools"
    "virtualenv"
    "pipenv"
)

# Application packages (installed in virtual environments, not globally)
readonly VENV_PIP_PACKAGES=(
    "requests"
    "gunicorn"
    "uvicorn"
    "fastapi"
    "flask"
)

# Security packages
readonly SECURITY_PACKAGES=(
    "ufw"
    "fail2ban"
    "unattended-upgrades"
    "needrestart"
    "lynis"
    "rkhunter"
    "chkrootkit"
)

# Monitoring packages
readonly MONITORING_PACKAGES=(
    "htop"
    "iotop"
    "iftop"
    "nload"
    "vnstat"
    "sysstat"
    "netdata"
)

# Oh My Zsh configuration
readonly ZSH_PLUGINS=(
    "git"
    "npm"
    "nvm"
    "python"
    "pip"
    "virtualenv"
)
readonly ZSH_THEME="robbyrussell"

# File permissions
readonly WEBAPP_FILE_PERMS=644
readonly WEBAPP_DIR_PERMS=755
readonly SCRIPT_PERMS=755
readonly CONFIG_FILE_PERMS=600
readonly LOG_FILE_PERMS=640

# Service configuration
readonly SERVICES_TO_ENABLE=(
    "nginx"
    "fail2ban"
    "ufw"
    "unattended-upgrades"
    "ssh"
)

readonly SERVICES_TO_DISABLE=(
    "apache2"
    "bind9"
    "sendmail"
)

# Systemd limits
readonly SYSTEMD_DEFAULT_LIMIT_NOFILE=65536
readonly SYSTEMD_DEFAULT_LIMIT_NPROC=32768

# NVM configuration
readonly NVM_VERSION="v0.39.4"
readonly NVM_DIR="/opt/nvm"
readonly NVM_PROFILE="/etc/profile.d/nvm.sh"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Default log level (can be overridden by environment)
DEFAULT_LOG_LEVEL=${SETUP_LOG_LEVEL:-"INFO"}

# Environment-specific overrides
if [[ -n "${SETUP_NO_COLOR:-}" ]]; then
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    PURPLE=""
    CYAN=""
    WHITE=""
    NC=""
fi

# Test connectivity URLs
readonly CONNECTIVITY_TEST_URLS=(
    "http://connectivity-check.ubuntu.com"
    "https://www.google.com"
    "https://github.com"
)

# Package mirror configuration
readonly UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu/"
readonly UBUNTU_SECURITY_MIRROR="http://security.ubuntu.com/ubuntu/"

# Cron job schedules
readonly SECURITY_UPDATES_CRON="0 6 * * *"  # Daily at 6 AM
readonly LOG_ROTATION_CRON="0 2 * * *"      # Daily at 2 AM
readonly BACKUP_CRON="0 3 * * 0"            # Weekly on Sunday at 3 AM

# Application-specific configuration
readonly WEBAPP_CONFIG_DIR="/etc/webapps"
readonly WEBAPP_LOG_DIR="/var/log/webapps"
readonly WEBAPP_PID_DIR="/var/run/webapps"

# Database configuration (if needed)
readonly DB_USER="appuser"
readonly DB_NAME="appdb"
readonly DB_HOST="localhost"
readonly DB_PORT=5432

# Cache directories
readonly NPM_CACHE_DIR="/var/cache/npm"
readonly PIP_CACHE_DIR="/var/cache/pip"
readonly APT_CACHE_DIR="/var/cache/apt"

# Temporary file configuration
readonly TMPDIR_SIZE="1G"
readonly TMPDIR_NOEXEC=true

# Health check configuration
readonly HEALTH_CHECK_INTERVAL=300  # 5 minutes
readonly HEALTH_CHECK_TIMEOUT=30
readonly HEALTH_CHECK_RETRIES=3

# Validation URLs for testing
readonly NGINX_TEST_PAGE="http://localhost/"
readonly NODE_TEST_SCRIPT="/tmp/node-test.js"

# Error handling configuration
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5
readonly BACKUP_ON_ERROR=true

# Module dependencies (bash 4+ required for associative arrays)
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    declare -A MODULE_DEPENDENCIES=(
        ["02-users"]="01-prerequisites"
        ["03-shell"]="02-users"
        ["04-nodejs"]="01-prerequisites 02-users"
        ["05-python"]="01-prerequisites"
        ["06-nginx"]="01-prerequisites 02-users"
        ["07-security"]="01-prerequisites"
        ["08-monitoring"]="01-prerequisites"
        ["09-optimization"]="01-prerequisites"
        ["10-validation"]="01-prerequisites"
    )
else
    # Fallback for older bash versions - dependencies not enforced
    echo "Warning: Bash version ${BASH_VERSION} - module dependencies not available" >&2
fi

# Export commonly used variables
export LOG_DIR LOG_FILE TEMP_DIR BACKUP_DIR
export DEFAULT_APP_USER DEFAULT_DEPLOY_USER
export WEBAPP_ROOT APP_DATA_DIR
export NODE_VERSION PYTHON_VERSION NGINX_VERSION
