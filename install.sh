#!/usr/bin/env bash
# Braindance — Installer
# One-shot setup: detects platform, installs files, configures shell
#
# With Cyberpunk 2077 braindance calibration sequence.
#
# Usage:
#   bash install.sh            # Interactive install
#   bash install.sh --yes      # Non-interactive (auto-confirm)
#
# Supports: Linux (GNU date), macOS (BSD date), Linux (musl/Alpine)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BRAINDANCE_DIR="${BRAINDANCE_DIR:-$HOME/.local/share/braindance}"
BRAINDANCE_BIN_DIR="${HOME}/.local/bin"
AUTO_CONFIRM=false
ANIMATE=true

if [ "${1:-}" = "--yes" ] || [ "${1:-}" = "-y" ]; then
	AUTO_CONFIRM=true
	ANIMATE=false
fi

# ─── Terminal Helpers ─────────────────────────────────────────────────────────

BD_CYAN='\033[96m'
BD_YELLOW='\033[93m'
BD_MAGENTA='\033[95m'
BD_GREEN='\033[92m'
BD_RED='\033[91m'
BD_BOLD='\033[1m'
BD_BLINK='\033[5m'
BD_DIM='\033[2m'
BD_RESET='\033[0m'
BD_CLR_EOL='\033[K'

_bd_hide_cursor() { printf '\033[?25l'; }
_bd_show_cursor() { printf '\033[?25h'; }
_bd_alt_on()     { printf '\033[?1049h\033[H'; }
_bd_alt_off()    { printf '\033[?1049l'; }
_bd_clear()      { printf '\033[2J\033[H'; }

# On any exit (even error), restore terminal so the screen is never stuck
trap '_bd_show_cursor; _bd_alt_off; clear 2>/dev/null || true' EXIT

_bd_cols() { tput cols 2>/dev/null || echo 80; }
_bd_rows() { tput lines 2>/dev/null || echo 24; }

# Write text at exact position
_bd_at() {
	local row=$1 col=$2
	shift 2
	printf '\033[%d;%dH%s' "$row" "$col" "$*"
}

