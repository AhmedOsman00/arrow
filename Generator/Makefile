# Variables
SWIFT_FILES := $(wildcard *.swift)
BUILD_DIR := .build
OUTPUT := bin/arrow
TEST_DIR := Tests

.PHONY: all build test lint lint-fix install-hooks

# Default target
all: build

# Build the Swift script
build:
	@set -e
	@echo "🔨 Building the Swift script..."
	@swift build -c release --arch x86_64 --arch arm64
	@BUILD_PATH=$$(swift build -c release --arch x86_64 --arch arm64 --show-bin-path); \
	mkdir -p bin; \
	cp "$$BUILD_PATH/arrow" "$(OUTPUT)"
	@echo "✅ Build complete: $(OUTPUT)"

# Test the Swift project (if Tests directory exists)
test:
	@if [ -d "$(TEST_DIR)" ]; then \
		echo "🧪 Running tests..." && swift test; \
	else \
		echo "❌ No Tests directory found. Skipping tests."; \
	fi

# Lint Swift files using SwiftLint
lint:
	@which swiftlint > /dev/null || { echo "⚠️  SwiftLint not installed. Skipping lint."; exit 0; }
	@echo "🔍 Running SwiftLint..."
	@swiftlint --strict
	@echo "✅ Linting complete."

# Lint and auto-fix violations
lint-fix:
	@which swiftlint > /dev/null || { echo "⚠️  SwiftLint not installed. Skipping lint-fix."; exit 0; }
	@echo "🔧 Running SwiftLint with auto-correction..."
	@swiftlint --fix --format
	@echo "✅ Auto-correction complete."

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
	@echo "✅ Git hooks installed successfully."
	@echo "   Pre-commit hook will now auto-fix SwiftLint issues before each commit."