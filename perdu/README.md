# Motia Perdu - PostgreSQL-First Durable Execution for Multi-Instance Environments

**Motia Perdu** is an opinionated implementation of durable execution for Motia.dev, designed specifically for **multi-instance cloud environments** like GCP Cloud Run, AWS Lambda, and Kubernetes deployments.

## Philosophy: PostgreSQL-Only Architecture

Perdu takes an **opinionated approach** to durability by using **PostgreSQL exclusively** for all persistence needs:

- **Single Database Per Stage**: No complex multi-database setup - one PostgreSQL instance handles everything
- **Cloud-Native**: Built for auto-scaling, stateless compute environments
- **Production-Ready**: Leverages PostgreSQL's ACID guarantees and battle-tested reliability
- **Multi-Instance Safe**: All state coordination happens through PostgreSQL, enabling true horizontal scaling

## Core Capabilities

### 🏗️ **Multi-Instance State Management**
- **Shared State**: All Motia instances share state through PostgreSQL
- **Automatic Coordination**: No manual coordination between instances required
- **Conflict Resolution**: PostgreSQL handles concurrent access with proper locking

### ⚡ **Durable Workflow Execution**
- **Crash Recovery**: Workflows survive instance restarts and crashes
- **Auto-Resume**: Failed workflows automatically resume from last checkpoint
- **Distributed Processing**: Workflows can be picked up by any available instance

### 🔄 **Event-Driven Coordination**
- **PostgreSQL LISTEN/NOTIFY**: Real-time event distribution across instances
- **Guaranteed Delivery**: Events are persisted before notification
- **Horizontal Scaling**: Events automatically route to available instances

## Quick Start

### Prerequisites
- Node.js 20+ (managed via Volta)
- pnpm (monorepo package manager)  
- Docker (for PostgreSQL services)
- Python 3.x (for integration tests)

### Setup Perdu Environment

1. **Configure Environment**:
   ```bash
   cd perdu
   # Copy example environment file
   cp .env.perdu.example .env.perdu.local
   # Edit .env.perdu.local with your values if needed
   ```

2. **Start Perdu Services**:
   ```bash
   docker compose -f docker-compose.perdu.yml up -d
   ```

3. **Install Perdu Dependencies**:
   ```bash
   pnpm install
   ```

4. **Verify Setup**:
   ```bash
   ./scripts/test-perdu-connection.sh
   ```

### Environment Configuration

Perdu uses a **single PostgreSQL database** per environment stage:
- PostgreSQL on port **5433** (avoids conflicts with main motia.dev)
- **Single database**: Contains all tables (state, events, workflows)
- **Stage management**: Database names determined by `PERDU_STAGE` environment variable
  - Development: `motia_perdu_dev` (default)
  - Production: `motia_perdu_prod`
  - Custom stages: `motia_perdu_${PERDU_STAGE}`

## Project Structure

```
perdu/
├── README.md                      # This overview
├── FORK_CI_STRATEGY.md            # Fork-isolated CI/CD strategy
├── PRESERVED_UPSTREAM_INFO.md     # Info moved from upstream files
├── UPSTREAM_INTEGRATION_REQUIREMENTS.md # Minimal upstream changes needed
│
├── plans/                         # All implementation plans
│   └── 20250726-dbos/             # Original DBOS-based plans
│       ├── 00-FOUNDATION/         # Dev environment setup
│       ├── 01-PARALLEL-PHASE-1/   # State adapter + execution wrapper  
│       ├── 02-PARALLEL-PHASE-2/   # Event manager
│       ├── 03-INTEGRATION/        # Configuration integration
│       ├── 04-DOCUMENTATION/      # Documentation and examples
│       └── REFERENCE/             # Background materials
│
├── docker-compose.perdu.yml       # Self-contained Docker services
├── .env.perdu                     # Environment template (with placeholders)
├── .env.perdu.example             # Environment example (with sample values)
├── .env.perdu.local               # Local environment (actual values - not committed)
├── package.json                   # Perdu dependencies
│
└── scripts/                       # Utility scripts
    ├── setup-perdu-dev.sh         # Automated development setup
    ├── init-perdu-postgres.sql    # Database initialization
    └── test-perdu-connection.sh   # Connection verification
```

## Implementation Status

### ✅ Completed
- **Environment Setup**: Self-contained Docker Compose configuration
- **Fork Compatibility**: Upstream file changes reverted and preserved  
- **Planning**: Complete PR specifications with TDD approach
- **Concurrent Strategy**: 5-6 week parallel development plan

### 📋 Ready for Implementation
All implementation plans are in `plans/20250726-dbos/` with:
- Detailed PR specifications
- Test-driven development approach
- Concurrent execution strategy
- Clear team boundaries and dependencies

