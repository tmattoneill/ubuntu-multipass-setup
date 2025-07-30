# Ubuntu Setup Script Plan

## Overview
This document outlines the plan for a comprehensive setup.sh script that will configure a fresh Ubuntu multipass instance with modern development tools and web application infrastructure.

## Script Architecture

### 1. Script Structure
```
setup.sh
├── Header (shebang, description, author)
├── Configuration variables
├── Error handling setup
├── Logging framework
├── Prerequisite checks
├── Main installation functions
├── User/group management
├── Service configuration
├── Validation functions
└── Cleanup and summary
```

### 2. Core Principles
- **Idempotency**: Script can be run multiple times safely
- **Error handling**: Fail gracefully with meaningful messages
- **Logging**: Comprehensive logging to file and console
- **Validation**: Check each step before proceeding
- **Rollback capability**: Where possible, provide rollback options
- **Non-interactive**: Minimize user input requirements

## Detailed Implementation Plan

### Phase 1: Initial Setup & Prerequisites

#### 1.1 Script Header
```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Set Internal Field Separator
```

#### 1.2 Variables & Configuration
- Define version numbers for all software
- Set installation paths
- Configure color codes for output
- Set log file locations

#### 1.3 Logging Framework
- Create log directory
- Implement log rotation
- Dual output (console + file)
- Timestamp all entries
- Log levels (INFO, WARN, ERROR, DEBUG)

#### 1.4 System Detection
- Verify Ubuntu version (20.04 LTS or newer)
- Check architecture (x86_64, arm64)
- Detect if running in container/VM
- Check available disk space
- Verify internet connectivity

### Phase 2: System Updates & Core Tools

#### 2.1 System Updates
```bash
- Update package lists
- Upgrade existing packages
- Install security updates
- Clean package cache
- Configure automatic security updates
```

#### 2.2 Essential Build Tools
```bash
- build-essential
- curl, wget, git
- software-properties-common
- apt-transport-https
- ca-certificates
- gnupg, lsb-release
- unzip, tar, gzip
```

### Phase 3: User & Group Management

#### 3.1 Create Application Users
- **www-data**: Already exists, verify and configure
- **app**: Application runtime user
  - Home directory: /home/app
  - Shell: /bin/bash (for debugging)
  - Add to necessary groups
- **deploy**: Deployment user
  - SSH key setup
  - Sudo privileges for specific commands

#### 3.2 Group Configuration
- **webapps**: General web application group
- **nodejs**: Node.js application group
- Configure proper permissions and umask

### Phase 4: Shell Environment Setup

#### 4.1 Zsh Installation
```bash
- Install zsh package
- Set as default shell for relevant users
- Configure .zshrc template
```

#### 4.2 Oh My Zsh Installation
```bash
- Clone Oh My Zsh repository
- Install for each user (app, deploy, root)
- Configure plugins:
  - git
  - npm
  - nvm
  - python
  - docker (if needed)
  - kubectl (if needed)
- Set theme (recommend: robbyrussell or agnoster)
- Configure aliases
```

### Phase 5: Development Tools Installation

#### 5.1 Node.js Environment
```bash
1. Install NVM (Node Version Manager)
   - Latest stable version
   - Configure for all users
   - Set up nvm lazy loading for performance

2. Install Node.js via NVM
   - Latest LTS version
   - Set as default
   - Install global npm packages:
     - npm-check-updates
     - pm2 (process manager)
     - yarn (alternative package manager)

3. Configure npm
   - Set registry
   - Configure cache location
   - Set up npm audit
```

#### 5.2 Python Environment
```bash
1. Install Python 3.x
   - Use deadsnakes PPA for latest version
   - Install python3-pip, python3-venv
   - Install python3-dev headers

2. Configure pip
   - Upgrade pip to latest
   - Install pipenv or poetry
   - Configure pip cache

3. Install common packages
   - virtualenv
   - requests
   - gunicorn/uwsgi
```

### Phase 6: Web Server Setup

#### 6.1 Nginx Installation
```bash
1. Install Nginx
   - From official Nginx repository
   - Latest stable version

2. Configure Nginx
   - Optimize worker processes
   - Configure gzip compression
   - Set up log rotation
   - Create sites-available/sites-enabled structure
   - Configure default server block
   - Set up SSL/TLS best practices template

3. Security hardening
   - Hide version number
   - Configure rate limiting
   - Set up fail2ban integration
   - Configure ModSecurity (optional)
```

