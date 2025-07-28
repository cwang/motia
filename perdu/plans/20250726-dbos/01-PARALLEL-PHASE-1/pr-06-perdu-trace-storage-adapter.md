# PR #6: Perdu Trace Storage Adapter Implementation

## Scope
Implement perdu as an optional trace storage backend adapter for durable observability and multi-instance trace sharing, following the established StreamAdapter interface pattern.

## Implementation Specification

### Phase 2 Objectives
- Add perdu as optional trace persistence backend for observability data
- Enable shared trace visibility across multiple Motia instances
- Maintain 100% backward compatibility with existing file-based trace storage
- Provide durable trace storage for debugging and audit requirements
- Support performance monitoring with SQL-based trace analysis

### Files to Create

#### 1. `packages/core/src/streams/adapters/perdu-trace-stream-adapter.ts`
**Purpose**: New perdu-backed trace stream adapter implementing StreamAdapter interface

**Key Features**:
- Implements complete StreamAdapter interface with PostgreSQL backend
- Uses DBOS SDK for durable execution and database operations
- Leverages DBOS transactions for reliable trace persistence
- Supports all existing trace operations (get, set, delete, getGroup)
- Automatic JSON serialization/deserialization for trace data
- Database schema initialization through DBOS SQL operations
- Configurable retention policies for trace cleanup

