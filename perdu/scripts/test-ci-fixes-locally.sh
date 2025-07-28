#!/bin/bash

# Quick CI/CD Fix Verification Script
# Tests the specific fixes we made without requiring full Docker build
# Verifies PostgreSQL client installation and database connectivity

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

print_color "🧪 Quick CI/CD Fix Verification" "$BLUE"
print_color "==============================" "$BLUE"
echo ""
print_color "Testing the specific fixes we made for GitHub Actions CI/CD" "$YELLOW"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_color "❌ Error: Docker is not running" "$RED"
    print_color "Please start Docker and try again." "$YELLOW"
    exit 1
fi

# Change to perdu directory
cd "$(dirname "$0")/.."

print_color "🔧 Testing PostgreSQL Client Installation Fix" "$BLUE"

# Test that postgresql-client can be installed (mirrors our GitHub Actions fix)
print_color "Testing postgresql-client installation in Ubuntu container..." "$YELLOW"
if docker run --rm ubuntu:22.04 bash -c "
    apt-get update -qq && 
    apt-get install -y postgresql-client >/dev/null 2>&1 && 
    psql --version && 
    pg_isready --version
"; then
    print_color "✅ PostgreSQL client installation works!" "$GREEN"
else
    print_color "❌ PostgreSQL client installation failed!" "$RED"
    exit 1
fi

print_color "🗄️ Testing Database Service Configuration" "$BLUE"

# Start just the PostgreSQL service to test our configuration
print_color "Starting PostgreSQL service with our exact CI configuration..." "$YELLOW"
docker compose -f docker-compose.ci-test.yml up -d perdu-postgres

# Wait for PostgreSQL to be ready
print_color "Waiting for PostgreSQL to be ready..." "$YELLOW"
timeout=30
while [ $timeout -gt 0 ]; do
    if docker exec perdu-ci-postgres pg_isready -U motia -d motia_perdu >/dev/null 2>&1; then
        print_color "✅ PostgreSQL is ready!" "$GREEN"
        break
    fi
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    print_color "❌ PostgreSQL failed to become ready in time!" "$RED"
    docker compose -f docker-compose.ci-test.yml logs perdu-postgres
    exit 1
fi

print_color "🔍 Testing Database Connection (mirrors GitHub Actions)" "$BLUE"

# Test database connection exactly as GitHub Actions does
if docker run --rm --network perdu_perdu-ci-network \
    -e PGPASSWORD=motia_perdu \
    postgres:15 \
    psql -h perdu-postgres -p 5432 -U motia -d motia_perdu -c "SELECT version();" >/dev/null 2>&1; then
    print_color "✅ Database connection works!" "$GREEN"
else
    print_color "❌ Database connection failed!" "$RED"
    exit 1
fi

print_color "📄 Testing Perdu Scripts Execution" "$BLUE"

# Test that our scripts can run (basic validation)
if [ -x "scripts/test-perdu-connection.sh" ]; then
    print_color "✅ test-perdu-connection.sh is executable" "$GREEN"
else
    print_color "❌ test-perdu-connection.sh is not executable" "$RED"
    exit 1
fi

if [ -x "scripts/setup-perdu-dev.sh" ]; then
    print_color "✅ setup-perdu-dev.sh is executable" "$GREEN"
else
    print_color "❌ setup-perdu-dev.sh is not executable" "$RED"
    exit 1
fi

print_color "🧹 Cleaning up test environment" "$BLUE"
docker compose -f docker-compose.ci-test.yml down --volumes >/dev/null 2>&1

print_color "🎉 All CI/CD fixes verified!" "$GREEN"
echo ""
print_color "📋 Verification Results:" "$BLUE"
print_color "  ✅ PostgreSQL client installation works (fixes GitHub Actions error)" "$GREEN"
print_color "  ✅ Database service configuration is correct" "$GREEN" 
print_color "  ✅ Database connection works with proper credentials" "$GREEN"
print_color "  ✅ Perdu scripts are properly executable" "$GREEN"
echo ""
print_color "🚀 The GitHub Actions CI/CD should now pass!" "$GREEN"
print_color "💡 Your fixes have been verified locally" "$BLUE"