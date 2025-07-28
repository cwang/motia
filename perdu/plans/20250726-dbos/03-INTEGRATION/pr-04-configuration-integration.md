# PR #4: Configuration Integration

## Scope
Wire up the configuration system to enable perdu features through config files, environment variables, and runtime configuration, completing the end-to-end integration of all perdu components.

## Implementation Specification

### Phase 4 Objectives
- Integrate perdu configuration into existing Motia configuration system
- Enable configuration-driven activation of perdu features
- Provide comprehensive configuration validation and error handling
- Support environment variable injection for sensitive data
- Maintain backward compatibility with existing configurations

### Files to Create

#### 1. `packages/core/src/config/perdu-config.ts`
**Purpose**: Centralized perdu configuration management and validation

**Key Features**:
- Configuration schema validation
- Environment variable substitution
- Default value management
- Configuration merging and validation
- Connection string generation

**Structure**:
```typescript
export interface perduConfig {
  state?: perduStateConfig
  events?: perduEventConfig
  durability?: perduExecutionConfig['durability']
}

export interface perduConnectionConfig {
  host: string
  port: number
  database: string
  username: string
  password: string
  ssl?: boolean
  poolSize?: number
}

export class perduConfigManager {
  static validate(config: perduConfig): ValidationResult
  static mergeWithDefaults(config: Partial<perduConfig>): perduConfig
  static substituteEnvironmentVariables(config: perduConfig): perduConfig
  static createConnectionString(db: perduConnectionConfig): string
}
```

#### 2. `packages/core/src/config/config-schema.ts`
**Purpose**: JSON schema definitions for configuration validation

**Key Features**:
- Complete JSON schema for perdu configuration
- Type-safe configuration validation
- Error message generation for invalid configurations
- Integration with existing Motia config schema

### Files to Modify

#### 1. `packages/core/src/server.ts`
**Changes**:
- Import perdu configuration management
- Modify server creation to use perdu-aware adapters
- Add configuration validation on startup
- Initialize perdu components based on configuration
- Handle configuration errors gracefully

**Risk Level**: LOW - Additive changes to server initialization

#### 2. `packages/core/src/types.ts`
**Changes**:
- Extend MotiaConfig interface with optional perdu configuration
- Add configuration validation types
- Maintain full backward compatibility

#### 3. `packages/core/src/config/index.ts` (if exists)
**Changes**:
- Export perdu configuration types and utilities
- Integrate with existing configuration loading

### Configuration Schema

```yaml
# Complete perdu Configuration Schema
perdu:
  # Shared PostgreSQL database connection (optional)
  database:
    host: string
    port: number
    database: string
    username: string
    password: string
    ssl: boolean (default: false)
    poolSize: number (default: 10)

# State adapter configuration
state:
  adapter: 'file' | 'memory' | 'redis' | 'perdu'
  # If adapter is 'perdu':
  database: # Uses shared perdu.database or override
    host: string
    port: number
    database: string
    username: string
    password: string

# Event manager configuration
events:
  adapter: 'memory' | 'perdu'
  # If adapter is 'perdu':
  database: # Uses shared perdu.database or override
    host: string
    port: number
    database: string
    username: string
    password: string
  options:
    batchSize: number (default: 100)
    pollInterval: number (default: 1000)
    maxRetries: number (default: 3)

# Execution durability configuration
durability:
  enabled: boolean (default: false)
  adapter: 'perdu'
  database: # Uses shared perdu.database or override
    host: string
    port: number
    database: string
    username: string
    password: string
  options:
    maxRetries: number (default: 3)
    retryDelayMs: number (default: 5000)
    timeoutMs: number (default: 300000)
    enableRecovery: boolean (default: true)
```

## Test Plan

### Unit Tests
**File**: `packages/core/src/config/__tests__/perdu-config.test.ts`

#### Test Scenarios:
1. **Configuration Validation Tests**
   - ✅ Should validate complete perdu configuration
   - ✅ Should reject invalid database configurations
   - ✅ Should validate adapter-specific options
   - ✅ Should provide clear error messages for validation failures

2. **Environment Variable Substitution Tests**
   - ✅ Should substitute environment variables in database passwords
   - ✅ Should handle missing environment variables gracefully
   - ✅ Should support complex environment variable patterns
   - ✅ Should preserve non-environment variable values

3. **Configuration Merging Tests**
   - ✅ Should merge perdu config with defaults
   - ✅ Should override defaults with user configuration
   - ✅ Should handle partial configurations correctly
   - ✅ Should maintain configuration hierarchy

4. **Connection String Generation Tests**
   - ✅ Should generate correct PostgreSQL connection strings
   - ✅ Should handle SSL configuration
   - ✅ Should include connection pool settings
   - ✅ Should escape special characters in passwords

### Integration Tests
**File**: `packages/core/src/config/__tests__/config-integration.test.ts`

#### Test Scenarios:
1. **Server Integration Tests**
   - ✅ Should initialize server with perdu configuration
   - ✅ Should create appropriate adapters based on configuration
   - ✅ Should handle configuration validation errors on startup
   - ✅ Should fall back to default adapters when perdu unavailable

2. **Adapter Configuration Tests**
   - ✅ Should configure state adapter from config
   - ✅ Should configure event manager from config
   - ✅ Should configure execution manager from config
   - ✅ Should share database connections when configured

3. **Runtime Configuration Tests**
   - ✅ Should support configuration hot reloading
   - ✅ Should validate configuration changes
   - ✅ Should handle configuration update failures
   - ✅ Should maintain service availability during config updates

