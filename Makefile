# Enhanced Makefile with configuration profiles support

.PHONY: help test lint create deploy deploy-auto deploy-config clean all all-auto all-config profiles

# Load configuration (can be overridden with PROFILE=profilename)
PROFILE ?= default
CONFIG_LOADED := $(shell source scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo "yes" || echo "no")

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
	@echo "  make create NAME=myapp            - Create instance with default settings"
	@echo "  make deploy NAME=myapp            - Deploy with interactive config"
	@echo "  make deploy-auto NAME=myapp       - Deploy with automatic config"
	@echo "  make all NAME=myapp               - Create + deploy interactively"
	@echo "  make all-auto NAME=myapp          - Create + deploy automatically"
	@echo ""
	@echo "Profile-Based Commands:"
	@echo "  make create-config NAME=myapp PROFILE=dev     - Create with profile settings"
	@echo "  make deploy-config NAME=myapp PROFILE=dev     - Deploy with profile + auto-config"
	@echo "  make all-config NAME=myapp PROFILE=dev        - Create + deploy with profile"
	@echo ""
	@echo "Configuration:"
	@echo "  make profiles                     - Show available profiles"
	@echo "  make show-config PROFILE=dev     - Show profile configuration"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make test                         - Run tests (if available)"
	@echo "  make lint                         - Check shell scripts with shellcheck"
	@echo "  make clean NAME=myapp             - Delete multipass instance"
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

create:
	@echo "Creating multipass instance: $(NAME)"
	@echo "Resources: $(MULTIPASS_CPUS) CPUs, $(MULTIPASS_MEMORY) memory, $(MULTIPASS_DISK) disk"
	@multipass launch --name $(NAME) --cpus $(MULTIPASS_CPUS) --memory $(MULTIPASS_MEMORY) --disk $(MULTIPASS_DISK)
	@echo "Instance $(NAME) created successfully"

create-config:
	@echo "Creating multipass instance: $(NAME) with profile: $(PROFILE)"
	@source scripts/load-config.sh $(PROFILE)
	@multipass launch --name $(NAME) \
		--cpus $$(source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_CPUS) \
		--memory $$(source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_MEMORY) \
		--disk $$(source scripts/load-config.sh $(PROFILE) >/dev/null && echo $$MULTIPASS_DISK)
	@echo "Instance $(NAME) created successfully with $(PROFILE) profile"

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
	@multipass transfer --recursive . $(NAME):ubuntu-multipass-setup/
	@echo "Running setup script with profile configuration..."
	@multipass exec $(NAME) -- bash -c ' \
		export PRIMARY_USER=$$(echo "$(PROFILE)" | cut -c1-10)_user 2>/dev/null || echo ubuntu; \
		export GIT_USER_NAME="$$(source /home/ubuntu/ubuntu-multipass-setup/scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_GIT_NAME || echo "User")"; \
		export GIT_USER_EMAIL="$$(source /home/ubuntu/ubuntu-multipass-setup/scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_GIT_EMAIL || echo "user@example.com")"; \
		export SERVER_HOSTNAME="$$(source /home/ubuntu/ubuntu-multipass-setup/scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_HOSTNAME || echo "$(NAME)")"; \
		export SERVER_TIMEZONE="$$(source /home/ubuntu/ubuntu-multipass-setup/scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_TIMEZONE || echo "UTC")"; \
		sudo /home/ubuntu/ubuntu-multipass-setup/setup.sh --yes --mode $$(source /home/ubuntu/ubuntu-multipass-setup/scripts/load-config.sh $(PROFILE) >/dev/null 2>&1 && echo $$SETUP_MODE || echo "full") \
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