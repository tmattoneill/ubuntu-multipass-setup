# Ubuntu Server Setup Script

A comprehensive, modular setup script for configuring Ubuntu 20.04 LTS+ servers with development tools, web server, and security hardening.

## Features

- **Modular Architecture**: 10 specialized modules for different aspects of server setup
- **Multiple Installation Modes**: Full, nginx-only, dev-only, and minimal configurations
- **Security First**: Comprehensive security hardening and monitoring
- **Performance Optimized**: System tuning and optimization
- **Extensive Logging**: Detailed logging with multiple levels
- **Error Handling**: Rollback capabilities and comprehensive error handling
- **Validation Framework**: Pre and post-installation validation
- **Maintenance Tools**: Built-in monitoring and maintenance scripts

## Quick Start

```bash
# Clone or download the setup script
wget https://your-repo.com/setup.sh
# or git clone https://your-repo.com/ubuntu-setup.git

# Make executable
chmod +x setup.sh

# Run with default settings (full installation)
sudo ./setup.sh

# Run with specific options
sudo ./setup.sh --verbose --user myapp --mode nginx-only
```

## Installation Modes

### Full Installation (default)
```bash
sudo ./setup.sh
```
Includes: System updates, users, shell, Node.js, Python, Nginx, security, monitoring, optimization

### Nginx-Only Mode
```bash
sudo ./setup.sh --mode nginx-only
```
Includes: System updates, users, Nginx, security, validation

### Development-Only Mode
```bash
sudo ./setup.sh --mode dev-only
```
Includes: System updates, users, shell, Node.js, Python, validation

### Minimal Mode
```bash
sudo ./setup.sh --mode minimal
```
Includes: System updates, users, validation only

## Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-v, --verbose` | Enable verbose output | `--verbose` |
| `-n, --dry-run` | Show what would be done without executing | `--dry-run` |
| `-s, --skip-updates` | Skip system package updates | `--skip-updates` |
| `-u, --user USER` | Specify primary application user | `--user webapp` |
| `-m, --mode MODE` | Installation mode (full, nginx-only, dev-only, minimal) | `--mode nginx-only` |
| `-y, --yes` | Assume yes for all prompts (non-interactive) | `--yes` |
| `-h, --help` | Show help message | `--help` |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SETUP_LOG_LEVEL` | Set logging level (DEBUG, INFO, WARN, ERROR) | INFO |
| `SETUP_NO_COLOR` | Disable colored output | - |
| `SETUP_ASSUME_YES` | Auto-confirm prompts | - |

## Architecture

### Main Components

```
setup.sh                    # Main orchestrator script
config.sh                   # Configuration variables
lib/                        # Utility libraries
├── logging.sh              # Logging framework
├── utils.sh                # Common utilities
├── validation.sh           # System validation
└── security.sh             # Security utilities
modules/                    # Installation modules
├── 01-prerequisites.sh     # System updates & essential tools
├── 02-users.sh             # User & group management
├── 03-shell.sh             # Zsh & Oh My Zsh setup
├── 04-nodejs.sh            # Node.js/NVM installation
├── 05-python.sh            # Python environment
├── 06-nginx.sh             # Nginx installation & config
├── 07-security.sh          # Firewall, fail2ban, hardening
├── 08-monitoring.sh        # System monitoring tools
├── 09-optimization.sh      # Performance optimization
└── 10-validation.sh        # Final validation & cleanup
```

### Module Details

#### 01-prerequisites.sh
- System package updates
- Essential build tools
- Development packages
- Package manager configuration

#### 02-users.sh
- Application user creation (`app`, `deploy`)
- Group management (`webapps`, `nodejs`)
- User environment configuration
- SSH key setup
- Sudo access configuration

#### 03-shell.sh
- Zsh installation
- Oh My Zsh setup
- Custom themes and plugins
- Shell environment optimization

#### 04-nodejs.sh
- NVM (Node Version Manager) installation
- Node.js latest LTS
- Global npm packages (PM2, yarn, etc.)
- npm configuration optimization

#### 05-python.sh
- Python 3.x installation via deadsnakes PPA
- pip and virtual environment setup
- Global Python packages
- Development environment configuration

#### 06-nginx.sh
- Nginx installation from official repository
- Security-hardened configuration
- SSL/TLS optimization
- Performance tuning
- Custom error pages

#### 07-security.sh
- UFW firewall configuration
- Fail2ban intrusion prevention
- SSH hardening
- Automatic security updates
- Kernel parameter hardening
- Security scanning tools

#### 08-monitoring.sh
- System monitoring tools (htop, iotop, etc.)
- Log monitoring and analysis
- Health check scripts
- Performance monitoring
- Alert system

#### 09-optimization.sh
- Kernel parameter optimization
- I/O scheduler optimization
- Network performance tuning
- systemd limits configuration
- CPU governor settings

#### 10-validation.sh
- Comprehensive system validation
- Service functionality testing
- Security configuration verification
- Performance settings validation
- Report generation
- Maintenance tool creation

## Security Features

### Firewall Configuration
- UFW with restrictive default policies
- SSH rate limiting
- HTTP/HTTPS access
- Custom rule support

### SSH Hardening
- Root login disabled
- Password authentication disabled
- Key-based authentication only
- Connection limits and timeouts

### Intrusion Prevention
- Fail2ban with custom filters
- Multiple jail configurations
- Automatic IP banning
- Log monitoring

### System Hardening
- Kernel parameter security
- File permission hardening
- Service minimization
- Automatic security updates

## Performance Optimizations

### System Tuning
- Optimized swappiness settings
- Network buffer optimization
- I/O scheduler optimization
- CPU governor configuration

### Web Server Optimization
- Worker process optimization
- Connection handling tuning
- Gzip compression
- Static file caching

### Development Environment
- Optimized Node.js settings
- Python environment optimization
- Shell performance improvements

## Monitoring and Maintenance

### Built-in Monitoring
- System health checks (every 15 minutes)
- Resource monitoring (every 30 minutes)
- Service monitoring (every 10 minutes)
- Disk space monitoring (every hour)

### Log Management
- Centralized logging configuration
- Log rotation setup
- Log analysis tools
- Alert system integration

### Maintenance Tools
- System status script: `/usr/local/bin/system-status.sh`
- Performance report: `/usr/local/bin/performance-report.sh`
- Health check API: `/usr/local/bin/health-check-api.sh`
- Setup verification: `/usr/local/bin/verify-setup.sh`

## Configuration

### Default Settings
- **Primary User**: `app`
- **Deploy User**: `deploy`
- **Node.js Version**: LTS
- **Python Version**: 3.11
- **Web Root**: `/var/www`
- **Log Directory**: `/var/log/setup`

### Customization
Modify `config.sh` to customize:
- Software versions
- Directory paths
- User configurations
- Security settings
- Performance parameters

## File Structure After Installation

```
/var/www/                   # Web server document root
├── html/                   # Default web content
├── default/                # Default site content
└── errors/                 # Custom error pages

/home/app/                  # Application user home
├── .ssh/                   # SSH configuration
├── python-projects/        # Python development directory
└── test-app/              # Node.js test application

/home/deploy/               # Deployment user home
├── .ssh/                  # SSH configuration
└── scripts/               # Deployment scripts

/var/log/setup/            # Setup and monitoring logs
├── setup-YYYYMMDD-HHMMSS.log     # Installation log
├── system-summary-latest.txt      # System summary
├── security-report-latest.txt     # Security report
└── performance-report-latest.txt  # Performance report

