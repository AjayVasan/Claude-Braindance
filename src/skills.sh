#!/usr/bin/env bash
# Braindance — Skills Management
# Sources, installs, and documents Claude Code skills from curated repos
#
# Usage:
#   braindance skills list             List available skill sources
#   braindance skills install [name]   Install a skill source (or all)
#   braindance skills remove  [name]   Remove a skill source
#   braindance skills docs             Generate skills/index.md

set -euo pipefail

# ─── Script Directory (cross-shell) ───────────────────────────────────────────

BRAINDANCE_SCRIPT_DIR=""
if [ -n "${BASH_SOURCE-}" ] && [ "${BASH_SOURCE[0]}" ]; then
	BRAINDANCE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION-}" ]; then
	BRAINDANCE_SCRIPT_DIR="${${(%):-%x}:A:h}" 2>/dev/null || BRAINDANCE_SCRIPT_DIR="$PWD"
else
	BRAINDANCE_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# ─── Skill Source Registry ────────────────────────────────────────────────────

# Format: name|description|git_url|install_hint
SKILL_SOURCES=(
	"vercel-labs/skills|Official Vercel skill pack: 8 skills (React, Design, Vercel optimize)|https://github.com/vercel-labs/agent-skills.git|npx skills add vercel-labs/agent-skills"
	"obra/superpowers|Complete SDLC methodology: 14 skills for brainstorming, TDD, code review, subagents|https://github.com/obra/superpowers.git|Plugin install per harness docs"
	"thedotmack/claude-mem|Persistent cross-session memory compression for Claude Code (85k+ stars)|https://github.com/thedotmack/claude-mem.git|npx claude-mem install"
	"pbakaus/impeccable|Design guidance with 23 commands, 45 anti-pattern detectors, live browser mode (42k+ stars)|https://github.com/pbakaus/impeccable.git|npx impeccable install"
	"rebelytics/one-skill-to-rule-them-all|Task Observer meta-skill — auto-creates/improves skills from usage patterns|https://github.com/rebelytics/one-skill-to-rule-them-all.git|Copy SKILL.md to skills directory"
)

# ─── Utility Functions ────────────────────────────────────────────────────────

braindance_skills_dir() {
	local dir="${BRAINDANCE_SKILLS_DIR:-$HOME/.local/share/braindance/skills}"
	mkdir -p "$dir"
	echo "$dir"
}

# ─── Commands ─────────────────────────────────────────────────────────────────

# braindance_skills_list: Display all available skill sources
braindance_skills_list() {
	local skills_dir
	skills_dir=$(braindance_skills_dir)

	echo "╔══════════════════════════════════════╗"
	echo "║     Claude Code Skill Sources         ║"
	echo "╚══════════════════════════════════════╝"
	echo ""

	printf "%-30s %-8s %s\n" "Name" "Status" "Description"
	printf "%-30s %-8s %s\n" "────" "──────" "───────────"

	local idx=0
	for source in "${SKILL_SOURCES[@]}"; do
		local name desc url hint
		name=$(echo "$source" | cut -d'|' -f1)
		desc=$(echo "$source" | cut -d'|' -f2)
		url=$(echo "$source" | cut -d'|' -f3)

		local status="available"
		if [ -d "$skills_dir/$name" ]; then
			status="installed"
		fi

		printf "%-30s %-8s %s\n" "$name" "[$status]" "${desc:0:60}"
		((idx++)) || true
	done

	echo ""
	echo "Usage:"
	echo "  braindance skills install <name>    Clone and install a skill"
	echo "  braindance skills install --all     Install all skills"
	echo "  braindance skills remove  <name>    Remove a skill"
	echo "  braindance skills docs              Generate skills index documentation"
	echo ""
}

# braindance_skills_install: Clone and install skill source(s)
braindance_skills_install() {
	local target="${1:-}"
	local skills_dir
	skills_dir=$(braindance_skills_dir)

	if [ -z "$target" ]; then
		echo "[braindance] Usage: braindance skills install <name>  or  braindance skills install --all" >&2
		return 1
	fi

	if [ "$target" = "--all" ]; then
		for source in "${SKILL_SOURCES[@]}"; do
			local name
			name=$(echo "$source" | cut -d'|' -f1)
			braindance_skills_install_one "$name"
		done
		return 0
	fi

	braindance_skills_install_one "$target"
}

braindance_skills_install_one() {
	local name="$1"
	local skills_dir url hint
	skills_dir=$(braindance_skills_dir)

	# Find matching source
	local found=""
	for source in "${SKILL_SOURCES[@]}"; do
		local sname
		sname=$(echo "$source" | cut -d'|' -f1)
		if [ "$sname" = "$name" ]; then
			found="$source"
			break
		fi
	done

	if [ -z "$found" ]; then
		echo "[braindance] Skill source '$name' not found in registry." >&2
		echo "[braindance] Run 'braindance skills list' to see available sources." >&2
		return 1
	fi

	local desc url hint
	desc=$(echo "$found" | cut -d'|' -f2)
	url=$(echo "$found" | cut -d'|' -f3)
	hint=$(echo "$found" | cut -d'|' -f4)

	if [ -d "$skills_dir/$name" ]; then
		echo "[braindance] '$name' is already installed at $skills_dir/$name" >&2
		echo "[braindance] Remove first: braindance skills remove $name" >&2
		return 0
	fi

	echo "[braindance] Installing: $name"
	echo "[braindance] Source:     $url"
	echo ""

	if ! command -v git &>/dev/null; then
		echo "[braindance] ERROR: git is required to install skills." >&2
		echo "[braindance] Install git first, or use the hint below." >&2
		echo "[braindance] Hint: $hint" >&2
		return 1
	fi

	git clone --depth 1 "$url" "$skills_dir/$name" 2>&1 | tail -3
	local status="${PIPESTATUS[0]}"
	if [ "$status" -eq 0 ]; then
		echo ""
		echo "[braindance] ✓ '$name' installed at $skills_dir/$name"
		echo "[braindance] Hint: $hint"
	else
		echo "[braindance] ERROR: Failed to clone $name" >&2
		return 1
	fi
}

