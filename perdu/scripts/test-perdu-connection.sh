#!/bin/bash

# Test perdu database connections

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PERDU_DIR="$(dirname "$SCRIPT_DIR")"

# Source environment variables
if [ -f "$PERDU_DIR/.env.perdu" ]; then
    source "$PERDU_DIR/.env.perdu"
else
    echo "❌ .env.perdu file not found"
    exit 1
fi

echo "🔍 Testing perdu database connections..."

# Test database using environment variable
echo -n "Testing perdu database (${PERDU_DB_NAME})... "
if docker exec motia-perdu-postgres psql -U motia -d "${PERDU_DB_NAME}" -c "SELECT COUNT(*) FROM motia_state;" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Test events table in same database
echo -n "Testing events table... "
if docker exec motia-perdu-postgres psql -U motia -d "${PERDU_DB_NAME}" -c "SELECT COUNT(*) FROM motia_events;" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Test workflows table in same database
echo -n "Testing workflows table... "
if docker exec motia-perdu-postgres psql -U motia -d "${PERDU_DB_NAME}" -c "SELECT COUNT(*) FROM motia_workflows;" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

echo "🎉 All perdu database connections successful!"