# Print centered text on current line
_bd_center() {
	local text="$1"
	local cols width plain pad
	cols=$(_bd_cols)
	plain=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
	width=${#plain}
	pad=$(( (cols - width) / 2 ))
	[[ $pad -lt 0 ]] && pad=0
	printf "%${pad}s%s\n" "" "$text"
}

# Get centered column offset for a line of text
_bd_center_col() {
	local text="$1"
	local cols width
	cols=$(_bd_cols)
	plain=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
	width=${#plain}
	local pad=$(( (cols - width) / 2 ))
	[[ $pad -lt 0 ]] && pad=0
	echo "$pad"
}

# Fill a rectangular area with spaces (color+bg applied beforehand)
_bd_fill() {
	local row=$1 col=$2 w=$3 h=$4 r c
	for ((r=0; r<h; r++)); do
		printf '\033[%d;%dH' $((row+r)) "$col"
		for ((c=0; c<w; c++)); do printf ' '; done
	done
}

# ─── Cyberpunk Effects ────────────────────────────────────────────────────────

# Scanning line — a bright horizontal line sweeps down the screen
_bd_scan_pass() {
	local rows cols r
	rows=$(_bd_rows)
	cols=$(_bd_cols)
	for ((r=0; r<rows; r+=2)); do
		printf '\033[%d;1H\033[92m%*s\033[0m' $((r+1)) "$cols" ''
		sleep 0.004
		printf '\033[%d;1H\033[K' $((r+1))
	done
}

# Flash — full screen wash with a color
_bd_flash() {
	local color="$1" dur="${2:-0.12}" rows cols r
	rows=$(_bd_rows)
	cols=$(_bd_cols)
	printf '\033[%s\033[%d;1H' "$color" 1
	for ((r=0; r<rows; r++)); do
		printf '%*s' "$cols" ''
	done
	printf '\033[0m'
	sleep "$dur"
}

# Glitch text — scramble random chars then reveal the real text
_bd_glitch_reveal() {
	local text="$1" row="$2" col="$3" delay="${4:-0.035}"
	local chars='!@#$%^&*<>?/\|~=+-_' i j glitch
	local len=${#text}
	for ((i=0; i<10; i++)); do
		glitch=''
		for ((j=0; j<len; j++)); do
			if (( RANDOM % 3 )); then
				glitch+="${chars:$(( RANDOM % ${#chars} )):1}"
			else
				glitch+="${text:$j:1}"
			fi
		done
		printf '\033[%d;%dH\033[91m%s\033[0m' "$row" "$col" "$glitch"
		sleep "$delay"
	done
	printf '\033[%d;%dH\033[93m\033[1m%s\033[0m' "$row" "$col" "$text"
}

# Type out text character by character
_bd_type() {
	local text="$1" row="$2" col="$3" delay="${4:-0.012}" i
	for ((i=0; i<${#text}; i++)); do
		printf '\033[%d;%dH\033[96m%s\033[0m' "$row" $((col+i)) "${text:$i:1}"
		sleep "$delay"
	done
}

# ─── Box Drawing ──────────────────────────────────────────────────────────────

# Draw a centered box with a title row. Sets _BD_CONTENT to first content row.
# Renders directly to terminal (no command substitution — render then read _BD_CONTENT).
_bd_box() {
	local title="$1" width="${2:-58}" color="${3:-96}"
	local rows cols top content_row i left edge reset
	rows=$(_bd_rows)
	cols=$(_bd_cols)
	top=$(( rows / 2 - 7 ))
	[[ -z "$title" ]] && top=$(( rows / 2 - 3 ))
	left=$(( (cols - width) / 2 ))
	[[ $left -lt 0 ]] && left=0
	edge="\033[${color}m\033[1m"
	reset="\033[0m"

	# Top border
	printf '\033[%d;%dH%b╔' "$top" "$left" "$edge"
	for ((i=0; i<width-2; i++)); do printf '═'; done
	printf '╗%b' "$reset"

	# Title row if provided
	content_row=$((top + 1))
	if [[ -n "$title" ]]; then
		printf '\033[%d;%dH%b║%b' "$content_row" "$left" "$edge" "$reset"
		local title_pad=$(( (width - 2 - ${#title}) / 2 ))
		printf '\033[%d;%dH%b%s%b' "$content_row" $((left + title_pad)) "$edge" "$title" "$reset"
		printf '\033[%d;%dH%b║\033[0m\033[K' "$content_row" $((left + width - 1)) "$edge"
		content_row=$((top + 2))
	fi

	# Empty rows between title and bottom
	for ((r=content_row; r<content_row+8; r++)); do
		printf '\033[%d;%dH%b║%b\033[K' "$r" "$left" "$edge" "$reset"
		printf '\033[%d;%dH%b║\033[0m\033[K' "$r" $((left + width - 1)) "$edge"
	done

	# Bottom border
	local bottom=$((content_row + 8))
	printf '\033[%d;%dH%b╚' "$bottom" "$left" "$edge"
	for ((i=0; i<width-2; i++)); do printf '═'; done
	printf '╝%b\033[K' "$reset"

	_BD_CONTENT=$((content_row + 1))
}

# ─── Braindance Calibration ───────────────────────────────────────────────────

# Draw the centered "BRAINDANCE CALIBRATING" neon header
_bd_draw_header() {
	local cols
	cols=$(_bd_cols)
	local text1="⚡ BRAINDANCE CALIBRATING ⚡"
	local text2="preset minds for Claude Code"
	local c1
	c1=$(_bd_center_col "$text1")

	printf '\033[%d;%dH\033[96m\033[1m%s\033[0m' 2 "$c1" "$text1"
	printf '\033[%d;%dH\033[93m\033[2m%s\033[0m' 3 "$(_bd_center_col "$text2")" "$text2"
}

# Full intro cinematic
_bd_cinematic_intro() {
	local cols rows
	cols=$(_bd_cols)
	rows=$(_bd_rows)

	_bd_hide_cursor
	_bd_clear

	# 1 — Scanning line, 2 passes
	_bd_scan_pass
	_bd_scan_pass

	# 2 — Flash green
	_bd_flash '\033[42m' 0.08

	# 3 — Glitch reveal "BRAINDANCE ACTIVE" centered
	local glitch_row=$(( rows / 2 - 2 ))
	local glitch_text="BRAINDANCE ACTIVE"
	local glitch_col
	glitch_col=$(_bd_center_col "$glitch_text")
	_bd_glitch_reveal "$glitch_text" "$glitch_row" $((glitch_col + 1)) 0.03
	sleep 0.25

	# 4 — Flash + dissolve
	_bd_flash '\033[41m' 0.06
	sleep 0.08

	# 5 — Clear and draw the neon header
	_bd_clear
	_bd_draw_header

	# 6 — Slow scan to reveal
	sleep 0.15
	_bd_scan_pass
	sleep 0.1

	_bd_show_cursor
}

# Short intro for --yes mode
_bd_quick_intro() {
	_bd_clear
	_bd_hide_cursor
	local cols
	cols=$(_bd_cols)
	local text="⚡ BRAINDANCE"
	local c
	c=$(_bd_center_col "$text")
	printf '\033[%d;%dH\033[96m\033[1m%s\033[0m' 2 "$c" "$text"
	sleep 0.2
	_bd_show_cursor
}

# ─── Step Rendering ───────────────────────────────────────────────────────────

# Show a step inside the box: draws the step line content at a specific row
_bd_step_show() {
	local content_row="$1" step_num="$2" desc="$3" status="$4"
	local cols col
	cols=$(_bd_cols)
	local box_width=58
	local left=$(( (cols - box_width) / 2 ))
	[[ $left -lt 0 ]] && left=0

	case "$status" in
		running)
			printf '\033[%d;%dH\033[93m  [%s] \033[96m%s...\033[0m\033[K' \
				"$content_row" $((left + 2)) "$step_num" "$desc"
			;;
		done)
			printf '\033[%d;%dH\033[92m  [%s] \033[2m%s\033[0m\033[K' \
				"$content_row" $((left + 2)) "$step_num" "$desc"
			# Checkmark on the right
			local check_col=$((left + box_width - 4))
			printf '\033[%d;%dH\033[92m✓\033[0m\033[K' "$content_row" "$check_col"
			;;
		skip)
			printf '\033[%d;%dH\033[90m  [%s] %s\033[0m\033[K' \
				"$content_row" $((left + 2)) "$step_num" "$desc"
			;;
		info)
			printf '\033[%d;%dH\033[90m  %s\033[0m\033[K' \
				"$content_row" "$((left + 4))" "$desc"
			;;
	esac
}

# Animate a step: type out description, then mark done
_bd_step_run() {
	local content_row="$1" step_num="$2" desc="$3"
	shift 3
	# Run the actual command, capture output
	local out
	out=$("$@" 2>&1) || {
		# Red X on failure
		_bd_step_show "$content_row" "$step_num" "$desc" running
		local cols left box_width
		cols=$(_bd_cols)
		box_width=58
		left=$(( (cols - box_width) / 2 ))
		[[ $left -lt 0 ]] && left=0
		local x_col=$((left + box_width - 4))
		printf '\033[%d;%dH\033[91m✗\033[0m\033[K' "$content_row" "$x_col"
		printf '\033[%d;%dH\033[91m%s\033[0m\033[K\n' $((content_row + 1)) "$((left + 4))" "$out"
		return 1
	}
	_bd_step_show "$content_row" "$step_num" "$desc" done
}

# Animate a step description typing
_bd_step_type() {
	local content_row="$1" step_num="$2" desc="$3" cols left box_width
	cols=$(_bd_cols)
	box_width=58
	left=$(( (cols - box_width) / 2 ))
	[[ $left -lt 0 ]] && left=0

	if $ANIMATE; then
		local full="  [${step_num}] ${desc}"
		_bd_type "$full" "$content_row" $((left + 2)) 0.005
	else
		_bd_step_show "$content_row" "$step_num" "$desc" running
	fi
}

# Print an info line inside the box
_bd_step_info() {
	local content_row="$1" text="$2"
	local cols left box_width
	cols=$(_bd_cols)
	box_width=58
	left=$(( (cols - box_width) / 2 ))
	[[ $left -lt 0 ]] && left=0
	printf '\033[%d;%dH\033[90m  %s\033[0m\033[K' "$content_row" "$((left + 4))" "$text"
}

# ─── OS & Shell Detection ─────────────────────────────────────────────────────

detect_os() {
	case "$(uname -s)" in
		Darwin) echo "macos" ;;
		Linux)  echo "linux" ;;
		*)      echo "unknown" ;;
	esac
}

detect_shell() {
	local sh
	sh="${SHELL##*/}"
	case "$sh" in
		zsh|bash|fish) echo "$sh" ;;
		*) echo "unknown" ;;
	esac
}

get_shell_config() {
	local sh="$1"
	case "$sh" in
		zsh)  echo "$HOME/.zshrc" ;;
		bash) echo "$HOME/.bashrc" ;;
		fish) echo "$HOME/.config/fish/config.fish" ;;
		*)    echo "" ;;
	esac
}

