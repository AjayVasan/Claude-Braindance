# Claude-Braindance — Specification Document

> **Repo:** https://github.com/AjayVasan/Claude-Braindance
> **Status:** v1.0.0 — Complete
> **License:** MIT

---

## 1. Problem Statement

Claude Code users with Z.ai API access have four distinct use cases — daily coding, deep thinking (peak hours), deep thinking (off-peak), and docs/utility tasks. Each requires different model allocations (Opus, Sonnet, Haiku) to balance cost, latency, and quality. Switching between these manually via `export` commands is error-prone and friction-heavy. Additionally, the Claude Code skills ecosystem is fragmented across multiple GitHub repos with no unified discovery or installation path.

---

## 2. Solution Overview

**Claude-Braindance** is a terminal utility that:

1. **Auto-export env vars** — Sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_DEFAULT_OPUS/SONNET/HAIKU_MODEL` based on the current IST time
2. **Four presets** — Daily coding, deep thinking (off-peak), deep thinking (peak), docs/utility — each with different model to Z.ai GLM model mappings
3. **Shell integration** — Sources into zsh/bash/fish via a single line in `.zshrc`, auto-exporting on every new shell
4. **Skills management** — Discovers, installs, and documents Claude Code skills from 5+ curated GitHub repos
5. **One-shot install** — `bash install.sh` detects OS, detects shell, copies files, symlinks, configures shell integration

---

## 3. Architecture

### 3.1 File Layout

```
Claude-Braindance/
├── braindance               # Symlink → src/main.sh (installed to PATH)
├── install.sh               # ~70 lines — one-shot setup
├── Makefile                 # ~20 lines — convenience targets
├── README.md
│
├── src/
│   ├── main.sh              # ~490 lines — core engine
│   └── skills.sh            # ~300 lines — skills management
│
├── presets/
│   ├── daily-coding.env
│   ├── deep-thinking-offpeak.env
│   ├── deep-thinking-peak.env
│   └── docs-utility.env
│
├── skills/
│   └── index.md             # Auto-generated skill ecosystem docs
│
├── tests/
│   ├── test_presets.bats    # 14 tests — preset detection, time, CLI, key mgmt
│   ├── test_install.bats    # 5 tests — installer behavior
│   └── test_skills.bats     # 4 tests — skills management
│
└── docs/
    └── MIGRATION.md          # Shell-to-Go migration triggers
    └── SPEC.md               # This document
```

### 3.2 Component Architecture

| Component | File | Responsibility |
|-----------|------|----------------|
| **CLI Dispatcher** | `src/main.sh` | Routes commands: `--check`, `set-key`, `preset`, `shell`, `skills` |
| **Time Engine** | `src/main.sh` | IST time detection with ±60s grace window at 11:30 boundary |
| **Preset Router** | `src/main.sh` | Maps time → preset: 00:00-06:29 daily, 06:30-11:29 offpeak, 11:30-15:30 peak, 15:30-23:59 offpeak |
| **Key Manager** | `src/main.sh` | Store/read/verify API key with `chmod 600` |
| **Shell Hook** | `src/main.sh` | Emits bash/zsh/fish integration snippet |
| **Skills Registry** | `src/skills.sh` | 5 curated skill sources with install/remove/docs |
| **Installer** | `install.sh` | OS+shell detection, file copy, symlink, rc injection |

### 3.3 Dual-Mode Entry Point

The script operates in two modes depending on how it's invoked:

```
source src/main.sh   → Exports ANTHROPIC_* env vars to current shell
braindance --check    → Executes CLI commands
```

Detection works in both bash and zsh using shell-specific source detection.

---

## 4. Time-Based Preset Switching

### 4.1 Preset Windows (IST)

| Preset | Time Window | Opus | Sonnet | Haiku | Use Case |
|--------|-------------|------|--------|-------|----------|
| `daily-coding` | 00:00-06:29 | GLM-4.7 | GLM-4.7 | GLM-4.5-Air | General dev |
| `deep-thinking-offpeak` | 06:30-11:29, 15:30-23:59 | GLM-5.2 | GLM-4.7 | GLM-4.5-Air | Architecture, planning |
| `deep-thinking-peak` | 11:30-15:30 | GLM-5-Turbo | GLM-4.7 | GLM-4.5-Air | Deep work |
| `docs-utility` | Manual (`claude-doc` alias) | GLM-4.7 | GLM-4.5-Air | GLM-4.5-Air | Docs, logs |

### 4.2 Time Detection Algorithm

```python
time_ist = TZ=Asia/Kolkata date +%H%M