/usr/local/bin/            # Custom scripts
├── system-status.sh       # System status check
├── performance-report.sh  # Performance report
├── health-check-api.sh    # Health check script
└── verify-setup.sh        # Setup verification
```

## Usage Examples

### Basic Installation
```bash
# Download and run
sudo ./setup.sh
```

### Custom User Installation
```bash
# Install with custom application user
sudo ./setup.sh --user myapp --verbose
```

### Development Server Setup
```bash
# Install only development tools
sudo ./setup.sh --mode dev-only --user developer
```

### Production Web Server
```bash
# Install web server with security hardening
sudo ./setup.sh --mode nginx-only --yes
```

### Preview Changes
```bash
# See what would be installed without making changes
sudo ./setup.sh --dry-run --verbose
```

## Post-Installation

### Verification
```bash
# Verify installation
sudo /usr/local/bin/verify-setup.sh

# Check system status
sudo /usr/local/bin/system-status.sh

# Generate performance report
sudo /usr/local/bin/performance-report.sh
```

### Next Steps
1. **Configure Domain**: Point your domain to the server
2. **SSL Certificates**: Install SSL certificates (Let's Encrypt recommended)
3. **Deploy Applications**: Upload your applications to `/var/www/html`
4. **Backup Setup**: Configure regular backups
5. **Monitoring**: Set up external monitoring

### Application Deployment

#### Node.js Application
```bash
# Switch to app user
sudo su - app

# Navigate to application directory
cd /var/www/html

# Install dependencies
npm install

# Start with PM2
pm2 start app.js --name myapp
pm2 save
```

#### Python Application
```bash
# Switch to app user
sudo su - app

# Create virtual environment
python3 -m venv ~/.virtualenvs/myapp

# Activate virtual environment
source ~/.virtualenvs/myapp/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start application
gunicorn --bind 0.0.0.0:8000 app:app
```

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
systemctl status nginx

# Check logs
journalctl -u nginx -n 50

# Test configuration
nginx -t
```

#### High Resource Usage
```bash
# Check system resources
htop

# Check disk usage
df -h
du -sh /*

# Check running processes
ps aux --sort=-%cpu
```

#### Web Server Not Accessible
```bash
# Check if nginx is running
systemctl status nginx

# Test locally
curl http://localhost/

# Check firewall
ufw status

# Check logs
tail -f /var/log/nginx/error.log
```

### Log Locations
- **Setup Logs**: `/var/log/setup/`
- **System Logs**: `/var/log/syslog`
- **Web Server**: `/var/log/nginx/`
- **Security**: `/var/log/auth.log`
- **Application**: `/var/log/webapps/`

### Getting Help
1. Check the troubleshooting guide: `/var/log/setup/troubleshooting-guide.txt`
2. Review setup logs: `/var/log/setup/setup-latest.log`
3. Run verification script: `/usr/local/bin/verify-setup.sh`
4. Check system status: `/usr/local/bin/system-status.sh`

## Requirements

### System Requirements
- **Operating System**: Ubuntu 20.04 LTS or newer
- **Architecture**: x86_64 or arm64
- **Memory**: Minimum 1GB RAM (2GB+ recommended)
- **Disk Space**: Minimum 10GB available
- **Network**: Internet connection for package downloads

### Permissions
- Must be run as root (use `sudo`)
- Requires write access to system directories
- Needs internet access for package downloads

## Safety Features

### Rollback Capabilities
- Automatic backup of configuration files
- Restore points before major changes
- Manual rollback procedures
- Configuration validation

### Error Handling
- Comprehensive error checking
- Graceful failure handling
- Detailed error logging
- Recovery procedures

### Validation
- Pre-installation system checks
- Post-installation validation
- Service functionality testing
- Configuration verification

## Contributing

### Development
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Testing
- Test on clean Ubuntu installations
- Verify all installation modes
- Test rollback procedures
- Validate security configurations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Documentation**: This README and inline comments
- **Troubleshooting**: `/var/log/setup/troubleshooting-guide.txt`
- **Issues**: Report issues via GitHub issues
- **Security**: Report security issues privately

## Version History

### v1.0.0
- Initial release
- Complete modular architecture
- All installation modes
- Comprehensive security hardening
- Performance optimization
- Monitoring and maintenance tools

---

**Note**: This setup script makes significant changes to your system. Always test on non-production systems first and ensure you have proper backups.