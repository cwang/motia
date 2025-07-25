# PR #1: perdu State Adapter Implementation

## Scope
Implement perdu as an optional state backend adapter without modifying core execution logic, following the established StateAdapter interface pattern.

## Implementation Specification

### Phase 1 Objectives
- Add perdu as optional state persistence backend
- Maintain 100% backward compatibility with existing state adapters
- Follow existing adapter patterns for seamless integration
- Enable configuration-driven activation

### Files to Create

#### 1. `packages/core/src/state/adapters/dbos-state-adapter.ts`
**Purpose**: New perdu-backed state adapter implementing StateAdapter interface

**Key Features**:
- Implements complete StateAdapter interface with PostgreSQL backend
- Uses perdu SDK for durable step execution
- Supports all existing state operations (get, set, delete, clear, getGroup)
- Automatic type conversion to match existing behavior
- Database schema initialization

**Dependencies**:
- `@dbos-inc/dbos-sdk` (new dependency)
- Existing StateAdapter interface
- PostgreSQL database connection

#### 2. Configuration Schema Addition
**Purpose**: Define TypeScript interfaces for perdu state configuration

**Structure**:
```typescript
export interface perduStateConfig {
  adapter: 'dbos'
  database: {
    host: string
    port: number
    database: string
    username: string
    password: string
  }
}
```

### Files to Modify

#### 1. `packages/core/src/state/create-state-adapter.ts`
**Changes**:
- Add import for perduStateAdapter
- Extend AdapterConfig type union with perduStateConfig
- Add conditional branch for 'dbos' adapter type
- Maintain existing factory function behavior

**Risk Level**: LOW - Only adds new conditional branch, no changes to existing logic

#### 2. `package.json` (workspace root)
**Changes**:
- Add `@dbos-inc/dbos-sdk` as dependency
- Add `pg` and `@types/pg` for PostgreSQL support

### Database Schema

```sql
CREATE TABLE IF NOT EXISTS motia_state (
  trace_id VARCHAR(255) NOT NULL,
  key VARCHAR(255) NOT NULL,
  value JSONB NOT NULL,
  type VARCHAR(50) NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (trace_id, key)
);

CREATE INDEX idx_motia_state_trace_id ON motia_state(trace_id);
CREATE INDEX idx_motia_state_updated_at ON motia_state(updated_at);
```

## 🧪 Test-Driven Development Plan

### Phase 1: Write Failing Tests First (Days 1-2)

#### 1.1 Core Unit Tests Setup
**File**: `packages/core/src/state/adapters/__tests__/dbos-state-adapter.test.ts`

