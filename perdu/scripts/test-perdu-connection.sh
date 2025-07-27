#!/bin/bash

# Test perdu database connections
# Works in both local Docker environment and GitHub Actions CI

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PERDU_DIR="$(dirname "$SCRIPT_DIR")"

# Detect environment (CI vs local)
if [ "$CI" = "true" ]; then
    echo "🔍 Testing perdu database connections (CI environment)..."
    
    # In CI, use environment variables set by GitHub Actions
    DB_HOST=${PERDU_DB_HOST:-localhost}
    DB_PORT=${PERDU_DB_PORT:-5433}
    DB_USER=${PERDU_DB_USER:-motia}
    DB_NAME=${PERDU_DB_NAME:-motia_perdu_dev}
    DB_PASSWORD=${PERDU_DB_PASSWORD:-motia_perdu}
    
    # Connection command for CI (direct psql)
    PSQL_CMD="PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
    
else
    echo "🔍 Testing perdu database connections (local Docker environment)..."
    
    # In local environment, source .env.perdu file
    if [ -f "$PERDU_DIR/.env.perdu.local" ]; then
        source "$PERDU_DIR/.env.perdu.local"
    elif [ -f "$PERDU_DIR/.env.perdu" ]; then
        source "$PERDU_DIR/.env.perdu"
    else
        echo "❌ No .env.perdu or .env.perdu.local file found"
        exit 1
    fi
    
    # Use environment variables from .env file
    DB_NAME=${PERDU_DB_NAME:-motia_perdu_dev}
    
    # Check if Docker container is running
    if docker ps --filter "name=motia-perdu-postgres" --filter "status=running" | grep -q motia-perdu-postgres; then
        # Connection command for local Docker
        PSQL_CMD="docker exec motia-perdu-postgres psql -U motia -d $DB_NAME"
    else
        echo "❌ Local perdu PostgreSQL container not running"
        echo "💡 Run: cd perdu && docker compose -f docker-compose.perdu.yml up -d"
        exit 1
    fi
fi

echo "📊 Environment: $([ "$CI" = "true" ] && echo "CI" || echo "Local Docker")"
echo "🗄️  Database: $DB_NAME"

# Test state table
echo -n "Testing state table... "
if eval "$PSQL_CMD -c \"SELECT COUNT(*) FROM motia_state;\"" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    echo "💡 Run database initialization first"
    exit 1
fi

# Test events table
echo -n "Testing events table... "
if eval "$PSQL_CMD -c \"SELECT COUNT(*) FROM motia_events;\"" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    echo "💡 Run database initialization first"
    exit 1
fi

# Test workflows table
echo -n "Testing workflows table... "
if eval "$PSQL_CMD -c \"SELECT COUNT(*) FROM motia_workflows;\"" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    echo "💡 Run database initialization first"
    exit 1
fi

# Test trace-related tables
echo -n "Testing trace tables... "
if eval "$PSQL_CMD -c \"SELECT COUNT(*) FROM motia_traces;\"" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    echo "💡 Run database initialization first"
    exit 1
fi

echo "🎉 All perdu database connections successful!"

# Print summary
echo ""
echo "📋 Connection Summary:"
if [ "$CI" = "true" ]; then
    echo "  🌐 Host: $DB_HOST:$DB_PORT"
    echo "  👤 User: $DB_USER"
    echo "  🗄️  Database: $DB_NAME"
else
    echo "  🐳 Container: motia-perdu-postgres"
    echo "  👤 User: motia"
    echo "  🗄️  Database: $DB_NAME"
fi
echo "  ✅ All tables accessible and ready"