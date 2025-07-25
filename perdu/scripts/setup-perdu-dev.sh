#!/bin/bash

# Perdu Development Environment Setup
# Self-contained setup that doesn't modify existing motia files

set -e

echo "🔧 Setting up Perdu development environment..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PERDU_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$PERDU_DIR")"

echo -e "${BLUE}Perdu directory: ${PERDU_DIR}${NC}"
echo -e "${BLUE}Root directory: ${ROOT_DIR}${NC}"

# Verify prerequisites
echo -e "\n${YELLOW}📋 Checking prerequisites...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker found${NC}"

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker Compose found${NC}"

# Check if we're in the right directory
if [ ! -f "$PERDU_DIR/docker-compose.perdu.yml" ]; then
    echo -e "${RED}❌ docker-compose.perdu.yml not found in perdu directory${NC}"
    exit 1
fi

# Start perdu services
echo -e "\n${YELLOW}🚀 Starting Perdu services...${NC}"
cd "$PERDU_DIR"

# Stop any existing perdu services
echo -e "${BLUE}Stopping existing perdu services...${NC}"
docker-compose -f docker-compose.perdu.yml down --volumes 2>/dev/null || true

# Start new services
echo -e "${BLUE}Starting perdu PostgreSQL and pgAdmin...${NC}"
docker-compose -f docker-compose.perdu.yml up -d

# Wait for PostgreSQL to be ready
echo -e "\n${YELLOW}⏳ Waiting for PostgreSQL to be ready...${NC}"
for i in {1..30}; do
    if docker exec motia-perdu-postgres pg_isready -U motia -d motia_dev > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

if [ $i -eq 30 ]; then
    echo -e "\n${RED}❌ PostgreSQL failed to start${NC}"
    docker-compose -f docker-compose.perdu.yml logs perdu-postgres
    exit 1
fi

# Verify database setup
echo -e "\n${YELLOW}🔍 Verifying database setup...${NC}"
EXPECTED_DBS=("motia_dev" "motia_test" "motia_state_dev" "motia_events_dev" "motia_execution_dev")

for db in "${EXPECTED_DBS[@]}"; do
    if docker exec motia-perdu-postgres psql -U motia -d "$db" -c '\q' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Database $db is accessible${NC}"
    else
        echo -e "${RED}❌ Database $db is not accessible${NC}"
        exit 1
    fi
done

# Verify tables in state database
echo -e "\n${YELLOW}🗄️ Verifying table creation...${NC}"
STATE_TABLES=("motia_state")
for table in "${STATE_TABLES[@]}"; do
    if docker exec motia-perdu-postgres psql -U motia -d motia_state_dev -c "\dt $table" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Table $table exists in motia_state_dev${NC}"
    else
        echo -e "${RED}❌ Table $table not found in motia_state_dev${NC}"
        exit 1
    fi
done

# Create perdu environment file
echo -e "\n${YELLOW}📄 Creating perdu environment configuration...${NC}"
cat > "$PERDU_DIR/.env.perdu" << EOF
# Perdu Development Environment Variables
# These are separate from the main motia environment

# PostgreSQL Configuration
PERDU_DB_HOST=localhost
PERDU_DB_PORT=5433
PERDU_DB_USER=motia
PERDU_DB_PASSWORD=motia_dev

# Database Names
PERDU_DB_STATE=motia_state_dev
PERDU_DB_EVENTS=motia_events_dev
PERDU_DB_EXECUTION=motia_execution_dev
PERDU_DB_TEST=motia_test

# pgAdmin Configuration
PERDU_PGADMIN_URL=http://localhost:5051
PERDU_PGADMIN_EMAIL=admin@motia.dev
PERDU_PGADMIN_PASSWORD=admin123

# Perdu SDK Configuration
PERDU_APP_NAME=motia-perdu
PERDU_APP_VERSION=1.0.0
EOF

echo -e "${GREEN}✅ Environment file created at ${PERDU_DIR}/.env.perdu${NC}"

# Create connection test script
echo -e "\n${YELLOW}🔧 Creating connection test script...${NC}"
cat > "$PERDU_DIR/scripts/test-perdu-connection.sh" << 'EOF'
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
EOF

chmod +x "$PERDU_DIR/scripts/test-perdu-connection.sh"

# Run connection test
echo -e "\n${YELLOW}🧪 Testing database connections...${NC}"
"$PERDU_DIR/scripts/test-perdu-connection.sh"

# Display setup summary
echo -e "\n${GREEN}🎉 Perdu development environment setup complete!${NC}"
echo -e "\n${BLUE}📊 Service Information:${NC}"
echo -e "  ${YELLOW}PostgreSQL:${NC} localhost:5433 (user: motia, password: motia_dev)"
echo -e "  ${YELLOW}pgAdmin:${NC} http://localhost:5051 (admin@motia.dev / admin123)"
echo -e "\n${BLUE}📁 Configuration:${NC}"
echo -e "  ${YELLOW}Environment file:${NC} $PERDU_DIR/.env.perdu"
echo -e "  ${YELLOW}Docker compose:${NC} $PERDU_DIR/docker-compose.perdu.yml"
echo -e "\n${BLUE}🗄️ Databases created:${NC}"
echo -e "  ${YELLOW}State:${NC} motia_state_dev (port 5433)"
echo -e "  ${YELLOW}Events:${NC} motia_events_dev (port 5433)"
echo -e "  ${YELLOW}Execution:${NC} motia_execution_dev (port 5433)"
echo -e "  ${YELLOW}Testing:${NC} motia_test (port 5433)"
echo -e "\n${BLUE}🚀 Next steps:${NC}"
echo -e "  1. Run tests: ${YELLOW}cd $PERDU_DIR && npm test${NC}"
echo -e "  2. Start implementing: ${YELLOW}Follow PR #0 implementation guide${NC}"
echo -e "  3. Monitor databases: ${YELLOW}Open http://localhost:5051 in browser${NC}"
echo -e "\n${GREEN}Happy coding! 🚀${NC}"