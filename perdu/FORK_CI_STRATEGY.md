# Fork-Isolated CI Strategy

> **TL;DR**: Perdu CI workflows are completely isolated from upstream motia.dev workflows to enable conflict-free syncing. Perdu workflows only trigger on `perdu/**` changes and use non-conflicting ports/services.

## Overview

This fork maintains complete CI/CD isolation from upstream motia.dev to enable frequent syncing without conflicts.

## Fork-Specific Workflows

### 🔒 Isolation Principles

1. **Trigger Isolation**: Perdu workflows only trigger on perdu-specific changes
2. **Naming Isolation**: All workflows have "(Fork-Isolated)" suffix to avoid conflicts
3. **Path Isolation**: Workflows only run when `perdu/**` or perdu CI files change
4. **Service Isolation**: Use non-conflicting ports (PostgreSQL 5433, Redis 6379)

### 📁 File Structure

```
.github/
├── workflows/
│   ├── perdu-ci.yml           # Perdu CI (Fork-Isolated)
│   ├── perdu-e2e.yml          # Perdu E2E (Fork-Isolated)
│   ├── motia.yml              # Upstream (unchanged)
│   ├── e2e-tests-pr.yml       # Upstream (unchanged)
│   └── ... (other upstream workflows unchanged)
└── actions/
    ├── setup-perdu/           # Perdu-specific setup action
    ├── setup/                 # Upstream (unchanged)
    └── ... (other upstream actions unchanged)
```

### 🚦 Trigger Strategy

**Perdu Workflows Trigger On**:
- Changes to `perdu/**`
- Changes to `.github/workflows/perdu-*.yml`
- Changes to `.github/actions/setup-perdu/**`
- Manual workflow dispatch

**Perdu Workflows DO NOT Trigger On**:
- Changes to `packages/**` (tested by upstream CI)
- Changes to `playground/**` (tested by upstream CI)
- Changes to upstream GitHub Actions
- Any other motia.dev changes

### ✅ Safety Mechanisms

#### 1. Fork Isolation Verification
Every perdu CI run verifies:
```bash
# Only perdu-specific files changed
for file in $changed_files; do
  if [[ ! "$file" =~ ^perdu/ ]] && [[ ! "$file" =~ ^\.github/workflows/perdu- ]]; then
    echo "❌ ERROR: Non-perdu file modified: $file"
    exit 1
  fi
done
```

#### 2. Critical File Protection
```bash
# Ensure no upstream CI files were touched
if echo "$changed_files" | grep -E '^\.github/workflows/(motia|e2e-tests|deploy)'; then
  echo "❌ ERROR: Upstream workflow modified"
  exit 1
fi
```

#### 3. Service Port Verification
```bash
# Verify perdu uses isolated ports
pg_isready -h localhost -p 5433  # Perdu PostgreSQL
redis-cli -p 6379 ping           # Standard Redis (unchanged)
```

## Upstream Sync Strategy

### ✅ Safe Operations
- **Merge upstream `main`**: No conflicts with perdu workflows
- **Pull upstream workflow changes**: Perdu workflows are isolated
- **Rebase on upstream**: Perdu files remain separate

### ⚠️ Considerations  
- **New upstream workflows**: Will not conflict due to naming isolation
- **Changes to existing workflows**: Our perdu workflows are separate files
- **Action updates**: We inherit from upstream actions, no conflicts

## Benefits

### 🔄 Frequent Upstream Syncing
- **Zero merge conflicts** in CI/CD configuration
- **Automatic inheritance** of upstream CI improvements
- **Independent feature development** without breaking upstream compatibility

### 🧪 Isolated Testing
- **Perdu features** tested independently
- **Upstream functionality** tested by upstream CI
- **No interference** between test suites

### 📊 Clear Separation
- **Perdu CI status** separate from upstream status
- **Easy debugging** of perdu-specific issues
- **Clean history** of perdu vs upstream changes

## Migration Strategy

When features are ready for upstream contribution:

1. **Feature Preparation**: Ensure implementation follows upstream patterns
2. **CI Adaptation**: Convert perdu CI checks to upstream-compatible format  
3. **Gradual Integration**: Submit PRs for individual components
4. **CI Cleanup**: Remove fork-specific workflows as features merge upstream

## Monitoring

### 📈 Success Metrics
- Perdu CI passes consistently
- No upstream workflow conflicts during syncing
- Clear separation of perdu vs upstream test failures

### 🚨 Alert Conditions
- Perdu workflow triggers on non-perdu changes (indicates trigger misconfiguration)
- Upstream workflow failures after perdu changes (indicates interference)
- Port conflicts in CI services (indicates isolation failure)

---

**Last Updated**: 2025-07-27  
**Fork Strategy**: Complete isolation for maximum upstream compatibility