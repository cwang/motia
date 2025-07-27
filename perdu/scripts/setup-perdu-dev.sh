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
echo -e "${BLUE}Starting perdu PostgreSQL...${NC}"
docker-compose -f docker-compose.perdu.yml up -d

# Wait for PostgreSQL to be ready
echo -e "\n${YELLOW}⏳ Waiting for PostgreSQL to be ready...${NC}"
for i in {1..30}; do
    if docker exec motia-perdu-postgres pg_isready -U motia -d motia_perdu > /dev/null 2>&1; then
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

# Source environment variables to get database names
if [ -f "$PERDU_DIR/.env.perdu.local" ]; then
    source "$PERDU_DIR/.env.perdu.local"
elif [ -f "$PERDU_DIR/.env.perdu" ]; then
    source "$PERDU_DIR/.env.perdu"
fi

# Set default stage if not set
PERDU_STAGE=${PERDU_STAGE:-dev}
PERDU_DB_NAME=${PERDU_DB_NAME:-motia_perdu_${PERDU_STAGE}}

# Verify database setup
echo -e "\n${YELLOW}🔍 Verifying database setup...${NC}"
EXPECTED_DBS=("${PERDU_DB_NAME}")
# Only add test database if stage is dev
if [ "$PERDU_STAGE" = "dev" ]; then
    EXPECTED_DBS+=("motia_perdu_test")
fi

for db in "${EXPECTED_DBS[@]}"; do
    if docker exec motia-perdu-postgres psql -U motia -d "$db" -c '\q' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Database $db is accessible${NC}"
    else
        echo -e "${RED}❌ Database $db is not accessible${NC}"
        exit 1
    fi
done

# Verify tables in database
echo -e "\n${YELLOW}🗄️ Verifying table creation...${NC}"
STATE_TABLES=("motia_state")
for table in "${STATE_TABLES[@]}"; do
    if docker exec motia-perdu-postgres psql -U motia -d "${PERDU_DB_NAME}" -c "\dt $table" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Table $table exists in ${PERDU_DB_NAME}${NC}"
    else
        echo -e "${RED}❌ Table $table not found in ${PERDU_DB_NAME}${NC}"
        exit 1
    fi
done

# Skip creating environment file - it should already exist or be created manually
if [ ! -f "$PERDU_DIR/.env.perdu" ]; then
    echo -e "${RED}❌ .env.perdu file not found. Please create it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment file found at ${PERDU_DIR}/.env.perdu${NC}"

# Run connection test
echo -e "\n${YELLOW}🧪 Testing database connections...${NC}"
"$PERDU_DIR/scripts/test-perdu-connection.sh"

# Display setup summary
echo -e "\n${GREEN}🎉 Perdu development environment setup complete!${NC}"
echo -e "\n${BLUE}📊 Service Information:${NC}"
echo -e "  ${YELLOW}PostgreSQL:${NC} localhost:5433 (user: motia, password: motia_perdu)"
echo -e "\n${BLUE}📁 Configuration:${NC}"
echo -e "  ${YELLOW}Environment file:${NC} $PERDU_DIR/.env.perdu"
echo -e "  ${YELLOW}Docker compose:${NC} $PERDU_DIR/docker-compose.perdu.yml"
echo -e "\n${BLUE}🗄️ Databases created:${NC}"
echo -e "  ${YELLOW}Primary Database:${NC} ${PERDU_DB_NAME} (port 5433)"
if [ "$PERDU_STAGE" = "dev" ]; then
    echo -e "  ${YELLOW}Test Database:${NC} motia_perdu_test (port 5433)"
fi
echo -e "\n${BLUE}🚀 Next steps:${NC}"
echo -e "  1. Run tests: ${YELLOW}cd $PERDU_DIR && npm test${NC}"
echo -e "  2. Start implementing: ${YELLOW}Follow PR #0 implementation guide${NC}"
echo -e "\n${GREEN}Happy coding! 🚀${NC}"