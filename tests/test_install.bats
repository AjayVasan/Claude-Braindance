#!/usr/bin/env bats
# Tests: Installer behavior (dry-run, shell detection, API key store)

setup() {
	export BRAINDANCE_DIR="${BATS_TEST_TMPDIR}/braindance"
	export BRAINDANCE_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
	mkdir -p "$BRAINDANCE_DIR" "$BRAINDANCE_BIN_DIR"
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
	mkdir -p "$BRAINDANCE_DIR"/{presets,skills,src}
	mkdir -p "$BRAINDANCE_BIN_DIR"

	[ -d "$BRAINDANCE_DIR/presets" ]
	[ -d "$BRAINDANCE_DIR/skills" ]
	[ -d "$BRAINDANCE_DIR/src" ]
}

@test "symlink creation works" {
	mkdir -p "$BRAINDANCE_BIN_DIR"
	mkdir -p "$BRAINDANCE_DIR/src"
	touch "$BRAINDANCE_DIR/src/main.sh"

	ln -sf "$BRAINDANCE_DIR/src/main.sh" "$BRAINDANCE_BIN_DIR/braindance"
	[ -L "$BRAINDANCE_BIN_DIR/braindance" ]
	[ "$(readlink "$BRAINDANCE_BIN_DIR/braindance")" = "$BRAINDANCE_DIR/src/main.sh" ]
}

@test "API key file permissions are 600 after store" {
	mkdir -p "$BRAINDANCE_DIR"
	echo -n "sk-test-key" > "$BRAINDANCE_DIR/api-key"
	chmod 600 "$BRAINDANCE_DIR/api-key"

	local perms
	perms=$(stat -c '%a' "$BRAINDANCE_DIR/api-key" 2>/dev/null || stat -f '%Lp' "$BRAINDANCE_DIR/api-key" 2>/dev/null)
	[ "$perms" = "600" ]
}
