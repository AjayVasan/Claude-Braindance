#!/usr/bin/env bash
# Braindance — Claude Code Preset Switcher & Skills Manager
# Dual-purpose: source for env export, execute for CLI commands
#
# Usage:
#   source src/main.sh           # Export env vars for current shell
#   braindance --check           # Show diagnostic status
#   braindance set-key <token>   # Store API key
#   braindance preset <name>     # Override active preset
#   braindance shell             # Emit shell integration snippet
#   braindance skills <list|docs> # Manage skills
#
# Environment:
#   BRAINDANCE_DIR         Config directory (default: ~/.local/share/braindance)
#   BRAINDANCE_TZ          Timezone for preset switching (default: Asia/Kolkata)
#   BRAINDANCE_API_KEY     API token (can be set via file or env var)
#   BRAINDANCE_PRESET_OVERRIDE  Force a specific preset

# ─── Script Directory (cross-shell: bash + zsh) ──────────────────────────────

BRAINDANCE_SCRIPT_DIR=""
if [ -n "${BASH_SOURCE-}" ] && [ "${BASH_SOURCE[0]}" ]; then
	# Follow symlinks to get the real script directory
	_bd_src="${BASH_SOURCE[0]}"
	while [ -L "$_bd_src" ]; do
		_bd_link="$(readlink "$_bd_src")"
		case "$_bd_link" in
			/*) _bd_src="$_bd_link" ;;  # absolute
			*)  _bd_src="$(cd "$(dirname "$_bd_src")" && pwd)/$_bd_link" ;;  # relative
		esac
	done
	BRAINDANCE_SCRIPT_DIR="$(cd "$(dirname "$_bd_src")" && pwd)"
	unset _bd_src _bd_link
elif [ -n "${ZSH_VERSION-}" ]; then
	# In zsh, use the %x expansion to get the sourced file path
	BRAINDANCE_SCRIPT_DIR="${${(%):-%x}:A:h}" 2>/dev/null || BRAINDANCE_SCRIPT_DIR="$PWD"
else
	BRAINDANCE_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# ─── Configuration ────────────────────────────────────────────────────────────

BRAINDANCE_DIR="${BRAINDANCE_DIR:-$HOME/.local/share/braindance}"
BRAINDANCE_PRESETS_DIR="${BRAINDANCE_DIR}/presets"
BRAINDANCE_SKILLS_DIR="${BRAINDANCE_DIR}/skills"
BRAINDANCE_API_KEY_FILE="${BRAINDANCE_DIR}/api-key"
BRAINDANCE_TZ="${BRAINDANCE_TZ:-Asia/Kolkata}"
BRAINDANCE_PRESET_OVERRIDE="${BRAINDANCE_PRESET_OVERRIDE:-}"
BRAINDANCE_DEFAULT_PRESET="daily-coding"

# ─── Time Detection ───────────────────────────────────────────────────────────

# braindance_detect_os: Detects OS for date command compatibility (E5)
# Returns: "linux" or "macos"
braindance_detect_os() {
	case "$(uname -s)" in
		Darwin) echo "macos" ;;
		*)      echo "linux" ;;
	esac
}

# braindance_get_time_ist: Returns current IST time as 4-digit string (HHMM)
# Handles BSD vs GNU date flags (E5)
# Applies ±60s grace window at 11:30 boundary (E6)
braindance_get_time_ist() {
	local os raw_time minute_part
	os=$(braindance_detect_os)
	case "$os" in
		macos)
			raw_time=$(TZ="$BRAINDANCE_TZ" date +%H:%M 2>/dev/null || TZ="$BRAINDANCE_TZ" date -j +%H:%M)
			;;
		*)
			raw_time=$(TZ="$BRAINDANCE_TZ" date +%H:%M)
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

# braindance_detect_preset: Maps current IST time to preset name
# Time windows:
#   00:00-06:29 → daily (default — late night is uncategorized)
#   06:30-11:29 → offpeak (before peak hours)
#   11:30-15:29 → peak (peak thinking hours)
#   15:30-23:59 → offpeak (after peak hours)
braindance_detect_preset() {
	local time_ist
	time_ist=$(braindance_get_time_ist)

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

# braindance_get_preset_path: Resolves preset file path
# Arguments: preset name (without .env)
braindance_get_preset_path() {
	local name="${1:-$BRAINDANCE_DEFAULT_PRESET}"
	local search_paths
	search_paths="$BRAINDANCE_PRESETS_DIR/${name}.env"

	if [ ! -f "$search_paths" ]; then
		if [ -d "$BRAINDANCE_SCRIPT_DIR/../presets" ]; then
			search_paths="$BRAINDANCE_SCRIPT_DIR/../presets/${name}.env"
		fi
	fi

	echo "$search_paths"
}

# braindance_apply_preset: Sources the preset .env file to export its vars
# Arguments: preset name
braindance_apply_preset() {
	local name="${1:-}"
	local preset_file

	# Check override file (persists across subprocess boundaries)
	if [ -f "$BRAINDANCE_DIR/override" ]; then
		BRAINDANCE_PRESET_OVERRIDE=$(cat "$BRAINDANCE_DIR/override")
		export BRAINDANCE_PRESET_OVERRIDE
	elif [ -n "${BRAINDANCE_PRESET_OVERRIDE:-}" ]; then
		# Env var set but file gone — stale override from old shell session
		unset BRAINDANCE_PRESET_OVERRIDE
	fi

	if [ -n "${BRAINDANCE_PRESET_OVERRIDE:-}" ]; then
		name="$BRAINDANCE_PRESET_OVERRIDE"
	elif [ -z "$name" ]; then
		name=$(braindance_detect_preset)
	fi

	preset_file=$(braindance_get_preset_path "$name")

	if [ ! -f "$preset_file" ]; then
		echo "[braindance] WARNING: Preset '$name' not found at $preset_file" >&2
		echo "[braindance] Falling back to: $BRAINDANCE_DEFAULT_PRESET" >&2
		preset_file=$(braindance_get_preset_path "$BRAINDANCE_DEFAULT_PRESET")
		if [ ! -f "$preset_file" ]; then
			echo "[braindance] ERROR: Default preset also missing!" >&2
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

	BRAINDANCE_APPLIED_PRESET="$name"
}

# ─── API Key Management ───────────────────────────────────────────────────────

# braindance_get_key: Reads API key from file or env var
braindance_get_key() {
	if [ -n "${BRAINDANCE_API_KEY:-}" ]; then
		echo "$BRAINDANCE_API_KEY"
	elif [ -f "$BRAINDANCE_API_KEY_FILE" ]; then
		cat "$BRAINDANCE_API_KEY_FILE"
	fi
}

# braindance_verify_key: Ensures API key is set before export (E1)
# Returns 0 if key is set, 1 if missing
braindance_verify_key() {
	local key
	key=$(braindance_get_key)
	if [ -z "$key" ]; then
		echo "[braindance] WARNING: Z.ai API key not set." >&2
		echo "[braindance] Set it with: braindance set-key <your-api-key>" >&2
		echo "[braindance] Or export:   export BRAINDANCE_API_KEY=sk-..." >&2
		return 1
	fi
	echo "$key"
}

# braindance_store_key: Writes API key to secure file (E2)
# Arguments: API key string
braindance_store_key() {
	local key="$1"
	if [ -z "$key" ]; then
		echo "[braindance] ERROR: No API key provided." >&2
		echo "[braindance] Usage: braindance set-key <your-api-key>" >&2
		return 1
	fi

	mkdir -p "$BRAINDANCE_DIR"
	echo "$key" > "$BRAINDANCE_API_KEY_FILE"
	chmod 600 "$BRAINDANCE_API_KEY_FILE"
	echo "[braindance] API key stored securely at $BRAINDANCE_API_KEY_FILE"
}

# ─── Environment Export ───────────────────────────────────────────────────────

# braindance_export: Main export function — detects preset, applies it, exports vars
braindance_export() {
	local key

	# Apply preset (call directly, NOT via $() — subshell kills exports)
	braindance_apply_preset

	# Set BRAINDANCE_API_KEY from file if not already in env
	if [ -z "${BRAINDANCE_API_KEY:-}" ] && [ -f "$BRAINDANCE_API_KEY_FILE" ]; then
		export BRAINDANCE_API_KEY
		BRAINDANCE_API_KEY=$(cat "$BRAINDANCE_API_KEY_FILE")
	fi

	# Export the key for substitution in preset env files
	if [ -n "${BRAINDANCE_API_KEY:-}" ]; then
		export ANTHROPIC_AUTH_TOKEN="$BRAINDANCE_API_KEY"
	fi

	export BRAINDANCE_ACTIVE_PRESET="${BRAINDANCE_APPLIED_PRESET:-}"

	# Export is complete — env vars are now set for Claude Code
	return 0
}

# ─── CLI Commands ─────────────────────────────────────────────────────────────

# braindance_cmd_check: Diagnostic status (E3: shows timezone info)
braindance_cmd_check() {
	local preset_name key ist_time os shell_type
	local preset_display="" key_status="" key_hint=""

	os=$(braindance_detect_os)
	ist_time=$(braindance_get_time_ist)
	# Resolve preset name considering override file
	if [ -f "$BRAINDANCE_DIR/override" ]; then
		preset_name=$(cat "$BRAINDANCE_DIR/override")
		preset_display=" (overridden)"
	elif [ -n "${BRAINDANCE_PRESET_OVERRIDE:-}" ]; then
		preset_name="$BRAINDANCE_PRESET_OVERRIDE"
		preset_display=" (overridden)"
	else
		preset_name=$(braindance_detect_preset)
	fi
	key=$(braindance_get_key)
	shell_type="${SHELL##*/}"

	echo "╔══════════════════════════════════════╗"
	echo "║     braindance — utility status      ║"
	echo "╚══════════════════════════════════════╝"
	echo ""
	echo "System"
	echo "  OS:              $os"
	echo "  Shell:           $shell_type"
	echo "  Date flags:      $([ "$os" = "macos" ] && echo "BSD (-j)" || echo "GNU (-d)")"
	echo ""
	echo "Timezone"
	echo "  Source:          ${BRAINDANCE_TZ}"
	echo "  Current (IST):   $(TZ="$BRAINDANCE_TZ" date '+%H:%M %Z' 2>/dev/null)"
	echo "  HHMM numeric:    ${ist_time}"
	echo ""
	echo "Preset"
	echo "  Active:          ${preset_name}${preset_display:-}"
	echo ""
	echo "  Model map:"

	# Show model mapping by reading the preset file
	local preset_file
	preset_file=$(braindance_get_preset_path "$preset_name")
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
		if [ -f "$BRAINDANCE_API_KEY_FILE" ]; then
			local perms
			perms=$(stat -c '%a' "$BRAINDANCE_API_KEY_FILE" 2>/dev/null || stat -f '%Lp' "$BRAINDANCE_API_KEY_FILE" 2>/dev/null)
			echo "  File perms:      ${perms} ($([ "$perms" = "600" ] && echo "secure" || echo "WARNING: not 600!"))"
		else
			echo "  Source:          env var BRAINDANCE_API_KEY"
		fi
	else
		echo "  Status:          NOT SET"
		echo "  Hint:            braindance set-key <your-api-key>"
	fi

	# Active env vars preview
	echo ""
	echo "Env Vars (exported to Claude Code)"
	local base_url opus sonnet haiku
	base_url=$(echo "${ANTHROPIC_BASE_URL:-https://api.z.ai/api/anthropic}")

	local preset_file
	preset_file=$(braindance_get_preset_path "$preset_name")
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

