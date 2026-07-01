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
# Renders directly to terminal.
# Args: title, width=58, color=96, content_lines=8
_bd_box() {
	local title="$1" width="${2:-58}" color="${3:-96}" content_lines="${4:-8}"
	local rows cols top content_row i left edge reset total_h
	rows=$(_bd_rows)
	cols=$(_bd_cols)
	[[ -z "$title" ]] && total_h=$((content_lines + 3)) || total_h=$((content_lines + 4))
	top=$(( (rows - total_h) / 2 ))
	[[ $top -lt 0 ]] && top=0
	left=$(( (cols - width) / 2 ))
	[[ $left -lt 0 ]] && left=0
	edge="\033[${color}m\033[1m"
	reset="\033[0m"

	# Top border
	printf '\033[%d;%dH%b╔' "$top" "$left" "$edge"
	for ((i=0; i<width-2; i++)); do printf '═'; done
	printf '╗%b' "$reset"

	# Title row if provided (counts as 1 content line)
	content_row=$((top + 1))
	if [[ -n "$title" ]]; then
		printf '\033[%d;%dH%b║%b' "$content_row" "$left" "$edge" "$reset"
		local title_pad=$(( (width - 2 - ${#title}) / 2 ))
		printf '\033[%d;%dH%b%s%b' "$content_row" $((left + title_pad)) "$edge" "$title" "$reset"
		printf '\033[%d;%dH%b║\033[0m\033[K' "$content_row" $((left + width - 1)) "$edge"
		content_row=$((top + 2))
	fi

	# Empty rows
	for ((r=content_row; r<content_row+content_lines; r++)); do
		printf '\033[%d;%dH%b║%b\033[K' "$r" "$left" "$edge" "$reset"
		printf '\033[%d;%dH%b║\033[0m\033[K' "$r" $((left + width - 1)) "$edge"
	done

	# Bottom border
	local bottom=$((content_row + content_lines))
	printf '\033[%d;%dH%b╚' "$bottom" "$left" "$edge"
	for ((i=0; i<width-2; i++)); do printf '═'; done
	printf '╝%b\033[K' "$reset"

	_BD_CONTENT=$((content_row))
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

# ─── Interactive Post-Install Help ─────────────────────────────────────────

# Shows a navigable menu of commands with animated explanations.
# Arrow keys to navigate, q/ESC to exit.
_bd_interactive_help() {
	local rows cols
	rows=$(_bd_rows)
	cols=$(_bd_cols)

	# Menu items: "label:description" where description lines separated by ;
	local items=(
		"braindance --check:• See your current time, preset, and model mapping;• Shows API key status and environment;• Verifies everything is connected"
		"braindance preset <name>:• Override automatic time-based preset;• Options: daily-coding | deep-thinking-offpeak;•         deep-thinking-peak | docs-utility"
		"braindance preset reset:• Clear any manual override;• Revert to automatic IST schedule"
		"claude:• Launch Claude Code with current preset;• Models auto-switch by IST time window"
		"claude-doc:• Always uses docs-utility preset;• Lower cost model for docs, formatting, logs"
		"braindance skills list:• Browse and install skill packs;• Enhance Claude Code with custom abilities"
		"braindance set-key <key>:• Store your Z.ai API key securely;• Saved to \$BRAINDANCE_DIR/api-key (chmod 600)"
	)
	local count=${#items[@]}
	local selected=0

	# Pre-extract labels and descriptions
	local labels=() descs=()
	local i item
	for ((i=0; i<count; i++)); do
		item="${items[$i]}"
		labels+=("${item%%:*}")
		descs+=("${item#*:}")
	done

	local box_w=62 box_h=17 box_color=93
	local box_top=$(( (rows - box_h) / 2 ))
	local left=$(( (cols - box_w) / 2 ))
	[[ $left -lt 0 ]] && left=0
	local indent=$((left + 3))
	local sep_row=$((box_top + 8))
	local footer_row=$((box_top + box_h - 2))

	local edge="\033[${box_color}m\033[1m"
	local reset="\033[0m"

	_draw_frame() {
		local r
		printf '\033[%d;%dH%b╔' "$box_top" "$left" "$edge"
		for ((r=0; r<box_w-2; r++)); do printf '═'; done
		printf '╗%b' "$reset"
		for ((r=1; r<box_h-1; r++)); do
			printf '\033[%d;%dH%b║%b\033[K' $((box_top+r)) "$left" "$edge" "$reset"
			printf '\033[%d;%dH%b║\033[0m\033[K' $((box_top+r)) $((left+box_w-1)) "$edge"
		done
		printf '\033[%d;%dH%b╚' $((box_top+box_h-1)) "$left" "$edge"
		for ((r=0; r<box_w-2; r++)); do printf '═'; done
		printf '╝%b\033[K' "$reset"
	}

	_draw_header() {
		printf '\033[%d;%dH\033[96m\033[1m⚡ BRAINDANCE \033[90m— calibration complete\033[0m\033[K' \
			$((box_top+1)) $((left+2))
	}

	_draw_item() {
		local idx=$1 row=$2 active=$3
		if (( active )); then
			printf '\033[%d;%dH\033[93m▸\033[33m %s\033[0m\033[K' "$row" "$indent" "${labels[$idx]}"
		else
			printf '\033[%d;%dH\033[90m \033[2m%s\033[0m\033[K' "$row" "$indent" "${labels[$idx]}"
		fi
	}

	_clear_desc() {
		local r
		for ((r=sep_row+1; r<footer_row; r++)); do
			printf '\033[%d;%dH\033[K' "$r" "$left"
		done
	}

	_animate_desc() {
		local idx=$1
		local desc="${descs[$idx]}"
		local drow=$((sep_row + 2))
		local dcol=$((left + 3))
		local line
		IFS=';' read -ra lines <<< "$desc"
		local li
		for ((li=0; li<${#lines[@]}; li++)); do
			line="${lines[$li]}"
			# Trim leading whitespace
			line="${line#"${line%%[! ]*}"}"
			local row=$((drow + li))
			local i
			for ((i=0; i<${#line}; i++)); do
				printf '\033[%d;%dH\033[96m%s\033[0m' "$row" $((dcol+i)) "${line:$i:1}"
				sleep 0.003
			done
			sleep 0.08
		done
	}

	_draw_footer() {
		printf '\033[%d;%dH\033[90m\033[2m↑↓ navigate  ·  q/ESC exit\033[0m\033[K' \
			$footer_row $((left + 2))
	}
	_read_key() {
		local key seq
		IFS= read -r -s -n 1 key 2>/dev/null || { echo "QUIT"; return; }
		if [[ $key == $'\x1b' ]]; then
			# Read escape sequence — generous timeout for slow terminals
			# Also handles double-escape prefix (\x1b\x1b[B) some terminals send
			seq=""
			local i
			for ((i=0; i<6; i++)); do
				read -r -s -t 0.3 -n 1 key 2>/dev/null || break
				seq="$seq$key"
			done
			# Strip leading \x1b sequences (double-escape support)
			while [[ $seq == $'\x1b'* ]]; do seq="${seq#$'\x1b'}"; done
			case "$seq" in
				'[A'|'OA')   echo "UP"    ;;
				'[B'|'OB')   echo "DOWN"  ;;
				'[C'|'OC')   echo "RIGHT" ;;
				'[D'|'OD')   echo "LEFT"  ;;
				'')          echo "ESC"   ;;  # bare Escape, no trailing bytes
			esac
		elif [[ $key == $'\x0a' ]] || [[ $key == $'\x0d' ]]; then
			echo "ENTER"
		elif [[ $key == "q" ]] || [[ $key == "Q" ]]; then
			echo "QUIT"
		fi
		# Unrecognized keys silently ignored
	}

	# ── Render ──
	_bd_clear
	if $ANIMATE; then
		# Clean reveal — no full-screen flash, just type out completion text
		local complete_row=$((rows/2-1))
		local complete_col
		complete_col=$(_bd_center_col "BRAINDANCE - CALIBRATION COMPLETE")
		_bd_type "BRAINDANCE - CALIBRATION COMPLETE" "$complete_row" "$complete_col" 0.008
		sleep 0.4
	fi
	_bd_clear

	# Let terminal settle after API key input before aggressive drain
	sleep 0.2
	# Aggressively drain leftover stdin (API key paste may leave stray bytes)
	_drain_input() {
		local d
		while read -r -t 0.2 -s -n 1 d 2>/dev/null; do :; done
		while read -r -t 0.2 -s -n 1 d 2>/dev/null; do :; done
		while read -r -t 0.1 -s -n 1 d 2>/dev/null; do :; done
	}
	_drain_input

	_draw_frame
	_draw_header
	_draw_footer

	# Separator line
	printf '\033[%d;%dH\033[90m%s\033[0m\033[K' $sep_row $((left+2)) \
		"──────────────────────────────────────────────"
	printf '\033[%d;%dH\033[90m\033[2musage\033[0m\033[K' $((sep_row)) $((left+29))

	# Drain again — terminal may have sent response bytes during rendering
	_drain_input

	# Initial render
	local r old_selected=-1 esc_count=0
	while true; do
		if (( selected != old_selected )); then
			for ((r=0; r<count && r<6; r++)); do
				_draw_item $r $((box_top+2+r)) $(( r == selected ? 1 : 0 ))
			done
			_clear_desc
			_animate_desc "$selected"
			old_selected=$selected
		fi

		case $(_read_key) in
			UP)    ((selected > 0)) && ((selected--)) ;;
			DOWN)  ((selected < count-1)) && ((selected++)) ;;
			ESC)
				# Ignore first few ESC returns — could be residual terminal bytes
				((esc_count++))
				[ "$esc_count" -ge 3 ] && break
				;;
			QUIT)  break ;;
		esac
	done
}
install_braindance() {
	local os shell_type shell_config
	local content_start step_row should_add

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
	_bd_box "" 58 96 16; content_start=$_BD_CONTENT

	# Box positioning for in-box prompts
	local bd_cols=$(_bd_cols)
	local box_left=$(( (bd_cols - 58) / 2 ))
	[[ $box_left -lt 0 ]] && box_left=0
	local box_indent=$((box_left + 4))

	# Show detected system info
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

	# ── PATH check (info only) ──
	if [[ ":$PATH:" != *":$BRAINDANCE_BIN_DIR:"* ]]; then
		_bd_step_info $((step_row + 3)) "! PATH not set — add to shell config"
	fi

	# ── Step 4: Shell integration ──
	if $ANIMATE; then
		_bd_step_type "$((step_row + 4))" "4/6" "Wiring shell integration"
	else
		_bd_step_show "$((step_row + 4))" "4/6" "Wiring shell integration" running
	fi
	if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
		if grep -q "# Braindance —" "$shell_config" 2>/dev/null; then
			_bd_step_show "$((step_row + 4))" "4/6" "Wiring shell integration" done
			_bd_step_info $((step_row + 5)) "  Already wired — skipping"
		else
			_bd_step_show "$((step_row + 4))" "4/6" "Wiring shell integration" done
			if $AUTO_CONFIRM; then
				should_add=true
			else
				printf '\033[%d;%dH\033[93m  Add to %s? [Y/n] \033[0m' \
					$((step_row + 5)) $((box_indent)) "${shell_config}"
				read -r response
				case "$response" in
					""|y|Y|yes|YES) should_add=true ;;
					*) should_add=false ;;
				esac
			fi
			if $should_add; then
				{
					echo ""
					echo "# Braindance — auto-switch Claude Code presets by IST time"
					echo "export BRAINDANCE_DIR=\"\${BRAINDANCE_DIR:-\$HOME/.local/share/braindance}\""
					echo "[[ -f \"\$BRAINDANCE_DIR/src/main.sh\" ]] && source \"\$BRAINDANCE_DIR/src/main.sh\""
				echo ""
				echo "# Re-evaluate preset on every claude invocation"
				echo "claude() {"
				echo "	[[ -f \"\$BRAINDANCE_DIR/src/main.sh\" ]] && source \"\$BRAINDANCE_DIR/src/main.sh\""
				echo ""
				echo "	# Show pending time-transition notification if any"
				echo "	if [ -f \"\$BRAINDANCE_DIR/last_transition\" ]; then"
				echo "		cat \"\$BRAINDANCE_DIR/last_transition\""
				echo "		rm -f \"\$BRAINDANCE_DIR/last_transition\""
				echo "		echo \"\""
				echo "	fi"
				echo ""
				echo "	local bd_preset=\"\${BRAINDANCE_ACTIVE_PRESET:-unknown}\""
				echo "	local bd_opus=\"\${ANTHROPIC_DEFAULT_OPUS_MODEL:-?}\""
				echo "	local bd_sonnet=\"\${ANTHROPIC_DEFAULT_SONNET_MODEL:-?}\""
				echo "	local bd_haiku=\"\${ANTHROPIC_DEFAULT_HAIKU_MODEL:-?}\""
				echo "	printf \"  [braindance] %s | opus: %s  sonnet: %s  haiku: %s\\n\" \"\$bd_preset\" \"\$bd_opus\" \"\$bd_sonnet\" \"\$bd_haiku\""
				echo "	command claude \"\$@\""
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

	# ── Step 5: API key ──
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
	else
		printf '\033[%d;%dH\033[93m  Set Z.ai API key now? [Y/n] \033[0m' \
			$((step_row + 8)) $((box_indent))
		read -r yn
		case "$yn" in
			""|y|Y|yes|YES)
				printf '\033[%d;%dH\033[96m  Enter Z.ai API key (sk-...): \033[0m' \
					$((step_row + 8)) $((box_indent))
				read -r api_key
				printf '\033[%dH\033[K' $((step_row + 8))
				if [ -n "$api_key" ]; then
					bash "$BRAINDANCE_DIR/src/main.sh" set-key "$api_key" &>/dev/null
					_bd_step_info $((step_row + 8)) "  ✓ Biometric key stored"
				else
					_bd_step_info $((step_row + 8)) "  No key — set later: braindance set-key"
				fi
				;;
			*)
				_bd_step_info $((step_row + 8)) "  Skipped — set later: braindance set-key"
				;;
		esac
	fi
fi
	sleep 0.1

	# ── Step 6: Hooks ──
	if $ANIMATE; then
		_bd_step_type "$((step_row + 10))" "6/6" "Deploying session hooks"
	else
		_bd_step_show "$((step_row + 10))" "6/6" "Deploying session hooks" running
	fi
	if command -v claude &>/dev/null; then
		bash "$BRAINDANCE_DIR/src/main.sh" hooks-install &>/dev/null || true
	fi
	if [ "$shell_type" = "zsh" ]; then
		bash "$BRAINDANCE_DIR/src/main.sh" completions install &>/dev/null || true
	fi
	_bd_step_show "$((step_row + 10))" "6/6" "Deploying session hooks" done
	sleep 0.3
	# ── Interactive post-install help (skip in --yes mode) ──
	if $ANIMATE; then
		_bd_interactive_help
	else
		_bd_clear
		local cols=$(_bd_cols)
		_bd_center "\033[96m\033[1m⚡ BRAINDANCE\033[0m"
		_bd_center "\033[2mInstallation complete\033[0m"
		echo ""
		_bd_center "\033[93mexec \$SHELL\033[0m"
		_bd_center "\033[93mbraindance --check\033[0m"
		_bd_center "\033[93mclaude\033[0m"
		sleep 1
	fi
	# Exit the alt screen
	_bd_show_cursor
	_bd_alt_off
	clear 2>/dev/null || true
}

# ─── Main ─────────────────────────────────────────────────────────────────────

install_braindance
