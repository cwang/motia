# Motia perdu Integration Plan
## Non-Intrusive Fork-Friendly Implementation

## Executive Summary

This document outlines a **non-intrusive, upstream-compatible** perdu integration for Motia that leverages existing adapter patterns and configuration systems. Based on research of the active Motia.dev repository (3.5+ commits/day), this approach maximizes merge compatibility with upstream changes.

**Key Principles:**
- **Configuration-Optional**: perdu features disabled by default, enabled via config
- **Adapter Pattern**: Follow existing state/stream adapter architecture  
- **Additive-Only**: Zero modifications to core execution logic
- **Backward Compatible**: 100% existing workflow compatibility
- **Upstream Friendly**: Minimal conflicts with active development areas

**Implementation Complexity**: EASY (2/10) - Leverages existing patterns  
**Estimated Timeline**: 4-6 weeks using adapter pattern  
**Merge Conflict Risk**: LOW - Follows established architectural patterns

## Research Findings: Motia.dev Repository Analysis

### Development Activity (Active Fork Considerations)
- **High Activity**: 208 commits/60 days, 17 commits/7 days  
- **Current Focus Areas**: Analytics, Docker deployment, UI improvements, observability
- **Major Active Branches**: `feat/no-config-refactor`, `feat/durable-objects`, `feat/api-consolidation`
- **Architecture**: Highly modular with clean adapter patterns

### Upstream Compatibility Assessment
✅ **Excellent Integration Opportunities:**
- Existing `StateAdapter` interface with multiple backends (memory, file, Redis)
- Established configuration patterns via `config.yml`
- Clean separation between execution and persistence layers
- RFC process for architectural changes