# braindance_cmd_set_key: Store API key
braindance_cmd_set_key() {
	if [ $# -lt 1 ]; then
		echo "[braindance] Usage: braindance set-key <your-api-key>" >&2
		echo "[braindance] Hint:  braindance set-key sk-your-key-here" >&2
		return 1
	fi
	braindance_store_key "$1"
}

# braindance_cmd_preset: Override the active preset
braindance_cmd_preset() {
	if [ $# -lt 1 ]; then
		echo "[braindance] Usage: braindance preset <preset-name>" >&2
		echo "[braindance]        braindance preset reset   (clear override)" >&2
		echo "[braindance] Available presets:" >&2
		for p in "$BRAINDANCE_PRESETS_DIR"/*.env; do
			local pname
			pname=$(basename "$p" .env)
			echo "  - $pname"
		done
		return 1
	fi

	local name="$1"

	if [ "$name" = "reset" ] || [ "$name" = "auto" ]; then
		braindance_cmd_auto
		return 0
	fi

	local preset_file
	preset_file=$(braindance_get_preset_path "$name")
	if [ ! -f "$preset_file" ]; then
		echo "[braindance] ERROR: Preset '$name' not found." >&2
		echo "[braindance] Available: daily-coding, deep-thinking-offpeak, deep-thinking-peak, docs-utility" >&2
		return 1
	fi

	mkdir -p "$BRAINDANCE_DIR"
	echo "$name" > "$BRAINDANCE_DIR/override"
	echo "[braindance] Preset overridden to: $name"
	echo "[braindance] Use 'braindance preset reset' to revert to time-based."
}

# braindance_cmd_shell: Emit shell integration snippet
braindance_cmd_shell() {
	local shell_type="${SHELL##*/}"

	case "$shell_type" in
		fish)
			cat <<-FISH
				# Braindance — auto-switch Claude Code presets by IST time
				set -gx BRAINDANCE_DIR \$BRAINDANCE_DIR $HOME/.local/share/braindance
				source \$BRAINDANCE_DIR/src/main.sh
				alias claude-doc="env BRAINDANCE_PRESET_OVERRIDE=docs-utility claude"
			FISH
			;;
		*)
			cat <<-EOBASH
				# Braindance — auto-switch Claude Code presets by IST time
				export BRAINDANCE_DIR="\${BRAINDANCE_DIR:-\$HOME/.local/share/braindance}"
				[[ -f "\$BRAINDANCE_DIR/src/main.sh" ]] && source "\$BRAINDANCE_DIR/src/main.sh"

				# Wrap claude to re-evaluate preset on every invocation
				claude() {
					[[ -f "\$BRAINDANCE_DIR/src/main.sh" ]] && source "\$BRAINDANCE_DIR/src/main.sh"
					local bd_preset="\${BRAINDANCE_ACTIVE_PRESET:-unknown}"
					local bd_opus="\${ANTHROPIC_DEFAULT_OPUS_MODEL:-?}"
					local bd_sonnet="\${ANTHROPIC_DEFAULT_SONNET_MODEL:-?}"
					local bd_haiku="\${ANTHROPIC_DEFAULT_HAIKU_MODEL:-?}"
					printf "  [braindance] %s | opus: %s  sonnet: %s  haiku: %s\n" "\$bd_preset" "\$bd_opus" "\$bd_sonnet" "\$bd_haiku"
					command claude "\$@"
				}
				alias claude-doc='BRAINDANCE_PRESET_OVERRIDE=docs-utility command claude'
			EOBASH
			;;
	esac
}

