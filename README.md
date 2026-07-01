# Claude-Braindance

**Drop into a different state of mind — without thinking about it.**

```
$ braindance --check
╔══════════════════════════════════════╗
║     braindance — utility status      ║
╚══════════════════════════════════════╝

System
  OS:              linux
  Shell:           zsh

Timezone
  Source:          Asia/Kolkata
  Current (IST):   14:22 IST

Preset
  Active:          deep-thinking (peak hours)

  Model map:
    Opus:                        GLM-5-Turbo
    Sonnet:                      GLM-4.7
    Haiku:                       GLM-4.5-Air

API Key
  Status:          set
  File perms:      600 (secure ✓)
```

---

Braindance is a terminal utility for [Claude Code](https://claude.ai) — an AI coding agent. It does two things:

1. **Auto-switches Claude's "mindset"** based on time of day — you get the right model for the right task without touching config
2. **Helps you discover and install Claude Code skills** — superpowers, memory, design guidance, and more from the best open-source repos

Inspired by the Cyberpunk 2077 concept of **braindance** — switching between different perceptual layers to experience the same world differently. Your coding environment, different mindsets.

---

## How it Works

Claude Code works with backend AI models (like Opus for deep reasoning, Sonnet for balanced work, Haiku for quick tasks). Different work needs different models — but manually switching between them is friction.

**Braindance automates this.** You install it once, add one line to your shell config, and forget about it. Every new terminal session, Braindance reads the current IST time and exports the right environment variables so Claude Code uses the optimal model preset.

No daemons. No background processes. No 200MB dependency installs. It's a shell script — it runs in milliseconds and disappears.

```
┌─────────────────────────────────────────────────────┐
│                   Your Terminal                      │
│                                                      │
│  $ claude                                            │
│                                                      │
│  ┌─────────────────────────────────────────────┐     │
│  │  braindance (source'd in .zshrc)             │     │
│  │  ├── Reads IST time → 14:22                 │     │
│  │  ├── Selects preset → deep-thinking-peak    │     │
│  │  └── Exports ANTHROPIC_* env vars           │     │
│  └─────────────────────────────────────────────┘     │
│                                                      │
│  ┌─────────────────────────────────────────────┐     │
│  │  Claude Code runs with:                      │     │
│  │  Opus  → GLM-5-Turbo  (deep reasoning)      │     │
│  │  Sonnet→ GLM-4.7      (balanced)            │     │
│  │  Haiku → GLM-4.5-Air  (quick tasks)         │     │
│  └─────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────┘
```

---

| Feature | What it does |
|---------|-------------|
| **⏰ Time-based presets** | Auto-selects model preset based on IST time windows |
| **🔔 Auto-notification** | Precmd hook alerts you when time window changes mid-session |
| **🧠 4 mindsets** | Daily coding, deep thinking (peak), deep thinking (off-peak), docs |
| **🔑 Secure key storage** | API key stored with `chmod 600`, verified before each session |
| **🔌 Provider abstraction** | Currently supports Z.ai API — plug in any Anthropic-compatible provider |
| **🐚 Shell integration** | Sources into zsh/bash/fish — one line, zero friction |
| **📦 Skills installer** | Discover and install 5+ curated Claude Code skill packs |
| **🏥 Diagnostic mode** | `braindance --check` shows full status at a glance |
---

## Quick Start

```bash
git clone https://github.com/AjayVasan/Claude-Braindance.git
cd Claude-Braindance
bash install.sh
exec $SHELL
braindance --check
claude
```

The installer walks you through:
1. Detecting your OS and shell
2. Copying files to `~/.local/share/braindance/`
3. Symlinking `braindance` to your PATH
4. Optionally adding shell integration to your config
5. Optionally storing your API key

---

| Mindset | Time Window (IST) | Opus | Sonnet | Haiku | When to use |
|---------|-------------------|------|--------|-------|-------------|
| `daily-coding` | 00:00-06:29 (default) | GLM-4.7 | GLM-4.7 | GLM-4.5-Air | General dev, quick tasks |
| `deep-thinking-offpeak` | 06:30-11:29, 15:30-23:59 | GLM-5.2 | GLM-4.7 | GLM-4.5-Air | Architecture, planning, debugging |
| `deep-thinking-peak` | 11:30-15:30 | GLM-5-Turbo | GLM-4.7 | GLM-4.5-Air | Deep work during peak hours |
| `docs-utility` | Manual (`claude-doc` alias) | GLM-4.7 | GLM-4.5-Air | GLM-4.5-Air | Documentation, formatting, logs |

Override anytime: `braindance preset deep-thinking-offpeak`

The ±60s grace window at 11:30 prevents boundary glitches.

### Preset Switch Output

```bash
$ braindance preset deep-thinking-peak
[braindance] Mindset switched: deep-thinking-offpeak → deep-thinking-peak

  Opus:        GLM-5.2              → GLM-5-Turbo
  Sonnet:      GLM-4.7              → GLM-4.7
  Haiku:       GLM-4.5-Air          → GLM-4.5-Air

[braindance] Use 'braindance preset reset' to revert to time-based.
```

Switching to the same preset prints current state without re-applying:

```bash
$ braindance preset deep-thinking-peak
[braindance] Already on preset: deep-thinking-peak
  Opus:   GLM-5-Turbo
  Sonnet: GLM-4.7
  Haiku:  GLM-4.5-Air
```
---

| Command | Description |
|---------|-------------|
| `braindance --check` | Full diagnostic: time, mindset, models, API key status |
| `braindance set-key <token>` | Store your API key securely |
| `braindance preset <name>` | Override the active mindset (shows model diff) |
| `braindance preset reset` / `auto` | Clear override, revert to time-based |
| `braindance shell` | Print shell integration snippet |
| `braindance hooks-install` | Install Claude Code SessionStart hook |
| `braindance completions install` | Install zsh tab-completions |
| `braindance upgrade` | Update .zshrc integration to latest version |
| `braindance skills list` | List available Claude Code skill sources |
| `braindance skills install <name>` | Clone and install a skill pack |
| `braindance skills install --all` | Install all curated skill sources |
| `braindance skills docs` | Generate ecosystem documentation |
| `braindance --help` | Show help |

---

## Provider Setup

### Z.ai (default)

Braindance is built for [Z.ai](https://z.ai) — an Anthropic-compatible API proxy.

```bash
braindance set-key sk-your-zai-api-key
braindance --check
```

This exports:
| Variable | Value |
|----------|-------|
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` |
| `ANTHROPIC_AUTH_TOKEN` | Your Z.ai API key |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Per preset |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Per preset |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Per preset |

### Other providers

Swap in any Anthropic-compatible API by creating a custom preset:

```bash
cp presets/daily-coding.env presets/my-provider.env
# Edit ANTHROPIC_BASE_URL and model names
braindance preset my-provider
```

---

## Shell Integration

The installer adds this to your shell config (with permission):

```bash
# .zshrc or .bashrc
export BRAINDANCE_DIR="${BRAINDANCE_DIR:-$HOME/.local/share/braindance}"
[[ -f "$BRAINDANCE_DIR/src/main.sh" ]] && source "$BRAINDANCE_DIR/src/main.sh"
alias claude-doc='BRAINDANCE_PRESET_OVERRIDE=docs-utility command claude'
```

To regenerate the snippet: `braindance shell`

### Auto-Notification (Precmd Hook)

### Auto-Notification + Auto-Switch (Precmd Hook)

Once sourced, Braindance registers a lightweight shell hook that watches for time-window crossings. When the clock passes a boundary (e.g., 11:30 → peak), it **automatically exports the new ANTHROPIC_* vars** to your live shell and shows:

```
[braindance] ⏰ Auto-switched: deep-thinking-offpeak → deep-thinking-peak
  Opus:        GLM-5.2              → GLM-5-Turbo
  Sonnet:      GLM-4.7              → GLM-4.7
  Haiku:       GLM-4.5-Air          → GLM-4.5-Air
```

No manual re-source needed — your `claude` command immediately uses the right models. No background processes — just a `precmd`/`PROMPT_COMMAND` hook that runs in <1ms. Skips entirely when a manual override is active.

### Fish shell
```fish
set -gx BRAINDANCE_DIR $HOME/.local/share/braindance
source $BRAINDANCE_DIR/src/main.sh
alias claude-doc="env BRAINDANCE_PRESET_OVERRIDE=docs-utility claude"
```
---

## Skills Ecosystem

Braindance catalogs the most impactful Claude Code skill sources:

| Source | Stars | What it gives you |
|--------|-------|-------------------|
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | 28k | 8 official skills: React best practices, web design guidelines, Vercel optimization |
| [obra/superpowers](https://github.com/obra/superpowers) | 243k | 14 skills: brainstorming, TDD, code review, subagents — full SDLC methodology |
| [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | 85k | Cross-session memory — Claude remembers what you did last session |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 42k | 23 design commands, 45 anti-pattern detectors, live browser mode |
| [rebelytics/one-skill-to-rule-them-all](https://github.com/rebelytics/one-skill-to-rule-them-all) | 769 | Task observer — auto-creates and improves skills from usage patterns |

Plus tools for knowledge graph generation:

| Tool | Stars | What it does |
|------|-------|-------------|
| [Graphify](https://github.com/safishamsi/graphify) | 75k | Maps entire project into a queryable knowledge graph |
| [Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) | 69k | Interactive dashboard with guided codebase tours |
| [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | 23k | Fastest code graph — C binary, 158 languages |
| [code-review-graph](https://github.com/tirth8205/code-review-graph) | 19k | PR review token reduction (82x median) |

Install any of them: `braindance skills install obra/superpowers`

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BRAINDANCE_DIR` | `~/.local/share/braindance` | Data directory |
| `BRAINDANCE_TZ` | `Asia/Kolkata` | Timezone for preset switching |
| `BRAINDANCE_PRESET_OVERRIDE` | _(unset)_ | Force a specific mindset |
| `BRAINDANCE_API_KEY` | _(from file)_ | API token (env var override) |

---

## Requirements

| Dependency | Required for | Notes |
|------------|-------------|-------|
| **bash** 4.0+ | Running scripts | Cross-platform |
| **curl** | Skills install | Usually pre-installed |
| **git** | Skills installation | Usually pre-installed |
| **npx bats** | Running tests | Optional, install via `npm` |

**Zero runtime dependencies.** No Python, Node.js, Ruby, Go, or package managers required.

---

## Testing

```bash
make test        # 25 tests — preset detection, CLI, key mgmt, skills
make check       # braindance --check — verify your setup
make lint        # shellcheck all scripts
```
---

```
Claude-Braindance/
├── braindance                 → symlink to src/main.sh
├── install.sh                 # One-shot installer
│
├── src/
│   ├── main.sh                # Core engine (~700 lines)
│   └── skills.sh              # Skills management (registry, install, docs)
│
├── presets/
│   ├── daily-coding.env
│   ├── deep-thinking-offpeak.env
│   ├── deep-thinking-peak.env
│   └── docs-utility.env
│
├── skills/
│   └── index.md               # Auto-generated skill catalog
│
├── tests/                     # 23 bats tests
├── docs/
│   ├── SPEC.md                # Full specification
│   └── MIGRATION.md           # Shell-to-Go migration guide
└── Makefile
```

The entire project is ~1900 lines of bash. Designed to be readable, auditable, and forkable.

---

## Design Philosophy

Built via adversarial multi-agent planning (hyperplan mode) with four specialists debating every decision:

- **Pragmatist** kept scope tight — shell-first, no unnecessary deps
- **Architect** drew clear component boundaries — 4 files, not 8
- **Deep-thinker** caught 25 edge cases, distilled to 6 essential ones
- **Innovator** pushed for delight — `--check` diagnostic mode, skills ecosystem

**Key decisions:**
- **Shell, not Python/Go** — env vars must be set in the parent shell; only `source` can do that
- **No LiteLLM** — 200MB+ dependency for an env var switcher is absurd
- **No daemon** — runs once at session start in <5ms, then exits
- **Opt-in shell integration** — never modifies `.zshrc` without asking
- **Documented migration path** — `docs/MIGRATION.md` for when Go becomes necessary

---

## License

MIT

---

*"Different perspectives. Same code. Different mind."*
