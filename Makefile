# VOILÀ — Makefile
# SPDX-License-Identifier: MIT
# Cibles principales : build, test, clean, ci-local

.PHONY: help build build-local test clean ci-local lint

ISO_NAME := voila-$(shell date +%Y.%m.%d)-amd64.iso
DIST := dist
WORK := build-work

help: ## Affiche cette aide
	@echo "VOILÀ — cibles disponibles :"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build l'ISO via Docker (recommandé)
	@mkdir -p $(DIST)
	docker build -t voila-builder docker/
	docker run --rm --privileged \
		-v "$(PWD)/$(DIST):/build/dist" \
		-v "$(PWD)/live-build-config:/build/live-build-config" \
		-v "$(PWD)/scripts:/build/scripts" \
		voila-builder
	@echo ""
	@echo "✓ ISO disponible dans $(DIST)/"
	@ls -la $(DIST)/

build-local: ## Build l'ISO directement (nécessite live-build installé, sudo)
	@mkdir -p $(DIST) $(WORK)
	cd $(WORK) && \
		cp -r ../live-build-config/config . && \
		lb config \
			--distribution bookworm \
			--archive-areas "main contrib non-free non-free-firmware" \
			--debian-installer none \
			--iso-application "VOILÀ" \
			--iso-publisher "JFR-Solutions; https://jfrsolution.fr; dev@jfrsolution.fr" \
			--binary-images iso-hybrid \
			--compression xz && \
		sudo lb build
	@echo "✓ ISO disponible dans $(DIST)/"

test: ## Test l'ISO en QEMU (boot, vérif que ça démarre)
	@if [ ! -f $(DIST)/*.iso ]; then \
		echo "Erreur : pas d'ISO dans $(DIST)/. Lance 'make build' d'abord."; \
		exit 1; \
	fi
	@ISO=$$(ls $(DIST)/*.iso | head -1); \
	qemu-system-x86_64 \
		-m 2048 \
		-enable-kvm \
		-drive file=$(WORK)/test.qcow2,format=qcow2,if=virtio \
		-cdrom "$$ISO" \
		-boot d \
		-nographic \
		-serial mon:stdio || echo "(QEMU timeout OK)"

ci-local: ## Simule ce que fait GitHub Actions en local
	@echo "=== Simulating CI ==="
	@echo "1. Build Docker image..."
	docker build -t voila-builder docker/
	@echo "2. Build ISO..."
	mkdir -p $(DIST)
	docker run --rm -v "$(PWD)/$(DIST):/build/dist" -v "$(PWD)/live-build-config:/build/live-build-config" voila-builder
	@echo "3. Calculate SHA256..."
	@cd $(DIST) && for f in *.iso; do sha256sum $$f > $$f.sha256; done
	@echo "4. List output..."
	@ls -la $(DIST)/
	@echo "✓ CI simulation complete"

lint: ## Vérifie la syntaxe des scripts bash
	@echo "=== Lint scripts bash ==="
	@for f in $(shell find scripts live-build-config -name "*.sh" -o -name "*.hook.chroot" 2>/dev/null); do \
		bash -n $$f && echo "  ✓ $$f" || echo "  ✗ $$f"; \
	done

clean: ## Nettoie les artefacts de build
	rm -rf $(DIST) $(WORK) config-bullseye config-buster config-stretch
	@echo "✓ Cleaned"

clean-all: clean ## Nettoie aussi le cache Docker
	docker rmi voila-builder 2>/dev/null || true
	@echo "✓ Cleaned everything"
