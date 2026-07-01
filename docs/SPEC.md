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
├── install.sh               # ~770 lines — interactive installer with TUI
├── Makefile                 # ~45 lines — convenience targets
├── README.md
│
├── src/
│   ├── main.sh              # ~820 lines — core engine + CLI dispatcher
│   ├── skills.sh            # ~320 lines — skills management
│   └── completion.zsh       # ~70 lines — zsh tab-completions
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
| **CLI Dispatcher** | `src/main.sh` | Routes commands: `--check`, `set-key`, `preset`, `auto`, `shell`, `skills`, `hooks-install`, `completions`, `upgrade` |
| **Time Engine** | `src/main.sh` | IST time detection with ±60s grace window at 11:30 boundary |
| **Preset Router** | `src/main.sh` | Maps time → preset: 00:00-06:29 daily, 06:30-11:29 offpeak, 11:30-15:30 peak, 15:30-23:59 offpeak |
| **Precmd Hook** | `src/main.sh` | Watches for time-window crossings, persists notification to `$BRAINDANCE_DIR/last_transition`, auto-exports new `ANTHROPIC_*` vars |
| **Key Manager** | `src/main.sh` | Store/read/verify API key with `chmod 600` |
| **Installer TUI** | `install.sh` | Cyberpunk braindance cinematic + interactive menu with arrow-key navigation |
| **Input Drain** | `install.sh` | Multi-pass stdin drain after API key paste to prevent stray bytes from corrupting TUI |
| **Key Reader** | `install.sh` | Raw escape-sequence parsing (ANSI + application mode) for arrow-key/ESC detection |
| **Shell Hook** | `src/main.sh` | Emits bash/zsh/fish integration snippet |
| **Skills Registry** | `src/skills.sh` | 5 curated skill sources with install/remove/docs |

### 3.3 Dual-Mode Entry Point

The script operates in two modes depending on how it's invoked:

```
source src/main.sh   → Exports ANTHROPIC_* env vars to current shell
braindance --check    → Executes CLI commands
```

Detection works in both bash and zsh using shell-specific source detection.


### 3.4 Transition Notification Flow

When a time-window crossing is detected (e.g., 11:29 → 11:30):

1. **Precmd hook** fires at next shell prompt, detects `current_preset != _BD_LAST_PRESET`
2. Calls `braindance_apply_preset` to source new `.env` and export `ANTHROPIC_*` vars
3. Writes `$BRAINDANCE_DIR/last_transition` (12-line notification, `>` overwrite — never appended)
4. Sets `_BD_LAST_PRESET = current_preset` so the same crossing doesn't re-fire
5. At next `claude` launch, the `claude()` wrapper (in `.zshrc`) cats the file, then deletes it
6. If the wrapper already cleaned it, the SessionStart hook sees nothing; otherwise it displays and cleans up

**In-flight safety:** The precmd hook cannot fire while `claude` owns the terminal. A user typing a message mid-transition is completely uninterrupted. The notification is deferred until the next `claude` launch, and old prompts are never re-sent to new models — only the `ANTHROPIC_*` env vars change.
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
| E7 | Stale override env var after preset auto | `--check` uses file as authority, drops env var fallback | 6 |
| E8 | Prompt notification on time crossing | `precmd`/`PROMPT_COMMAND` hook, skips when override active | 25 |
| E9 | In-flight message during time transition | Precmd hook writes `last_transition` file; notification displayed on next `claude` launch; old prompts never re-sent | 15 |
| E10 | Missing shell config file | `install.sh` checks `[ -f "$shell_config" ]` before prompting | 3 |
| E11 | Zsh completions dir doesn't exist | `mkdir -p $HOME/.zsh/completions` before copy | 1 |
| E12 | API key shown in plaintext during install | `read -s` (silent mode) + clear line after input | 2 |
| E13 | Hook or completions install failure | `|| true` guard — non-critical step never blocks install | 2 |
| E14 | Skills dir doesn't exist | `braindance_skills_dir` auto-creates with `mkdir -p` | 1 |
| E15 | Skill name path traversal | Sanitize: strip `/` and `..` before `rm -rf` | 3 |
| E16 | BRAINDANCE_API_KEY loaded after preset source | Load key from file BEFORE `braindance_apply_preset` so `${VAR:-}` expansion resolves correctly | 5 |
| E17 | Zsh arrow keys in application mode | `_read_key` handles both `\x1b[A` (ANSI) and `\x1bOA` (application mode) escape sequences | 3 |
| E18 | Stale input from paste corrupting TUI | Three-pass `_drain_input` with 100ms timeout per pass | 6 |
| E19 | ZSH_EVAL_CONTEXT toplevel vs sourcing | Explicit `toplevel => return 1`, `*:file*|file|*cmdarg* => return 0` | 6 |
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
| `braindance preset <name>` | Override active preset (shows mindset + model diff) |
| `braindance preset reset` / `auto` | Clear override, revert to time-based |
| `braindance shell` | Print shell integration snippet |
| `braindance hooks-install` | Install Claude Code SessionStart hook |
| `braindance completions install` | Install zsh tab-completions |
| `braindance upgrade` | Update .zshrc to latest integration |
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
bash install.sh                # Interactive — cinematic intro + step-by-step + TUI help
bash install.sh --yes          # Non-interactive — auto-confirm all prompts, skip animations
  → Detects: Linux | macOS + zsh | bash | fish
  → Creates: ~/.local/share/braindance/{presets,skills,src,api-key}
  → Symlinks: ~/.local/bin/braindance → src/main.sh
  → Prompts: Add to shell config? [Y/n]         (auto-yes with --yes)
  → Prompts: Set Z.ai API key? [y/N]            (skipped with --yes)
  → Hooks:   Installs Claude Code SessionStart hook
  → Completions: Installs zsh tab-completions (if zsh detected)
  → TUI:     Interactive help menu with arrow-key navigation (skipped with --yes)
→ exec $SHELL
→ braindance --check
→ claude          # Uses time-based preset, shows model banner
→ claude-doc      # Always docs-utility preset
```
---

## 11. Testing

```bash
make test        # Runs all 23 bats tests
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
cab110a fix: stale BRAINDANCE_PRESET_OVERRIDE env var survives after file deleted
b6dd1f0 fix: --check now shows overridden preset, not time-based
79a55e3 fix: --check no longer shows stale override after preset reset
d754402 fix: remove duplicate 'reset' from preset completions
51b4e44 feat: preset switch shows mindset + model diff on change
```

## 14. Credits

Built via adversarial multi-agent planning (hyperplan mode) with 4 specialist agents:
- **Pragmatist** — MVP scope, cost control, shell-first bias
- **Architect** — System decomposition, module interfaces, provider abstraction
- **Deep-thinker** — Edge case analysis, security hardening, cross-platform compat
- **Innovator** — UX delight, context-aware detection vision, skill ecosystem design

Planning sourced from 6 background research agents covering the Claude Code skills ecosystem.

---

*End of specification.*