#### 6.2 Nginx User Configuration
- Run as www-data user
- Configure proper file permissions
- Set up log directory permissions

### Phase 7: Security & Monitoring

#### 7.1 Firewall Configuration
```bash
- Install and configure ufw
- Allow SSH (rate limited)
- Allow HTTP/HTTPS
- Default deny incoming
- Enable logging
```

#### 7.2 Security Tools
```bash
- fail2ban (SSH and Nginx protection)
- unattended-upgrades
- needrestart
- lynis (security auditing)
```

#### 7.3 Monitoring Setup
```bash
- htop, iotop, iftop
- ncdu (disk usage)
- nginx amplify agent (optional)
- Custom health check scripts
```

### Phase 8: Additional Best Practices

#### 8.1 System Optimization
```bash
- Configure swappiness
- Set up tmpfs for /tmp
- Configure systemd service limits
- Optimize kernel parameters (sysctl)
```

#### 8.2 Backup Preparation
```bash
- Create backup directories
- Install backup tools (rsync, rclone)
- Create backup script templates
```

#### 8.3 Development Utilities
```bash
- jq (JSON processor)
- httpie (HTTP client)
- tree (directory listing)
- ncurses-term
- bash-completion
```

### Phase 9: Validation & Testing

#### 9.1 Service Validation
- Check all services are running
- Verify port bindings
- Test basic functionality
- Check log files for errors

#### 9.2 User Validation
- Verify user creation
- Test shell access
- Confirm permissions

#### 9.3 Network Validation
- Test nginx configuration
- Verify firewall rules
- Check DNS resolution

### Phase 10: Cleanup & Documentation

#### 10.1 Cleanup Tasks
- Remove unnecessary packages
- Clean package cache
- Remove temporary files
- Optimize package database

#### 10.2 Generate Documentation
- Create system inventory
- Document installed versions
- Generate configuration summary
- Create maintenance checklist

## Error Handling Strategy

### Rollback Mechanism
1. Create restore points before major changes
2. Backup critical configurations
3. Implement undo functions for each major step
4. Provide manual rollback instructions

### Error Categories
1. **Critical**: Cannot continue (exit 1)
2. **Warning**: Can continue but may have issues
3. **Info**: Informational messages

## Script Features

### Command Line Options
```bash
--verbose       Enable verbose output
--dry-run       Show what would be done
--skip-updates  Skip system updates
--user NAME     Specify primary user
--nginx-only    Install only Nginx
--dev-only      Install only development tools
--help          Show help message
```

### Environment Variables
```bash
SETUP_LOG_LEVEL     Set logging level
SETUP_NO_COLOR      Disable colored output
SETUP_ASSUME_YES    Auto-confirm prompts
```

## Testing Plan

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test complete workflow
3. **Compatibility Tests**: Test on different Ubuntu versions
4. **Idempotency Tests**: Run script multiple times
5. **Failure Tests**: Test error handling

## Maintenance Considerations

1. **Version Management**: Pin versions where appropriate
2. **Update Mechanism**: Built-in update checker
3. **Deprecation Handling**: Graceful handling of deprecated features
4. **Documentation Updates**: Keep inline docs current

## Security Considerations

1. **No Hardcoded Secrets**: Use environment variables
2. **Secure Downloads**: Verify checksums/signatures
3. **Minimal Privileges**: Run as unprivileged user where possible
4. **Audit Trail**: Log all actions
5. **Input Validation**: Sanitize all user input

## Performance Optimization

1. **Parallel Installation**: Where safe, parallelize tasks
2. **Caching**: Cache downloaded files
3. **Minimal Network Calls**: Batch operations
4. **Progress Indicators**: Show clear progress

## Post-Installation

### Success Report
- Summary of installed components
- Service status
- Next steps guide
- Quick reference commands

### Maintenance Scripts
- Update checker script
- Health check script
- Backup script template
- Log rotation verification

## Example Usage

```bash
# Basic installation
./setup.sh

# Verbose with specific user
./setup.sh --verbose --user john

# Dry run to see what would happen
./setup.sh --dry-run

# Install only development tools
./setup.sh --dev-only
```

## Notes

- Script should be compatible with Ubuntu 20.04 LTS and newer
- Consider using Ansible or similar for production environments
- Regular updates to component versions will be necessary
- Consider creating a companion update script