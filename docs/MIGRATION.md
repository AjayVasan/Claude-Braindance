# Zai — Shell to Go Migration Guide

Zai starts as a shell script (bash) because that's the right tool for setting environment variables and running a program — it's the shell's native purpose. However, as Zai grows, shell may not scale cleanly.

## When to Migrate from Shell to Go

Migrate from `src/main.sh` to a compiled Go binary when **any** of these conditions are met:

### Trigger 1: Cross-Platform Date Incompatibility

**Symptom:** You switch between macOS and Linux daily, or team members use different platforms. The BSD/GNU `date` flag differences become a recurring issue.

**Shell limitation:** Shell has no portable way to handle the `date -r` (BSD) vs `date -d @timestamp` (GNU) incompatibility. The workaround in main.sh (`zai_detect_os`) is brittle.

**Go fix:** `time.LoadLocation("Asia/Kolkata")` works identically on all platforms.

### Trigger 2: Skills Management

**Symptom:** You need features beyond `git clone` — version tracking, dependency resolution, update checks, conflict resolution between skills.

**Shell limitation:** Shell has no package management primitives. `git clone --depth 1` is the ceiling of what a shell skills manager can do.

**Go fix:** True dependency resolution, parallel downloads, version pinning, registry protocol.

### Trigger 3: Three or More Model Providers

**Symptom:** Beyond Z.ai and direct Claude, you add OpenAI, Anthropic, or custom endpoints. Config logic for provider selection, failover, and request routing exceeds what shell handles cleanly.

**Shell limitation:** Shell `case` statements don't compose. Adding a provider means editing the central dispatch. No type safety on config values.

**Go fix:** Plugin architecture per provider, typed config structs, interface-based provider abstraction.

### Trigger 4: Health Checks / Diagnostics

**Symptom:** You want async health checks (ping endpoints, validate tokens, check rate limits), persistent monitoring, or a background daemon.

**Shell limitation:** Shell can't do concurrent HTTP health checks without external tools (`curl` in a loop = sequential). No real event loop.

**Go fix:** Native HTTP client, goroutines for parallel checks, proper error handling with timeouts.

## Migration Path

### Phase 1: Dual-Run (Recommended)

Keep the shell script as the primary entry point. Build a Go binary alongside it:

```
~/.local/share/zai/
├── src/main.sh          # Shell — still the primary CLI
├── zaid                 # Go binary — optional, for enhanced features
└── ...
```

Gradually move features to the Go binary as they hit the trigger conditions.

### Phase 2: Replace

When the Go binary covers all CLI commands:

```bash
# Old shell entry point (removed or becomes a thin wrapper)
# New:
~/.local/bin/zai → ~/.local/share/zai/zaid
```

### Build Target

```bash
cd zai
go build -o ~/.local/bin/zai ./cmd/zai
```

Single binary, no interpreter dependency, true cross-compilation.

---

## Why Go Over Python

| Factor | Go | Python |
|--------|----|--------|
| Single binary | ✓ (no deps) | ✗ (interpreter + pip) |
| Cross-platform | ✓ (GOOS/GOARCH) | ✗ (Python version compat) |
| Startup time | ~5ms | ~150ms+ |
| Parent env export | ✓ (direct) | ✗ (child process can't modify parent's env) |
| Stdlib timezone | ✓ (built-in) | ✓ (pytz/datetime) |

Go solves the fundamental problem Python can't: a Python subprocess cannot export environment variables to its parent shell process. This is the core reason the primary tool stays as a sourced shell script, not Python.