# braindance_cmd_auto: Clear override and revert to time-based detection
braindance_cmd_auto() {
	if [ -f "$BRAINDANCE_DIR/override" ]; then
		rm -f "$BRAINDANCE_DIR/override"
		unset BRAINDANCE_PRESET_OVERRIDE
	fi
	local preset
	preset=$(braindance_detect_preset)
	echo "[braindance] Override cleared. Reverted to time-based detection."
	echo "[braindance] Current preset: $preset"
}

# braindance_cmd_hooks_install: Install Claude Code SessionStart hook
braindance_cmd_hooks_install() {
	local hooks_dir="$HOME/.claude/hooks"
	local marker_start="# === braindance start ==="
	local marker_end="# === braindance end ==="
	local hook_file="$hooks_dir/SessionStart"

	mkdir -p "$hooks_dir"

	if [ -f "$hook_file" ]; then
		sed -i "/$marker_start/,/$marker_end/d" "$hook_file" 2>/dev/null || true
	fi

	if [ ! -f "$hook_file" ]; then
		printf '#!/usr/bin/env bash\n' > "$hook_file"
		chmod +x "$hook_file"
	fi

	{
		printf '\n'
		printf '%s\n' "$marker_start"
		printf '# Braindance — show active preset at Claude Code session start\n'
		printf 'BRAINDANCE_DIR="${BRAINDANCE_DIR:-$HOME/.local/share/braindance}"\n'
		printf 'if [ -f "$BRAINDANCE_DIR/src/main.sh" ]; then\n'
		printf '  source "$BRAINDANCE_DIR/src/main.sh" 2>/dev/null\n'
		printf '  printf '"'"'╭─ braindance ─────────────────────────────────────────╮\n'"'"'\n'
		printf '  printf '"'"'│ mindset:  %-41s │\n'"'"' "${BRAINDANCE_ACTIVE_PRESET:-unknown}"\n'
		printf '  printf '"'"'│ opus:     %-41s │\n'"'"' "${ANTHROPIC_DEFAULT_OPUS_MODEL:-not-set}"\n'
		printf '  printf '"'"'│ sonnet:   %-41s │\n'"'"' "${ANTHROPIC_DEFAULT_SONNET_MODEL:-not-set}"\n'
		printf '  printf '"'"'│ haiku:    %-41s │\n'"'"' "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-not-set}"\n'
		printf '  printf '"'"'╰──────────────────────────────────────────────────────╯\n'"'"'\n'
		printf 'fi\n'
		printf '%s\n' "$marker_end"
	} >> "$hook_file"

	echo "[braindance] ✓ Hook updated at $hook_file"
	echo "[braindance] Every Claude Code session now shows braindance status."
}

