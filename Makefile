# Enhanced Makefile with configuration profiles support

.PHONY: help test lint create deploy deploy-auto deploy-config clean all all-auto all-config profiles check-ssh setup-profile interactive-config quick-setup

# Load configuration (can be overridden with PROFILE=profilename)
PROFILE ?= default
CONFIG_LOADED := $(shell source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo "yes" || echo "no")

# Network interface for bridged networking (can be overridden)
NETWORK_INTERFACE ?= en0
ENABLE_NETWORK ?= false

# Set defaults if config loading failed
ifeq ($(CONFIG_LOADED),no)
MULTIPASS_CPUS ?= 2
MULTIPASS_MEMORY ?= 4G
MULTIPASS_DISK ?= 20G
SETUP_MODE ?= full
else
# Load config values
MULTIPASS_CPUS := $(shell source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_CPUS)
MULTIPASS_MEMORY := $(shell source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_MEMORY)
MULTIPASS_DISK := $(shell source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_DISK)
SETUP_MODE := $(shell source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$SETUP_MODE)
endif

help:
	@echo "Ubuntu Multipass Setup - Available Commands:"
	@echo ""
	@echo "Basic Commands:"
	@echo "  make create NAME=myapp            - Create instance (prompts for network setup)"
	@echo "  make deploy NAME=myapp            - Deploy with interactive config"
	@echo "  make deploy-auto NAME=myapp       - Deploy with automatic config"
	@echo "  make all NAME=myapp               - Create + deploy interactively"
	@echo "  make all-auto NAME=myapp          - Create + deploy automatically"
	@echo ""
	@echo "Profile-Based Commands:"
	@echo "  make create-config NAME=myapp PROFILE=dev     - Create with profile settings"
	@echo "  make deploy-config NAME=myapp PROFILE=dev     - Deploy with profile + auto-config"
	@echo "  make all-config NAME=myapp PROFILE=dev        - Create + deploy with profile"
	@echo "  make quick-setup NAME=myapp PROFILE=personal  - Prompt for settings then deploy"
	@echo ""
	@echo "Configuration:"
	@echo "  make profiles                     - Show available profiles"
	@echo "  make show-config PROFILE=dev     - Show profile configuration"
	@echo "  make check-ssh PROFILE=dev       - Validate SSH key for profile"
	@echo "  make setup-profile PROFILE=dev   - Interactively configure profile settings"
	@echo "  make interactive-config NAME=myapp PROFILE=dev - Update config then deploy"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make test                         - Run tests (if available)"
	@echo "  make lint                         - Check shell scripts with shellcheck"
	@echo "  make clean NAME=myapp             - Delete multipass instance"
	@echo ""
	@echo "Network Configuration:"
	@echo "  All create commands prompt for network setup during instance creation"
	@echo "  ⚠️  WARNING: Network settings are PERMANENT and cannot be changed after creation!"
	@echo ""
	@echo "Available Profiles: default, dev, production, personal, testing"
	@echo "Default resources: $(MULTIPASS_CPUS) CPUs, $(MULTIPASS_MEMORY) memory, $(MULTIPASS_DISK) disk"

profiles:
	@echo "Available Configuration Profiles:"
	@echo ""
	@echo "default    - Basic setup ($(MULTIPASS_CPUS) CPUs, $(MULTIPASS_MEMORY) memory, $(MULTIPASS_DISK) disk)"
	@if grep -q "^dev:" multipass-config.yaml 2>/dev/null; then \
		echo "dev        - Development profile (higher resources, dev-only mode)"; \
	fi
	@if grep -q "^production:" multipass-config.yaml 2>/dev/null; then \
		echo "production - Production profile (nginx-only, optimized)"; \
	fi
	@if grep -q "^personal:" multipass-config.yaml 2>/dev/null; then \
		echo "personal   - Personal preferences"; \
	fi
	@if grep -q "^testing:" multipass-config.yaml 2>/dev/null; then \
		echo "testing    - Minimal resources for testing"; \
	fi
	@echo ""
	@echo "Usage: make all-config NAME=myserver PROFILE=dev"
	@echo "Edit multipass-config.yaml to customize profiles"

show-config:
	@source scripts/load-config.sh $(PROFILE)
	@echo ""
	@echo "⚠️  SSH Key Validation:"
	@if source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && [[ -n "$$SETUP_SSH_PUBLIC_KEY" ]]; then \
		echo "✅ SSH key found and loaded"; \
	else \
		echo "❌ SSH key not found - you may not be able to access the instance!"; \
		echo "   Update the ssh_key_path in multipass-config.yaml or use interactive setup"; \
	fi

