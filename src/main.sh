#!/usr/bin/env bash
# Zai — Claude Code Preset Switcher & Skills Manager
# Dual-purpose: source for env export, execute for CLI commands
#
# Usage:
#   source src/main.sh           # Export env vars for current shell
#   zai --check                  # Show diagnostic status
#   zai set-key <api_key>        # Store Z.ai API key
#   zai preset <name>            # Override active preset
#   zai shell                    # Emit shell integration snippet
#   zai skills <list|docs>       # Manage skills
#
# Environment:
#   ZAI_DIR         Config directory (default: ~/.local/share/zai)
#   ZAI_TZ          Timezone for preset switching (default: Asia/Kolkata)
#   ZAI_API_KEY     Z.ai API token (can be set via file or env var)
#   ZAI_PRESET_OVERRIDE  Force a specific preset

set -euo pipefail

# ─── Script Directory (cross-shell: bash + zsh) ──────────────────────────────

ZAI_SCRIPT_DIR=""
if [ -n "${BASH_SOURCE-}" ] && [ "${BASH_SOURCE[0]}" ]; then
	ZAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION-}" ]; then
	# In zsh, use the %x expansion to get the sourced file path
	ZAI_SCRIPT_DIR="${${(%):-%x}:A:h}" 2>/dev/null || ZAI_SCRIPT_DIR="$PWD"
else
	ZAI_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# ─── Configuration ────────────────────────────────────────────────────────────

ZAI_DIR="${ZAI_DIR:-$HOME/.local/share/zai}"
ZAI_PRESETS_DIR="${ZAI_DIR}/presets"
ZAI_SKILLS_DIR="${ZAI_DIR}/skills"
ZAI_API_KEY_FILE="${ZAI_DIR}/api-key"
ZAI_TZ="${ZAI_TZ:-Asia/Kolkata}"
ZAI_PRESET_OVERRIDE="${ZAI_PRESET_OVERRIDE:-}"
ZAI_DEFAULT_PRESET="daily-coding"

# ─── Time Detection ───────────────────────────────────────────────────────────

# zai_detect_os: Detects OS for date command compatibility (E5)
# Returns: "linux" or "macos"
zai_detect_os() {
	case "$(uname -s)" in
		Darwin) echo "macos" ;;
		*)      echo "linux" ;;
	esac
}

# zai_get_time_ist: Returns current IST time as 4-digit string (HHMM)
# Handles BSD vs GNU date flags (E5)
# Applies ±60s grace window at 11:30 boundary (E6)
zai_get_time_ist() {
	local os raw_time minute_part
	os=$(zai_detect_os)
	case "$os" in
		macos)
			raw_time=$(TZ="$ZAI_TZ" date +%H:%M 2>/dev/null || TZ="$ZAI_TZ" date -j +%H:%M)
			;;
		*)
			raw_time=$(TZ="$ZAI_TZ" date +%H:%M)
			;;
	esac

	# Grace window: 11:30 boundary (E6)
	# If time is 11:29-11:31, snap to 11:30
	case "$raw_time" in
		11:29|11:30|11:31) echo "1130" ;;
		*)
			# Strip colon and return HHMM
			echo "${raw_time%:*}$(printf '%02d' $((10#${raw_time#*:})))"
			;;
	esac
}