**Dependencies**:
- `@dbos-inc/dbos-sdk@^1.0.0` for durable execution and database operations
- `pg@^8.11.0` and `@types/pg@^8.10.0` (from PR #1)  
- Existing StreamAdapter interface
- PostgreSQL database connection (shared with state/events)

#### 2. `packages/core/src/streams/adapters/perdu-trace-group-stream-adapter.ts`
**Purpose**: New perdu-backed trace group stream adapter for trace group persistence

**Key Features**:
- Implements StreamAdapter interface for TraceGroup objects
- Shared database connection with trace storage
- Optimized queries for trace group operations
- Automatic cleanup of orphaned trace groups

#### 3. Configuration Schema Addition
**Purpose**: Define TypeScript interfaces for perdu trace configuration

**Structure**:
```typescript
export interface PerduTraceConfig {
  adapter: 'perdu'
  database: {
    host: string
    port: number
    database: string
    username: string
    password: string
  }
  options?: {
    retentionDays?: number
    batchSize?: number
    enableMetrics?: boolean
  }
}
```

### Files to Modify

#### 1. `packages/core/src/observability/tracer.ts`
**Changes**:
- Add import for PerduTraceStreamAdapter and PerduTraceGroupStreamAdapter
- Extend createTracerFactory to accept optional trace configuration
- Add conditional logic to create perdu adapters when configured
- Maintain existing file-based behavior as default

**Risk Level**: LOW - Only adds new conditional branches, preserves existing behavior

#### 2. `packages/core/src/streams/adapters/stream-adapter.ts` (Optional)
**Changes**:
- Add optional configuration interface for stream adapters
- Maintain backward compatibility with existing implementations

### Database Schema

```sql
-- Traces table for individual trace persistence
CREATE TABLE IF NOT EXISTS motia_traces (
  group_id VARCHAR(255) NOT NULL,
  trace_id VARCHAR(255) NOT NULL,
  trace_data JSONB NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'running',
  entry_point JSONB NOT NULL,
  start_time BIGINT NOT NULL,
  end_time BIGINT NULL,
  error_data JSONB NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (group_id, trace_id)
);

-- Trace groups table for trace group persistence  
CREATE TABLE IF NOT EXISTS motia_trace_groups (
  id VARCHAR(255) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  correlation_id VARCHAR(255) NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'running',
  start_time BIGINT NOT NULL,
  end_time BIGINT NULL,
  last_activity BIGINT NOT NULL,
  metadata JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Performance and query optimization indexes
CREATE INDEX idx_motia_traces_group_id ON motia_traces(group_id);
CREATE INDEX idx_motia_traces_status ON motia_traces(status);
CREATE INDEX idx_motia_traces_start_time ON motia_traces(start_time);
CREATE INDEX idx_motia_traces_created_at ON motia_traces(created_at);

CREATE INDEX idx_motia_trace_groups_status ON motia_trace_groups(status);
CREATE INDEX idx_motia_trace_groups_correlation_id ON motia_trace_groups(correlation_id);
CREATE INDEX idx_motia_trace_groups_start_time ON motia_trace_groups(start_time);
CREATE INDEX idx_motia_trace_groups_created_at ON motia_trace_groups(created_at);

-- Retention policy support
CREATE INDEX idx_motia_traces_retention ON motia_traces(created_at) WHERE status IN ('completed', 'failed');
CREATE INDEX idx_motia_trace_groups_retention ON motia_trace_groups(created_at) WHERE status IN ('completed', 'failed');
```

## 🧪 Test-Driven Development Plan

### Phase 1: Write Failing Tests First (Days 1-2)

#### 1.1 Core Unit Tests Setup
**File**: `packages/core/src/streams/adapters/__tests__/perdu-trace-stream-adapter.test.ts`

```typescript
import { DBOS } from '@dbos-inc/dbos-sdk'
import { PerduTraceStreamAdapter } from '../perdu-trace-stream-adapter'
import { Trace } from '../../observability/types'

describe('PerduTraceStreamAdapter', () => {
  let adapter: PerduTraceStreamAdapter
  let testConfig: PerduTraceConfig

  beforeAll(async () => {
    testConfig = {
      adapter: 'perdu',
      database: {
        host: 'localhost',
        port: 5433,
        database: 'motia_perdu_test',
        username: 'motia',
        password: 'motia_perdu'
      }
    }
  })

  beforeEach(async () => {
    adapter = new PerduTraceStreamAdapter(testConfig)
    await adapter.init()
    // Clean test data
    await adapter.delete('test-group', 'test-trace')
  })

  afterEach(async () => {
    // Clean up test data
    await adapter.delete('test-group', 'test-trace')
  })

  describe('Initialization', () => {
    test('should connect to PostgreSQL database', async () => {
      // This will FAIL initially - implement to make it pass
      expect(adapter).toBeDefined()
      expect(adapter.client).toBeDefined()
    })

    test('should create motia_traces table if not exists', async () => {
      // This will FAIL initially - implement schema creation
      const tableExists = await adapter.client.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_name = 'motia_traces'
        )
      `)
      expect(tableExists.rows[0].exists).toBe(true)
    })

    test('should handle connection failures gracefully', async () => {
      // This will FAIL initially - implement error handling
      const badConfig = { ...testConfig, database: { ...testConfig.database, host: 'invalid-host' } }
      const badAdapter = new PerduTraceStreamAdapter(badConfig)
      
      await expect(badAdapter.init()).rejects.toThrow()
    })
  })

  describe('Basic Trace Operations', () => {
    const mockTrace: Trace = {
      id: 'test-trace',
      name: 'test-step',
      status: 'running',
      startTime: Date.now(),
      entryPoint: { type: 'step', stepName: 'test-step' },
      events: []
    }

    test('should set and get trace data', async () => {
      // This will FAIL initially - implement get/set methods
      await adapter.set('test-group', 'test-trace', mockTrace)
      const result = await adapter.get('test-group', 'test-trace')
      
      expect(result).toBeDefined()
      expect(result?.id).toBe('test-trace')
      expect(result?.name).toBe('test-step')
      expect(result?.status).toBe('running')
    })

    test('should handle complex trace data with events', async () => {
      // This will FAIL initially - implement JSON handling
      const complexTrace: Trace = {
        ...mockTrace,
        events: [
          { type: 'state', timestamp: Date.now(), operation: 'set', data: { key: 'value' } },
          { type: 'emit', timestamp: Date.now(), topic: 'test', data: { message: 'test' } }
        ]
      }

      await adapter.set('test-group', 'test-trace', complexTrace)
      const result = await adapter.get('test-group', 'test-trace')
      
      expect(result?.events).toHaveLength(2)
      expect(result?.events[0].type).toBe('state')
      expect(result?.events[1].type).toBe('emit')
    })

    test('should return null for non-existent traces', async () => {
      // This will FAIL initially
      const result = await adapter.get('test-group', 'non-existent-trace')
      expect(result).toBeNull()
    })

    test('should delete existing traces', async () => {
      // This will FAIL initially
      await adapter.set('test-group', 'delete-trace', mockTrace)
      const deleted = await adapter.delete('test-group', 'delete-trace')
      
      expect(deleted).toBeDefined()
      expect(deleted?.id).toBe('delete-trace')
      
      const result = await adapter.get('test-group', 'delete-trace')
      expect(result).toBeNull()
    })
  })

  describe('Group Operations', () => {
    test('should retrieve all traces for a group', async () => {
      // This will FAIL initially - implement getGroup method
      const trace1 = { ...mockTrace, id: 'trace1', name: 'step1' }
      const trace2 = { ...mockTrace, id: 'trace2', name: 'step2' }
      
      await adapter.set('group-traces', 'trace1', trace1)
      await adapter.set('group-traces', 'trace2', trace2)
      
      const result = await adapter.getGroup('group-traces')
      expect(result).toHaveLength(2)
      expect(result.map(t => t.id)).toContain('trace1')
      expect(result.map(t => t.id)).toContain('trace2')
    })

    test('should return empty array for non-existent group', async () => {
      // This will FAIL initially
      const result = await adapter.getGroup('non-existent-group')
      expect(result).toEqual([])
    })
  })

  describe('Status Tracking', () => {
    test('should update trace status correctly', async () => {
      // This will FAIL initially - implement status updates
      const runningTrace = { ...mockTrace, status: 'running' as const }
      await adapter.set('status-group', 'status-trace', runningTrace)
      
      const completedTrace = { ...runningTrace, status: 'completed' as const, endTime: Date.now() }
      await adapter.set('status-group', 'status-trace', completedTrace)
      
      const result = await adapter.get('status-group', 'status-trace')
      expect(result?.status).toBe('completed')
      expect(result?.endTime).toBeDefined()
    })

    test('should handle error states with error data', async () => {
      // This will FAIL initially - implement error handling
      const errorTrace = { 
        ...mockTrace, 
        status: 'failed' as const, 
        endTime: Date.now(),
        error: { message: 'Test error', code: 'TEST_ERROR' }
      }
      
      await adapter.set('error-group', 'error-trace', errorTrace)
      const result = await adapter.get('error-group', 'error-trace')
      
      expect(result?.status).toBe('failed')
      expect(result?.error?.message).toBe('Test error')
    })
  })
})
```

#### 1.2 Trace Group Adapter Tests
**File**: `packages/core/src/streams/adapters/__tests__/perdu-trace-group-stream-adapter.test.ts`

```typescript
import { PerduTraceGroupStreamAdapter } from '../perdu-trace-group-stream-adapter'
import { TraceGroup } from '../../observability/types'