create:
	@if [ -z "$(NAME)" ]; then \
		echo "❌ ERROR: NAME parameter is required"; \
		echo "Usage: make create NAME=myapp"; \
		exit 1; \
	fi
	@echo "Creating multipass instance: $(NAME)"
	@echo "Resources: $(MULTIPASS_CPUS) CPUs, $(MULTIPASS_MEMORY) memory, $(MULTIPASS_DISK) disk"
	@read -p "Would you like to enable external SSH/Network access? (Cannot be changed later) [y/N]: " enable_network; \
	if [ "$$enable_network" = "y" ] || [ "$$enable_network" = "Y" ]; then \
		if ! command -v networksetup >/dev/null 2>&1; then \
			echo ""; \
			echo "❌ ERROR: networksetup command not found"; \
			echo "This feature requires macOS. For other platforms, please create instances without bridged networking."; \
			exit 1; \
		fi; \
		echo ""; \
		echo "⚠️  Network support is ONLY available on wired (ethernet) connections."; \
		echo ""; \
		echo "Available ethernet interfaces:"; \
		echo "Name"; \
		echo "----"; \
		networksetup -listallhardwareports 2>/dev/null | \
		grep -A2 "Hardware Port:" | \
		grep -E "Hardware Port:|Device:" | \
		sed 'N;s/Hardware Port: \(.*\)\nDevice: \(.*\)/\2 \1/' | \
		while read device desc; do \
			if [ -n "$$device" ]; then \
				case "$$desc" in \
					*Ethernet*) echo "$$device" ;; \
				esac; \
			fi; \
		done | head -10; \
		echo ""; \
		ethernet_found=$$(networksetup -listallhardwareports 2>/dev/null | \
		grep -A1 "Hardware Port.*Ethernet" | \
		grep "Device:" | \
		head -1 | \
		cut -d' ' -f2); \
		if [ -z "$$ethernet_found" ]; then \
			echo "❌ No ethernet interfaces found. Network bridging requires ethernet connection."; \
			echo "   Create instance without network bridging using: make create NAME=$(NAME)"; \
			exit 1; \
		fi; \
		default_interface="$$ethernet_found"; \
		selected_interface=""; \
		while [ -z "$$selected_interface" ]; do \
			read -p "Which ethernet interface would you like to use? (default: $$default_interface): " user_interface; \
			test_interface=$${user_interface:-$$default_interface}; \
			valid_interface=$$(networksetup -listallhardwareports 2>/dev/null | \
			grep -B1 "Device: $$test_interface" | \
			grep "Hardware Port.*Ethernet" >/dev/null && echo "valid"); \
			if [ "$$valid_interface" = "valid" ]; then \
				selected_interface="$$test_interface"; \
			else \
				echo "❌ Invalid ethernet interface: $$test_interface"; \
				echo "   Please choose from the ethernet interfaces listed above."; \
				echo ""; \
			fi; \
		done; \
		echo ""; \
		echo "✅ Selected ethernet interface: $$selected_interface"; \
		echo "Creating instance with bridged networking..."; \
		multipass launch --name $(NAME) \
			--cpus $(MULTIPASS_CPUS) \
			--memory $(MULTIPASS_MEMORY) \
			--disk $(MULTIPASS_DISK) \
			--network name=$$selected_interface,mode=auto; \
		echo "✅ Instance $(NAME) created successfully with bridged networking on $$selected_interface"; \
		echo "Getting network information..."; \
		sleep 3; \
		instance_ip=$$(multipass info $(NAME) 2>/dev/null | grep IPv4 | awk '{print $$2}' | head -1); \
		if [ -n "$$instance_ip" ]; then \
			echo "Access via ubuntu@$$instance_ip"; \
		else \
			echo "IP address will be available shortly - check with: multipass info $(NAME)"; \
		fi; \
	else \
		echo "Creating standard instance without external network access..."; \
		multipass launch --name $(NAME) \
			--cpus $(MULTIPASS_CPUS) \
			--memory $(MULTIPASS_MEMORY) \
			--disk $(MULTIPASS_DISK); \
		echo "✅ Instance $(NAME) created successfully (host-only access)"; \
	fi
	@echo ""
	@echo "Instance Information:"
	@echo "==================="
	@multipass info $(NAME)