# Grace window: 11:29-11:31 snaps to 11:30
if time_ist in ["11:29", "11:30", "11:31"]:
    time_ist = "1130"

if 630 <= time_ist < 1130:
    preset = "deep-thinking-offpeak"
elif 1130 <= time_ist < 1530:
    preset = "deep-thinking-peak"
elif 1530 <= time_ist < 2400:
    preset = "deep-thinking-offpeak"
else:
    preset = "daily-coding"
```

### 4.3 Provided Abstraction

Currently supports **Z.ai** (Anthropic-compatible API). The tool exports these env vars:

```
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
ANTHROPIC_AUTH_TOKEN=<token>
ANTHROPIC_DEFAULT_OPUS_MODEL=GLM-*
ANTHROPIC_DEFAULT_SONNET_MODEL=GLM-*
ANTHROPIC_DEFAULT_HAIKU_MODEL=GLM-4.5-Air
```

Adding a new provider = create a new preset `.env` file with the provider's base URL and model names.

---

## 5. Skills Management

### 5.1 Curated Sources

| Source | Stars | Description |
|--------|-------|-------------|
| vercel-labs/agent-skills | 28k | 8 official Vercel skills (React, Design, Optimize) |
| obra/superpowers | 243k | 14 skills: full SDLC methodology |
| thedotmack/claude-mem | 85k | Cross-session memory compression |
| pbakaus/impeccable | 42k | 23 design commands, 45 anti-pattern detectors |
| rebelytics/one-skill-to-rule-them-all | 769 | Task observer meta-skill |

### 5.2 Knowledge Graph Tool References

| Tool | Stars | Description |
|------|-------|-------------|
| Graphify | 75k | `/graphify .` — maps project to knowledge graph |
| Understand-Anything | 69k | Interactive knowledge graph dashboard |
| codebase-memory-mcp | 23k | Fastest option — C binary, 158 languages |
| code-review-graph | 19k | PR review token reduction (82x median) |

---

## 6. Edge Cases Handled

| ID | Issue | Fix | Lines |
|----|-------|-----|-------|
| E1 | Missing/empty API key | `[ -z "$BRAINDANCE_API_KEY" ] && echo error && return 1` | 3 |
| E2 | Token file permissions | `chmod 600` after write | 1 |
| E3 | Non-IST timezone | `TZ=${BRAINDANCE_TZ:-Asia/Kolkata}` + `--check` shows TZ | 1 |
| E4 | Shell-agnostic install | `case $SHELL in zsh|bash|fish)` in install.sh | 5 |
| E5 | BSD vs GNU date | OS detection + correct date flags | 10 |
| E6 | 11:30 boundary clock skew | ±60s grace window + deterministic function | 5 |

---

## 7. Dependencies

| Dependency | Required For | Version |
|------------|-------------|---------|
| bash | Running scripts | 4.0+ |
| curl | Skills install from GitHub | Any |
| git | Skills installation | Any |
| bats (npx) | Running tests | 1.13+ |

**Explicit non-dependencies:** No Python, no Node.js, no Ruby, no Go. Zero runtime dependencies beyond bash.

---

## 8. Design Decisions (from adversarial planning)

### 8.1 Shell-first, not Python/Go

The tool starts as bash because:
- Setting env vars is the shell's native purpose
- Zero runtime dependencies
- A sourced shell script can modify the parent shell's environment (Python/Go binaries cannot)
- Startup time is ~5ms vs 150ms+ for Python

### 8.2 Migration path documented

When the tool outgrows shell (cross-platform date issues, skills management complexity, 3+ providers, health checks), the `docs/MIGRATION.md` documents the exact trigger conditions for a Go rewrite.

### 8.3 No LiteLLM

The adversarial debate identified LiteLLM as the single most dangerous dependency — 200MB+ install, Python runtime requirement, 150ms+ process fork on every `claude` invocation. Instead, env vars are set directly.

### 8.4 4 files, not 8

The architecture was distilled from an initial 8-module design down to 4 files (main.sh, skills.sh, install.sh, Makefile) after cross-attack critique identified module boundary overhead.

### 8.5 Opt-in shell integration

The installer does NOT modify `.zshrc` without asking. Explicit confirmation required.

---

## 9. Command Reference

| Command | Description |
|---------|-------------|
| `braindance --check` | Full diagnostic: time, preset, model map, API key, env vars |
| `braindance set-key <key>` | Store Z.ai API key (chmod 600) |
| `braindance preset <name>` | Override active preset temporarily |
| `braindance shell` | Print shell integration snippet |
| `braindance skills list` | Show available skill sources |
| `braindance skills install <name>` | Clone and install a skill from GitHub |
| `braindance skills install --all` | Install all curated skills |
| `braindance skills remove <name>` | Remove installed skill |
| `braindance skills docs` | Generate skills/index.md |
| `braindance --help` | Show usage |

---

## 10. Install Flow

```bash
git clone https://github.com/AjayVasan/Claude-Braindance.git
cd Claude-Braindance
bash install.sh
  → Detects: Linux | macOS + zsh | bash | fish
  → Creates: ~/.local/share/braindance/{presets,skills,api-key}
  → Symlinks: ~/.local/bin/braindance → src/main.sh
  → Prompts: Add to shell config? [Y/n]
  → Prompts: Set Z.ai API key? [y/N]
