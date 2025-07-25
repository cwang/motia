-- Perdu PostgreSQL Initialization Script
-- This script creates the databases and tables needed for perdu functionality

-- Create databases for different perdu components
CREATE DATABASE motia_test;
CREATE DATABASE motia_state_dev;
CREATE DATABASE motia_events_dev;
CREATE DATABASE motia_execution_dev;

-- Switch to state database for state adapter tables
\c motia_state_dev;

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

-- Switch to events database for event manager tables
\c motia_events_dev;

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

-- Switch to execution database for workflow tables
\c motia_execution_dev;

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

-- Grant permissions to motia user for all databases
\c motia_dev;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO motia;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO motia;

\c motia_test;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO motia;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO motia;

\c motia_state_dev;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO motia;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO motia;

\c motia_events_dev;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO motia;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO motia;

\c motia_execution_dev;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO motia;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO motia;