create-config:
	@if [ -z "$(NAME)" ]; then \
		echo "❌ ERROR: NAME parameter is required"; \
		echo "Usage: make create-config NAME=myapp PROFILE=dev"; \
		exit 1; \
	fi
	@echo "Creating multipass instance: $(NAME) with profile: $(PROFILE)"
	@bash -c 'source scripts/load-config.sh $(PROFILE) >/dev/null && echo "Resources: $$MULTIPASS_CPUS CPUs, $$MULTIPASS_MEMORY memory, $$MULTIPASS_DISK disk"'
	@read -p "Would you like to enable external SSH/Network access? (Cannot be changed later) [y/N]: " enable_network; \
	if [ "$$enable_network" = "y" ] || [ "$$enable_network" = "Y" ]; then \
		if ! command -v networksetup >/dev/null 2>&1; then \
			echo ""; \
			echo "❌ ERROR: networksetup command not found"; \
			echo "This feature requires macOS. For other platforms, please create instances without bridged networking."; \
			exit 1; \
		fi; \
		echo ""; \
		echo "⚠️  Network support is ONLY available on wired (ethernet) connections."; \
		echo ""; \
		echo "Available ethernet interfaces:"; \
		echo "Name"; \
		echo "----"; \
		networksetup -listallhardwareports 2>/dev/null | \
		grep -A2 "Hardware Port:" | \
		grep -E "Hardware Port:|Device:" | \
		sed 'N;s/Hardware Port: \(.*\)\nDevice: \(.*\)/\2 \1/' | \
		while read device desc; do \
			if [ -n "$$device" ]; then \
				case "$$desc" in \
					*Ethernet*) echo "$$device" ;; \
				esac; \
			fi; \
		done | head -10; \
		echo ""; \
		ethernet_found=$$(networksetup -listallhardwareports 2>/dev/null | \
		grep -A1 "Hardware Port.*Ethernet" | \
		grep "Device:" | \
		head -1 | \
		cut -d' ' -f2); \
		if [ -z "$$ethernet_found" ]; then \
			echo "❌ No ethernet interfaces found. Network bridging requires ethernet connection."; \
			echo "   Create instance without network bridging by choosing 'N' when prompted."; \
			exit 1; \
		fi; \
		default_interface="$$ethernet_found"; \
		selected_interface=""; \
		while [ -z "$$selected_interface" ]; do \
			read -p "Which ethernet interface would you like to use? (default: $$default_interface): " user_interface; \
			test_interface=$${user_interface:-$$default_interface}; \
			valid_interface=$$(networksetup -listallhardwareports 2>/dev/null | \
			grep -B1 "Device: $$test_interface" | \
			grep "Hardware Port.*Ethernet" >/dev/null && echo "valid"); \
			if [ "$$valid_interface" = "valid" ]; then \
				selected_interface="$$test_interface"; \
			else \
				echo "❌ Invalid ethernet interface: $$test_interface"; \
				echo "   Please choose from the ethernet interfaces listed above."; \
				echo ""; \
			fi; \
		done; \
		echo ""; \
		echo "✅ Selected ethernet interface: $$selected_interface"; \
		echo "Creating instance with bridged networking..."; \
		multipass launch --name $(NAME) \
			--cpus $$(bash -c 'source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_CPUS') \
			--memory $$(bash -c 'source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_MEMORY') \
			--disk $$(bash -c 'source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_DISK') \
			--network name=$$selected_interface,mode=auto; \
		echo "✅ Instance $(NAME) created successfully with $(PROFILE) profile and bridged networking on $$selected_interface"; \
		echo "Getting network information..."; \
		sleep 3; \
		instance_ip=$$(multipass info $(NAME) 2>/dev/null | grep IPv4 | awk '{print $$2}' | head -1); \
		if [ -n "$$instance_ip" ]; then \
			echo "Access via ubuntu@$$instance_ip"; \
		else \
			echo "IP address will be available shortly - check with: multipass info $(NAME)"; \
		fi; \
	else \
		echo "Creating standard instance without external network access..."; \
		multipass launch --name $(NAME) \
			--cpus $$(bash -c 'source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_CPUS') \
			--memory $$(bash -c 'source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_MEMORY') \
			--disk $$(bash -c 'source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_DISK'); \
		echo "✅ Instance $(NAME) created successfully with $(PROFILE) profile (host-only access)"; \
	fi
	@echo ""
	@echo "Instance Information:"
	@echo "==================="
	@multipass info $(NAME)


deploy:
	@echo "Deploying ubuntu-multipass-setup to instance: $(NAME)"
	@multipass transfer --recursive . $(NAME):ubuntu-multipass-setup/
	@echo "Running interactive setup script on $(NAME)..."
	@multipass exec $(NAME) -- sudo /home/ubuntu/ubuntu-multipass-setup/setup.sh