# braindance_skills_remove: Remove installed skill source
braindance_skills_remove() {
	local name="$1"
	local skills_dir sanitized
	skills_dir=$(braindance_skills_dir)

	if [ -z "$name" ]; then
		echo "[braindance] Usage: braindance skills remove <name>" >&2
		echo "[braindance] Run 'braindance skills list' to see installed sources." >&2
		return 1
	fi

	# Sanitize: strip path separators and parent-dir traversal (H2)
	sanitized="${name//\//}"
	sanitized="${sanitized//\.\./}"
	if [ "$sanitized" != "$name" ]; then
		echo "[braindance] ERROR: Invalid skill name: $name" >&2
		return 1
	fi

	local target="$skills_dir/$sanitized"
	if [ ! -d "$target" ]; then
		echo "[braindance] '$name' is not installed." >&2
		return 1
	fi

	rm -rf "$target"
	echo "[braindance] ✓ '$name' removed."
}

# braindance_skills_docs: Generate skills/index.md
braindance_skills_docs() {
	local skills_dir
	skills_dir=$(braindance_skills_dir)

	local doc_file
	# Write alongside the script by default
	if [ -d "$BRAINDANCE_SCRIPT_DIR/.." ]; then
		doc_file="$(cd "$BRAINDANCE_SCRIPT_DIR/.." && pwd)/skills/index.md"
	else
		doc_file="./skills/index.md"
	fi

	echo "[braindance] Generating skills documentation → $doc_file"

	cat > "$doc_file" <<- 'MD_HEADER'
		# Braindance — Claude Code Skills Ecosystem

		This index catalogs the most impactful Claude Code skills, plugins, and tools
		available for the Claude Code + Z.ai ecosystem. Braindance helps you discover and
		install these skill sources.

		---

		## Quick Install

		```bash
		# Install via Braindance (requires git):
		braindance skills install --all

		# Or install individually:
		braindance skills install <name>
		```

		---

	MD_HEADER

	local idx=0
	for source in "${SKILL_SOURCES[@]}"; do
		local name desc url hint
		name=$(echo "$source" | cut -d'|' -f1)
		desc=$(echo "$source" | cut -d'|' -f2)
		url=$(echo "$source" | cut -d'|' -f3)
		hint=$(echo "$source" | cut -d'|' -f4)

		local installed=""
		if [ -d "$skills_dir/$name" ]; then
			installed=" (installed)"
		fi

		cat >> "$doc_file" <<- MD_SOURCE

			### ${idx}) ${name}${installed}

			**Description:** ${desc}

			| Detail | Value |
			|--------|-------|
			| Source | [GitHub](${url}) |
			| Install | \`${hint}\` |

		MD_SOURCE

		((idx++)) || true
	done

	# Add knowledge graph tools section
	cat >> "$doc_file" <<- 'MD_KG'

		---

		## Knowledge Graph Tools for Claude Code

		These tools create graph representations of codebases, enabling Claude Code
		to navigate code structure without re-reading files:

		| Tool | Stars | Description | Install |
		|------|-------|-------------|--------|
		| [Graphify](https://github.com/safishamsi/graphify) | 75k | `/graphify .` in any Claude Code session. Maps entire project into queryable knowledge graph. | `pip install graphifyy` |
		| [Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) | 69k | Interactive knowledge graph dashboard with guided tours, diff impact analysis. | Plugin marketplace |
		| [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | 23k | Fastest option. Single C binary, 158 languages, indexes Linux kernel in 3min. | `curl ... \| bash` |
		| [code-review-graph](https://github.com/tirth8205/code-review-graph) | 19k | PR review token reduction. Claims 82x median reduction. | `pip install code-review-graph` |

		---

		*Generated by Braindance — https://github.com/AjayVasan/Claude-Braindance*
	MD_KG

	echo "[braindance] ✓ Documentation written to $doc_file"
}

# ─── Dispatcher ───────────────────────────────────────────────────────────────

braindance_skills_main() {
	if [ $# -eq 0 ]; then
		braindance_skills_list
		return 0
	fi

	case "${1:-}" in
		list)
			braindance_skills_list
			;;
		install)
			shift
			braindance_skills_install "$@"
			;;
		remove)
			shift
			braindance_skills_remove "$@"
			;;
		docs)
			braindance_skills_docs
			;;
		*)
			echo "[braindance] Unknown skills command: ${1:-}" >&2
			echo "[braindance] Usage: braindance skills <list|install|remove|docs>" >&2
			return 1
			;;
	esac
}

# ─── Entry Point ──────────────────────────────────────────────────────────────

braindance_skills_main "$@"