```typescript
import { perduStateAdapter } from '../dbos-state-adapter'
import { perdu } from '@dbos-inc/dbos-sdk'

describe('perduStateAdapter', () => {
  let adapter: perduStateAdapter
  let testConfig: perduStateConfig

  beforeAll(async () => {
    testConfig = {
      adapter: 'dbos',
      database: {
        host: 'localhost',
        port: 5432,
        database: 'motia_test',
        username: 'motia',
        password: 'motia_dev'
      }
    }
  })

  beforeEach(async () => {
    adapter = new perduStateAdapter(testConfig)
    await adapter.init()
    // Clean test data
    await adapter.clear('test-trace-id')
  })

  afterEach(async () => {
    // Clean up test data
    await adapter.clear('test-trace-id')
  })

  describe('Initialization', () => {
    test('should connect to PostgreSQL database', async () => {
      // This will FAIL initially - implement to make it pass
      expect(adapter).toBeDefined()
      expect(adapter.dbos).toBeDefined()
    })

    test('should create motia_state table if not exists', async () => {
      // This will FAIL initially - implement schema creation
      const tableExists = await adapter.dbos.sql`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_name = 'motia_state'
        )
      `
      expect(tableExists[0].exists).toBe(true)
    })

    test('should handle connection failures gracefully', async () => {
      // This will FAIL initially - implement error handling
      const badConfig = { ...testConfig, database: { ...testConfig.database, host: 'invalid-host' } }
      const badAdapter = new perduStateAdapter(badConfig)
      
      await expect(badAdapter.init()).rejects.toThrow()
    })
  })

  describe('Basic State Operations', () => {
    test('should set and get string values', async () => {
      // This will FAIL initially - implement get/set methods
      await adapter.set('test-trace-id', 'string-key', 'test-value')
      const result = await adapter.get('test-trace-id', 'string-key')
      expect(result).toBe('test-value')
      expect(typeof result).toBe('string')
    })

    test('should set and get number values', async () => {
      // This will FAIL initially
      await adapter.set('test-trace-id', 'number-key', 42)
      const result = await adapter.get('test-trace-id', 'number-key')
      expect(result).toBe(42)
      expect(typeof result).toBe('number')
    })

    test('should set and get boolean values', async () => {
      // This will FAIL initially
      await adapter.set('test-trace-id', 'boolean-key', true)
      const result = await adapter.get('test-trace-id', 'boolean-key')
      expect(result).toBe(true)
      expect(typeof result).toBe('boolean')
    })

    test('should set and get object values', async () => {
      // This will FAIL initially
      const testObj = { nested: { value: 'test' }, array: [1, 2, 3] }
      await adapter.set('test-trace-id', 'object-key', testObj)
      const result = await adapter.get('test-trace-id', 'object-key')
      expect(result).toEqual(testObj)
    })

    test('should return undefined for non-existent keys', async () => {
      // This will FAIL initially
      const result = await adapter.get('test-trace-id', 'non-existent-key')
      expect(result).toBeUndefined()
    })

    test('should delete existing keys', async () => {
      // This will FAIL initially
      await adapter.set('test-trace-id', 'delete-key', 'delete-value')
      await adapter.delete('test-trace-id', 'delete-key')
      const result = await adapter.get('test-trace-id', 'delete-key')
      expect(result).toBeUndefined()
    })

    test('should clear all keys for a trace ID', async () => {
      // This will FAIL initially
      await adapter.set('test-trace-id', 'key1', 'value1')
      await adapter.set('test-trace-id', 'key2', 'value2')
      await adapter.clear('test-trace-id')
      
      const result1 = await adapter.get('test-trace-id', 'key1')
      const result2 = await adapter.get('test-trace-id', 'key2')
      expect(result1).toBeUndefined()
      expect(result2).toBeUndefined()
    })
  })

  describe('Group Operations', () => {
    test('should retrieve all keys for a group ID', async () => {
      // This will FAIL initially - implement getGroup method
      await adapter.set('group-id', 'key1', 'value1')
      await adapter.set('group-id', 'key2', 'value2')
      
      const result = await adapter.getGroup('group-id')
      expect(result).toHaveLength(2)
      expect(result).toEqual(expect.arrayContaining([
        { key: 'key1', value: 'value1' },
        { key: 'key2', value: 'value2' }
      ]))
    })

    test('should return empty array for non-existent group', async () => {
      // This will FAIL initially
      const result = await adapter.getGroup('non-existent-group')
      expect(result).toEqual([])
    })
  })

  describe('Error Handling', () => {
    test('should handle database connection errors', async () => {
      // This will FAIL initially - implement connection error handling
      // Mock database failure
      jest.spyOn(adapter.dbos, 'sql').mockRejectedValueOnce(new Error('Connection failed'))
      
      await expect(adapter.get('test-trace-id', 'key')).rejects.toThrow('Connection failed')
    })

    test('should handle invalid JSON data gracefully', async () => {
      // This will FAIL initially - implement JSON error handling
      // Manually insert invalid JSON to test recovery
      await adapter.dbos.sql`
        INSERT INTO motia_state (trace_id, key, value, type)
        VALUES ('test-trace-id', 'invalid-json', 'invalid-json-string', 'string')
      `
      
      // Should not crash the adapter
      const result = await adapter.get('test-trace-id', 'invalid-json')
      expect(result).toBeDefined() // Should handle gracefully
    })
  })

  describe('Type Conversion', () => {
    test('should preserve type information through database round-trip', async () => {
      // This will FAIL initially - implement type preservation
      const testCases = [
        { key: 'string', value: 'test-string', expectedType: 'string' },
        { key: 'number', value: 42, expectedType: 'number' },
        { key: 'boolean', value: true, expectedType: 'boolean' },
        { key: 'object', value: { test: 'value' }, expectedType: 'object' },
        { key: 'array', value: [1, 2, 3], expectedType: 'object' },
        { key: 'null', value: null, expectedType: 'object' }
      ]

      for (const testCase of testCases) {
        await adapter.set('test-trace-id', testCase.key, testCase.value)
        const result = await adapter.get('test-trace-id', testCase.key)
        
        expect(result).toEqual(testCase.value)
        expect(typeof result).toBe(testCase.expectedType)
      }
    })
  })
})
```