### End-to-End Tests
**File**: `packages/core/src/__tests__/perdu-config-e2e.test.ts`

#### Test Scenarios:
1. **Complete Integration Tests**
   - ✅ Should work with all perdu features enabled
   - ✅ Should work with mixed adapter configurations
   - ✅ Should work with shared database configuration
   - ✅ Should work with individual database configurations

2. **Environment-Based Configuration Tests**
   - ✅ Should load configuration from environment variables
   - ✅ Should work in different deployment environments
   - ✅ Should handle containerized deployments
   - ✅ Should work with configuration management systems

3. **Backward Compatibility Tests**
   - ✅ Should work with existing configuration files
   - ✅ Should not break existing workflows
   - ✅ Should maintain performance characteristics
   - ✅ Should preserve all existing functionality

## Configuration Examples

### Minimal Configuration (Single Feature)
```yaml
# Enable only perdu state persistence
state:
  adapter: perdu
  database:
    host: localhost
    port: 5432
    database: motia
    username: motia
    password: "${MOTIA_DB_PASSWORD}"
```

### Full Configuration (All Features)
```yaml
# Shared PostgreSQL database configuration
perdu:
  database:
    host: postgres.example.com
    port: 5432
    database: motia_prod
    username: motia
    password: "${MOTIA_DB_PASSWORD}"
    ssl: true
    poolSize: 20

# State persistence
state:
  adapter: perdu
  # Uses shared perdu.database

# Event management
events:
  adapter: perdu
  # Uses shared perdu.database
  options:
    batchSize: 200
    pollInterval: 500
    maxRetries: 5

# Execution durability
durability:
  enabled: true
  adapter: perdu
  # Uses shared perdu.database
  options:
    maxRetries: 5
    retryDelayMs: 10000
    timeoutMs: 600000
    enableRecovery: true
```

### Environment Variable Configuration
```yaml
# Production configuration with environment variables
perdu:
  database:
    host: "${POSTGRES_HOST}"
    port: "${POSTGRES_PORT:-5432}"
    database: "${POSTGRES_DATABASE}"
    username: "${POSTGRES_USERNAME}"
    password: "${POSTGRES_PASSWORD}"
    ssl: "${POSTGRES_SSL:-true}"

state:
  adapter: perdu

events:
  adapter: perdu

durability:
  enabled: "${MOTIA_DURABILITY_ENABLED:-true}"
  adapter: perdu
```

### Development Configuration
```yaml
# Local development with individual PostgreSQL databases
state:
  adapter: perdu
  database:
    host: localhost
    port: 5432
    database: motia_state_dev
    username: dev
    password: "dev"

events:
  adapter: perdu
  database:
    host: localhost
    port: 5432
    database: motia_events_dev
    username: dev
    password: "dev"

durability:
  enabled: true
  adapter: perdu
  database:
    host: localhost
    port: 5432
    database: motia_execution_dev
    username: dev
    password: "dev"
  options:
    maxRetries: 1
    retryDelayMs: 1000
    timeoutMs: 30000
```

## Success Criteria
- [ ] All existing configuration tests pass
- [ ] New perdu configuration validation works correctly
- [ ] Environment variable substitution works as expected
- [ ] Server initializes correctly with perdu configuration
- [ ] Configuration errors provide clear, actionable messages
- [ ] Backward compatibility maintained for existing configs
- [ ] Performance impact minimal for configuration loading
- [ ] Documentation updated with configuration examples

## Risk Mitigation
1. **Configuration Validation**: Comprehensive schema validation with clear error messages
2. **Environment Variables**: Graceful handling of missing variables with defaults
3. **Database Connections**: Connection validation on startup with retry logic
4. **Backward Compatibility**: Extensive testing with existing configurations
5. **Performance**: Minimal configuration loading overhead

## Deployment Considerations
- Environment variable management for sensitive data
- Configuration validation in CI/CD pipelines
- Database connection health checks
- Configuration hot reloading capabilities
- Monitoring for configuration-related issues

## Dependencies
- All previous PRs (State Adapter, Event Manager, Execution Wrapper)
- JSON schema validation library
- Environment variable parsing utilities
- Existing Motia configuration system

## Environment Variables
```bash
# Required for production deployment
MOTIA_DB_PASSWORD=your_database_password
POSTGRES_HOST=your_postgres_host
POSTGRES_PORT=5432
POSTGRES_DATABASE=motia_prod
POSTGRES_USERNAME=motia
POSTGRES_PASSWORD=your_database_password
POSTGRES_SSL=true
MOTIA_DURABILITY_ENABLED=true
```

## Monitoring and Observability
- Configuration validation metrics
- Database connection health metrics
- perdu feature utilization tracking
- Configuration change audit logging
- Performance impact measurement

## Migration Guide
1. **Phase 1**: Update configuration schema documentation
2. **Phase 2**: Add perdu configuration to existing config files
3. **Phase 3**: Test configuration validation in staging
4. **Phase 4**: Deploy with environment variable management
5. **Phase 5**: Monitor configuration usage and performance

## Estimated Effort
**Development**: 5-6 days
**Testing**: 2-3 days
**Documentation**: 2 days
**Total**: 1 week

## Integration Notes
- This PR completes the perdu integration by wiring all components together
- Critical for enabling end-users to configure and use perdu features
- Provides the foundation for production deployment of perdu-enabled Motia
- Must maintain 100% backward compatibility with existing configurations