describe('PerduTraceGroupStreamAdapter', () => {
  let adapter: PerduTraceGroupStreamAdapter
  let testConfig: PerduTraceConfig

  beforeEach(async () => {
    adapter = new PerduTraceGroupStreamAdapter(testConfig)
    await adapter.init()
  })

  describe('Trace Group Operations', () => {
    const mockTraceGroup: TraceGroup = {
      id: 'test-group',
      correlationId: 'corr-123',
      name: 'test-flow',
      status: 'running',
      startTime: Date.now(),
      lastActivity: Date.now(),
      metadata: {
        completedSteps: 0,
        activeSteps: 1,
        totalSteps: 1
      }
    }

    test('should set and get trace group data', async () => {
      // This will FAIL initially - implement trace group operations
      await adapter.set('default', 'test-group', mockTraceGroup)
      const result = await adapter.get('default', 'test-group')
      
      expect(result).toBeDefined()
      expect(result?.id).toBe('test-group')
      expect(result?.name).toBe('test-flow')
      expect(result?.status).toBe('running')
    })

    test('should handle trace group metadata correctly', async () => {
      // This will FAIL initially - implement metadata handling
      await adapter.set('default', 'metadata-group', mockTraceGroup)
      const result = await adapter.get('default', 'metadata-group')
      
      expect(result?.metadata).toBeDefined()
      expect(result?.metadata.completedSteps).toBe(0)
      expect(result?.metadata.activeSteps).toBe(1)
      expect(result?.metadata.totalSteps).toBe(1)
    })
  })
})
```

#### 1.3 Integration Tests Setup
**File**: `packages/core/src/observability/__tests__/perdu-tracer-integration.test.ts`

```typescript
import { createTracerFactory } from '../tracer'
import { PerduTraceStreamAdapter } from '../../streams/adapters/perdu-trace-stream-adapter'

