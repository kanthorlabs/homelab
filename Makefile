.DEFAULT_GOAL := help

ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

.PHONY: help nginx kanthord kanthord-cleanup check

help:
	@echo "Homelab. Run make <target>."
	@echo ""
	@echo "  nginx            Install the nginx site of the homelab on 127.0.0.1:80 with sudo"
	@echo "                   /s/kanthord goes to the daemon. / serves the nginx default page"
	@echo "                   HOMELAB_HOST=name sets the host, for example homelab.example.com"
	@echo "                   Without it, every target reads HOMELAB_HOST= from .env"
	@echo "  kanthord         Run the kanthord container under /s/kanthord on 127.0.0.1:31416"
	@echo "                   The first run creates its configuration in the volume"
	@echo "                   IMAGE=name:tag (kanthord:latest) CONTAINER=name VOLUME=name"
	@echo "                   HOMELAB_PORT=port moves it off 31416"
	@echo "  kanthord-cleanup Remove the kanthord container. Ask before it removes the volume"
	@echo "                   YES=1 skips the question. The nginx site stays"
	@echo "  check            Lint the scripts with shellcheck"

nginx:
	@$(ROOT)/nginx/install.sh
kanthord:
	@$(ROOT)/kanthord/run.sh
kanthord-cleanup:
	@$(ROOT)/kanthord/cleanup.sh
check:
	@shellcheck $(ROOT)/lib/*.sh $(ROOT)/nginx/*.sh $(ROOT)/kanthord/*.sh
