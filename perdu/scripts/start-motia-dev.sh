#!/bin/bash

# Perdu Development Server Launcher
# Provides easy multi-instance Motia server setup for perdu testing
# Maintains fork compatibility by not modifying upstream cli.ts

set -e

# Default port if not specified
DEFAULT_PORT=3000

# Parse command line arguments  
PORT=${1:-$DEFAULT_PORT}

# Validate port number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
    echo "❌ Error: Port must be a number between 1024 and 65535"
    echo "📖 Usage: $0 [PORT]"
    echo "📖 Example: $0 3001  # Start on port 3001"
    echo "📖 Example: $0       # Start on default port 3000"
    exit 1
fi

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "❌ Error: Port $PORT is already in use"
    echo "🔍 Use 'lsof -i :$PORT' to see what's using it"
    echo "💡 Try a different port: $0 $((PORT + 1))"
    exit 1
fi

# Set environment variables for perdu
export MOTIA_PORT=$PORT

echo "🚀 Starting Motia development server with perdu support..."
echo "📍 Port: $PORT"
echo "🗄️  Database: PostgreSQL (if configured)"
echo "🔗 URL: http://localhost:$PORT"
echo ""

# Change to playground directory and start server
cd "$(dirname "$0")/../.."
cd playground

# Start the server with the specified port
exec pnpm run dev -- --port $PORT