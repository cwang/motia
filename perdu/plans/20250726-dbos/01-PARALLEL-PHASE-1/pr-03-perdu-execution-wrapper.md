# PR #3: perdu Execution Wrapper Implementation

## Scope
Implement perdu workflow durability for step execution through a non-intrusive wrapper pattern that extends the existing ProcessManager without modifying core execution logic.

## Implementation Specification

### Phase 3 Objectives
- Add optional perdu workflow durability for step execution
- Provide automatic retry, recovery, and exactly-once execution guarantees
- Maintain 100% backward compatibility with existing ProcessManager
- Enable distributed execution coordination across multiple instances
- Zero modifications to `call-step-file.ts` core logic

### Files to Create

#### 1. `packages/core/src/execution/dbos-process-manager.ts`
**Purpose**: perdu-enhanced ProcessManager that wraps execution in durable workflows

**Key Features**:
- Extends existing ProcessManager class
- Wraps process execution in perdu workflows for durability
- Provides automatic retry and recovery capabilities
- Maintains exact same interface as ProcessManager
- Distributed execution coordination
- Execution state persistence and recovery

**Architecture**:
```typescript
export class perduProcessManager extends ProcessManager {
  // Inherits all ProcessManager functionality
  // Wraps critical methods with perdu workflow annotations
  // Provides transparent durability layer
}
```

#### 2. `packages/core/src/execution/dbos-execution-config.ts`
**Purpose**: Configuration interfaces and validation for perdu execution

**Structure**:
```typescript
export interface perduExecutionConfig {
  durability: {
    enabled: true
    adapter: 'dbos'
    database: {
      host: string
      port: number
      database: string
      username: string
      password: string
    }
    options?: {
      maxRetries?: number
      retryDelayMs?: number
      timeoutMs?: number
      enableRecovery?: boolean
    }
  }
}
```

#### 3. `packages/core/src/execution/workflow-registry.ts`
**Purpose**: Registry for perdu workflow definitions and step execution tracking

**Key Features**:
- Workflow definition management
- Step execution state tracking
- Recovery coordination
- Execution metrics collection

### Files to Modify

#### 1. `packages/core/src/call-step-file.ts`
**Changes**:
- Add import for perduProcessManager and configuration types
- Add factory function `createProcessManager()` to choose appropriate manager
- Replace direct ProcessManager instantiation with factory call
- Maintain exact same execution logic and error handling
- Zero changes to execution flow or interface

**Risk Level**: MINIMAL - Only changes ProcessManager instantiation, all logic preserved

#### 2. `packages/core/src/types.ts`
**Changes**:
- Add perduExecutionConfig type export
- Extend MotiaConfig interface to include optional durability configuration
- Maintain backward compatibility

### Database Schema

```sql
-- Workflow execution tracking
CREATE TABLE IF NOT EXISTS motia_workflows (
  workflow_id VARCHAR(255) PRIMARY KEY,
  trace_id VARCHAR(255) NOT NULL,
  step_file_path VARCHAR(255) NOT NULL,
  input_data JSONB NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'running', -- running, completed, failed, retrying
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP NULL,
  failed_at TIMESTAMP NULL,
  retry_count INTEGER DEFAULT 0,
  error_message TEXT NULL,
  result_data JSONB NULL
);

-- Step execution within workflows
CREATE TABLE IF NOT EXISTS motia_workflow_steps (
  id BIGSERIAL PRIMARY KEY,
  workflow_id VARCHAR(255) NOT NULL REFERENCES motia_workflows(workflow_id),
  step_name VARCHAR(255) NOT NULL,
  step_type VARCHAR(100) NOT NULL,
  input_data JSONB,
  output_data JSONB,
  status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, running, completed, failed
  started_at TIMESTAMP NULL,
  completed_at TIMESTAMP NULL,
  duration_ms INTEGER NULL,
  error_message TEXT NULL
);

-- Execution locks for distributed coordination
CREATE TABLE IF NOT EXISTS motia_execution_locks (
  lock_key VARCHAR(255) PRIMARY KEY,
  workflow_id VARCHAR(255) NOT NULL,
  instance_id VARCHAR(255) NOT NULL,
  acquired_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_motia_workflows_trace_id ON motia_workflows(trace_id);
CREATE INDEX idx_motia_workflows_status ON motia_workflows(status);
CREATE INDEX idx_motia_workflows_started_at ON motia_workflows(started_at);
CREATE INDEX idx_motia_workflow_steps_workflow_id ON motia_workflow_steps(workflow_id);
CREATE INDEX idx_motia_workflow_steps_status ON motia_workflow_steps(status);
CREATE INDEX idx_motia_execution_locks_expires_at ON motia_execution_locks(expires_at);
```

## Test Plan

### Unit Tests
**File**: `packages/core/src/execution/__tests__/dbos-process-manager.test.ts`

#### Test Scenarios:
1. **Inheritance Tests**
   - ✅ Should extend ProcessManager correctly
   - ✅ Should maintain all parent class methods
   - ✅ Should preserve original method behavior when durability disabled
   - ✅ Should initialize perdu SDK correctly

2. **Workflow Wrapping Tests**
   - ✅ Should wrap spawn() method in perdu workflow
   - ✅ Should persist workflow state to database
   - ✅ Should track step execution progress
   - ✅ Should handle workflow completion correctly

3. **Error Handling Tests**
   - ✅ Should handle process execution failures
   - ✅ Should retry failed executions according to configuration
   - ✅ Should respect maximum retry limits
   - ✅ Should fallback to regular ProcessManager on perdu failures