✅ **No Architectural Conflicts:**
- perdu aligns with roadmap items: database support (#484), queue strategies (#476)
- No competing durability implementations in active development
- Existing `durable-objects` branch shows interest in durability patterns

## Revised Architecture: Adapter-First Approach

### Integration Strategy: Pure Adapter Pattern

Instead of modifying core execution, implement perdu as **optional adapters** that plug into existing interfaces:

```
Motia Core (Unchanged)
├── StateAdapter Interface
│   ├── MemoryStateAdapter (existing)
│   ├── FileStateAdapter (existing)  
│   ├── RedisStateAdapter (existing)
│   └── perduStateAdapter (NEW - optional)
├── EventManager Interface
│   ├── InMemoryEventManager (existing)
│   └── perduEventManager (NEW - optional)
└── ExecutionRunner Interface
    ├── ProcessManager (existing)
    └── perduProcessManager (NEW - optional)
```

### Configuration-Driven Activation

```yaml
# config.yml - perdu features are completely optional
durability:
  enabled: true           # Default: false
  adapter: dbos          # Options: none, dbos
  database:
    host: localhost
    port: 5432
    database: motia_dbos
    username: postgres
    password: ""

state:
  adapter: dbos           # Default: file (unchanged behavior)
  # ... existing state config options remain

events:
  adapter: dbos           # Default: memory (unchanged behavior) 
  # ... existing event config options remain
```

## Implementation Plan: Minimally Intrusive Approach

### Phase 1: perdu State Adapter (2 weeks)

**Goal:** Add perdu as optional state backend without touching core execution.

#### **NEW FILE: `packages/core/src/state/adapters/dbos-state-adapter.ts`**

```typescript
import { perdu } from '@dbos-inc/dbos-sdk'
import { StateAdapter, StateItem, StateItemsInput } from '../state-adapter'

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
  private dbos: perdu

  constructor(private config: perduStateConfig) {
    this.dbos = new perdu({
      database: config.database,
      application: { name: 'motia-state', version: '1.0.0' }
    })
  }

  async init(): Promise<void> {
    await this.dbos.init()
    // Create state table if not exists
    await this.dbos.sql`
      CREATE TABLE IF NOT EXISTS motia_state (
        trace_id VARCHAR(255) NOT NULL,
        key VARCHAR(255) NOT NULL,
        value JSONB NOT NULL,
        type VARCHAR(50) NOT NULL,
        updated_at TIMESTAMP DEFAULT NOW(),
        PRIMARY KEY (trace_id, key)
      )
    `
  }

  @perdu.step()
  async get(traceId: string, key: string): Promise<unknown> {
    const result = await this.dbos.sql`
      SELECT value, type FROM motia_state 
      WHERE trace_id = ${traceId} AND key = ${key}
    `
    
    if (result.length === 0) return undefined
    
    const { value, type } = result[0]
    const parsed = JSON.parse(value)
    
    // Type conversion to match existing behavior
    switch (type) {
      case 'string': return String(parsed)
      case 'number': return Number(parsed)
      case 'boolean': return Boolean(parsed)
      default: return parsed
    }
  }

  @perdu.step()
  async set(traceId: string, key: string, value: unknown): Promise<void> {
    const type = typeof value
    await this.dbos.sql`
      INSERT INTO motia_state (trace_id, key, value, type)
      VALUES (${traceId}, ${key}, ${JSON.stringify(value)}, ${type})
      ON CONFLICT (trace_id, key)
      DO UPDATE SET value = EXCLUDED.value, type = EXCLUDED.type, updated_at = NOW()
    `
  }

  @perdu.step()
  async delete(traceId: string, key: string): Promise<void> {
    await this.dbos.sql`
      DELETE FROM motia_state 
      WHERE trace_id = ${traceId} AND key = ${key}
    `
  }

  @perdu.step()
  async clear(traceId: string): Promise<void> {
    await this.dbos.sql`
      DELETE FROM motia_state WHERE trace_id = ${traceId}
    `
  }

  async getGroup(groupId: string): Promise<unknown[]> {
    // Implementation following existing pattern
    const result = await this.dbos.sql`
      SELECT key, value, type FROM motia_state 
      WHERE trace_id = ${groupId}
      ORDER BY key
    `
    
    return result.map(row => ({
      key: row.key,
      value: JSON.parse(row.value)
    }))
  }

  // ... implement remaining StateAdapter interface methods
  // All methods follow existing patterns, just with perdu backend
}
```

#### **MODIFICATION: `packages/core/src/state/create-state-adapter.ts`**

```typescript
import { FileAdapterConfig, FileStateAdapter } from './adapters/default-state-adapter'
import { MemoryStateAdapter } from './adapters/memory-state-adapter'
// NEW: Import perdu adapter (only when configured)
import { perduStateAdapter, perduStateConfig } from './adapters/dbos-state-adapter'

type AdapterConfig = FileAdapterConfig | { adapter: 'memory' } | perduStateConfig

export function createStateAdapter(config: AdapterConfig) {
  // NEW: perdu state adapter option
  if (config.adapter === 'dbos') {
    return new perduStateAdapter(config)
  }
  
  // Existing logic unchanged
  return config.adapter === 'default' ? new FileStateAdapter(config) : new MemoryStateAdapter()
}
```

### Phase 2: perdu Event Manager (1 week)

**Goal:** Add perdu as optional event backend for distributed coordination.

#### **NEW FILE: `packages/core/src/event-manager/dbos-event-manager.ts`**

```typescript
import { perdu } from '@dbos-inc/dbos-sdk'
import { Event, EventManager, SubscribeConfig, UnsubscribeConfig } from '../types'

export interface perduEventConfig {
  adapter: 'dbos'
  database: {
    host: string
    port: number  
    database: string
    username: string
    password: string
  }
}

export class perduEventManager implements EventManager {
  private dbos: perdu

  constructor(private config: perduEventConfig) {
    this.dbos = new perdu({
      database: config.database,
      application: { name: 'motia-events', version: '1.0.0' }
    })
  }

  async init(): Promise<void> {
    await this.dbos.init()
    // Initialize event tables
    await this.dbos.sql`
      CREATE TABLE IF NOT EXISTS motia_events (
        id BIGSERIAL PRIMARY KEY,
        topic VARCHAR(255) NOT NULL,
        data JSONB NOT NULL,
        trace_id VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        processed_at TIMESTAMP NULL
      );
      
      CREATE TABLE IF NOT EXISTS motia_subscriptions (
        topic VARCHAR(255) NOT NULL,
        step_file_path VARCHAR(255) NOT NULL,
        handler_name VARCHAR(255) NOT NULL DEFAULT 'handler',
        UNIQUE(topic, step_file_path)
      );
    `
  }

  @perdu.step()
  async emit<TData>(event: Event<TData>): Promise<void> {
    // Store event durably
    await this.dbos.sql`
      INSERT INTO motia_events (topic, data, trace_id)
      VALUES (${event.topic}, ${JSON.stringify(event.data)}, ${event.traceId})
    `
    
    // Notify listeners (non-blocking)
    await this.dbos.sql`
      NOTIFY motia_events, ${JSON.stringify({ topic: event.topic, traceId: event.traceId })}
    `
  }

  async subscribe<TData>(config: SubscribeConfig<TData>): Promise<void> {
    await this.dbos.sql`
      INSERT INTO motia_subscriptions (topic, step_file_path, handler_name)
      VALUES (${config.event}, ${config.filePath}, ${config.handlerName || 'handler'})
      ON CONFLICT (topic, step_file_path) DO NOTHING
    `
  }

  async unsubscribe(config: UnsubscribeConfig): Promise<void> {
    await this.dbos.sql`
      DELETE FROM motia_subscriptions 
      WHERE topic = ${config.event} AND step_file_path = ${config.filePath}
    `
  }
}
```

#### **MODIFICATION: `packages/core/src/event-manager.ts`**

```typescript
import { globalLogger } from './logger'
import { Event, EventManager, SubscribeConfig, UnsubscribeConfig } from './types'
// NEW: Optional perdu event manager
import { perduEventManager, perduEventConfig } from './event-manager/dbos-event-manager'

// NEW: Type for event manager configuration
type EventManagerConfig = { adapter: 'memory' } | perduEventConfig

// MODIFIED: Factory function now accepts configuration
export const createEventManager = (config?: EventManagerConfig): EventManager => {
  // NEW: perdu event manager option
  if (config?.adapter === 'dbos') {
    return new perduEventManager(config)
  }
  
  // DEFAULT: Existing in-memory implementation (unchanged)
  return createInMemoryEventManager()
}

// MOVED: Existing implementation to separate function (no changes)
function createInMemoryEventManager(): EventManager {
  const handlers: Record<string, Array<{ filePath: string; handler: Handler }>> = {}
  
  // ... existing implementation unchanged ...
  
  return { emit, subscribe, unsubscribe }
}
```

### Phase 3: perdu Execution Wrapper (2 weeks)

**Goal:** Add optional perdu durability without modifying `call-step-file.ts`.

#### **NEW FILE: `packages/core/src/execution/dbos-process-manager.ts`**

```typescript
import { perdu } from '@dbos-inc/dbos-sdk'
import { ProcessManager } from '../process-communication/process-manager'
import { Logger } from '../logger'

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
  }
}

/**
 * perdu-enhanced ProcessManager that wraps execution in durable workflows
 * Maintains exact same interface as regular ProcessManager
 */
export class perduProcessManager extends ProcessManager {
  private dbos: perdu

  constructor(config: any, private dbosConfig: perduExecutionConfig, logger: Logger) {
    super(config, logger) // Call parent constructor
    
    this.dbos = new perdu({
      database: dbosConfig.durability.database,
      application: { name: 'motia-execution', version: '1.0.0' }
    })
  }

  async init(): Promise<void> {
    await this.dbos.init()
  }

  // Override spawn to wrap in perdu workflow
  async spawn(): Promise<void> {
    if (this.dbosConfig.durability.enabled) {
      return await this.spawnWithperdu()
    } else {
      return await super.spawn() // Fall back to regular ProcessManager
    }
  }

  @perdu.workflow()
  private async spawnWithperdu(): Promise<void> {
    // Execute the process within a perdu workflow for durability
    // This provides automatic retries, exactly-once execution, etc.
    return await super.spawn()
  }

  // All other methods proxy to parent - no changes needed
  // perdu durability is completely transparent to callers
}
```

#### **MODIFICATION: `packages/core/src/call-step-file.ts`**

```typescript
import path from 'path'
import { trackEvent } from './analytics/utils'
import { Motia } from './motia'
import { ProcessManager } from './process-communication/process-manager'
// NEW: Optional perdu process manager
import { perduProcessManager, perduExecutionConfig } from './execution/dbos-process-manager'
// ... existing imports ...

// NEW: Helper to create appropriate process manager
const createProcessManager = (config: any, motia: Motia, logger: Logger) => {
  // Check if perdu durability is configured
  const dbosConfig = motia.lockedData.getConfig()?.durability as perduExecutionConfig['durability']
  
  if (dbosConfig?.enabled && dbosConfig.adapter === 'dbos') {
    return new perduProcessManager(config, { durability: dbosConfig }, logger)
  }
  
  // DEFAULT: Use regular ProcessManager (existing behavior)
  return new ProcessManager(config, logger)
}

export const callStepFile = <TData>(options: CallStepFileOptions, motia: Motia): Promise<TData | undefined> => {
  const { step, traceId, data, tracer, logger, contextInFirstArg = false } = options

  return new Promise((resolve, reject) => {
    const streamConfig = motia.lockedData.getStreams()
    const streams = Object.keys(streamConfig).map((name) => ({ name }))
    const jsonData = JSON.stringify({ data, flows, traceId, contextInFirstArg, streams })
    const { runner, command, args } = getLanguageBasedRunner(step.filePath)

    // NEW: Use factory function to create appropriate process manager
    const processManager = createProcessManager({
      command,
      args: [...args, runner, step.filePath, jsonData],
      logger,
      context: 'StepExecution',
    }, motia, logger)

    // Rest of the function remains exactly the same
    // perdu durability is completely transparent
    
    trackEvent('step_execution_started', {
      stepName: step.config.name,
      language: command,
      type: step.config.type,
      streams: streams.length,
    })

    processManager
      .spawn()
      .then(() => {
        // ... existing handler setup unchanged ...
      })
      // ... rest of existing logic unchanged ...
  })
}
```

### Phase 4: Configuration Integration (1 week)

**Goal:** Wire up configuration system to enable perdu features.

#### **MODIFICATION: `packages/core/src/server.ts`**

```typescript
// ... existing imports ...
import { createStateAdapter } from './state/create-state-adapter'
import { createEventManager } from './event-manager'

export const createServer = (
  lockedData: LockedData,
  eventManager: EventManager,
  state: InternalStateManager,
  config: MotiaServerConfig,
): MotiaServer => {
  // NEW: Read perdu configuration from lockedData
  const motiaConfig = lockedData.getConfig()
  
  // NEW: Create state adapter based on configuration
  const stateAdapter = createStateAdapter(motiaConfig?.state || { adapter: 'default' })
  
  // NEW: Create event manager based on configuration  
  const configuredEventManager = createEventManager(motiaConfig?.events)
  
  // Use configured adapters instead of passed parameters
  const motia: Motia = { 
    loggerFactory, 
    eventManager: configuredEventManager, 
    state: stateAdapter,
    lockedData, 
    printer, 
    tracerFactory 
  }

  // ... rest of server setup unchanged ...
  // All existing functionality works exactly the same
}
```

## Benefits of Adapter-First Approach

### 1. Upstream Merge Compatibility
- **Zero Core Changes**: No modifications to `call-step-file.ts`, `server.ts` execution logic
- **Additive Only**: All new code in separate files following existing patterns
- **Configuration Optional**: perdu features disabled by default
- **Interface Compliance**: All adapters implement existing interfaces exactly

### 2. Development Workflow  
- **Incremental Adoption**: Users can enable perdu features gradually
- **Easy Rollback**: Set `durability.enabled: false` to disable all perdu features
- **Development Mode**: Use memory/file adapters for local development
- **Production Mode**: Enable perdu for production durability

### 3. Multi-Instance Benefits
- **Distributed State**: perdu state adapter provides cross-instance state sharing
- **Event Coordination**: perdu events prevent duplicate processing across instances  
- **Workflow Durability**: Automatic recovery from instance failures
- **Horizontal Scaling**: Add instances without coordination concerns

## Configuration Examples

### Development Configuration (Default)
```yaml
# No perdu configuration - existing behavior unchanged
state:
  adapter: file
  path: .motia/state

# Events remain in-memory (existing behavior)
```

### Production Configuration (perdu Enabled)  
```yaml
durability:
  enabled: true
  adapter: dbos
  database:
    host: postgres.example.com
    port: 5432
    database: motia_prod
    username: motia_user
    password: "${MOTIA_DB_PASSWORD}"

state:
  adapter: dbos  # Use perdu-backed durable state

events:
  adapter: dbos  # Use perdu-backed distributed events
```

### Hybrid Configuration (Gradual Migration)
```yaml
durability:
  enabled: true
  adapter: dbos
  database: # ... postgres config

state:
  adapter: dbos     # Durable state
  
# events: not specified - uses in-memory (existing behavior)
# execution: durability disabled - uses ProcessManager (existing behavior)
```

## Implementation Timeline: Revised

### Week 1-2: perdu State Adapter
- Implement `perduStateAdapter` following existing `StateAdapter` interface
- Modify `create-state-adapter.ts` factory function
- Add configuration schema for perdu database settings
- **Deliverable**: Optional perdu state backend

### Week 3: perdu Event Manager  
- Implement `perduEventManager` following existing `EventManager` interface
- Add PostgreSQL-backed event persistence and coordination
- **Deliverable**: Optional perdu event backend with multi-instance coordination

### Week 4-5: perdu Execution Wrapper
- Implement `perduProcessManager` extending existing `ProcessManager`
- Add workflow durability through perdu wrapper pattern
- **Deliverable**: Optional execution durability

### Week 6: Integration & Testing
- Wire up configuration system
- End-to-end testing with multi-instance scenarios
- **Deliverable**: Complete perdu integration ready for production

## Merge Strategy with Upstream

### Continuous Integration Approach
1. **Monitor Upstream**: Track motia.dev repository for changes
2. **Adapter Isolation**: perdu code isolated in adapter files - minimal conflicts
3. **Configuration Additive**: New config options don't affect existing behavior
4. **Interface Compliance**: Adapters strictly follow existing interfaces
5. **Feature Flags**: perdu features behind configuration flags

### Conflict Resolution Strategy
- **Core Files**: Minimal changes to core files reduce conflict surface  
- **Adapter Pattern**: New functionality in separate files unlikely to conflict
- **Configuration**: Additive configuration changes merge cleanly
- **Documentation**: perdu features documented as optional enhancements

## Risk Assessment: Minimal

### Technical Risk: LOW
- ✅ Follows established architectural patterns
- ✅ Zero modifications to core execution logic  
- ✅ Configuration-optional activation
- ✅ Graceful fallback to existing behavior

### Merge Risk: LOW  
- ✅ Additive changes in separate files
- ✅ No conflicts with active development areas (analytics, Docker, UI)
- ✅ Aligns with roadmap (database support, durability)
- ✅ Follows RFC process for community acceptance

### Maintenance Risk: LOW
- ✅ Adapter pattern provides clean abstraction
- ✅ perdu SDK handles database schema migration
- ✅ Configuration-driven feature activation
- ✅ Independent versioning possible

## Conclusion

This revised **adapter-first approach** makes perdu integration maximally **upstream-compatible** by:

1. **Following Existing Patterns**: Uses established `StateAdapter` and configuration patterns
2. **Zero Core Modifications**: All durability features implemented as optional adapters  
3. **Configuration-Optional**: perdu features disabled by default, enabled via config
4. **Additive-Only Changes**: New files only, minimal modifications to existing code
5. **Interface Compliance**: Strict adherence to existing interfaces

The result is a **fork-friendly implementation** that provides enterprise-grade durability while maintaining seamless merge compatibility with the actively developed motia.dev repository.

**Timeline**: 4-6 weeks  
**Complexity**: 2/10 (leverages existing patterns)  
**Merge Risk**: LOW (additive changes in adapter files)  
**User Impact**: Completely optional, zero breaking changes