# zai_detect_preset: Maps current IST time to preset name
# Time windows:
#   00:00-06:29 → daily (default — late night is uncategorized)
#   06:30-11:29 → offpeak (before peak hours)
#   11:30-15:29 → peak (peak thinking hours)
#   15:30-23:59 → offpeak (after peak hours)
zai_detect_preset() {
	local time_ist
	time_ist=$(zai_get_time_ist)

	# Strip leading zeros for numeric comparison
	local numeric_time=$((10#$time_ist + 0))

	if [ "$numeric_time" -ge 630 ] && [ "$numeric_time" -lt 1130 ]; then
		echo "deep-thinking-offpeak"
	elif [ "$numeric_time" -ge 1130 ] && [ "$numeric_time" -lt 1530 ]; then
		echo "deep-thinking-peak"
	elif [ "$numeric_time" -ge 1530 ] && [ "$numeric_time" -lt 2400 ]; then
		echo "deep-thinking-offpeak"
	else
		echo "daily-coding"
	fi
}

# ─── Preset Management ────────────────────────────────────────────────────────

# zai_get_preset_path: Resolves preset file path
# Arguments: preset name (without .env)
zai_get_preset_path() {
	local name="${1:-$ZAI_DEFAULT_PRESET}"
	local search_paths
	search_paths="$ZAI_PRESETS_DIR/${name}.env"

	if [ ! -f "$search_paths" ]; then
		if [ -d "$ZAI_SCRIPT_DIR/../presets" ]; then
			search_paths="$ZAI_SCRIPT_DIR/../presets/${name}.env"
		fi
	fi

	echo "$search_paths"
}

# zai_apply_preset: Sources the preset .env file to export its vars
# Arguments: preset name
zai_apply_preset() {
	local name="${1:-}"
	local preset_file

	# Use override if set
	if [ -n "$ZAI_PRESET_OVERRIDE" ]; then
		name="$ZAI_PRESET_OVERRIDE"
	elif [ -z "$name" ]; then
		name=$(zai_detect_preset)
	fi

	preset_file=$(zai_get_preset_path "$name")

	if [ ! -f "$preset_file" ]; then
		echo "[zai] WARNING: Preset '$name' not found at $preset_file" >&2
		echo "[zai] Falling back to: $ZAI_DEFAULT_PRESET" >&2
		preset_file=$(zai_get_preset_path "$ZAI_DEFAULT_PRESET")
		if [ ! -f "$preset_file" ]; then
			echo "[zai] ERROR: Default preset also missing!" >&2
			return 1
		fi
	fi

	# Source the preset file to set ANTHROPIC_* vars
	# Use eval to handle ${VAR:-} expansion in preset values
	while IFS='=' read -r k v || [ -n "$k" ]; do
		case "$k" in
			ANTHROPIC_BASE_URL)
				eval "export $k=\"$v\""
				;;
			ANTHROPIC_AUTH_TOKEN)
				eval "export $k=${v:-}"
				;;
			ANTHROPIC_DEFAULT_OPUS_MODEL|ANTHROPIC_DEFAULT_SONNET_MODEL|ANTHROPIC_DEFAULT_HAIKU_MODEL)
				export "$k=$v"
				;;
		esac
	done < "$preset_file"

	ZAI_APPLIED_PRESET="$name"
}

# ─── API Key Management ───────────────────────────────────────────────────────

# zai_get_key: Reads API key from file or env var
zai_get_key() {
	if [ -n "${ZAI_API_KEY:-}" ]; then
		echo "$ZAI_API_KEY"
	elif [ -f "$ZAI_API_KEY_FILE" ]; then
		cat "$ZAI_API_KEY_FILE"
	fi
}

# zai_verify_key: Ensures API key is set before export (E1)
# Returns 0 if key is set, 1 if missing
zai_verify_key() {
	local key
	key=$(zai_get_key)
	if [ -z "$key" ]; then
		echo "[zai] WARNING: Z.ai API key not set." >&2
		echo "[zai] Set it with: zai set-key <your-api-key>" >&2
		echo "[zai] Or export:   export ZAI_API_KEY=sk-..." >&2
		return 1
	fi
	echo "$key"
}

# zai_store_key: Writes API key to secure file (E2)
# Arguments: API key string
zai_store_key() {
	local key="$1"
	if [ -z "$key" ]; then
		echo "[zai] ERROR: No API key provided." >&2
		echo "[zai] Usage: zai set-key <your-zai-api-key>" >&2
		return 1
	fi

	mkdir -p "$ZAI_DIR"
	echo "$key" > "$ZAI_API_KEY_FILE"
	chmod 600 "$ZAI_API_KEY_FILE"
	echo "[zai] API key stored securely at $ZAI_API_KEY_FILE"
}

# ─── Environment Export ───────────────────────────────────────────────────────

# zai_export: Main export function — detects preset, applies it, exports vars
zai_export() {
	local key

	# Apply preset (call directly, NOT via $() — subshell kills exports)
	zai_apply_preset

	# Set ZAI_API_KEY from file if not already in env
	if [ -z "${ZAI_API_KEY:-}" ] && [ -f "$ZAI_API_KEY_FILE" ]; then
		export ZAI_API_KEY
		ZAI_API_KEY=$(cat "$ZAI_API_KEY_FILE")
	fi

	# Export the key for substitution in preset env files
	if [ -n "${ZAI_API_KEY:-}" ]; then
		export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
	fi

	export ZAI_ACTIVE_PRESET="${ZAI_APPLIED_PRESET:-}"

	# Export is complete — env vars are now set for Claude Code
	return 0
}

# ─── CLI Commands ─────────────────────────────────────────────────────────────

