# Multipass Setup Script Deployment Guide

## Best Deployment Methods (Ranked)

### 1. **Cloud-Init (BEST OPTION)** ✨
This is the most elegant solution - your setup runs automatically during instance creation.

#### Method A: Inline Cloud-Init
```bash
# Create instance with inline cloud-init
multipass launch --name myapp --cloud-init - <<EOF
#cloud-config
runcmd:
  - curl -sSL https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh | bash
  # OR download and execute
  - wget https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh -O /tmp/setup.sh
  - chmod +x /tmp/setup.sh
  - /tmp/setup.sh --verbose
EOF
```

#### Method B: Cloud-Init File
```yaml
# cloud-init.yaml
#cloud-config
package_update: true
package_upgrade: true

# Download and run setup script
runcmd:
  - |
    wget https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh -O /tmp/setup.sh
    chmod +x /tmp/setup.sh
    /tmp/setup.sh --verbose 2>&1 | tee /var/log/setup-script.log

# Or if you want to embed the entire script
write_files:
  - path: /root/setup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Your entire setup script here
      
runcmd:
  - /root/setup.sh
```

Launch with:
```bash
multipass launch --name myapp --cloud-init cloud-init.yaml
```

### 2. **GitHub + One-Liner** 🚀
Simple and version-controlled.

```bash
# Create instance
multipass launch --name myapp ubuntu

# Execute setup in one line
multipass exec myapp -- bash -c "curl -sSL https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh | bash"

# Or with wget
multipass exec myapp -- bash -c "wget -qO- https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh | bash"
```

### 3. **Transfer + Execute** 📦
Good for local development/testing.

```bash
# Create instance
multipass launch --name myapp ubuntu

# Transfer script
multipass transfer setup.sh myapp:/home/ubuntu/

# Execute
multipass exec myapp -- bash /home/ubuntu/setup.sh
```

### 4. **Custom Multipass Image** 🏗️
For frequently used configurations.

```bash
# Create and configure a base instance
multipass launch --name base-image ubuntu
multipass transfer setup.sh base-image:/home/ubuntu/
multipass exec base-image -- bash /home/ubuntu/setup.sh

# Create a snapshot (Multipass doesn't directly support this, but you can:)
# - Use the instance as a template
# - Document the exact steps
# - Create a custom cloud-init that recreates the state
```

### 5. **Ansible + Multipass** 🔧
For complex deployments.

```yaml
# inventory.yml
all:
  hosts:
    myapp:
      ansible_host: "{{ multipass_ip }}"
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

```bash
# Get IP
IP=$(multipass info myapp | grep IPv4 | awk '{print $2}')

# Run playbook
ansible-playbook -i inventory.yml setup-playbook.yml
```

## Recommended Approach: Hybrid Solution

### 1. Create a Bootstrap Script
```bash
#!/bin/bash
# bootstrap.sh - Minimal script to fetch and run main setup

set -euo pipefail

# Configuration
REPO_URL="https://github.com/yourusername/ubuntu-setup"
BRANCH="main"
SETUP_ARGS="--verbose"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Starting Ubuntu Setup Bootstrap...${NC}"

# Install prerequisites
sudo apt-get update
sudo apt-get install -y curl git

# Clone or download setup script
if command -v git &> /dev/null; then
    echo "Cloning setup repository..."
    git clone -b "$BRANCH" "$REPO_URL" /tmp/ubuntu-setup
    cd /tmp/ubuntu-setup
    chmod +x setup.sh
    ./setup.sh $SETUP_ARGS
else
    echo "Downloading setup script..."
    curl -sSL "$REPO_URL/raw/$BRANCH/setup.sh" -o /tmp/setup.sh
    chmod +x /tmp/setup.sh
    /tmp/setup.sh $SETUP_ARGS
fi
```

### 2. Create Helper Functions
```bash
# ~/.bashrc or ~/.zshrc

# Quick Multipass Ubuntu setup
mp-ubuntu-dev() {
    local name="${1:-ubuntu-dev}"
    local cpus="${2:-2}"
    local memory="${3:-4G}"
    local disk="${4:-20G}"
    
    echo "Creating Multipass instance: $name"
    
    # Create cloud-init file
    cat > /tmp/mp-cloud-init.yaml <<EOF
#cloud-config
runcmd:
  - curl -sSL https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/bootstrap.sh | bash
EOF
    
    # Launch instance
    multipass launch \
        --name "$name" \
        --cpus "$cpus" \
        --memory "$memory" \
        --disk "$disk" \
        --cloud-init /tmp/mp-cloud-init.yaml \
        ubuntu
    
    # Clean up
    rm /tmp/mp-cloud-init.yaml
    
    echo "Instance $name created and configured!"
    echo "Connect with: multipass shell $name"
}

