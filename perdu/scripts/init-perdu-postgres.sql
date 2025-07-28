-- Motia Perdu PostgreSQL Initialization Script
-- OPINIONATED APPROACH: Single database per stage for multi-instance environments
-- Designed for GCP Cloud Run, AWS Lambda, and Kubernetes deployments

-- Create databases for different stages (single database approach)
CREATE DATABASE motia_perdu;
CREATE DATABASE motia_perdu_test;

-- Switch to perdu development database - contains ALL tables
\c motia_perdu;

-- State storage table
CREATE TABLE IF NOT EXISTS motia_state (
    trace_id VARCHAR(255) NOT NULL,
    key VARCHAR(255) NOT NULL,
    value JSONB NOT NULL,
    type VARCHAR(50) NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (trace_id, key)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_motia_state_trace_id ON motia_state(trace_id);

-- ===== EVENT MANAGEMENT TABLES (same database) =====

-- Events table
CREATE TABLE IF NOT EXISTS motia_events (
    id SERIAL PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    trace_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP NULL
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS motia_subscriptions (
    id SERIAL PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    step_file_path VARCHAR(255) NOT NULL,
    handler_name VARCHAR(255) NOT NULL DEFAULT 'handler',
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(topic, step_file_path)
);

-- Event processors tracking table
CREATE TABLE IF NOT EXISTS motia_event_processors (
    id SERIAL PRIMARY KEY,
    instance_id VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    last_processed_event_id INTEGER,
    heartbeat TIMESTAMP DEFAULT NOW(),
    UNIQUE(instance_id, topic)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_motia_events_topic ON motia_events(topic);
CREATE INDEX IF NOT EXISTS idx_motia_events_created_at ON motia_events(created_at);
CREATE INDEX IF NOT EXISTS idx_motia_subscriptions_topic ON motia_subscriptions(topic);

-- ===== WORKFLOW EXECUTION TABLES (same database) =====

-- Workflows table
CREATE TABLE IF NOT EXISTS motia_workflows (
    id SERIAL PRIMARY KEY,
    workflow_id VARCHAR(255) UNIQUE NOT NULL,
    trace_id VARCHAR(255) NOT NULL,
    step_file_path VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'running',
    input_data JSONB,
    output_data JSONB,
    error_message TEXT,
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP NULL
);

-- Workflow steps table
CREATE TABLE IF NOT EXISTS motia_workflow_steps (
    id SERIAL PRIMARY KEY,
    workflow_id VARCHAR(255) NOT NULL,
    step_name VARCHAR(255) NOT NULL,
    step_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    input_data JSONB,
    output_data JSONB,
    error_message TEXT,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    FOREIGN KEY (workflow_id) REFERENCES motia_workflows(workflow_id) ON DELETE CASCADE
);

-- Execution locks table
CREATE TABLE IF NOT EXISTS motia_execution_locks (
    id SERIAL PRIMARY KEY,
    resource_id VARCHAR(255) UNIQUE NOT NULL,
    locked_by VARCHAR(255) NOT NULL,
    locked_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_motia_workflows_trace_id ON motia_workflows(trace_id);
CREATE INDEX IF NOT EXISTS idx_motia_workflows_status ON motia_workflows(status);  
CREATE INDEX IF NOT EXISTS idx_motia_workflow_steps_workflow_id ON motia_workflow_steps(workflow_id);
CREATE INDEX IF NOT EXISTS idx_motia_workflow_steps_status ON motia_workflow_steps(status);
CREATE INDEX IF NOT EXISTS idx_motia_execution_locks_expires_at ON motia_execution_locks(expires_at);

-- ===== TRACE STORAGE TABLES (same database) =====

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

-- Performance and query optimization indexes for traces
CREATE INDEX IF NOT EXISTS idx_motia_traces_group_id ON motia_traces(group_id);
CREATE INDEX IF NOT EXISTS idx_motia_traces_status ON motia_traces(status);
CREATE INDEX IF NOT EXISTS idx_motia_traces_start_time ON motia_traces(start_time);
CREATE INDEX IF NOT EXISTS idx_motia_traces_created_at ON motia_traces(created_at);

CREATE INDEX IF NOT EXISTS idx_motia_trace_groups_status ON motia_trace_groups(status);
CREATE INDEX IF NOT EXISTS idx_motia_trace_groups_correlation_id ON motia_trace_groups(correlation_id);
CREATE INDEX IF NOT EXISTS idx_motia_trace_groups_start_time ON motia_trace_groups(start_time);
CREATE INDEX IF NOT EXISTS idx_motia_trace_groups_created_at ON motia_trace_groups(created_at);

-- Grant permissions to motia user for single database
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO motia;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO motia;

-- Switch to test database and grant permissions
\c motia_perdu_test;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO motia;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO motia;