deploy-auto:
	@echo "Deploying ubuntu-multipass-setup to instance: $(NAME) (non-interactive)"
	@multipass transfer --recursive . $(NAME):ubuntu-multipass-setup/
	@echo "Running automated setup script on $(NAME)..."
	@multipass exec $(NAME) -- sudo /home/ubuntu/ubuntu-multipass-setup/setup.sh --yes

deploy-config:
	@echo "Deploying ubuntu-multipass-setup to instance: $(NAME) with profile: $(PROFILE)"
	@echo "Checking SSH key availability..."
	@source scripts/load-config.sh $(PROFILE) >/dev/null
	@multipass transfer --recursive . $(NAME):ubuntu-multipass-setup/
	@echo "Running setup script with profile configuration..."
	@multipass exec $(NAME) -- bash -c ' \
		source /home/ubuntu/ubuntu-multipass-setup/scripts/load-config.sh $(PROFILE) >/dev/null 2>&1; \
		export PRIMARY_USER="$$SETUP_PRIMARY_USER"; \
		export GIT_USER_NAME="$$SETUP_GIT_NAME"; \
		export GIT_USER_EMAIL="$$SETUP_GIT_EMAIL"; \
		export USER_SSH_PUBLIC_KEY="$$SETUP_SSH_PUBLIC_KEY"; \
		export SERVER_HOSTNAME="$$SETUP_HOSTNAME"; \
		if [[ "$$SERVER_HOSTNAME" == "auto" ]]; then export SERVER_HOSTNAME="$(NAME)"; fi; \
		export SERVER_TIMEZONE="$$SETUP_TIMEZONE"; \
		sudo /home/ubuntu/ubuntu-multipass-setup/setup.sh --yes --mode "$$SETUP_MODE" \
	'

test:
	@if [ -d "tests" ]; then \
		bash tests/test-all.sh; \
	else \
		echo "No tests directory found. Skipping tests."; \
	fi

lint:
	@echo "Running shellcheck on all scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck setup.sh lib/*.sh modules/*.sh scripts/*.sh; \
		echo "Shellcheck completed successfully"; \
	else \
		echo "Warning: shellcheck not installed. Install with: brew install shellcheck"; \
	fi

check-ssh:
	@echo "SSH Key Validation for Profile: $(PROFILE)"
	@echo "==========================================="
	@source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1
	@if source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && [[ -n "$$SETUP_SSH_PUBLIC_KEY" ]]; then \
		echo "✅ SSH key found and loaded successfully"; \
		echo "   Key type: $$(source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_SSH_PUBLIC_KEY | cut -d' ' -f1)"; \
		echo "   Key comment: $$(source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_SSH_PUBLIC_KEY | cut -d' ' -f3)"; \
	else \
		echo "❌ SSH key not found!"; \
		echo "   Path checked: $$(source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_SSH_KEY_PATH)"; \
		echo "   ⚠️  WARNING: You may not be able to access the instance without SSH keys!"; \
		echo ""; \
		echo "Solutions:"; \
		echo "1. Generate SSH key: ssh-keygen -t ed25519 -C 'your@email.com'"; \
		echo "2. Update ssh_key_path in multipass-config.yaml"; \
		echo "3. Use interactive setup: make deploy NAME=instance-name"; \
	fi

setup-profile:
	@echo "Setting up profile: $(PROFILE)"
	@echo "=============================="
	@scripts/update-config.sh $(PROFILE)

interactive-config: setup-profile all-config
	@echo "Interactive setup completed for $(NAME) with $(PROFILE) profile!"

quick-setup:
	@echo "Quick Setup: $(NAME) with $(PROFILE) profile"
	@echo "==========================================="
	@echo "First, let's update your profile settings..."
	@scripts/update-config.sh $(PROFILE)
	@echo ""
	@echo "Now creating and deploying instance..."
	@$(MAKE) all-config NAME=$(NAME) PROFILE=$(PROFILE)

all: create deploy
	@echo "Instance $(NAME) created and interactive setup completed!"

all-auto: create deploy-auto
	@echo "Instance $(NAME) created and setup deployed automatically!"

all-config: create-config deploy-config
	@echo "Instance $(NAME) created and configured with $(PROFILE) profile!"


clean:
	@echo "Deleting multipass instance: $(NAME)"
	@multipass delete $(NAME)
	@multipass purge
	@echo "Instance $(NAME) deleted successfully"