4. **Recovery Tests**
   - ✅ Should recover incomplete workflows on startup
   - ✅ Should resume from last successful step
   - ✅ Should handle partial execution state correctly
   - ✅ Should clean up completed workflows

### Integration Tests
**File**: `packages/core/src/__tests__/dbos-execution-integration.test.ts`

#### Test Scenarios:
1. **Factory Function Tests**
   - ✅ Should create perduProcessManager when durability enabled
   - ✅ Should create regular ProcessManager when durability disabled
   - ✅ Should handle invalid perdu configuration gracefully
   - ✅ Should fall back to ProcessManager on perdu connection failure

2. **Call Step File Integration**
   - ✅ Should execute steps through perdu workflows when enabled
   - ✅ Should maintain identical behavior to regular execution
   - ✅ Should preserve all existing error handling
   - ✅ Should support all step types (JavaScript, Python, shell, etc.)

3. **Multi-Instance Coordination**
   - ✅ Should prevent duplicate workflow execution across instances
   - ✅ Should handle instance failures during execution
   - ✅ Should coordinate workflow recovery between instances
   - ✅ Should maintain execution locks correctly

### End-to-End Tests
**File**: `packages/core/src/__tests__/dbos-execution-e2e.test.ts`

#### Test Scenarios:
1. **Durability Tests**
   - ✅ Should survive process crashes during step execution
   - ✅ Should resume workflows after system restart
   - ✅ Should maintain exactly-once execution guarantees
   - ✅ Should handle database connection failures gracefully

2. **Performance Tests**
   - ✅ Should execute steps within acceptable latency overhead (<20%)
   - ✅ Should handle concurrent workflow execution
   - ✅ Should scale with multiple instances
   - ✅ Should manage database connections efficiently

3. **Configuration Tests**
   - ✅ Should work with all configuration combinations
   - ✅ Should validate configuration on startup
   - ✅ Should handle missing required configuration
   - ✅ Should support configuration hot reloading

### Failure Simulation Tests
**File**: `packages/core/src/__tests__/dbos-failure-simulation.test.ts`

#### Test Scenarios:
1. **Process Failure Simulation**
   - ✅ Should handle step process crashes
   - ✅ Should retry failed processes according to policy
   - ✅ Should persist failure information
   - ✅ Should escalate persistent failures

2. **Database Failure Simulation**
   - ✅ Should handle temporary database disconnections
   - ✅ Should queue operations during database outages
   - ✅ Should recover gracefully when database reconnects
   - ✅ Should maintain workflow consistency

3. **Network Partition Simulation**
   - ✅ Should handle split-brain scenarios
   - ✅ Should prevent conflicting workflow execution
   - ✅ Should recover from network partition healing
   - ✅ Should maintain data consistency

## Configuration Examples

### Development (Durability Disabled - Default)
```yaml
# No durability config - uses regular ProcessManager
# Existing behavior unchanged
```

### Production (Full Durability)
```yaml
durability:
  enabled: true
  adapter: dbos
  database:
    host: postgres.example.com
    port: 5432
    database: motia_execution
    username: motia_exec
    password: "${MOTIA_EXEC_DB_PASSWORD}"
  options:
    maxRetries: 3
    retryDelayMs: 5000
    timeoutMs: 300000  # 5 minutes
    enableRecovery: true
```

### Testing Configuration
```yaml
durability:
  enabled: true
  adapter: dbos
  database:
    host: localhost
    port: 5432
    database: motia_test
    username: test
    password: "test"
  options:
    maxRetries: 1
    retryDelayMs: 100
    timeoutMs: 30000  # 30 seconds
    enableRecovery: false
```

## Success Criteria
- [ ] All existing step execution tests pass
- [ ] New perdu execution wrapper passes comprehensive test suite
- [ ] Zero breaking changes to existing step execution
- [ ] Performance overhead within acceptable limits (<20%)
- [ ] Durability guarantees verified through failure testing
- [ ] Multi-instance coordination works correctly
- [ ] Recovery functionality works after process crashes
- [ ] Configuration-driven activation works as expected

## Risk Mitigation
1. **Performance Impact**: Benchmark and optimize database operations
2. **Database Failures**: Implement fallback to regular ProcessManager
3. **Workflow Recovery**: Comprehensive testing of recovery scenarios
4. **Configuration Errors**: Validate configuration and provide clear error messages
5. **Memory Leaks**: Proper cleanup of workflow state and database connections

## Deployment Considerations
- Requires PostgreSQL database (can share with state/events)
- Database connection pooling for performance
- Monitoring for workflow execution metrics
- Cleanup policies for completed workflows
- Instance coordination and health monitoring
- Recovery procedures for corrupted workflow state

## Dependencies
- `@dbos-inc/dbos-sdk@^1.0.0` (from PR #1)
- PostgreSQL database with transaction support
- Existing ProcessManager and call-step-file infrastructure

## Migration Strategy
1. **Phase 1**: Deploy with durability disabled (default behavior)
2. **Phase 2**: Enable durability for non-critical workflows
3. **Phase 3**: Gradual rollout to all workflow execution
4. **Phase 4**: Monitor and optimize performance

## Monitoring and Observability
- Workflow execution metrics (duration, success rate, retry count)
- Database connection health
- Recovery event tracking
- Performance impact measurement
- Multi-instance coordination status

## Estimated Effort
**Development**: 10-12 days
**Testing**: 4-5 days
**Documentation**: 2 days
**Total**: 2+ weeks

## Integration Notes
- This PR builds on PR #1 (State Adapter) and PR #2 (Event Manager)
- Shares database configuration and connection patterns
- Can be deployed independently with its own database
- Maintains complete backward compatibility
- Critical path for providing durability guarantees to Motia workflows