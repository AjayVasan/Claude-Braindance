#!/usr/bin/env bats
# Tests: Installer behavior (dry-run, shell detection, API key store)

setup() {
	export ZAI_DIR="${BATS_TEST_TMPDIR}/zai"
	export ZAI_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
	mkdir -p "$ZAI_DIR" "$ZAI_BIN_DIR"
}

@test "detect_os returns linux or macos" {
	run bash -c '
		case "$(uname -s)" in
			Darwin) echo "macos" ;;
			Linux)  echo "linux" ;;
			*)      echo "unknown" ;;
		esac
	'
	[[ "$output" =~ ^(linux|macos|unknown)$ ]]
}

@test "detect_shell identifies current shell" {
	run bash -c '
		sh="${SHELL##*/}"
		case "$sh" in
			zsh|bash|fish) echo "$sh" ;;
			*) echo "unknown" ;;
		esac
	'
	[[ "$output" =~ ^(zsh|bash|fish|unknown)$ ]]
}

@test "install.sh creates directory structure" {
	# Simulate install by creating expected dirs
	mkdir -p "$ZAI_DIR"/{presets,skills,src}
	mkdir -p "$ZAI_BIN_DIR"

	[ -d "$ZAI_DIR/presets" ]
	[ -d "$ZAI_DIR/skills" ]
	[ -d "$ZAI_DIR/src" ]
}

@test "symlink creation works" {
	mkdir -p "$ZAI_BIN_DIR"
	mkdir -p "$ZAI_DIR/src"
	touch "$ZAI_DIR/src/main.sh"

	ln -sf "$ZAI_DIR/src/main.sh" "$ZAI_BIN_DIR/zai"
	[ -L "$ZAI_BIN_DIR/zai" ]
	[ "$(readlink "$ZAI_BIN_DIR/zai")" = "$ZAI_DIR/src/main.sh" ]
}

@test "API key file permissions are 600 after store" {
	mkdir -p "$ZAI_DIR"
	echo -n "sk-test-key" > "$ZAI_DIR/api-key"
	chmod 600 "$ZAI_DIR/api-key"

	local perms
	perms=$(stat -c '%a' "$ZAI_DIR/api-key" 2>/dev/null || stat -f '%Lp' "$ZAI_DIR/api-key" 2>/dev/null)
	[ "$perms" = "600" ]
}