#### 1.2 Integration Tests Setup
**File**: `packages/core/src/state/__tests__/state-adapter-integration.test.ts`

```typescript
import { createStateAdapter } from '../create-state-adapter'
import { perduStateAdapter } from '../adapters/dbos-state-adapter'
import { FileStateAdapter } from '../adapters/default-state-adapter'

describe('State Adapter Factory Integration', () => {
  test('should create perduStateAdapter when config.adapter === "dbos"', () => {
    // This will FAIL initially - implement factory logic
    const config = {
      adapter: 'dbos' as const,
      database: {
        host: 'localhost',
        port: 5432,
        database: 'motia_test',
        username: 'motia',
        password: 'motia_dev'
      }
    }
    
    const adapter = createStateAdapter(config)
    expect(adapter).toBeInstanceOf(perduStateAdapter)
  })

  test('should fall back to FileStateAdapter when perdu config invalid', () => {
    // This will FAIL initially - implement fallback logic
    const invalidConfig = {
      adapter: 'dbos' as const,
      database: {
        host: '',
        port: 0,
        database: '',
        username: '',
        password: ''
      }
    }
    
    const adapter = createStateAdapter(invalidConfig)
    expect(adapter).toBeInstanceOf(FileStateAdapter)
  })

  test('should maintain existing adapter creation for other types', () => {
    // This should PASS - existing functionality
    const fileConfig = { adapter: 'default' as const, path: '/tmp/test' }
    const memoryConfig = { adapter: 'memory' as const }
    
    const fileAdapter = createStateAdapter(fileConfig)
    const memoryAdapter = createStateAdapter(memoryConfig)
    
    expect(fileAdapter).toBeInstanceOf(FileStateAdapter)
    expect(memoryAdapter).toBeDefined() // MemoryStateAdapter
  })
})
```

#### 1.3 Performance Test Setup
**File**: `packages/core/src/state/__tests__/dbos-state-performance.test.ts`

```typescript
describe('perduStateAdapter Performance', () => {
  let adapter: perduStateAdapter

  beforeEach(async () => {
    adapter = new perduStateAdapter(testConfig)
    await adapter.init()
  })

  test('should perform get operations within acceptable latency', async () => {
    // This will FAIL initially - optimize implementation
    await adapter.set('perf-trace', 'test-key', 'test-value')
    
    const startTime = Date.now()
    const iterations = 100
    
    for (let i = 0; i < iterations; i++) {
      await adapter.get('perf-trace', 'test-key')
    }
    
    const avgLatency = (Date.now() - startTime) / iterations
    expect(avgLatency).toBeLessThan(50) // < 50ms average
  })

  test('should handle concurrent operations without corruption', async () => {
    // This will FAIL initially - implement concurrency safety
    const promises = []
    const traceId = 'concurrent-trace'
    
    // Concurrent writes
    for (let i = 0; i < 10; i++) {
      promises.push(adapter.set(traceId, `key-${i}`, `value-${i}`))
    }
    
    await Promise.all(promises)
    
    // Verify all values are correct
    for (let i = 0; i < 10; i++) {
      const result = await adapter.get(traceId, `key-${i}`)
      expect(result).toBe(`value-${i}`)
    }
  })
})
```

### Phase 2: Implement to Make Tests Pass (Days 3-7)

#### 2.1 Basic Implementation Structure
**File**: `packages/core/src/state/adapters/dbos-state-adapter.ts`

