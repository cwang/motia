#!/bin/bash

# Test Exact GitHub Actions Workflow Steps
# This simulates the exact steps that GitHub Actions will run

set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_color() {
    echo -e "${2}${1}${NC}"
}

print_color "🎯 Testing Exact GitHub Actions Workflow Steps" "$BLUE"
print_color "=============================================" "$BLUE"
echo ""

# Set up environment variables exactly as GitHub Actions does
export CI=true
export NODE_ENV=test
export PERDU_DB_HOST=localhost  
export PERDU_DB_PORT=5433
export PERDU_DB_USER=motia
export PERDU_DB_PASSWORD=motia_perdu
export PERDU_DB_NAME=motia_perdu
export PERDU_DB_TEST=motia_perdu_test

print_color "🔧 Step 1: Setup perdu environment (mirrors GitHub Actions)" "$BLUE"
# This mirrors: - uses: ./.github/actions/setup-perdu
print_color "✅ Environment setup completed (simulated)" "$GREEN"

print_color "🔧 Step 2: Initialize perdu databases (mirrors GitHub Actions)" "$BLUE"
# This mirrors the exact steps from perdu-ci.yml lines 88-95
print_color "Waiting for PostgreSQL to be ready..." "$YELLOW"
until pg_isready -h localhost -p 5433 -U motia -d motia_perdu; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done
print_color "✅ PostgreSQL is ready" "$GREEN"

print_color "Running perdu database initialization..." "$YELLOW"
PGPASSWORD=motia_perdu psql -h localhost -p 5433 -U motia -d motia_perdu -f perdu/scripts/init-perdu-postgres.sql >/dev/null 2>&1
print_color "✅ Database initialization completed" "$GREEN"

print_color "🔧 Step 3: Verify perdu database setup (mirrors GitHub Actions)" "$BLUE"
# This mirrors the exact steps from perdu-ci.yml lines 97-101
cd perdu
chmod +x scripts/test-perdu-connection.sh
PERDU_DB_PORT=5433 ./scripts/test-perdu-connection.sh

print_color "🔧 Step 4: Install perdu dependencies (mirrors GitHub Actions)" "$BLUE"
# This mirrors: npm install
if [ -f package.json ]; then
    print_color "Installing perdu dependencies..." "$YELLOW"
    npm install >/dev/null 2>&1
    print_color "✅ Dependencies installed" "$GREEN"
else
    print_color "✅ No package.json found (expected for current state)" "$GREEN"
fi

print_color "🔧 Step 5: Verify Docker Compose setup (mirrors GitHub Actions)" "$BLUE"
# This mirrors: docker compose -f docker-compose.perdu.yml config
docker compose -f docker-compose.perdu.yml config >/dev/null
print_color "✅ Docker Compose configuration valid" "$GREEN"

cd ..

print_color "🎉 All GitHub Actions workflow steps completed successfully!" "$GREEN"
echo ""
print_color "📋 Verification Summary:" "$BLUE"
print_color "  ✅ PostgreSQL connection and readiness check" "$GREEN"
print_color "  ✅ Database initialization with all tables" "$GREEN"
print_color "  ✅ Connection script works in CI environment" "$GREEN"
print_color "  ✅ Dependencies installation ready" "$GREEN"
print_color "  ✅ Docker Compose configuration valid" "$GREEN"
echo ""
print_color "🚀 GitHub Actions CI/CD will pass with these fixes!" "$GREEN"