# Usage: mp-ubuntu-dev myapp 4 8G 50G
```

### 3. Create a Makefile
```makefile
# Makefile for Multipass Ubuntu Setup

.PHONY: create setup destroy shell info

INSTANCE_NAME ?= ubuntu-dev
CPUS ?= 2
MEMORY ?= 4G
DISK ?= 20G
UBUNTU_VERSION ?= 22.04

create:
	@echo "Creating Multipass instance $(INSTANCE_NAME)..."
	@multipass launch --name $(INSTANCE_NAME) \
		--cpus $(CPUS) \
		--memory $(MEMORY) \
		--disk $(DISK) \
		ubuntu:$(UBUNTU_VERSION)

setup: create
	@echo "Running setup script on $(INSTANCE_NAME)..."
	@multipass exec $(INSTANCE_NAME) -- \
		bash -c "curl -sSL https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh | bash"

destroy:
	@echo "Destroying instance $(INSTANCE_NAME)..."
	@multipass delete $(INSTANCE_NAME)
	@multipass purge

shell:
	@multipass shell $(INSTANCE_NAME)

info:
	@multipass info $(INSTANCE_NAME)

# Combined command
deploy: create setup
	@echo "Deployment complete!"
	@multipass info $(INSTANCE_NAME) | grep IPv4
```

Usage:
```bash
# Default instance
make deploy

# Custom instance
make deploy INSTANCE_NAME=myapp CPUS=4 MEMORY=8G
```

## Best Practices for Script Deployment

### 1. **Version Control**
```bash
# Tag stable versions
git tag -a v1.0.0 -m "Initial stable release"
git push origin v1.0.0

# Use specific versions in production
curl -sSL https://raw.githubusercontent.com/user/repo/v1.0.0/setup.sh | bash
```

### 2. **Security Considerations**
```bash
# Verify script integrity
# Add to your setup script:
SCRIPT_SHA256="your-script-sha256-hash"

# In bootstrap:
wget https://example.com/setup.sh
echo "$SCRIPT_SHA256  setup.sh" | sha256sum -c -
```

### 3. **Environment-Specific Configs**
```yaml
# cloud-init-dev.yaml
#cloud-config
runcmd:
  - curl -sSL https://.../setup.sh | bash -s -- --env=development

# cloud-init-prod.yaml  
#cloud-config
runcmd:
  - curl -sSL https://.../setup.sh | bash -s -- --env=production --secure
```

### 4. **Monitoring Setup Progress**
```bash
# Create instance with cloud-init
multipass launch --name myapp --cloud-init cloud-init.yaml

# Monitor setup progress
multipass exec myapp -- tail -f /var/log/cloud-init-output.log

# Or check status
multipass exec myapp -- cloud-init status --wait
```

## Complete Example Workflow

### 1. Repository Structure
```
ubuntu-setup/
├── setup.sh           # Main setup script
├── bootstrap.sh       # Lightweight bootstrap
├── cloud-init.yaml    # Cloud-init template
├── Makefile          # Automation commands
├── configs/
│   ├── nginx/        # Nginx configs
│   ├── systemd/      # Service files
│   └── dotfiles/     # User configurations
└── scripts/
    ├── health-check.sh
    └── update.sh
```

### 2. Quick Start Command
```bash
# One-liner to rule them all
curl -sSL https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/quick-start.sh | bash -s -- myapp

# quick-start.sh content:
#!/bin/bash
INSTANCE_NAME="${1:-ubuntu-dev}"

multipass launch --name "$INSTANCE_NAME" --cloud-init - <<EOF
#cloud-config
runcmd:
  - curl -sSL https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh | bash
final_message: "Setup complete! Connect with: multipass shell $INSTANCE_NAME"
EOF
```

## Recommendations

1. **For Development**: Use cloud-init with a GitHub-hosted script
2. **For Production**: Use tagged versions with checksum verification
3. **For Testing**: Use local transfer method for rapid iteration
4. **For Teams**: Create a Makefile or shell functions for consistency

The cloud-init approach is generally best because:
- ✅ Runs automatically during instance creation
- ✅ No manual intervention needed
- ✅ Logs available in `/var/log/cloud-init-output.log`
- ✅ Can be version controlled
- ✅ Works with automation tools