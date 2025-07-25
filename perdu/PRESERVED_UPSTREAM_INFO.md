# Preserved Information from Upstream File Changes

This document contains information that was previously added to upstream motia.dev files but has been moved here to maintain fork compatibility.

## Environment Variables (from playground/.env.example)

The following environment variables were added to the original `.env.example` but have been moved to the perdu-specific environment:

### Redis Configuration (Original motia.dev)
```bash
# Redis configuration (for existing state adapter)
REDIS_URL="redis://:pingpong@localhost:6379"
```

### PostgreSQL Configuration (Now in perdu/.env.perdu)
```bash
# PostgreSQL configuration (for perdu integration)
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_DATABASE="motia_dev"
POSTGRES_USERNAME="motia"
POSTGRES_PASSWORD="motia_dev"

# perdu configuration (for testing)
MOTIA_DB_PASSWORD="motia_dev"
MOTIA_DURABILITY_ENABLED="false"
```

## Docker Services (from compose.yml)

The following services were added to the original `compose.yml` but are now in `perdu/docker-compose.perdu.yml` with non-conflicting ports:

### PostgreSQL Service
- **Original**: Port 5432
- **perdu**: Port 5433 (in docker-compose.perdu.yml)

### pgAdmin Service  
- **Original**: Port 8080
- **perdu**: Port 5051 (in docker-compose.perdu.yml)

## Setup Instructions (from MONOREPO-README.md)

The following setup instructions were added to the original README but are now covered by the perdu-specific setup scripts:

### Development Services Section
```markdown
### Development Services

The Docker setup provides:
- **Redis Stack** (port 6379) - Current state management
- **Redis UI** (port 8001) - Redis administration interface
- **PostgreSQL** (port 5432) - perdu integration database
- **pgAdmin** (port 8080) - PostgreSQL administration interface (optional)

To start only core services (without admin UIs):
```bash
docker compose up -d redis-stack postgres
```

To include admin interfaces:
```bash
docker compose --profile ui up -d
```
```

### Prerequisites Update
```markdown
### Prerequisites

- **Node.js** (v20+ recommended, managed via Volta)
- **Python** (LTS recommended)
- **pnpm** (for managing the monorepo)
- **Docker** (for development databases: Redis + PostgreSQL)
```

## Note

All perdu-related functionality is now self-contained in the `perdu/` directory to avoid upstream merge conflicts. Use the perdu-specific Docker Compose and environment files for development.