→ exec $SHELL
→ braindance --check
→ claude          # Uses time-based preset
→ claude-doc      # Always docs-utility preset
```

---

## 11. Testing

```bash
make test        # Runs all 23 bats tests
make check       # Shows braindance --check status
make lint        # Runs shellcheck on all scripts
```

Test categories:
- **test_presets.bats** — Time detection, preset resolution, CLI dispatch, API key management, shell integration
- **test_install.bats** — OS/shell detection, directory structure, symlink, file permissions
- **test_skills.bats** — Registry, install/remove, docs generation

---

## 12. Future Phases (v2+)

| Feature | Phase | Approach |
|---------|-------|----------|
| Context-aware detection | v2 | Go binary (~300 lines) that checks git branch, file types, time-of-day |
| Provider mesh | v2+ | Request-level routing across providers |
| Skills marketplace | v3+ | Community ratings, auto-update, quality scoring |
| SHA-pinned installs | v1.1 | Supply chain hardening for skills install |
| Interactive TUI | v3 | Ratatui dashboard for preset management |

---

## 13. Git History (v1)

```
71a22dc docs: add README, migration guide, Makefile, and gitignore
bad1c00 feat: add skills management system
171f5c6 feat: add installer and shell integration
1dd8f98 feat: add preset definitions and core switching engine
```

---

## 14. Credits

Built via adversarial multi-agent planning (hyperplan mode) with 4 specialist agents:
- **Pragmatist** — MVP scope, cost control, shell-first bias
- **Architect** — System decomposition, module interfaces, provider abstraction
- **Deep-thinker** — Edge case analysis, security hardening, cross-platform compat
- **Innovator** — UX delight, context-aware detection vision, skill ecosystem design

Planning sourced from 6 background research agents covering the Claude Code skills ecosystem.

---

*End of specification.*
