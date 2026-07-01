#!/usr/bin/env bats
# Tests: Skills management system

setup() {
	export BRAINDANCE_SKILLS_DIR="${BATS_TEST_TMPDIR}/skills"
	export BRAINDANCE_DIR="${BATS_TEST_TMPDIR}"
	mkdir -p "$BRAINDANCE_SKILLS_DIR" "$BRAINDANCE_DIR"
}

@test "skills list shows available sources" {
	run bash -c '
		BRAINDANCE_SKILLS_DIR="'"$BRAINDANCE_SKILLS_DIR"'" \
		source "'"${BATS_TEST_DIRNAME}/../src/skills.sh"'" \
		&& braindance_skills_list
	'
	[ "$status" -eq 0 ]
	[[ "$output" == *"Skill Sources"* ]]
}

@test "skills docs generates index.md" {
	run bash -c '
		BRAINDANCE_SKILLS_DIR="'"$BRAINDANCE_SKILLS_DIR"'" \
		BRAINDANCE_DIR="'"$BRAINDANCE_DIR"'" \
		source "'"${BATS_TEST_DIRNAME}/../src/skills.sh"'" \
		&& braindance_skills_docs
	'
	[ "$status" -eq 0 ]
	[[ "$output" == *"Documentation written"* ]]
}

@test "skills registry sources are accessible" {
	run bash -c '
		BRAINDANCE_SKILLS_DIR="'"$BRAINDANCE_SKILLS_DIR"'" \
		BRAINDANCE_DIR="'"$BRAINDANCE_DIR"'" \
		source "'"${BATS_TEST_DIRNAME}/../src/skills.sh"'" \
		&& braindance_skills_list 2>&1 >/dev/null
	'
	[ "$status" -eq 0 ]
}

@test "install with no arguments shows usage" {
	run bash -c '
		BRAINDANCE_SKILLS_DIR="'"$BRAINDANCE_SKILLS_DIR"'" \
		source "'"${BATS_TEST_DIRNAME}/../src/skills.sh"'" \
		&& braindance_skills_install
	'
	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage"* ]]
}
