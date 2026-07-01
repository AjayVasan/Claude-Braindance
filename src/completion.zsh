#compdef braindance
# Zsh completion for Braindance — Claude Code preset switcher
# Install: braindance completions install  (or  source src/completion.zsh)

_braindance_presets() {
	local -a presets
	presets=(
		'daily-coding:GLM-4.7 all models. Default 00:00-06:29 IST'
		'deep-thinking-offpeak:GLM-5.2 Opus. Before 11:30AM or after 3:30PM IST'
		'deep-thinking-peak:GLM-5-Turbo Opus. 11:30AM-3:30PM IST peak hours'
		'docs-utility:GLM-4.7 Opus, GLM-4.5-Air Sonnet/Haiku. Docs and utility'
	)
	_describe 'preset' presets
}

_braindance() {
	local context state state_descr line
	typeset -A opt_args

	_arguments -C \
		'--check[Show diagnostic: time, preset, models, API key]' \
		'--help[Show usage help]' \
		'set-key:API token: ' \
		'preset:Switch mindset:->presets' \
		'shell:Print shell integration snippet: ' \
		'hooks-install:Install Claude Code hook: ' \
		'completions:Install shell completions:->completions' \
		'skills:Manage skill sources:->skills' && return 0

	case $state in
		presets)
			_braindance_presets
			;;
		skills)
			local -a skills_cmds
			skills_cmds=(
				'list:Show available skill sources'
				'install:Clone and install a skill source'
				'remove:Remove an installed skill source'
				'docs:Generate skills ecosystem documentation'
			)
			_describe 'skill command' skills_cmds
			;;
		completions)
			local -a comp_cmds
			comp_cmds=(
				'install:Install zsh completions to FPATH'
			)
			_describe 'completion command' comp_cmds
			;;
	esac
}

_braindance "$@"