## Key Benefits

### 🔀 Fork-Friendly Architecture
- **Zero upstream changes**: All perdu code in dedicated directory
- **Non-conflicting ports**: PostgreSQL 5433
- **Separate environment**: `.env.perdu` avoids main motia.dev config
- **Self-contained**: Independent Docker Compose stack

### ⚡ Concurrent Development Ready
- **5-6 week timeline** (vs 7-9 weeks sequential)
- **Clear team boundaries**: State, execution, events, configuration
- **Minimal coordination**: Well-defined interfaces
- **Independent testing**: Each component testable in isolation

## Development Workflow

### Starting Implementation

1. **Review Plans**: Start with `plans/20250726-dbos/EXECUTION_ORDER.md`
2. **Choose Component**: Pick State, Execution, or Events based on team assignment
3. **Follow TDD**: Each PR spec includes comprehensive test plans
4. **Use Perdu Environment**: Always use `docker-compose.perdu.yml` for development

### Integration Points

While perdu is self-contained, it integrates with motia.dev through:
- `StateAdapter` interface extension 
- `EventManager` interface extension
- `ProcessManager` interface extension
- Server configuration registration

See `plans/20250726-dbos/REFERENCE/` for detailed integration architecture.

## Cloud Deployment Patterns

### 🚀 **GCP Cloud Run**
```yaml
# cloud-run.yaml
apiVersion: serving.knative.dev/v1
kind: Service
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/execution-environment: gen2
    spec:
      containerConcurrency: 1000
      containers:
      - image: gcr.io/project/motia-perdu
        env:
        - name: PERDU_DB_HOST
          value: "10.x.x.x"  # Cloud SQL Private IP
        - name: PERDU_DB_NAME
          value: "motia_perdu_prod"
```

### ⚡ **AWS Lambda + RDS**
```yaml
# serverless.yml
service: motia-perdu
provider:
  name: aws
  runtime: nodejs20.x
  environment:
    PERDU_DB_HOST: ${env:RDS_ENDPOINT}
    PERDU_DB_NAME: motia_perdu_prod
  vpc:
    securityGroupIds:
      - ${env:SECURITY_GROUP_ID}
    subnetIds:
      - ${env:SUBNET_ID}
```

### ☸️ **Kubernetes Deployment**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3  # Multiple instances sharing PostgreSQL state
  template:
    spec:
      containers:
      - name: motia-perdu
        env:
        - name: PERDU_DB_HOST
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: host
        - name: PERDU_DB_NAME
          value: "motia_perdu_prod"
```

## CI/CD and Testing

### 🧪 **Local CI/CD Testing**

Perdu includes comprehensive local testing infrastructure that mirrors GitHub Actions exactly:

#### Quick CI/CD Fix Verification
```bash
cd perdu
./scripts/test-ci-fixes-locally.sh
```
- Tests PostgreSQL client installation 
- Verifies database connectivity
- Validates script permissions
- **Fast**: ~30 seconds

#### Full CI/CD Test Suite  
```bash
cd perdu
./scripts/test-ci-locally.sh
```
- Complete environment mirroring
- Full dependency installation testing
- Fork isolation verification
- **Comprehensive**: Mirrors entire GitHub Actions pipeline

### 🛡️ **Fork-Isolated CI/CD**

All CI/CD pipelines are completely isolated from upstream motia.dev:

- **Trigger Isolation**: Only runs on `perdu/**` file changes
- **Service Isolation**: Uses unique PostgreSQL ports (5433) and database names
- **Workflow Isolation**: Separate `.github/workflows/perdu-*.yml` files
- **Action Isolation**: Custom `.github/actions/setup-perdu/` action

This ensures:
- ✅ **Safe upstream syncing** without CI/CD conflicts
- ✅ **Independent development** with dedicated testing
- ✅ **Local verification** before pushing to GitHub

### 🔧 **Development Tools**

#### Multi-Instance Testing
```bash
# Start multiple instances for testing
./scripts/start-motia-dev.sh 3000  # Instance 1
./scripts/start-motia-dev.sh 3001  # Instance 2  
./scripts/start-motia-dev.sh 3002  # Instance 3
```

#### Database Management
```bash
# Setup development environment
./scripts/setup-perdu-dev.sh

# Test database connections
./scripts/test-perdu-connection.sh
```

## Next Steps

1. **Review Implementation Plans**: All specs in `plans/20250726-dbos/`
2. **Start Environment Setup**: Follow foundation PR for PostgreSQL setup
3. **Begin Parallel Development**: Teams can work independently on state/execution
4. **Coordinate Integration**: Final integration phase brings components together

---

**Note**: This is a fork-compatible implementation designed to minimize upstream merge conflicts while providing full durable execution capabilities.