# ─── Confirm / Prompt (inline in alt screen) ──────────────────────────────────

confirm() {
	local prompt="$1"
	if $AUTO_CONFIRM; then
		return 0
	fi
	printf "%s [Y/n] " "$prompt"
	read -r response
	case "$response" in
		""|y|Y|yes|YES) return 0 ;;
		*) return 1 ;;
	esac
}

# ─── Install Steps ────────────────────────────────────────────────────────────

install_braindance() {
	local os shell_type shell_config date_cmd
	local content_start step_row

	os=$(detect_os)
	shell_type=$(detect_shell)
	shell_config=$(get_shell_config "$shell_type")

	# ── Cinematic intro ──
	if $ANIMATE; then
		_bd_cinematic_intro
	else
		_bd_quick_intro
	fi

	_bd_hide_cursor

	# ── Draw the installation box ──
	_bd_box "BRAINDANCE INSTALL" 58 96; content_start=$_BD_CONTENT

	# Show detected system info (lines 0-2 inside box)
	_bd_step_info $((content_start))     "SYSTEM"
	_bd_step_info $((content_start + 1)) "  OS:      ${os}"
	_bd_step_info $((content_start + 2)) "  Shell:   ${shell_type}"
	_bd_step_info $((content_start + 3)) "  Config:  ${shell_config:-"(detection failed)"}"
	_bd_step_info $((content_start + 4)) "  Target:  ${BRAINDANCE_DIR}"

	# Steps start at line 6
	step_row=$((content_start + 6))

	# ── Step 1: Create directories ──
	if $ANIMATE; then
		_bd_step_type "$step_row" "1/6" "Initializing neural interface" 2>/dev/null
	else
		_bd_step_show "$step_row" "1/6" "Initializing neural interface" running
	fi
	mkdir -p "$BRAINDANCE_DIR"/{presets,skills,src}
	mkdir -p "$BRAINDANCE_BIN_DIR"
	_bd_step_show "$step_row" "1/6" "Initializing neural interface" done
	sleep 0.1

	# ── Step 2: Copy source files ──
	if $ANIMATE; then
		_bd_step_type "$((step_row + 1))" "2/6" "Loading preset engrams" 2>/dev/null
	else
		_bd_step_show "$((step_row + 1))" "2/6" "Loading preset engrams" running
	fi
	cp -r "$REPO_DIR/src/"* "$BRAINDANCE_DIR/src/"
	cp -r "$REPO_DIR/presets/"* "$BRAINDANCE_DIR/presets/"
	chmod +x "$BRAINDANCE_DIR/src/main.sh"
	_bd_step_show "$((step_row + 1))" "2/6" "Loading preset engrams" done
	sleep 0.1

	# ── Step 3: Create symlink ──
	if $ANIMATE; then
		_bd_step_type "$((step_row + 2))" "3/6" "Syncing neural pathways"
	else
		_bd_step_show "$((step_row + 2))" "3/6" "Syncing neural pathways" running
	fi
	ln -sf "$BRAINDANCE_DIR/src/main.sh" "$BRAINDANCE_BIN_DIR/braindance"
	_bd_step_show "$((step_row + 2))" "3/6" "Syncing neural pathways" done
	sleep 0.1

	# ── Step 4: PATH check ──
	if [[ ":$PATH:" != *":$BRAINDANCE_BIN_DIR:"* ]]; then
		_bd_step_info $((step_row + 3)) "! PATH not set — add to shell config"
	fi

	# ── Step 5: Shell integration ──
	if $ANIMATE; then
		_bd_step_type "$((step_row + 4))" "4/6" "Wiring shell integration"
	else
		_bd_step_show "$((step_row + 4))" "4/6" "Wiring shell integration" running
	fi
	if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
		if grep -q "Braindance — auto-switch Claude Code presets" "$shell_config" 2>/dev/null; then
			_bd_step_show "$((step_row + 4))" "4/6" "Wiring shell integration" done
			_bd_step_info $((step_row + 5)) "  Already wired — skipping"
		else
			_bd_step_show "$((step_row + 4))" "4/6" "Wiring shell integration" done
			if $AUTO_CONFIRM || confirm "  Add Braindance to ${shell_config}?"; then
				{
					echo ""
					echo "# Braindance — auto-switch Claude Code presets by IST time"
					echo "export BRAINDANCE_DIR=\"\${BRAINDANCE_DIR:-\$HOME/.local/share/braindance}\""
					echo "[[ -f \"\$BRAINDANCE_DIR/src/main.sh\" ]] && source \"\$BRAINDANCE_DIR/src/main.sh\""
					echo ""
					echo "# Re-evaluate preset on every claude invocation"
					echo "claude() {"
					echo "	[[ -f \"\$BRAINDANCE_DIR/src/main.sh\" ]] && source \"\$BRAINDANCE_DIR/src/main.sh\""
					echo '	command claude "$@"'
					echo "}"
					echo "alias claude-doc='BRAINDANCE_PRESET_OVERRIDE=docs-utility command claude'"
				} >> "$shell_config"
				_bd_step_info $((step_row + 5)) "  ✓ Added to ${shell_config}"
			else
				_bd_step_info $((step_row + 5)) "  Skipped — run 'braindance shell' later"
			fi
		fi
	else
		_bd_step_show "$((step_row + 4))" "4/6" "Wiring shell integration" skip
	fi
	sleep 0.1

	# ── Step 6: API key ──
	if $ANIMATE; then
		_bd_step_type "$((step_row + 7))" "5/6" "Registering biometric key"
	else
		_bd_step_show "$((step_row + 7))" "5/6" "Registering biometric key" running
	fi
	if [ -f "$BRAINDANCE_DIR/api-key" ]; then
		_bd_step_show "$((step_row + 7))" "5/6" "Registering biometric key" done
		_bd_step_info $((step_row + 8)) "  Key already registered"
	else
		_bd_step_show "$((step_row + 7))" "5/6" "Registering biometric key" done
		if $AUTO_CONFIRM; then
			_bd_step_info $((step_row + 8)) "  Skipped — set later: braindance set-key"
		elif confirm "  Set Z.ai API key now?"; then
			printf "  Enter your Z.ai API key: "
			read -r api_key
			if [ -n "$api_key" ]; then
				bash "$BRAINDANCE_DIR/src/main.sh" set-key "$api_key"
				_bd_step_info $((step_row + 8)) "  ✓ Biometric key stored"
			else
				_bd_step_info $((step_row + 8)) "  No key — set later: braindance set-key"
			fi
		else
			_bd_step_info $((step_row + 8)) "  Skipped — set later: braindance set-key"
		fi
	fi
	sleep 0.1

	# ── Step 7: Hooks ──
	if $ANIMATE; then
		_bd_step_type "$((step_row + 10))" "6/6" "Deploying session hooks"
	else
		_bd_step_show "$((step_row + 10))" "6/6" "Deploying session hooks" running
	fi
	if command -v claude &>/dev/null; then
		bash "$BRAINDANCE_DIR/src/main.sh" hooks-install 2>/dev/null || true
	fi
	if [ "$shell_type" = "zsh" ]; then
		bash "$BRAINDANCE_DIR/src/main.sh" completions install 2>/dev/null || true
	fi
	_bd_step_show "$((step_row + 10))" "6/6" "Deploying session hooks" done
	sleep 0.3

	# ── Complete ──────────────────────────────────────────────────────────
	_bd_clear

	if $ANIMATE; then
		# Flash cyan
		_bd_flash '\033[46m' 0.1

		local rows cols
		rows=$(_bd_rows)
		cols=$(_bd_cols)

		# Glitch reveal "BRAINDANCE COMPLETE"
		local comp_row=$(( rows / 2 - 1 ))
		local comp_text="BRAINDANCE COMPLETE"
		local comp_col
		comp_col=$(_bd_center_col "$comp_text")
		_bd_glitch_reveal "$comp_text" "$comp_row" $((comp_col + 1)) 0.025
		sleep 0.3

		# Subtitle
		local sub_text="preset minds for Claude Code"
		local sub_col
		sub_col=$(_bd_center_col "$sub_text")
		printf '\033[%d;%dH\033[93m%s\033[0m' $((comp_row + 2)) "$sub_col" "$sub_text"
		sleep 0.5
	fi

	# ── Next steps ──
	_bd_box "" 52 93; content_start=$_BD_CONTENT
	if $ANIMATE; then
		local bd_c=$(_bd_cols)
		local type_col=$(( bd_c / 2 - 14 ))
		_bd_type "  exec \$SHELL"   "$content_start"     "$type_col" 0.008
		_bd_type "  braindance --check"  "$((content_start + 1))" "$type_col" 0.008
		_bd_type "  claude"              "$((content_start + 2))" "$type_col" 0.008
	else
		_bd_center "\033[93mexec \$SHELL\033[0m"
		_bd_center "\033[93mbraindance --check\033[0m"
		_bd_center "\033[93mclaude\033[0m"
	fi

	sleep 0.5

	# Exit the alt screen
	_bd_show_cursor
	_bd_alt_off
	clear 2>/dev/null || true
}

# ─── Main ─────────────────────────────────────────────────────────────────────

install_braindance
