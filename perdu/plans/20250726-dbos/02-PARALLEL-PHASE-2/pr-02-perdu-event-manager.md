# PR #2: perdu Event Manager Implementation

## Scope
Implement perdu as an optional event backend adapter for distributed coordination and persistent event handling, following the established EventManager interface pattern.

## Implementation Specification

### Phase 2 Objectives
- Add perdu as optional event persistence and coordination backend
- Enable distributed event processing across multiple Motia instances
- Maintain 100% backward compatibility with existing in-memory events
- Provide durable event storage for reliability

### Files to Create

#### 1. `packages/core/src/event-manager/dbos-event-manager.ts`
**Purpose**: New perdu-backed event manager implementing EventManager interface

**Key Features**:
- Implements complete EventManager interface with PostgreSQL backend
- Uses perdu SDK for durable event processing
- PostgreSQL LISTEN/NOTIFY for real-time event distribution
- Persistent event storage for replay and auditing
- Subscription management with database persistence
- Multi-instance coordination to prevent duplicate processing

**Dependencies**:
- `@dbos-inc/dbos-sdk` (from PR #1)
- Existing EventManager interface
- PostgreSQL database connection

#### 2. `packages/core/src/event-manager/types.ts`
**Purpose**: Define TypeScript interfaces for perdu event configuration

**Structure**:
```typescript
export interface perduEventConfig {
  adapter: 'dbos'
  database: {
    host: string
    port: number
    database: string
    username: string
    password: string
  }
  options?: {
    batchSize?: number
    pollInterval?: number
    maxRetries?: number
  }
}
```

### Files to Modify

#### 1. `packages/core/src/event-manager.ts`
**Changes**:
- Add import for perduEventManager
- Extend EventManagerConfig type union with perduEventConfig
- Modify createEventManager factory to support perdu configuration
- Refactor existing implementation into createInMemoryEventManager function
- Maintain existing behavior as default

**Risk Level**: LOW - Only adds new factory logic, existing behavior preserved

#### 2. `packages/core/src/types.ts` (if EventManager interface needs extension)
**Changes**:
- Add optional configuration parameter to EventManager interface
- Maintain backward compatibility with existing implementations

### Database Schema

```sql
-- Events table for persistent storage
CREATE TABLE IF NOT EXISTS motia_events (
  id BIGSERIAL PRIMARY KEY,
  topic VARCHAR(255) NOT NULL,
  data JSONB NOT NULL,
  trace_id VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  processed_at TIMESTAMP NULL,
  retry_count INTEGER DEFAULT 0,
  failed_at TIMESTAMP NULL,
  error_message TEXT NULL
);

-- Subscriptions table for durable subscriptions
CREATE TABLE IF NOT EXISTS motia_subscriptions (
  id BIGSERIAL PRIMARY KEY,
  topic VARCHAR(255) NOT NULL,
  step_file_path VARCHAR(255) NOT NULL,
  handler_name VARCHAR(255) NOT NULL DEFAULT 'handler',
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(topic, step_file_path)
);

-- Event processing state for multi-instance coordination
CREATE TABLE IF NOT EXISTS motia_event_processors (
  id BIGSERIAL PRIMARY KEY,
  instance_id VARCHAR(255) NOT NULL,
  topic VARCHAR(255) NOT NULL,
  last_processed_event_id BIGINT DEFAULT 0,
  last_heartbeat TIMESTAMP DEFAULT NOW(),
  UNIQUE(instance_id, topic)
);

-- Indexes for performance
CREATE INDEX idx_motia_events_topic ON motia_events(topic);
CREATE INDEX idx_motia_events_created_at ON motia_events(created_at);
CREATE INDEX idx_motia_events_processed_at ON motia_events(processed_at);
CREATE INDEX idx_motia_subscriptions_topic ON motia_subscriptions(topic);
CREATE INDEX idx_motia_event_processors_instance ON motia_event_processors(instance_id);
```

## Test Plan

### Unit Tests
**File**: `packages/core/src/event-manager/__tests__/dbos-event-manager.test.ts`

#### Test Scenarios:
1. **Initialization Tests**
   - ✅ Should connect to PostgreSQL database
   - ✅ Should create required tables if not exist
   - ✅ Should handle connection failures gracefully
   - ✅ Should register instance in processors table

2. **Event Emission Tests**
   - ✅ Should emit events to database
   - ✅ Should store event data as JSONB
   - ✅ Should include trace ID and timestamp
   - ✅ Should trigger PostgreSQL NOTIFY

3. **Subscription Management Tests**
   - ✅ Should subscribe to topics with file path and handler
   - ✅ Should prevent duplicate subscriptions
   - ✅ Should unsubscribe from topics
   - ✅ Should persist subscriptions across restarts

4. **Event Processing Tests**
   - ✅ Should process events for subscribed topics
   - ✅ Should call appropriate handler functions
   - ✅ Should mark events as processed
   - ✅ Should handle processing failures with retry logic

5. **Multi-Instance Coordination Tests**
   - ✅ Should distribute events across multiple instances
   - ✅ Should prevent duplicate event processing
   - ✅ Should handle instance failures gracefully
   - ✅ Should rebalance processing on instance changes

### Integration Tests
**File**: `packages/core/src/event-manager/__tests__/event-manager-integration.test.ts`

#### Test Scenarios:
1. **Factory Function Tests**
   - ✅ Should create perduEventManager when config.adapter === 'dbos'
   - ✅ Should fall back to InMemoryEventManager when perdu config invalid
   - ✅ Should maintain existing behavior for no configuration

2. **Interface Compliance Tests**
   - ✅ Should implement all EventManager interface methods
   - ✅ Should behave consistently with InMemoryEventManager for basic operations
   - ✅ Should provide additional durability guarantees

3. **Configuration Tests**
   - ✅ Should work with complete perdu event configuration
   - ✅ Should handle optional configuration parameters
   - ✅ Should validate database connection on startup

### End-to-End Tests
**File**: `packages/core/src/__tests__/dbos-events-e2e.test.ts`

#### Test Scenarios:
1. **Multi-Instance Event Distribution**
   - ✅ Should distribute events across multiple Motia instances
   - ✅ Should handle concurrent event processing
   - ✅ Should maintain event ordering guarantees
   - ✅ Should recover events after instance restart

2. **Event Replay Tests**
   - ✅ Should replay unprocessed events on startup
   - ✅ Should skip already processed events
   - ✅ Should handle partial processing failures

3. **Failure Recovery Tests**
   - ✅ Should retry failed event processing
   - ✅ Should handle database connection failures
   - ✅ Should maintain event consistency during failures

### Performance Tests
**File**: `packages/core/src/event-manager/__tests__/dbos-events-performance.test.ts`

#### Test Scenarios:
1. **Throughput Tests**
   - ✅ Should handle high event emission rates (>1000 events/sec)
   - ✅ Should process events within acceptable latency (<500ms)
   - ✅ Should scale event processing with multiple instances

2. **Memory Usage Tests**
   - ✅ Should maintain stable memory usage under load
   - ✅ Should handle large event payloads efficiently
   - ✅ Should clean up processed events appropriately

## Configuration Examples

### Development (In-Memory - Default)
```yaml
# No events config - uses existing in-memory manager
# This maintains existing behavior
```

### Production (perdu Events)
```yaml
events:
  adapter: dbos
  database:
    host: postgres.example.com
    port: 5432
    database: motia_events
    username: motia_events
    password: "${MOTIA_EVENTS_DB_PASSWORD}"
  options:
    batchSize: 100
    pollInterval: 1000
    maxRetries: 3
```

### Hybrid Configuration
```yaml
events:
  adapter: dbos
  database:
    host: localhost
    port: 5432
    database: motia_dbos
    username: motia
    password: "${MOTIA_DB_PASSWORD}"
  # Use default options
```

## Success Criteria
- [ ] All existing event manager tests pass
- [ ] New perdu event manager passes comprehensive test suite
- [ ] Zero breaking changes to existing event functionality
- [ ] Multi-instance event coordination works correctly
- [ ] Event persistence and replay functionality works
- [ ] Performance benchmarks meet requirements
- [ ] Configuration-driven activation works as expected
- [ ] Documentation updated with perdu event configuration

## Risk Mitigation
1. **Database Connection Failures**: Queue events in memory with configurable buffer
2. **Event Processing Failures**: Implement retry logic with exponential backoff
3. **Multi-Instance Coordination**: Use database locks and heartbeat mechanism
4. **Performance Issues**: Implement batching and connection pooling
5. **Data Consistency**: Use database transactions for event processing

## Deployment Considerations
- Requires PostgreSQL database (can share with state adapter)
- Database connection pooling for high throughput
- Monitoring for event processing lag and failures
- Event retention policies for storage management
- Instance coordination and health monitoring

## Dependencies
- `@dbos-inc/dbos-sdk@^1.0.0` (from PR #1)
- PostgreSQL database with LISTEN/NOTIFY support
- Existing EventManager interface

## Estimated Effort
**Development**: 5-6 days
**Testing**: 2-3 days
**Documentation**: 1 day
**Total**: 1 week

## Integration Notes
- This PR builds on PR #1 (perdu State Adapter)
- Shares database connection and configuration patterns
- Can be deployed independently or together with state adapter
- Maintains complete backward compatibility with existing event system