braindance_cmd_upgrade() {
	local rc_file="$HOME/.zshrc"
	if [ ! -f "$rc_file" ]; then
		echo "[braindance] No .zshrc found."
		return 1
	fi

	if ! grep -q "Braindance" "$rc_file" 2>/dev/null; then
		echo "[braindance] No braindance integration found in .zshrc."
		echo "[braindance] Run 'braindance shell' to see integration snippet."
		return 0
	fi

	sed -i '/# Braindance/,/^$/d' "$rc_file"

	{
	echo ""
	echo "# Braindance — auto-switch Claude Code presets by IST time"
	echo "export BRAINDANCE_DIR=\"\${BRAINDANCE_DIR:-\$HOME/.local/share/braindance}\""
	echo "[[ -f \"\$BRAINDANCE_DIR/src/main.sh\" ]] && source \"\$BRAINDANCE_DIR/src/main.sh\""
	echo ""
		echo 'claude() {'
		echo '	[[ -f "$BRAINDANCE_DIR/src/main.sh" ]] && source "$BRAINDANCE_DIR/src/main.sh"'
		echo '	local bd_preset="${BRAINDANCE_ACTIVE_PRESET:-unknown}"'
		echo '	local bd_opus="${ANTHROPIC_DEFAULT_OPUS_MODEL:-?}"'
		echo '	local bd_sonnet="${ANTHROPIC_DEFAULT_SONNET_MODEL:-?}"'
		echo '	local bd_haiku="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-?}"'
		echo '	printf "  [braindance] %s | opus: %s  sonnet: %s  haiku: %s\n" "$bd_preset" "$bd_opus" "$bd_sonnet" "$bd_haiku"'
		echo '	command claude "$@"'
		echo '}'
		echo "alias claude-doc='BRAINDANCE_PRESET_OVERRIDE=docs-utility command claude'"
	} >> "$rc_file"

	echo "[braindance] ✓ Shell integration upgraded in $rc_file"
	echo "[braindance] Run: exec \$SHELL"
}

