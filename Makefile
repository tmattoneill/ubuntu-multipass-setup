.PHONY: help test lint create deploy clean

help:
	@echo "Available commands:"
	@echo "  make create NAME=myapp  - Create new instance"
	@echo "  make deploy NAME=myapp  - Deploy to instance"
	@echo "  make test              - Run tests"
	@echo "  make lint              - Check shell scripts"

create:
	@multipass launch --name $(NAME) --cloud-init cloud-init/basic.yaml

deploy:
	@multipass transfer setup.sh $(NAME):/tmp/
	@multipass exec $(NAME) -- sudo bash /tmp/setup.sh

test:
	@bash tests/test-all.sh

lint:
	@shellcheck setup.sh lib/*.sh modules/*.sh