```typescript
import { perdu } from '@dbos-inc/dbos-sdk'
import { StateAdapter } from '../state-adapter'

export interface perduStateConfig {
  adapter: 'dbos'
  database: {
    host: string
    port: number
    database: string
    username: string
    password: string
  }
}

export class perduStateAdapter implements StateAdapter {
  public dbos: perdu
  
  constructor(private config: perduStateConfig) {
    // Initial failing implementation - will make tests pass incrementally
    this.dbos = new perdu({
      database: config.database,
      application: { name: 'motia-state', version: '1.0.0' }
    })
  }

  async init(): Promise<void> {
    // START FAILING - implement to make tests pass
    throw new Error('Not implemented yet - TDD implementation needed')
  }

  async get(traceId: string, key: string): Promise<unknown> {
    // START FAILING - implement to make tests pass
    throw new Error('Not implemented yet - TDD implementation needed')
  }

  async set(traceId: string, key: string, value: unknown): Promise<void> {
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
- **Day 4**: Basic get/set operations tests pass
- **Day 5**: Type conversion and group operations tests pass
- **Day 6**: Error handling and edge cases tests pass
- **Day 7**: Performance and concurrency tests pass

### Phase 3: Integration & Advanced Testing (Days 8-10)

#### 3.1 Multi-Instance Testing
**File**: `packages/core/src/__tests__/dbos-state-multi-instance.test.ts`

```typescript
describe('Multi-Instance State Sharing', () => {
  let adapter1: perduStateAdapter
  let adapter2: perduStateAdapter

  beforeEach(async () => {
    // Two separate adapter instances sharing same database
    adapter1 = new perduStateAdapter(testConfig)
    adapter2 = new perduStateAdapter(testConfig)
    await adapter1.init()
    await adapter2.init()
  })

  test('should share state between multiple instances', async () => {
    // Write with instance 1, read with instance 2
    await adapter1.set('shared-trace', 'shared-key', 'shared-value')
    const result = await adapter2.get('shared-trace', 'shared-key')
    expect(result).toBe('shared-value')
  })

  test('should handle concurrent modifications across instances', async () => {
    const promises = []
    
    // Concurrent modifications from both instances
    for (let i = 0; i < 5; i++) {
      promises.push(adapter1.set('concurrent-trace', `key-${i}`, `value1-${i}`))
      promises.push(adapter2.set('concurrent-trace', `key-${i + 5}`, `value2-${i}`))
    }
    
    await Promise.all(promises)
    
    // Verify all modifications are persisted correctly
    for (let i = 0; i < 5; i++) {
      const result1 = await adapter1.get('concurrent-trace', `key-${i}`)
      const result2 = await adapter2.get('concurrent-trace', `key-${i + 5}`)
      expect(result1).toBe(`value1-${i}`)
      expect(result2).toBe(`value2-${i}`)
    }
  })
})
```

### Phase 4: Comprehensive Test Coverage

#### 4.1 Test Coverage Requirements
- **Unit Tests**: 100% line and branch coverage
- **Integration Tests**: All adapter factory scenarios  
- **Performance Tests**: Latency and throughput benchmarks
- **Multi-Instance Tests**: Cross-instance state sharing
- **Error Handling Tests**: All failure modes covered

#### 4.2 Continuous Testing Commands
```bash
# Run tests in watch mode during development
npm test -- --watch packages/core/src/state

# Run with coverage
npm test -- --coverage packages/core/src/state

# Run performance benchmarks
npm test -- packages/core/src/state/__tests__/dbos-state-performance.test.ts

# Run multi-instance tests (requires PostgreSQL)
npm test -- packages/core/src/__tests__/dbos-state-multi-instance.test.ts
```

### Test Execution Order (TDD)
1. **Day 1**: Write ALL failing tests
2. **Day 2**: Set up test infrastructure and mocks
3. **Days 3-7**: Implement features to make tests pass (one test at a time)
4. **Days 8-9**: Multi-instance and integration testing
5. **Day 10**: Performance optimization and final validation

**Key TDD Principle**: Never write production code without a failing test first!

## Configuration Examples

### Development (Disabled)
```yaml
# No perdu config - uses existing file adapter
state:
  adapter: file
  path: .motia/state
```

### Production (Enabled)
```yaml
state:
  adapter: dbos
  database:
    host: localhost
    port: 5432
    database: motia_dbos
    username: motia
    password: "${MOTIA_DB_PASSWORD}"
```

## Success Criteria
- [ ] All existing state adapter tests pass
- [ ] New perdu state adapter passes comprehensive test suite
- [ ] Zero breaking changes to existing functionality
- [ ] Documentation updated with perdu configuration options
- [ ] Performance benchmarks within 10% of file adapter for single instance
- [ ] Multi-instance state sharing works correctly
- [ ] Configuration-driven activation works as expected

## Risk Mitigation
1. **Database Connection Failures**: Graceful fallback with error logging
2. **Schema Changes**: Use perdu SDK migration capabilities
3. **Performance Regression**: Benchmark against existing adapters
4. **Configuration Errors**: Validate config and provide clear error messages

## Deployment Considerations
- Requires PostgreSQL database setup
- Environment variables for database credentials
- Database schema migration on first startup
- Monitoring for database connection health

## Dependencies
- `@dbos-inc/dbos-sdk@^1.0.0`
- `pg@^8.11.0`
- `@types/pg@^8.10.0`

## Estimated Effort
**Development**: 8-10 days
**Testing**: 3-4 days
**Documentation**: 1-2 days
**Total**: 2 weeks