# braindance_cmd_completions: Install zsh tab-completions
braindance_cmd_completions() {
	local action="${1:-}"
	case "$action" in
		install)
			local comp_target="$HOME/.zsh/completions/_braindance"
			mkdir -p "$HOME/.zsh/completions"
			cp "$BRAINDANCE_SCRIPT_DIR/completion.zsh" "$comp_target"

			# Add to shell integration if not already there
			local rc_file="$HOME/.zshrc"
			if grep -q "_braindance_complete" "$rc_file" 2>/dev/null; then
				echo "[braindance] ✓ Completion already sourced in $rc_file"
			else
				cat >> "$rc_file" <<- EORC
					# Braindance tab-completions
					[[ -f "$HOME/.zsh/completions/_braindance" ]] && source "$HOME/.zsh/completions/_braindance"
				EORC
				echo "[braindance] ✓ Added source line to $rc_file"
			fi
			echo "[braindance] ✓ Completions installed. Run: exec \$SHELL"
			;;
		*)
			echo "[braindance] Usage: braindance completions install"
			echo "[braindance] Installs tab-completion for presets and commands."
			;;
	esac
}

# braindance_cmd_skills: Delegate to skills.sh
braindance_cmd_skills() {
	local skills_script="$BRAINDANCE_DIR/src/skills.sh"
	if [ ! -f "$skills_script" ] && [ -n "$BRAINDANCE_SCRIPT_DIR" ]; then
		skills_script="$BRAINDANCE_SCRIPT_DIR/skills.sh"
	fi

	if [ ! -f "$skills_script" ]; then
		echo "[braindance] ERROR: skills.sh not found. Has braindance been installed?" >&2
		echo "[braindance] Run install.sh first, or check BRAINDANCE_DIR." >&2
		return 1
	fi

	# shellcheck disable=SC1090
	source "$skills_script" "$@"
}