describe('Perdu Tracer Integration', () => {
  test('should create perdu trace adapters when configured', () => {
    // This will FAIL initially - implement factory logic
    const mockLockedData = {
      traceConfig: {
        adapter: 'perdu',
        database: {
          host: 'localhost',
          port: 5433,
          database: 'motia_perdu_test',
          username: 'motia',  
          password: 'motia_perdu'
        }
      }
    }
    
    const tracerFactory = createTracerFactory(mockLockedData as any)
    expect(tracerFactory).toBeDefined()
    // Test that perdu adapters are used instead of file adapters
  })

  test('should fall back to file adapters when perdu config invalid', () => {
    // This will FAIL initially - implement fallback logic
    const mockLockedData = {
      traceConfig: {
        adapter: 'perdu',
        database: {
          host: '',
          port: 0,
          database: '',
          username: '',
          password: ''
        }
      }
    }
    
    const tracerFactory = createTracerFactory(mockLockedData as any)
    expect(tracerFactory).toBeDefined()
    // Test that file adapters are used as fallback
  })

  test('should maintain existing behavior with no trace configuration', () => {
    // This should PASS - existing functionality
    const mockLockedData = { /* no traceConfig */ }
    
    const tracerFactory = createTracerFactory(mockLockedData as any)
    expect(tracerFactory).toBeDefined()
    // Test that existing file-based behavior is preserved
  })
})
```

### Phase 2: Implement to Make Tests Pass (Days 3-5)

#### 2.1 Basic Implementation Structure
**File**: `packages/core/src/streams/adapters/perdu-trace-stream-adapter.ts`

```typescript
import { DBOS } from '@dbos-inc/dbos-sdk'
import { Client } from 'pg'
import { StreamAdapter } from './stream-adapter'
import { BaseStreamItem } from '../../types-stream'
import { Trace } from '../../observability/types'

export interface PerduTraceConfig {
  adapter: 'perdu'
  database: {
    host: string
    port: number
    database: string
    username: string
    password: string
  }
  options?: {
    retentionDays?: number
    batchSize?: number
    enableMetrics?: boolean
  }
}

export class PerduTraceStreamAdapter extends StreamAdapter<Trace> {
  public client: Client
  
  constructor(private config: PerduTraceConfig) {
    super()
    this.client = new Client({
      host: config.database.host,
      port: config.database.port,
      database: config.database.database,
      user: config.database.username,
      password: config.database.password
    })
  }

