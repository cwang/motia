# PR #0: Perdu Development Environment Setup (Self-Contained)

## Scope
Set up a completely self-contained development environment for perdu integration that doesn't modify any existing Motia files, ensuring perfect upstream compatibility for fork management.

## Self-Contained Architecture

### Core Principle: Zero Impact on Existing Motia
- **No modifications** to existing `compose.yml`, `.env.example`, or any core files
- **Separate Docker stack** with different ports to avoid conflicts
- **Independent database** setup on non-conflicting ports
- **Self-contained scripts** that work entirely within the `perdu/` directory

### Directory Structure
```
perdu/
├── README.md                           # Main perdu documentation
├── package.json                        # Perdu-specific dependencies
├── docker-compose.perdu.yml            # Self-contained Docker stack
├── .env.perdu                          # Generated environment variables
├── scripts/
│   ├── setup-perdu-dev.sh             # Automated setup (self-contained)
│   ├── test-perdu-connection.sh       # Connection validation
│   └── init-perdu-postgres.sql        # Database initialization
└── [all other perdu files...]
```

## Implementation Specification

### Files to Create

#### 1. `perdu/docker-compose.perdu.yml`
**Purpose**: Self-contained Docker stack for perdu services

**Key Features**:
- PostgreSQL on port 5433 (not 5432 to avoid conflicts)
- pgAdmin on port 5051 (not 5050 to avoid conflicts)
- Separate Docker networks (`perdu-network`)
- Independent volume names (`perdu_postgres_data`, `perdu_pgadmin_data`)
- Health checks and service dependencies

#### 2. `perdu/scripts/setup-perdu-dev.sh`
**Purpose**: Automated setup script that works entirely within perdu directory

**Key Features**:
- Checks prerequisites (Docker, Docker Compose)
- Starts perdu-specific services only
- Creates `.env.perdu` file with perdu configuration
- Validates database connections
- Creates helper scripts for development
- Zero impact on existing Motia setup

#### 3. `perdu/scripts/init-perdu-postgres.sql`
**Purpose**: Database initialization for all perdu components

**Databases Created**:
- `motia_state_dev` - State adapter persistence
- `motia_events_dev` - Event manager persistence  
- `motia_execution_dev` - Workflow execution tracking
- `motia_test` - Testing database

#### 4. `perdu/package.json`
**Purpose**: Perdu-specific dependencies and scripts

**Key Scripts**:
- `npm run setup` - Run complete perdu environment setup
- `npm run start-services` - Start perdu Docker stack
- `npm run stop-services` - Stop perdu Docker stack
- `npm run test-connection` - Validate database connections

#### 5. `perdu/.env.perdu`
**Purpose**: Generated environment file (created by setup script)

**Configuration**:
```env
PERDU_DB_HOST=localhost
PERDU_DB_PORT=5433
PERDU_DB_USER=motia
PERDU_DB_PASSWORD=motia_dev
PERDU_DB_STATE=motia_state_dev
PERDU_DB_EVENTS=motia_events_dev
PERDU_DB_EXECUTION=motia_execution_dev
PERDU_DB_TEST=motia_test
PERDU_PGADMIN_URL=http://localhost:5051
```

## Setup Process

### Automated Setup (Recommended)
```bash
# From the perdu directory
cd perdu
npm run setup
```

### Manual Setup (Step by Step)
```bash
# 1. Navigate to perdu directory
cd perdu

# 2. Install perdu dependencies
npm install

# 3. Start perdu services
docker-compose -f docker-compose.perdu.yml up -d

# 4. Wait for services to be ready
npm run test-connection

# 5. Verify setup
docker-compose -f docker-compose.perdu.yml ps
```

### Validation Commands
```bash
# Check service status
docker-compose -f docker-compose.perdu.yml ps

# Test database connections
npm run test-connection

# Connect to databases directly
npm run psql-state     # Connect to state database
npm run psql-events    # Connect to events database
npm run psql-execution # Connect to execution database

# View logs
npm run logs
```

## Port Allocation (Conflict-Free)

| Service | Port | Purpose | Conflicts Avoided |
|---------|------|---------|-------------------|
| PostgreSQL | 5433 | Database | 5432 (default postgres) |
| pgAdmin | 5051 | Admin UI | 5050 (motia pgAdmin if exists) |

## Database Schema