# ─── Main Dispatch ────────────────────────────────────────────────────────────

braindance_main() {
	set -euo pipefail
	if [ $# -eq 0 ]; then
		braindance_export
		return $?
	fi

	case "${1:-}" in
		--check|-c|status)
			braindance_cmd_check
			;;
		set-key)
			shift
			braindance_cmd_set_key "$@"
			;;
		preset)
			shift
			braindance_cmd_preset "$@"
			;;
		auto|--auto)
			braindance_cmd_auto
			;;
		shell)
			braindance_cmd_shell
			;;
		skills)
			shift
			braindance_cmd_skills "$@"
			;;
		hooks-install)
			braindance_cmd_hooks_install
			;;
		completions)
			shift
			braindance_cmd_completions "$@"
			;;
		upgrade)
			braindance_cmd_upgrade
			;;
		--help|-h)
			echo "Braindance — Claude Code Preset Switcher & Skills Manager"
			echo ""
			echo "Usage:"
			echo "  source braindance       Export env vars (add to .zshrc)"
			echo "  braindance --check             Show diagnostic status"
			echo "  braindance set-key <key>       Store Z.ai API key"
			echo "  braindance preset <name>       Override mindset (persists)"
			echo "  braindance auto                Revert to time-based auto-detection"
			echo "  braindance preset reset        Clear override, revert to auto"
			echo "  braindance upgrade             Update .zshrc to latest integration"
			echo "  braindance shell               Print shell integration"
			echo "  braindance hooks-install       Install Claude Code SessionStart hook"
			echo "  braindance completions install Install zsh tab-completions"
			echo "  braindance skills list         List available skills"
			echo "  braindance skills docs         Generate skills index"
			echo "  braindance --help              This help"
			;;
		*)
			echo "[braindance] Unknown command: ${1:-}" >&2
			echo "[braindance] Run 'braindance --help' for usage." >&2
			return 1
			;;
	esac
}

# ─── Entry Point ──────────────────────────────────────────────────────────────

# Detect if being sourced (works in bash and zsh)
# When sourced, export env vars automatically
# When executed, dispatch CLI command
_braindance_is_sourced() {
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

if _braindance_is_sourced; then
	braindance_export
else
	braindance_main "$@"
fi