  @DBOS.transaction()
  async init(): Promise<void> {
    // Initialize database schema using DBOS transaction for durability
    await DBOS.sql`
      CREATE TABLE IF NOT EXISTS motia_traces (
        group_id VARCHAR(255) NOT NULL,
        trace_id VARCHAR(255) NOT NULL,
        trace_data JSONB NOT NULL,
        status VARCHAR(50) NOT NULL DEFAULT 'running',
        created_at TIMESTAMP DEFAULT NOW(),
        PRIMARY KEY (group_id, trace_id)
      )
    `;
    // START FAILING - implement to make tests pass
    throw new Error('Not implemented yet - TDD implementation needed')
  }

  @DBOS.transaction()
  async get(groupId: string, id: string): Promise<BaseStreamItem<Trace> | null> {
    // Use DBOS SQL operations for durable trace retrieval
    const result = await DBOS.sql`
      SELECT trace_data FROM motia_traces 
      WHERE group_id = ${groupId} AND trace_id = ${id}
    `;
    // START FAILING - implement to make tests pass
    throw new Error('Not implemented yet - TDD implementation needed')
  }

  @DBOS.transaction()
  async set(groupId: string, id: string, data: Trace): Promise<BaseStreamItem<Trace>> {
    // Use DBOS SQL operations for durable trace persistence
    await DBOS.sql`
      INSERT INTO motia_traces (group_id, trace_id, trace_data, status)
      VALUES (${groupId}, ${id}, ${JSON.stringify(data)}, ${data.status})
      ON CONFLICT (group_id, trace_id) 
      DO UPDATE SET trace_data = EXCLUDED.trace_data, status = EXCLUDED.status
    `;
    // START FAILING - implement to make tests pass
    throw new Error('Not implemented yet - TDD implementation needed')
  }

  // ... other methods will start failing and be implemented incrementally
}
```

#### 2.2 TDD Implementation Cycle
For each test case:
1. **Run test** → See it FAIL
2. **Write minimal code** to make it PASS  
3. **Refactor** if needed
4. **Move to next test**

#### 2.3 Implementation Milestones
- **Day 3**: Database connection and schema creation tests pass
- **Day 4**: Basic trace get/set operations tests pass
- **Day 5**: Group operations and status tracking tests pass

### Phase 3: Integration & Performance Testing (Days 6-7)

#### 3.1 Multi-Instance Testing
**File**: `packages/core/src/__tests__/perdu-trace-multi-instance.test.ts`

```typescript
describe('Multi-Instance Trace Sharing', () => {
  let adapter1: PerduTraceStreamAdapter
  let adapter2: PerduTraceStreamAdapter

  beforeEach(async () => {
    // Two separate adapter instances sharing same database
    adapter1 = new PerduTraceStreamAdapter(testConfig)
    adapter2 = new PerduTraceStreamAdapter(testConfig)
    await adapter1.init()
    await adapter2.init()
  })

  test('should share traces between multiple instances', async () => {
    // Write with instance 1, read with instance 2
    await adapter1.set('shared-group', 'shared-trace', mockTrace)
    const result = await adapter2.get('shared-group', 'shared-trace')
    expect(result?.id).toBe('shared-trace')
  })

  test('should handle concurrent trace updates across instances', async () => {
    const promises = []
    
    // Concurrent modifications from both instances
    for (let i = 0; i < 5; i++) {
      promises.push(adapter1.set('concurrent-group', `trace-${i}`, { ...mockTrace, id: `trace-${i}` }))
      promises.push(adapter2.set('concurrent-group', `trace-${i + 5}`, { ...mockTrace, id: `trace-${i + 5}` }))
    }
    
    await Promise.all(promises)
    
    // Verify all modifications are persisted correctly
    const group = await adapter1.getGroup('concurrent-group')
    expect(group).toHaveLength(10)
  })
})
```

#### 3.2 Performance Testing
**File**: `packages/core/src/streams/adapters/__tests__/perdu-trace-performance.test.ts`

```typescript
describe('PerduTraceStreamAdapter Performance', () => {
  let adapter: PerduTraceStreamAdapter

  test('should perform trace operations within acceptable latency', async () => {
    const startTime = Date.now()
    const iterations = 100
    
    for (let i = 0; i < iterations; i++) {
      await adapter.set('perf-group', `trace-${i}`, { ...mockTrace, id: `trace-${i}` })
      await adapter.get('perf-group', `trace-${i}`)
    }
    
    const avgLatency = (Date.now() - startTime) / (iterations * 2)
    expect(avgLatency).toBeLessThan(100) // < 100ms average for set+get
  })

  test('should handle large trace payloads efficiently', async () => {
    const largeTrace = {
      ...mockTrace,
      events: Array.from({ length: 1000 }, (_, i) => ({
        type: 'state',
        timestamp: Date.now(),
        operation: 'set',
        data: { iteration: i, payload: 'large-data'.repeat(10) }
      }))
    }
    
    const startTime = Date.now()
    await adapter.set('large-group', 'large-trace', largeTrace)
    const result = await adapter.get('large-group', 'large-trace')
    const duration = Date.now() - startTime
    
    expect(result?.events).toHaveLength(1000)
    expect(duration).toBeLessThan(5000) // < 5 seconds for large payload
  })
})
```

## Configuration Examples

### Development (File-based - Default)
```yaml
# No trace config - uses existing file-based trace storage
# This maintains existing behavior
```

### Production (Perdu Traces)
```yaml
observability:
  traces:
    adapter: perdu
    database:
      host: postgres.example.com
      port: 5432
      database: motia_perdu
      username: motia_traces
      password: "${PERDU_DB_PASSWORD}"
    options:
      retentionDays: 30
      batchSize: 100
      enableMetrics: true
