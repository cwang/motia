# Perdu - Persist and Durable Execution for Motia.dev

Perdu adds durable execution capabilities to the Motia.dev framework through a self-contained, fork-friendly implementation.

## Overview

Perdu (from "persist" and "durable") provides:
- **Persistent State**: PostgreSQL-backed state management 
- **Durable Workflows**: Workflow execution that survives restarts
- **Event Coordination**: Distributed event handling with PostgreSQL LISTEN/NOTIFY
- **Fork Compatibility**: Minimal changes to upstream motia.dev codebase

## Quick Start

### Prerequisites
- Node.js 20+ (managed via Volta)
- pnpm (monorepo package manager)  
- Docker (for PostgreSQL services)
- Python 3.x (for integration tests)

### Setup Perdu Environment

1. **Start Perdu Services**:
   ```bash
   cd perdu
   docker compose -f docker-compose.perdu.yml up -d
   ```

2. **Install Perdu Dependencies**:
   ```bash
   pnpm install
   ```

3. **Verify Setup**:
   ```bash
   ./scripts/test-perdu-connection.sh
   ```

### Environment Configuration

Perdu uses dedicated environment variables in `.env.perdu`:
- PostgreSQL on port **5433** (avoids conflicts with main motia.dev)
- pgAdmin on port **5051** 
- Separate databases for state, events, and execution tracking

## Project Structure

```
perdu/
├── README.md                    # This overview
├── PRESERVED_UPSTREAM_INFO.md   # Info moved from upstream files
│
├── plans/                       # All implementation plans
│   └── 20250726-dbos/           # Original DBOS-based plans
│       ├── 00-FOUNDATION/       # Dev environment setup
│       ├── 01-PARALLEL-PHASE-1/ # State adapter + execution wrapper  
│       ├── 02-PARALLEL-PHASE-2/ # Event manager
│       ├── 03-INTEGRATION/      # Configuration integration
│       ├── 04-DOCUMENTATION/    # Documentation and examples
│       └── REFERENCE/           # Background materials
│
├── docker-compose.perdu.yml     # Self-contained Docker services
├── .env.perdu                   # Perdu-specific environment variables
├── package.json                 # Perdu dependencies
│
└── scripts/                     # Utility scripts
    ├── setup-perdu-dev.sh       # Automated development setup
    ├── init-perdu-postgres.sql  # Database initialization
    └── test-perdu-connection.sh # Connection verification
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
- **Non-conflicting ports**: PostgreSQL 5433, pgAdmin 5051
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

## Next Steps

1. **Review Implementation Plans**: All specs in `plans/20250726-dbos/`
2. **Start Environment Setup**: Follow foundation PR for PostgreSQL setup
3. **Begin Parallel Development**: Teams can work independently on state/execution
4. **Coordinate Integration**: Final integration phase brings components together

---

**Note**: This is a fork-compatible implementation designed to minimize upstream merge conflicts while providing full durable execution capabilities.