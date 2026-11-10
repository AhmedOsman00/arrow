# Variables
BUILD_DIR := .build
SWIFT_BUILD_FLAGS := -c release

.PHONY: all build build-generator generate-version test test-library lint lint-library compatibility install-hooks clean bootstrap help docs

# Default target
all: build

# Show available commands
help:
	@echo "Available targets:"
	@echo ""
	@echo "Setup:"
	@echo "  make bootstrap     - Complete project setup (recommended for first-time setup)"
	@echo "  make install-hooks - Install git pre-commit hooks"
	@echo ""
	@echo "Development:"
	@echo "  make build         - Build the Arrow library"
	@echo "  make build-generator - Build the universal generator binary into Generator/bin/arrow"
	@echo "  make test          - Run both packages' test suites (test-library for Arrow only)"
	@echo "  make lint          - Run SwiftLint in strict mode on both packages (lint-library for Arrow only)"
	@echo "  make compatibility - Generate Compatibility/'s registry with this generator and run it against this Arrow"
	@echo ""
	@echo "Other:"
	@echo "  make docs          - Generate documentation"
	@echo "  make clean         - Remove build artifacts"
	@echo "  make all           - Build (default target)"

# Complete development environment setup
bootstrap:
	@echo "🚀 Starting Arrow development environment setup..."
	@echo ""
	@# Download the pinned SwiftLint
	@./scripts/swiftlint.sh version > /dev/null || { echo "❌ Failed to download SwiftLint"; exit 1; }
	@echo "✅ SwiftLint $$(./scripts/swiftlint.sh version) ready"
	@echo ""
	@# Install git hooks
	@$(MAKE) install-hooks
	@echo ""
	@# Verify environment
	@echo "🔍 Verifying environment setup..."
	@if which swift > /dev/null 2>&1; then \
		SWIFT_VERSION=$$(swift --version | head -n1 | awk '{print $$4}'); \
		EXPECTED_VERSION=$$(cat .swift-version 2>/dev/null || echo "unknown"); \
		echo "✅ Swift: $$SWIFT_VERSION"; \
		if [ "$$SWIFT_VERSION" != "$$EXPECTED_VERSION" ] && [ "$$EXPECTED_VERSION" != "unknown" ]; then \
			echo "   ⚠️  Expected version: $$EXPECTED_VERSION"; \
			echo "   ℹ️  Consider using 'xcodes' to manage Xcode versions"; \
		fi; \
	else \
		echo "❌ Swift: Not found"; exit; \
	fi
	@echo ""
	@echo "✅ Bootstrap complete! Your development environment is ready."
	@echo ""
	@echo "Next steps:"
	@echo "  make build    - Build the project"
	@echo "  make test     - Run tests"
	@echo "  make help     - See all available commands"

# Build the Swift script (universal binary)
build:
	@echo "🔨 Building..."
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "✅ Build complete"

# Build the generator (see Generator/Makefile)
build-generator:
	@$(MAKE) -C Generator build

# Write the generator's version constant, e.g. `make generate-version VERSION=2.1.0`
generate-version:
	@$(MAKE) -C Generator generate-version VERSION="$(VERSION)"

# Run both packages' tests
test: test-library
	@$(MAKE) -C Generator test

# Run Arrow's tests
test-library:
	@echo "🧪 Running tests..."
	@swift test --enable-code-coverage
	@echo "✅ Tests passed."

# Generate Compatibility/'s registry with this commit's generator, then build and run it against this
# commit's Arrow, which checks what every kind of registration resolves to
compatibility:
	@echo "🔗 Checking the generator against Arrow..."
	@swift run --package-path Generator arrow generate --is-package --package-path Compatibility/Sources/Compatibility
	@swift run --package-path Compatibility
	@echo "✅ Generated code builds and resolves."

# Lint both packages
lint: lint-library
	@$(MAKE) -C Generator lint

# Lint Arrow's Swift files using the pinned SwiftLint
lint-library:
	@echo "🔍 Running SwiftLint..."
	@./scripts/swiftlint.sh --strict --reporter github-actions-logging
	@echo "✅ Linting complete."

# Generate documentation
docs:
	@echo "📚 Generating documentation..."
	@swift package --allow-writing-to-directory ./docs \
		generate-documentation --target Arrow \
		--output-path ./docs \
		--transform-for-static-hosting \
		--hosting-base-path arrow
	@echo "✅ Documentation generated in ./docs"
	@echo "   To preview: open ./docs/index.html"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf docs
	@echo "✅ Clean complete."
	@$(MAKE) -C Generator clean

# Install git hooks
install-hooks:
	@echo "📦 Installing git hooks..."
	@if [ ! -d ".git" ]; then \
		echo "❌ Not a git repository. Cannot install hooks."; \
		exit 1; \
	fi
	@mkdir -p .git/hooks
	@cp scripts/git-hooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Git hooks installed."
	@echo "   Pre-commit hook will auto-fix SwiftLint issues before commits."