### State Database (`motia_state_dev`)
```sql
CREATE TABLE motia_state (
    trace_id VARCHAR(255) NOT NULL,
    key VARCHAR(255) NOT NULL,
    value JSONB NOT NULL,
    type VARCHAR(50) NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (trace_id, key)
);
```

### Events Database (`motia_events_dev`)
```sql
CREATE TABLE motia_events (
    id SERIAL PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    trace_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE motia_subscriptions (
    id SERIAL PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    step_file_path VARCHAR(255) NOT NULL,
    handler_name VARCHAR(255) NOT NULL DEFAULT 'handler',
    UNIQUE(topic, step_file_path)
);
```

### Execution Database (`motia_execution_dev`)
```sql
CREATE TABLE motia_workflows (
    id SERIAL PRIMARY KEY,
    workflow_id VARCHAR(255) UNIQUE NOT NULL,
    trace_id VARCHAR(255) NOT NULL,
    step_file_path VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'running',
    input_data JSONB,
    output_data JSONB,
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP NULL
);
```

## Testing Framework

### Connection Tests
```bash
# Automated connection testing
npm run test-connection

# Manual connection verification
docker exec motia-perdu-postgres pg_isready -U motia -d motia_state_dev
```

### Database Health Checks
```bash
# Check all tables exist
docker exec motia-perdu-postgres psql -U motia -d motia_state_dev -c "\dt"
docker exec motia-perdu-postgres psql -U motia -d motia_events_dev -c "\dt"
docker exec motia-perdu-postgres psql -U motia -d motia_execution_dev -c "\dt"
```

## Fork-Friendly Benefits

### Zero Upstream Conflicts
1. **No file modifications**: Existing `compose.yml`, `.env.example` untouched
2. **Separate ports**: No service conflicts with existing setup
3. **Independent setup**: Can be added/removed without affecting main setup
4. **Self-contained**: All perdu files in dedicated directory

### Easy Maintenance
1. **Clean separation**: Perdu can be updated independently
2. **Simple removal**: Delete `perdu/` directory to remove completely
3. **Version control**: Perdu changes isolated from main codebase
4. **Team workflow**: Different team members can work on perdu vs main codebase

### Concurrent Development
1. **Parallel work**: Main Motia development continues unchanged
2. **Independent testing**: Perdu tests don't interfere with main tests
3. **Gradual integration**: Features can be developed and tested separately
4. **Easy rollback**: Disable perdu without affecting existing functionality

## Development Workflow

### Daily Development
```bash
# Start working on perdu
cd perdu
npm run start-services

# Develop and test perdu features
# ... development work ...

# Stop perdu services when done
npm run stop-services
```

### Reset Environment
```bash
# Complete reset of perdu environment
npm run reset-services
```

### Monitor Services
```bash
# View real-time logs
npm run logs

# Check service health
docker-compose -f docker-compose.perdu.yml ps
```

## Success Criteria
- [ ] PostgreSQL running on port 5433 without conflicts
- [ ] pgAdmin accessible at http://localhost:5051
- [ ] All perdu databases created and accessible
- [ ] All required tables exist with correct schema
- [ ] Connection validation scripts pass
- [ ] Zero impact on existing Motia setup
- [ ] Fork-friendly: No modifications to upstream files
- [ ] Complete documentation for team onboarding

## Risk Mitigation

### Port Conflicts
- **Solution**: Use non-standard ports (5433, 5051) to avoid conflicts
- **Validation**: Connection tests verify correct port usage

### Database Connection Issues
- **Solution**: Health checks and retry logic in setup scripts
- **Validation**: Automated connection testing with clear error messages

### Docker Environment Issues
- **Solution**: Comprehensive prerequisite checking
- **Validation**: Docker and Docker Compose version verification

### Upstream Merge Conflicts
- **Solution**: Zero modifications to existing files
- **Validation**: All perdu files contained within `perdu/` directory

## Next Steps
1. Complete PR #0 setup
2. Verify all services running correctly
3. Proceed to PR #1 (Perdu State Adapter) implementation
4. Test concurrent development workflow

## Estimated Effort
**Setup**: 2-3 hours
**Testing**: 1 hour  
**Documentation**: 1 hour
**Total**: Half day

This self-contained approach ensures perdu development can proceed without any impact on the main Motia codebase, making it perfect for fork management and concurrent development.