# Ubuntu Server Setup - Usage Guide

## Quick Start Examples

### 1. Full Server Setup (Recommended)
```bash
# Complete setup with all components
sudo ./setup.sh

# With verbose output and custom user
sudo ./setup.sh --verbose --user webapp
```

### 2. Web Server Only
```bash
# Just nginx, security, and essential tools
sudo ./setup.sh --mode nginx-only --yes
```

### 3. Development Environment
```bash
# Node.js, Python, shell customization
sudo ./setup.sh --mode dev-only --user developer
```

### 4. Preview Mode
```bash
# See what will be installed without making changes
sudo ./setup.sh --dry-run --verbose
```

## Installation Process

The script will:
1. **Validate** system requirements
2. **Update** packages and install essentials
3. **Create** users and configure environments
4. **Install** selected components (Node.js, Python, Nginx)
5. **Harden** security (firewall, fail2ban, SSH)
6. **Optimize** performance settings
7. **Setup** monitoring and maintenance tools
8. **Validate** installation and generate reports

## After Installation

### Check Installation Status
```bash
# Verify everything is working
sudo /usr/local/bin/verify-setup.sh

# Check system status
sudo /usr/local/bin/system-status.sh

# View system summary
cat /var/log/setup/system-summary-latest.txt
```

### Deploy Your First Application

#### Node.js App
```bash
# Switch to app user
sudo su - app

# Create your app
cd /var/www/html
npm init -y
npm install express

# Create simple app
cat > app.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.json({ message: 'Hello from your Ubuntu server!' });
});

app.listen(port, () => {
  console.log(`App running at http://localhost:${port}`);
});
EOF

# Start with PM2
pm2 start app.js --name myapp
pm2 save
```

#### Python App
```bash
# Switch to app user
sudo su - app

# Create virtual environment
python3 -m venv ~/.virtualenvs/myapp
source ~/.virtualenvs/myapp/bin/activate

# Install Flask
pip install flask gunicorn

# Create simple app
cat > /var/www/html/app.py << 'EOF'
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({'message': 'Hello from your Ubuntu server!'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
EOF

# Start with Gunicorn
gunicorn --bind 0.0.0.0:8000 app:app --daemon
```

### Configure Nginx (if installed)
```bash
# Create site configuration
sudo nano /etc/nginx/sites-available/myapp

# Example configuration:
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3000;  # for Node.js
        # proxy_pass http://localhost:8000;  # for Python
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Enable site
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Maintenance Commands

### Daily Checks
```bash
# System health
sudo /usr/local/bin/system-health.sh

# Check services
sudo systemctl status nginx ssh fail2ban

# Check logs
sudo tail -f /var/log/syslog
```

### Weekly Maintenance
```bash
# Update packages
sudo apt update && sudo apt upgrade

# Clean up
sudo apt autoremove
sudo apt autoclean

# Check security
sudo fail2ban-client status
sudo ufw status verbose
```

### Monitoring
```bash
# Performance report
sudo /usr/local/bin/performance-report.sh

# Resource usage
htop
df -h
free -h

# Network connections
ss -tuln
```

## Troubleshooting

### Service Issues
```bash
# If nginx won't start
sudo systemctl status nginx
sudo nginx -t
sudo journalctl -u nginx

# If fail2ban has issues
sudo systemctl status fail2ban
sudo fail2ban-client status
```

### Performance Issues
```bash
# Check resource usage
htop
iotop
iftop

# Check disk space
df -h
du -sh /*
```

### Security Checks
```bash
# Review auth logs
sudo tail -f /var/log/auth.log

# Check firewall
sudo ufw status verbose

# Check for intrusions
sudo fail2ban-client status sshd
```

## Configuration Files

### Main Config Locations
- **Nginx**: `/etc/nginx/nginx.conf`
- **SSH**: `/etc/ssh/sshd_config`
- **Firewall**: `/etc/ufw/`
- **Fail2ban**: `/etc/fail2ban/jail.local`

### Application Directories
- **Web Root**: `/var/www/html/`
- **App User Home**: `/home/app/`
- **Deploy User Home**: `/home/deploy/`
- **Logs**: `/var/log/setup/`

## Need Help?

1. **Check logs**: `/var/log/setup/setup-latest.log`
2. **Read troubleshooting guide**: `/var/log/setup/troubleshooting-guide.txt`
3. **Run verification**: `sudo /usr/local/bin/verify-setup.sh`
4. **Check system status**: `sudo /usr/local/bin/system-status.sh`

Remember to always backup important data before making system changes!