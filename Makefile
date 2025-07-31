.PHONY: help test lint create deploy deploy-auto clean all all-auto

help:
	@echo "Available commands:"
	@echo "  make create NAME=myapp     - Create new multipass instance"
	@echo "  make deploy NAME=myapp     - Deploy setup with interactive config"
	@echo "  make deploy-auto NAME=myapp - Deploy setup with default settings (non-interactive)"
	@echo "  make all NAME=myapp        - Create instance and deploy with interactive config"
	@echo "  make all-auto NAME=myapp   - Create instance and deploy with defaults"
	@echo "  make test                  - Run tests (if available)"
	@echo "  make lint                  - Check shell scripts with shellcheck"
	@echo "  make clean NAME=myapp      - Delete multipass instance"

create:
	@echo "Creating multipass instance: $(NAME)"
	@multipass launch --name $(NAME) --cpus 2 --memory 4G --disk 20G
	@echo "Instance $(NAME) created successfully"

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

test:
	@if [ -d "tests" ]; then \
		bash tests/test-all.sh; \
	else \
		echo "No tests directory found. Skipping tests."; \
	fi

lint:
	@echo "Running shellcheck on all scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck setup.sh lib/*.sh modules/*.sh; \
		echo "Shellcheck completed successfully"; \
	else \
		echo "Warning: shellcheck not installed. Install with: brew install shellcheck"; \
	fi

all: create deploy
	@echo "Instance $(NAME) created and interactive setup completed!"

all-auto: create deploy-auto
	@echo "Instance $(NAME) created and setup deployed automatically!"

clean:
	@echo "Deleting multipass instance: $(NAME)"
	@multipass delete $(NAME)
	@multipass purge
	@echo "Instance $(NAME) deleted successfully"