#!/bin/bash

# Local CI/CD Test Suite Launcher
# Easy way to test GitHub Actions CI/CD pipeline locally before pushing

set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

print_color "🧪 Perdu Local CI/CD Test Suite" "$BLUE"
print_color "===============================" "$BLUE"
echo ""
print_color "This script mirrors the GitHub Actions CI/CD environment locally" "$YELLOW"
print_color "so you can verify changes will pass before pushing to GitHub." "$YELLOW"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_color "❌ Error: Docker is not running" "$RED"
    print_color "Please start Docker and try again." "$YELLOW"
    exit 1
fi

# Change to perdu directory
cd "$(dirname "$0")/.."

print_color "📦 Building CI test environment..." "$BLUE"
echo "This may take a few minutes on first run..."
echo ""

# Build and run the CI test environment
docker compose -f docker-compose.ci-test.yml down --volumes 2>/dev/null || true
docker compose -f docker-compose.ci-test.yml build --no-cache

print_color "🚀 Starting CI/CD test environment..." "$BLUE"
echo ""

# Run the tests
if docker compose -f docker-compose.ci-test.yml up --exit-code-from ci-test-runner; then
    print_color "🎉 All CI/CD tests passed!" "$GREEN"
    print_color "✅ Your changes should pass GitHub Actions CI/CD" "$GREEN"
    echo ""
    print_color "Next steps:" "$BLUE"
    print_color "1. Commit your changes: git add . && git commit -m 'your message'" "$YELLOW"
    print_color "2. Push to GitHub: git push origin your-branch" "$YELLOW"
    print_color "3. GitHub Actions should now pass successfully! 🚀" "$GREEN"
else
    print_color "❌ CI/CD tests failed!" "$RED"
    print_color "Please fix the issues above before pushing to GitHub." "$YELLOW"
    echo ""
    print_color "Debugging tips:" "$BLUE"
    print_color "1. Check the test output above for specific errors" "$YELLOW"
    print_color "2. Run individual services: docker compose -f docker-compose.ci-test.yml up perdu-postgres" "$YELLOW"
    print_color "3. Connect to test runner: docker compose -f docker-compose.ci-test.yml run ci-test-runner bash" "$YELLOW"
    exit 1
fi

# Cleanup
print_color "🧹 Cleaning up test environment..." "$BLUE"
docker compose -f docker-compose.ci-test.yml down --volumes

print_color "✨ Local CI/CD testing complete!" "$GREEN"