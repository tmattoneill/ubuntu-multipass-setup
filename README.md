# Ubuntu Multipass Setup

A comprehensive, production-ready Ubuntu server setup script designed for automating server configuration with development tools, web servers, and security hardening. Features interactive configuration, modular architecture, and robust error handling.

## 🚀 Quick Start

### One-Command Setup (Recommended)
```bash
# Clone repository
git clone https://github.com/tmattoneill/ubuntu-multipass-setup.git
cd ubuntu-multipass-setup

# Create instance and deploy setup in one command
make all NAME=my-server
```

### Manual Setup
```bash
# Create multipass instance
multipass launch --name my-server --cpus 2 --memory 4G --disk 20G

# Deploy setup
multipass transfer . my-server:ubuntu-multipass-setup/
multipass shell my-server
cd ubuntu-multipass-setup
sudo ./setup.sh
```

## ✨ Key Features

### 🎯 **Interactive Configuration**
- **Primary User Selection**: Choose your main user (ubuntu, app, myproj, etc.)
- **Git Configuration**: Name, email, and SSH key setup
- **Server Settings**: Hostname and timezone configuration
- **Configuration Summary**: Review all settings before installation

### 🏗️ **Modular Architecture**
- **10 Specialized Modules**: Each module handles specific functionality
- **Independent Operation**: Modules can fail without stopping the entire setup
- **Continue on Failure**: Option to proceed when individual modules fail
- **Comprehensive Logging**: Detailed logs with multiple output levels

### 🔒 **Security Hardening**
- **UFW Firewall**: Configured with sensible defaults
- **Fail2ban**: Protection against brute force attacks
- **SSH Hardening**: Secure SSH configuration without lockouts
- **SSL/TLS**: Automated Let's Encrypt certificates with Certbot
- **Security Headers**: Comprehensive Nginx security configuration

### 💻 **Development Environment**
- **Node.js via NVM**: Latest LTS with global package management
- **Python 3.11**: Virtual environments and development tools
- **Zsh + Oh My Zsh**: Feature-rich shell with plugins and themes
- **Git Configuration**: Personalized Git setup with SSH keys
- **Development Tools**: Essential packages and utilities

### 🌐 **Web Server Stack**
- **Nginx**: High-performance web server with optimization
- **SSL Certificates**: Automated certificate management
- **Security Configuration**: Headers, rate limiting, and hardening
- **Performance Tuning**: Optimized for production workloads

### 📊 **Monitoring & Validation**
- **System Health Monitoring**: Automated health checks and alerts
- **Performance Monitoring**: Resource usage tracking
- **Comprehensive Validation**: Post-installation testing and verification
- **Maintenance Tools**: Automated maintenance scripts

## 🛠️ Installation Modes

| Mode | Description | Modules Included |
|------|-------------|------------------|
| **full** (default) | Complete server setup | All 10 modules |
| **nginx-only** | Web server focused | Prerequisites, Users, Nginx, Security, Validation |
| **dev-only** | Development environment | Prerequisites, Users, Shell, Node.js, Python, Validation |
| **minimal** | Basic system setup | Prerequisites, Users, Validation |

```bash
# Specify installation mode
sudo ./setup.sh --mode nginx-only
sudo ./setup.sh --mode dev-only
sudo ./setup.sh --mode minimal
```

## 📋 Module Overview

| Module | Name | Description |
|--------|------|-------------|
| **01** | Prerequisites | System updates, essential tools, repositories |
| **02** | Users | User creation, SSH keys, group management |
| **03** | Shell | Zsh, Oh My Zsh, shell configuration |
| **04** | Node.js | NVM, Node.js LTS, npm, global packages |
| **05** | Python | Python 3.11, pip, virtual environments |
| **06** | Nginx | Web server, SSL, security headers |
| **07** | Security | UFW, fail2ban, SSH hardening |
| **08** | Monitoring | System monitoring, health checks |
| **09** | Optimization | Performance tuning, system optimization |
| **10** | Validation | Testing, verification, final report |

## 🎮 Makefile Commands

