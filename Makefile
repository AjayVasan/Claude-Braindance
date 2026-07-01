SHELL := /usr/bin/env bash
.PHONY: help install check skills-docs test all

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install Zai (interactive)
	bash install.sh

check: ## Show Zai status
	@bash src/main.sh --check

skills-docs: ## Generate skills index documentation
	@bash -c 'source src/skills.sh && braindance_skills_docs'

test: ## Run all bats tests
	@if command -v bats &>/dev/null; then \
		bats tests/; \
	elif command -v npx &>/dev/null; then \
		npx bats tests/; \
	else \
		echo "bats not found. Install: npm install -g bats"; \
		exit 1; \
	fi

test-presets: ## Run only preset tests
	@npx bats tests/test_presets.bats

test-install: ## Run only install tests
	@npx bats tests/test_install.bats

test-skills: ## Run only skills tests
	@npx bats tests/test_skills.bats

lint: ## Shellcheck all scripts
	@if command -v shellcheck &>/dev/null; then \
		shellcheck src/main.sh src/skills.sh install.sh; \
	else \
		echo "shellcheck not found. Install: sudo pacman -S shellcheck"; \
	fi

all: test check skills-docs ## Run all checks
	@echo "[braindance] All checks passed ✓"