# zai_cmd_check: Diagnostic status (E3: shows timezone info)
zai_cmd_check() {
	local preset_name key ist_time os shell_type
	local preset_display="" key_status="" key_hint=""

	os=$(zai_detect_os)
	ist_time=$(zai_get_time_ist)
	preset_name=$(zai_detect_preset)
	key=$(zai_get_key)
	shell_type="${SHELL##*/}"

	echo "╔══════════════════════════════════════╗"
	echo "║        zai — utility status          ║"
	echo "╚══════════════════════════════════════╝"
	echo ""
	echo "System"
	echo "  OS:              $os"
	echo "  Shell:           $shell_type"
	echo "  Date flags:      $([ "$os" = "macos" ] && echo "BSD (-j)" || echo "GNU (-d)")"
	echo ""
	echo "Timezone"
	echo "  Source:          ${ZAI_TZ}"
	echo "  Current (IST):   $(TZ="$ZAI_TZ" date '+%H:%M %Z' 2>/dev/null)"
	echo "  HHMM numeric:    ${ist_time}"
	echo ""
	echo "Preset"
	if [ -n "$ZAI_PRESET_OVERRIDE" ]; then
		echo "  Active:          ${ZAI_PRESET_OVERRIDE} (overridden)"
	else
		echo "  Active:          ${preset_name}"
	fi
	echo ""
	echo "  Model map:"

	# Show model mapping by sourcing the active preset
	local active_preset="${ZAI_PRESET_OVERRIDE:-$preset_name}"
	local preset_file
	preset_file=$(zai_get_preset_path "$active_preset")
	if [ -f "$preset_file" ]; then
		while IFS='=' read -r key_eq val; do
			case "$key_eq" in
				ANTHROPIC_DEFAULT_OPUS_MODEL)
					printf "    %-30s %s\n" "Opus:" "$val" ;;
				ANTHROPIC_DEFAULT_SONNET_MODEL)
					printf "    %-30s %s\n" "Sonnet:" "$val" ;;
				ANTHROPIC_DEFAULT_HAIKU_MODEL)
					printf "    %-30s %s\n" "Haiku:" "$val" ;;
			esac
		done < "$preset_file"
	fi

	echo ""
	echo "API Key"
	if [ -n "$key" ]; then
		echo "  Status:          set"
		echo "  Prefix:          ${key:0:8}..."
		if [ -f "$ZAI_API_KEY_FILE" ]; then
			local perms
			perms=$(stat -c '%a' "$ZAI_API_KEY_FILE" 2>/dev/null)
			echo "  File perms:      ${perms} ($([ "$perms" = "600" ] && echo "secure ✓" || echo "WARNING: not 600!"))"
		else
			echo "  Source:          env var ZAI_API_KEY"
		fi
	else
		echo "  Status:          NOT SET"
		echo "  Hint:            zai set-key <your-api-key>"
	fi

	# Active env vars preview
	echo ""
	echo "Env Vars (exported to Claude Code)"
	local base_url opus sonnet haiku
	base_url=$(echo "${ANTHROPIC_BASE_URL:-https://api.z.ai/api/anthropic}")

	# Read model values directly from the active preset file (not from potentially stale env vars)
	local active_preset="${ZAI_PRESET_OVERRIDE:-$preset_name}"
	local preset_file
	preset_file=$(zai_get_preset_path "$active_preset")
	if [ -f "$preset_file" ]; then
		opus=$(grep -m1 '^ANTHROPIC_DEFAULT_OPUS_MODEL=' "$preset_file" 2>/dev/null | cut -d= -f2)
		sonnet=$(grep -m1 '^ANTHROPIC_DEFAULT_SONNET_MODEL=' "$preset_file" 2>/dev/null | cut -d= -f2)
		haiku=$(grep -m1 '^ANTHROPIC_DEFAULT_HAIKU_MODEL=' "$preset_file" 2>/dev/null | cut -d= -f2)
	fi
	opus="${opus:-<not set>}"
	sonnet="${sonnet:-<not set>}"
	haiku="${haiku:-<not set>}"
	printf "  %-35s %s\n" "ANTHROPIC_BASE_URL:" "${base_url}"
	printf "  %-35s %s\n" "ANTHROPIC_DEFAULT_OPUS_MODEL:" "${opus:-<not set>}"
	printf "  %-35s %s\n" "ANTHROPIC_DEFAULT_SONNET_MODEL:" "${sonnet:-<not set>}"
	printf "  %-35s %s\n" "ANTHROPIC_DEFAULT_HAIKU_MODEL:" "${haiku:-<not set>}"
	echo ""
	echo "Timeline"
	echo "  Preset windows (IST):"
	echo "    00:00-06:29   daily-coding"
	echo "    06:30-11:29   deep-thinking-offpeak"
	echo "    11:30-15:29   deep-thinking-peak"
	echo "    15:30-23:59   deep-thinking-offpeak"
	echo "    11:29-11:31   ±60s grace window → peak"
	echo ""
}

