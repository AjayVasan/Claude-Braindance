#!/usr/bin/env bash
# Braindance — Installer
# One-shot setup: detects platform, installs files, configures shell
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

if [ "${1:-}" = "--yes" ] || [ "${1:-}" = "-y" ]; then
	AUTO_CONFIRM=true
fi

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

# ─── Install Steps ────────────────────────────────────────────────────────────

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

install_braindance() {
	local os shell_type shell_config date_cmd

	os=$(detect_os)
	shell_type=$(detect_shell)
	shell_config=$(get_shell_config "$shell_type")

	echo "╔══════════════════════════════════════╗"
	echo "║     Braindance — Installing           ║"
	echo "╚══════════════════════════════════════╝"
	echo ""
	echo "Detected:"
	echo "  OS:           ${os}"
	echo "  Shell:        ${shell_type}"
	echo "  Config:       ${shell_config:-"(detection failed)"}"
	echo "  Install dir:  ${BRAINDANCE_DIR}"
	echo "  Source:       ${REPO_DIR}"
	echo ""

	# ── Step 1: Create directories ──
	echo "[1/5] Creating directories..."
	mkdir -p "$BRAINDANCE_DIR"/{presets,skills,src}
	mkdir -p "$BRAINDANCE_BIN_DIR"

	# ── Step 2: Copy source files ──
	echo "[2/5] Installing source files..."
	cp -r "$REPO_DIR/src/"* "$BRAINDANCE_DIR/src/"
	cp -r "$REPO_DIR/presets/"* "$BRAINDANCE_DIR/presets/"
	chmod +x "$BRAINDANCE_DIR/src/main.sh"

	# ── Step 3: Create symlink ──
	echo "[3/5] Creating symlink..."
	ln -sf "$BRAINDANCE_DIR/src/main.sh" "$BRAINDANCE_BIN_DIR/braindance"
	echo "  → $BRAINDANCE_BIN_DIR/braindance → $BRAINDANCE_DIR/src/main.sh"

	# ── Step 4: Ensure PATH ──
	if [[ ":$PATH:" != *":$BRAINDANCE_BIN_DIR:"* ]]; then
		echo "[!] NOTE: $BRAINDANCE_BIN_DIR is not in your PATH."
		echo "    Add this to your shell config:"
		echo "    export PATH=\"\$PATH:$BRAINDANCE_BIN_DIR\""
		echo ""
	fi

	# ── Step 5: Shell integration (opt-in) ──
	echo "[4/5] Shell integration..."
	if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
		if grep -q "Braindance — auto-switch Claude Code presets" "$shell_config" 2>/dev/null; then
			echo "  Braindance already integrated in ${shell_config} — skipping."
		else
			if confirm "Add Braindance shell integration to ${shell_config}?"; then
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
				echo "  ✓ Added to ${shell_config}"
				echo "  Run: exec \$SHELL  (or open new terminal)"
			else
				echo "  Skipped (you can manually add later with: braindance shell)"
			fi
		fi
	else
		echo "  Shell config not detected. Run 'braindance shell' to see integration snippet."
	fi

	# ── Step 6: API key prompt (optional) ──
	echo "[5/5] API key..."
	if [ -f "$BRAINDANCE_DIR/api-key" ]; then
		echo "  API key already set (file: $BRAINDANCE_DIR/api-key)."
		echo "  Overwrite with: braindance set-key <your-key>"
	else
		if confirm "Set Z.ai API key now?"; then
			printf "  Enter your Z.ai API key: "
			read -r api_key
			if [ -n "$api_key" ]; then
				bash "$BRAINDANCE_DIR/src/main.sh" set-key "$api_key"
				echo "  ✓ API key saved to $BRAINDANCE_DIR/api-key"
			else
				echo "  No key entered. Set later: braindance set-key <your-key>"
			fi
		else
			echo "  Skipped. Set later: braindance set-key <your-key>"
		fi
	fi

	echo ""
	echo "╔══════════════════════════════════════╗"
	echo "║        Install complete!              ║"
	echo "╚══════════════════════════════════════╝"
	echo ""
	echo "Next steps:"
	echo "  1. Open a new terminal (or: exec \$SHELL)"
	echo "  2. Verify:  braindance --check"
	echo "  3. Use:     claude"
	echo "  4. Docs:    claude-doc"
	echo ""
	echo "Need help?  braindance --help"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

install_braindance