| Command | Description | Example |
|---------|-------------|---------|
| `make help` | Show all available commands | `make help` |
| `make create NAME=x` | Create multipass instance | `make create NAME=test-server` |
| `make deploy NAME=x` | Deploy setup to instance | `make deploy NAME=test-server` |
| `make all NAME=x` | Create + deploy in one command | `make all NAME=test-server` |
| `make clean NAME=x` | Delete multipass instance | `make clean NAME=test-server` |
| `make lint` | Check scripts with shellcheck | `make lint` |
| `make test` | Run tests (if available) | `make test` |

## 🔧 Configuration

### Interactive Setup
The script guides you through configuration:

```
=== Primary User Configuration ===
Enter primary username (default: ubuntu): myapp

=== Git Configuration ===
Enter your full name for Git commits: John Doe
Enter your email for Git commits: john@example.com

=== SSH Key Setup ===
[Automatically detects and configures SSH keys]

=== Server Configuration ===
Enter a hostname for this server (default: ubuntu): my-server
Enter timezone (default: UTC): America/New_York
```

### Advanced Configuration
Edit `config.sh` for advanced customization:
- Software versions and repositories
- User accounts and permissions  
- Security policies and firewall rules
- Performance and monitoring settings
- Package selections and configurations

## 🚨 Important Notes

### Shell Configuration Changes
After setup completion, **exit and reconnect** to activate all changes:

```bash
# Exit current session
exit

# Reconnect to activate Zsh + Node.js environment
multipass shell my-server
```

### Post-Installation
- **Zsh with Oh My Zsh**: Feature-rich shell environment
- **Node.js + npm**: Available via NVM (latest LTS)
- **Python virtual environments**: Ready for development
- **SSL certificates**: Managed via `/usr/local/bin/manage-ssl.sh`
- **System monitoring**: Automated health checks and logging

## 🔍 Troubleshooting

### Common Issues

**Node.js/npm not found:**
```bash
# Source NVM configuration
source ~/.zshrc
# Or explicitly use NVM
nvm use node
```

**SSL certificate issues:**
```bash
# Use SSL management script
sudo /usr/local/bin/manage-ssl.sh obtain yourdomain.com
sudo /usr/local/bin/manage-ssl.sh status
```

**Check logs:**
```bash
# View setup logs
sudo tail -f /var/log/setup/setup-*.log

# Check specific service
sudo systemctl status nginx
sudo systemctl status fail2ban
```

### Validation
The setup includes comprehensive validation testing:
- System configuration verification
- Service status checks  
- Development environment testing
- Security configuration validation
- SSL certificate verification

## 🏗️ Architecture

### Project Structure
```
ubuntu-multipass-setup/
├── setup.sh              # Main orchestrator script
├── config.sh             # Centralized configuration
├── Makefile              # Automation commands
│
├── lib/                  # Shared library functions
│   ├── logging.sh        # Logging framework
│   ├── utils.sh          # Utility functions
│   ├── validation.sh     # System validation
│   └── security.sh       # Security utilities
│
├── modules/              # Installation modules (01-10)
│   ├── 01-prerequisites.sh
│   ├── 02-users.sh
│   ├── 03-shell.sh
│   ├── 04-nodejs.sh
│   ├── 05-python.sh
│   ├── 06-nginx.sh
│   ├── 07-security.sh
│   ├── 08-monitoring.sh
│   ├── 09-optimization.sh
│   └── 10-validation.sh
│
└── cloud-init/           # Cloud-init configurations
    └── basic.yaml
```

### Design Principles
- **Modularity**: Independent, reusable components
- **Error Handling**: Graceful failure and recovery
- **Security First**: Secure defaults and hardening
- **User Experience**: Interactive and informative
- **Production Ready**: Tested and reliable configurations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make lint` to check code quality
5. Test with `make all NAME=test-instance`
6. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ using modular shell scripting
- Designed for Ubuntu 20.04+ compatibility
- Optimized for Multipass development environments
- Production-tested server configurations

---

**Ready to deploy?** `make all NAME=your-server` 🚀