# zai_cmd_set_key: Store API key
zai_cmd_set_key() {
	if [ $# -lt 1 ]; then
		echo "[zai] Usage: zai set-key <your-zai-api-key>" >&2
		echo "[zai] Hint:  zai set-key sk-your-key-here" >&2
		return 1
	fi
	zai_store_key "$1"
}

# zai_cmd_preset: Override the active preset
zai_cmd_preset() {
	if [ $# -lt 1 ]; then
		echo "[zai] Usage: zai preset <preset-name>" >&2
		echo "[zai] Available presets:" >&2
		for p in "$ZAI_PRESETS_DIR"/*.env; do
			local name
			name=$(basename "$p" .env)
			echo "  - $name"
		done
		return 1
	fi

	local name="$1"
	local preset_file
	preset_file=$(zai_get_preset_path "$name")
	if [ ! -f "$preset_file" ]; then
		echo "[zai] ERROR: Preset '$name' not found." >&2
		echo "[zai] Available: daily-coding, deep-thinking-offpeak, deep-thinking-peak, docs-utility" >&2
		return 1
	fi

	export ZAI_PRESET_OVERRIDE="$name"
	zai_apply_preset "$name"
	echo "[zai] Preset overridden to: $name"
	echo "[zai] Run 'zai --check' to verify."
}

# zai_cmd_shell: Emit shell integration snippet
zai_cmd_shell() {
	local shell_type="${SHELL##*/}"

	case "$shell_type" in
		fish)
			cat <<-FISH
				# Zai — auto-switch Claude Code presets by IST time
				set -gx ZAI_DIR \$ZAI_DIR $HOME/.local/share/zai
				source \$ZAI_DIR/src/main.sh
				alias claude-doc="env ZAI_PRESET_OVERRIDE=docs-utility claude"
			FISH
			;;
		*)
			cat <<-EOBASH
				# Zai — auto-switch Claude Code presets by IST time
				export ZAI_DIR="\${ZAI_DIR:-\$HOME/.local/share/zai}"
				[[ -f "\$ZAI_DIR/src/main.sh" ]] && source "\$ZAI_DIR/src/main.sh"
				alias claude-doc='ZAI_PRESET_OVERRIDE=docs-utility claude'
			EOBASH
			;;
	esac
}

# zai_cmd_skills: Delegate to skills.sh
zai_cmd_skills() {
	local skills_script="$ZAI_DIR/src/skills.sh"
	if [ ! -f "$skills_script" ] && [ -n "$ZAI_SCRIPT_DIR" ]; then
		skills_script="$ZAI_SCRIPT_DIR/skills.sh"
	fi

	if [ ! -f "$skills_script" ]; then
		echo "[zai] ERROR: skills.sh not found. Has zai been installed?" >&2
		echo "[zai] Run install.sh first, or check ZAI_DIR." >&2
		return 1
	fi

	# shellcheck disable=SC1090
	source "$skills_script" "$@"
}

# ─── Main Dispatch ────────────────────────────────────────────────────────────

zai_main() {
	if [ $# -eq 0 ]; then
		zai_export
		return $?
	fi

	case "${1:-}" in
		--check|-c|status)
			zai_cmd_check
			;;
		set-key)
			shift
			zai_cmd_set_key "$@"
			;;
		preset)
			shift
			zai_cmd_preset "$@"
			;;
		shell)
			zai_cmd_shell
			;;
		skills)
			shift
			zai_cmd_skills "$@"
			;;
		--help|-h)
			echo "Zai — Claude Code Preset Switcher & Skills Manager"
			echo ""
			echo "Usage:"
			echo "  source zai              Export env vars (add to .zshrc)"
			echo "  zai --check             Show diagnostic status"
			echo "  zai set-key <key>       Store Z.ai API key"
			echo "  zai preset <name>       Override preset"
			echo "  zai shell               Print shell integration"
			echo "  zai skills list         List available skills"
			echo "  zai skills docs         Generate skills index"
			echo "  zai --help              This help"
			;;
		*)
			echo "[zai] Unknown command: ${1:-}" >&2
			echo "[zai] Run 'zai --help' for usage." >&2
			return 1
			;;
	esac
}

# ─── Entry Point ──────────────────────────────────────────────────────────────

# Detect if being sourced (works in bash and zsh)
# When sourced, export env vars automatically
# When executed, dispatch CLI command
_zai_is_sourced() {
	# In zsh: check ZSH_EVAL_CONTEXT for file-sourcing,
	# also check if $0 does not end with main.sh (sourced vs executed)
	if [ -n "${ZSH_VERSION-}" ]; then
		case "$ZSH_EVAL_CONTEXT" in
			*:file:*)       return 0 ;;  # sourced from another file
			*toplevel*)     return 0 ;;  # sourced from interactive prompt
			*cmdarg*)       return 0 ;;  # sourced via zsh -c
		esac
		# If we have no CLI args, assume sourced
		[ $# -eq 0 ] && return 0
		return 1
	elif [ -n "${BASH_SOURCE-}" ]; then
		[ "${BASH_SOURCE[0]}" != "${0}" ] && return 0
		return 1
	fi
	return 1
}

if _zai_is_sourced; then
	zai_export
else
	zai_main "$@"
fi
