# Zai

**Claude Code Preset Switcher & Skills Manager for Z.ai**

Zai automatically exports the right Claude Code environment variables based on the current IST time, switching between model presets optimized for different tasks and peak/off-peak hours.

```
$ zai --check
╔══════════════════════════════════════╗
║        zai — utility status          ║
╚══════════════════════════════════════╝

System
  OS:              linux
  Shell:           zsh

Timezone
  Source:          Asia/Kolkata
  Current (IST):   14:22 IST

Preset
  Active:          deep-thinking-peak

  Model map:
    Opus:                        GLM-5-Turbo
    Sonnet:                      GLM-4.7
    Haiku:                       GLM-4.5-Air

API Key
  Status:          set
  Prefix:          sk-abc12...
  File perms:      600 (secure ✓)
```

---

## Quick Start

```bash
git clone https://github.com/ajayvasan-nitro/Zai
cd Zai
bash install.sh
exec $SHELL
zai --check
claude
```

---

## Presets

Zai switches between 4 presets based on IST time:

| Preset | Time Window (IST) | Opus Model | Sonnet | Haiku | Use Case |
|--------|-------------------|------------|--------|-------|----------|
| `daily-coding` | 00:00-06:29 (default) | GLM-4.7 | GLM-4.7 | GLM-4.5-Air | General dev work |
| `deep-thinking-offpeak` | 06:30-11:29, 15:30-23:59 | GLM-5.2 | GLM-4.7 | GLM-4.5-Air | Architecture, planning |
| `deep-thinking-peak` | 11:30-15:30 | GLM-5-Turbo | GLM-4.7 | GLM-4.5-Air | Deep work, peak hours |
| `docs-utility` | Manual (`claude-doc`) | GLM-4.7 | GLM-4.5-Air | GLM-4.5-Air | Docs, logs, formatting |

Override any preset: `zai preset deep-thinking-offpeak`

---

## Commands

| Command | Description |
|---------|-------------|
| `zai --check` | Show diagnostic status (time, preset, models, API key) |
| `zai set-key <key>` | Store your Z.ai API key securely |
| `zai preset <name>` | Override the active preset |
| `zai shell` | Print shell integration snippet (for manual setup) |
| `zai skills list` | List available Claude Code skill sources |
| `zai skills install <name>` | Clone and install a skill source |
| `zai skills install --all` | Install all skill sources |
| `zai skills docs` | Generate skills ecosystem documentation |
| `zai --help` | Show help |

---

## Provider Setup

### Z.ai

1. Get your API key from [Z.ai](https://z.ai)
2. Store it:
   ```bash
   zai set-key sk-your-key-here
   ```
3. Verify:
   ```bash
   zai --check
   ```

The script exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_DEFAULT_OPUS/SONNET/HAIKU_MODEL` for Claude Code to use the Z.ai API.

### Direct Claude (fallback)

If you also use Claude's native API, unset Zai's env vars:
```bash
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
```

---

## Shell Integration

Zai integrates with your shell via `source` in your shell config:

```bash
# .zshrc or .bashrc
export ZAI_DIR="${ZAI_DIR:-$HOME/.local/share/zai}"
[[ -f "$ZAI_DIR/src/main.sh" ]] && source "$ZAI_DIR/src/main.sh"
alias claude-doc='ZAI_PRESET_OVERRIDE=docs-utility claude'
```

The installer does this automatically (opt-in). To regenerate the snippet:
```bash
zai shell
```

### Fish shell

```fish
set -gx ZAI_DIR $HOME/.local/share/zai
source $ZAI_DIR/src/main.sh
alias claude-doc="env ZAI_PRESET_OVERRIDE=docs-utility claude"
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ZAI_DIR` | `~/.local/share/zai` | Zai data directory |
| `ZAI_TZ` | `Asia/Kolkata` | Timezone for preset switching |
| `ZAI_PRESET_OVERRIDE` | _(unset)_ | Force a specific preset |
| `ZAI_API_KEY` | _(from file)_ | Z.ai API token (env var override) |

---

## Skills Management

Zai catalogs and installs the most impactful Claude Code skill sources:

| Source | Description |
|--------|-------------|
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Official Vercel skill pack (28k★) |
| [obra/superpowers](https://github.com/obra/superpowers) | Full SDLC methodology (243k★) |
| [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | Cross-session memory (85k★) |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | Design guidance (42k★) |
| [rebelytics/one-skill-to-rule-them-all](https://github.com/rebelytics/one-skill-to-rule-them-all) | Task observer meta-skill |

See full catalog: `zai skills docs` → `skills/index.md`

---

## Installation

### New user (clone)

```bash
git clone https://github.com/ajayvasan-nitro/Zai
cd Zai
bash install.sh
```

The installer will:
1. Copy files to `~/.local/share/zai/`
2. Create a `zai` symlink in `~/.local/bin/`
3. Optionally add shell integration to your config
4. Optionally store your Z.ai API key

### Requirements

- **bash** 4.0+ (for running the scripts)
- **curl** (for skills install from GitHub)
- **git** (for skills installation)
- **bats** (optional, for running tests)

---

## Testing

```bash
make test
# or
npx bats tests/
```

---

## Migration Guide

See [docs/MIGRATION.md](docs/MIGRATION.md) for when and how to migrate from shell to a compiled binary.

---

## License

MIT
