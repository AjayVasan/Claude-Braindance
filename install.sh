#!/usr/bin/env bash
# Zai — Installer
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
ZAI_DIR="${ZAI_DIR:-$HOME/.local/share/zai}"
ZAI_BIN_DIR="${HOME}/.local/bin"
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

install_zai() {
	local os shell_type shell_config date_cmd

	os=$(detect_os)
	shell_type=$(detect_shell)
	shell_config=$(get_shell_config "$shell_type")

	echo "╔══════════════════════════════════════╗"
	echo "║        Zai — Installing               ║"
	echo "╚══════════════════════════════════════╝"
	echo ""
	echo "Detected:"
	echo "  OS:           ${os}"
	echo "  Shell:        ${shell_type}"
	echo "  Config:       ${shell_config:-"(detection failed)"}"
	echo "  Install dir:  ${ZAI_DIR}"
	echo "  Source:       ${REPO_DIR}"
	echo ""

	# ── Step 1: Create directories ──
	echo "[1/5] Creating directories..."
	mkdir -p "$ZAI_DIR"/{presets,skills,src}
	mkdir -p "$ZAI_BIN_DIR"

	# ── Step 2: Copy source files ──
	echo "[2/5] Installing source files..."
	cp -r "$REPO_DIR/src/"* "$ZAI_DIR/src/"
	cp -r "$REPO_DIR/presets/"* "$ZAI_DIR/presets/"

	# ── Step 3: Create symlink ──
	echo "[3/5] Creating symlink..."
	ln -sf "$ZAI_DIR/src/main.sh" "$ZAI_BIN_DIR/zai"
	echo "  → $ZAI_BIN_DIR/zai → $ZAI_DIR/src/main.sh"

	# ── Step 4: Ensure PATH ──
	if [[ ":$PATH:" != *":$ZAI_BIN_DIR:"* ]]; then
		echo "[!] NOTE: $ZAI_BIN_DIR is not in your PATH."
		echo "    Add this to your shell config:"
		echo "    export PATH=\"\$PATH:$ZAI_BIN_DIR\""
		echo ""
	fi

	# ── Step 5: Shell integration (opt-in) ──
	echo "[4/5] Shell integration..."
	if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
		if grep -q "Zai — auto-switch Claude Code presets" "$shell_config" 2>/dev/null; then
			echo "  Zai already integrated in ${shell_config} — skipping."
		else
			if confirm "Add Zai shell integration to ${shell_config}?"; then
				{
					echo ""
					echo "# Zai — auto-switch Claude Code presets by IST time"
					echo "export ZAI_DIR=\"\${ZAI_DIR:-\$HOME/.local/share/zai}\""
					echo "[[ -f \"\$ZAI_DIR/src/main.sh\" ]] && source \"\$ZAI_DIR/src/main.sh\""
					echo "alias claude-doc='ZAI_PRESET_OVERRIDE=docs-utility claude'"
				} >> "$shell_config"
				echo "  ✓ Added to ${shell_config}"
				echo "  Run: exec \$SHELL  (or open new terminal)"
			else
				echo "  Skipped (you can manually add later with: zai shell)"
			fi
		fi
	else
		echo "  Shell config not detected. Run 'zai shell' to see integration snippet."
	fi

	# ── Step 6: API key prompt (optional) ──
	echo "[5/5] API key..."
	if [ ! -f "$ZAI_DIR/api-key" ]; then
		if confirm "Set Z.ai API key now?"; then
			printf "  Enter your Z.ai API key: "
			read -r api_key
			if [ -n "$api_key" ]; then
				"$ZAI_BIN_DIR/zai" set-key "$api_key"
			fi
		else
			echo "  You can set it later with: zai set-key <your-key>"
		fi
	else
		echo "  API key already configured."
	fi

	echo ""
	echo "╔══════════════════════════════════════╗"
	echo "║        Install complete!              ║"
	echo "╚══════════════════════════════════════╝"
	echo ""
	echo "Next steps:"
	echo "  1. Open a new terminal (or: exec \$SHELL)"
	echo "  2. Verify:  zai --check"
	echo "  3. Use:     claude"
	echo "  4. Docs:    claude-doc"
	echo ""
	echo "Need help?  zai --help"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

install_zai
