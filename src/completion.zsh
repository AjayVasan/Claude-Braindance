# Braindance zsh completion — source this file directly in .zshrc
# Usage: source src/completion.zsh  (or  braindance completions install)

_braindance_complete() {
	local curcontext="$curcontext" state line
	typeset -A opt_args

	_arguments -C \
		'--check[Show diagnostic: time, preset, models, API key]' \
		'--help[Show usage information]' \
		'(preset):subcommand:->subcmd' \
		'*::arg:->args'

	case $state in
		subcmd)
			local -a subcmds
			subcmds=(
				'--check:Show current preset status'
				'--help:Show help'
				'set-key:Store your Z.ai API key'
				'preset:Switch to a different mindset'
				'shell:Print shell integration snippet'
				'hooks-install:Install Claude Code startup hook'
				'completions:Install shell tab-completions'
				'skills:Manage Claude Code skill sources'
			)
			_describe -t commands 'braindance command' subcmds
			;;
		args)
			case $line[1] in
				preset)
					local -a presets
					presets=(
						'daily-coding:GLM-4.7 all models. Default 00:00-06:29 IST'
						'deep-thinking-offpeak:GLM-5.2 Opus. 06:30-11:29 and 15:30-23:59 IST'
						'deep-thinking-peak:GLM-5-Turbo Opus. 11:30-15:30 IST peak hours'
						'docs-utility:GLM-4.7 Opus. GLM-4.5-Air Sonnet/Haiku. Docs and utility'
					)
					_describe -t presets 'preset' presets
					;;
				skills)
					local -a skills_cmds
					skills_cmds=(
						'list:Show available skill sources'
						'install:Clone and install a skill'
						'remove:Remove an installed skill'
						'docs:Generate skills documentation'
					)
					_describe -t skills 'skill command' skills_cmds
					;;
				completions)
					local -a comp_cmds
					comp_cmds=(
						'install:Install zsh completions'
					)
					_describe -t completions 'completion command' comp_cmds
					;;
			esac
			;;
	esac
}

compdef _braindance_complete braindance
