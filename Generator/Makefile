# Variables
SWIFT_FILES := $(wildcard *.swift)
BUILD_DIR := .build
OUTPUT := bin/arrow
TEST_DIR := Tests

.PHONY: all build test lint format

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

# Format Swift files using swift-format (if installed)
format:
	@if ! command -v swift-format &> /dev/null; then \
		echo "⚠️  swift-format not installed. Skipping format."; \
	else \
		echo "🎨 Formatting Swift files..."; \
		swift-format format -i $(SWIFT_FILES); \
		echo "✅ Format complete."; \
	fi