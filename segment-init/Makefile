.PHONY: build test clean run install help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the project
	cargo build

release: ## Build the project in release mode
	cargo build --release

test: ## Run all tests
	cargo test

test-unit: ## Run unit tests only
	cargo test --lib

test-integration: ## Run integration tests only
	cargo test --test test_cli

run: ## Run the CLI (example: make run ARGS="create --help")
	cargo run -- $(ARGS)

clean: ## Clean build artifacts
	cargo clean

install: ## Install the binary locally
	cargo install --path .

fmt: ## Format code
	cargo fmt

clippy: ## Run clippy linter
	cargo clippy -- -D warnings

check: ## Check code without building
	cargo check

watch: ## Watch for changes and rebuild
	cargo watch -x build

doc: ## Generate documentation
	cargo doc --no-deps --open

# Examples
example-help: ## Show CLI help
	cargo run -- --help

example-list: ## List available templates
	cargo run -- list-templates

example-create: ## Example create command
	cargo run -- create test-app --name "Test App" --platform android
