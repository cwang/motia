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

# Test state database
echo -n "Testing state database... "
if docker exec motia-perdu-postgres psql -U motia -d motia_state_dev -c "SELECT COUNT(*) FROM motia_state;" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Test events database
echo -n "Testing events database... "
if docker exec motia-perdu-postgres psql -U motia -d motia_events_dev -c "SELECT COUNT(*) FROM motia_events;" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Test execution database
echo -n "Testing execution database... "
if docker exec motia-perdu-postgres psql -U motia -d motia_execution_dev -c "SELECT COUNT(*) FROM motia_workflows;" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

echo "🎉 All database connections successful!"
