# Variables
BUILD_DIR := .build
OUTPUT_DIR := bin
OUTPUT := $(OUTPUT_DIR)/arrow
# Setup and tooling versions are shared with Arrow at the repo root (run `make bootstrap` there).
SWIFT_VERSION := $(shell cat ../.swift-version 2>/dev/null || echo "6.0")
SWIFT_BUILD_FLAGS := -c release --arch x86_64 --arch arm64 -Xswiftc -swift-version -Xswiftc $(SWIFT_VERSION)

.PHONY: all build test lint clean help generate-version

# Default target
all: build

# Show available commands
help:
	@echo "Available targets:"
	@echo ""
	@echo "Development:"
	@echo "  make build         - Build universal release binary"
	@echo "  make test          - Run test suite"
	@echo "  make lint          - Run SwiftLint in strict mode"
	@echo "  make generate-version - Generate version from git tags"
	@echo ""
	@echo "Other:"
	@echo "  make clean         - Remove build artifacts"
	@echo "  make all           - Build (default target)"

# Generate version from git tags
generate-version:
	@echo "🔢 Generating version $(VERSION)"
	@./scripts/generate-version.sh $(VERSION)

# Build the Swift script (universal binary)
build: 
	@echo "🔨 Building universal binary (x86_64 + arm64)..."
	@swift build $(SWIFT_BUILD_FLAGS)
	@mkdir -p $(OUTPUT_DIR)
	@cp "$$(swift build $(SWIFT_BUILD_FLAGS) --show-bin-path)/arrow" "$(OUTPUT)"
	@chmod +x "$(OUTPUT)"
	@echo "✅ Build complete: $(OUTPUT)"

# Run tests
test:
	@echo "🧪 Running tests..."
	@swift test --enable-code-coverage
	@echo "✅ Tests passed."

# Lint Swift files using the pinned SwiftLint at the repo root
lint:
	@echo "🔍 Running SwiftLint..."
	@../scripts/swiftlint.sh --strict --reporter github-actions-logging
	@echo "✅ Linting complete."

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(OUTPUT_DIR)
	@rm -f Sources/Constants/Version.generated.swift
	@echo "✅ Clean complete."