```

### Hybrid Configuration (Development with PostgreSQL)
```yaml
observability:
  traces:
    adapter: perdu
    database:
      host: localhost
      port: 5433
      database: motia_perdu_dev
      username: motia
      password: "${PERDU_DB_PASSWORD}"
    # Use default options
```

## Success Criteria
- [ ] All existing trace/observability tests pass
- [ ] New perdu trace adapters pass comprehensive test suite
- [ ] Zero breaking changes to existing trace functionality
- [ ] Multi-instance trace sharing works correctly
- [ ] Trace persistence survives instance restarts
- [ ] Performance benchmarks within 10x of file adapter (acceptable for durability gains)
- [ ] Configuration-driven activation works as expected
- [ ] SQL-based trace queries work for debugging/monitoring
- [ ] Documentation updated with perdu trace configuration

## Risk Mitigation
1. **Database Connection Failures**: Graceful fallback to file storage with error logging
2. **Schema Changes**: Use database migrations for schema evolution
3. **Performance Regression**: Optimize with database indexes and connection pooling
4. **Large Trace Payloads**: Implement payload size limits and compression
5. **Retention Management**: Automated cleanup of old traces based on configuration

## Deployment Considerations
- Requires PostgreSQL database (can share with state/events adapters)
- Database indexes for query performance
- Monitoring for trace storage growth and performance
- Automated trace retention policies
- Connection pooling for high-throughput scenarios

## Dependencies
- `@dbos-inc/dbos-sdk@^1.0.0`
- `pg@^8.11.0` and `@types/pg@^8.10.0` (from PR #1)
- PostgreSQL database with JSON support
- Existing StreamAdapter interface
- Shared database connection patterns from other perdu adapters

## Estimated Effort
**Development**: 5 days
**Testing**: 2 days  
**Documentation**: 1 day
**Total**: 1 week

## Integration Notes
- This PR builds on PR #1 (Perdu State Adapter) for database patterns
- Can share database connection and configuration with state/event adapters
- Can be deployed independently or together with other perdu adapters
- Maintains complete backward compatibility with existing file-based trace storage
- Provides foundation for advanced observability features (trace analytics, debugging tools)