#!/bin/bash
# Bash completion for devbox CLI
# Install: source this file or copy to /etc/bash_completion.d/

# Fallback _init_completion for systems without bash-completion package
if ! declare -F _init_completion >/dev/null 2>&1; then
	_init_completion() {
		# Basic implementation when bash-completion is not available
		COMPREPLY=()
		cur="${COMP_WORDS[COMP_CWORD]}"
		prev="${COMP_WORDS[COMP_CWORD - 1]}"
		words=("${COMP_WORDS[@]}")
		cword=$COMP_CWORD
	}
fi

_devbox_completion() {
	local cur prev words cword
	_init_completion || return

	# Top-level commands
	local commands="init create list attach stop start rm logs exec ports secrets help"

	# Get the command (first non-option argument)
	local command=""
	local i
	for ((i = 1; i < cword; i++)); do
		if [[ "${words[i]}" != -* ]]; then
			command="${words[i]}"
			break
		fi
	done

	# If no command yet, complete command names
	if [[ -z "$command" ]]; then
		COMPREPLY=($(compgen -W "$commands" -- "$cur"))
		return 0
	fi

	# Helper function to get container names
	_devbox_containers() {
		devbox list 2>/dev/null | tail -n +3 | awk '{print $1}' 2>/dev/null
	}

	# Complete based on the command
	case "$command" in
	init)
		local init_opts="--bedrock --import-aws --help -h"
		COMPREPLY=($(compgen -W "$init_opts" -- "$cur"))
		;;

	create)
		# Check if we need container name, repo URL, or options
		local create_opts="--port -p --bedrock --aws-profile --help -h"

		# Count non-option arguments after 'create'
		local arg_count=0
		for ((i = 2; i < cword; i++)); do
			if [[ "${words[i]}" != -* ]] && [[ "${words[i - 1]}" != --port ]] && [[ "${words[i - 1]}" != -p ]] && [[ "${words[i - 1]}" != --aws-profile ]]; then
				((arg_count++))
			fi
		done

		# If previous word needs a value, don't suggest anything
		if [[ "$prev" == "--port" ]] || [[ "$prev" == "-p" ]]; then
			# Could suggest common port patterns, but leave empty for user input
			return 0
		elif [[ "$prev" == "--aws-profile" ]]; then
			# Could read from ~/.aws/config but leave empty for now
			return 0
		else
			# Suggest flags
			COMPREPLY=($(compgen -W "$create_opts" -- "$cur"))
		fi
		;;

	list)
		local list_opts="--help -h"
		COMPREPLY=($(compgen -W "$list_opts" -- "$cur"))
		;;

	attach | stop | start)
		# Complete container names or flags
		if [[ "$cur" == -* ]]; then
			case "$command" in
			attach)
				COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
				;;
			stop | start)
				COMPREPLY=($(compgen -W "--dry-run --help -h" -- "$cur"))
				;;
			esac
		else
			# Complete container names
			COMPREPLY=($(compgen -W "$(_devbox_containers)" -- "$cur"))
		fi
		;;

	rm)
		# Complete container names or flags
		if [[ "$cur" == -* ]]; then
			local rm_opts="--force -f -a -af -fa --dry-run --help -h"
			COMPREPLY=($(compgen -W "$rm_opts" -- "$cur"))
		else
			# Only suggest container names if -a flag not present
			local has_all_flag=false
			for word in "${words[@]}"; do
				if [[ "$word" == "-a" ]] || [[ "$word" == "-af" ]] || [[ "$word" == "-fa" ]]; then
					has_all_flag=true
					break
				fi
			done

			if [[ "$has_all_flag" == false ]]; then
				COMPREPLY=($(compgen -W "$(_devbox_containers)" -- "$cur"))
			fi
		fi
		;;

	logs)
		# Complete container names or flags
		if [[ "$cur" == -* ]]; then
			local logs_opts="--follow -f --tail --dry-run --help -h"
			COMPREPLY=($(compgen -W "$logs_opts" -- "$cur"))
		elif [[ "$prev" == "--tail" ]]; then
			# Suggest common tail values
			COMPREPLY=($(compgen -W "10 50 100 200 500" -- "$cur"))
		else
			# Complete container names
			COMPREPLY=($(compgen -W "$(_devbox_containers)" -- "$cur"))
		fi
		;;

	exec)
		# Complete container names or flags
		if [[ "$cur" == -* ]]; then
			local exec_opts="-it -ti --dry-run --help -h"
			COMPREPLY=($(compgen -W "$exec_opts" -- "$cur"))
		else
			# Count arguments to determine if we're completing container name or command
			local arg_count=0
			for ((i = 2; i < cword; i++)); do
				if [[ "${words[i]}" != -* ]]; then
					((arg_count++))
				fi
			done

			if [[ $arg_count -eq 0 ]]; then
				# First argument: complete container name
				COMPREPLY=($(compgen -W "$(_devbox_containers)" -- "$cur"))
			elif [[ $arg_count -eq 1 ]]; then
				# Second argument: suggest common commands
				local common_cmds="bash sh claude gh git node npm yarn python pip"
				COMPREPLY=($(compgen -W "$common_cmds" -- "$cur"))
			fi
			# After second argument, no completion (arbitrary command args)
		fi
		;;

	ports)
		# Complete container names or flags
		if [[ "$cur" == -* ]]; then
			local ports_opts="--dry-run --help -h"
			COMPREPLY=($(compgen -W "$ports_opts" -- "$cur"))
		else
			# Complete container names
			COMPREPLY=($(compgen -W "$(_devbox_containers)" -- "$cur"))
		fi
		;;

	secrets)
		# Get secrets subcommand
		local secrets_subcmd=""
		for ((i = 2; i < cword; i++)); do
			if [[ "${words[i]}" != -* ]]; then
				secrets_subcmd="${words[i]}"
				break
			fi
		done

		if [[ -z "$secrets_subcmd" ]]; then
			# Complete subcommands
			local secrets_cmds="add remove list path --help -h"
			COMPREPLY=($(compgen -W "$secrets_cmds" -- "$cur"))
		else
			case "$secrets_subcmd" in
			add)
				if [[ "$cur" == -* ]]; then
					local add_opts="--from-env --from-file --force -f --help -h"
					COMPREPLY=($(compgen -W "$add_opts" -- "$cur"))
				elif [[ "$prev" == "--from-file" ]]; then
					# Complete file paths
					COMPREPLY=($(compgen -f -- "$cur"))
				fi
				;;
			remove | rm)
				if [[ "$cur" == -* ]]; then
					local remove_opts="--force -f --help -h"
					COMPREPLY=($(compgen -W "$remove_opts" -- "$cur"))
				else
					# Complete secret names from secrets list
					local secrets_list
					secrets_list=$(devbox secrets list 2>/dev/null | tail -n +4 | awk '{print $1}' 2>/dev/null)
					COMPREPLY=($(compgen -W "$secrets_list" -- "$cur"))
				fi
				;;
			list | ls)
				local list_opts="--help -h"
				COMPREPLY=($(compgen -W "$list_opts" -- "$cur"))
				;;
			path)
				local path_opts="--help -h"
				COMPREPLY=($(compgen -W "$path_opts" -- "$cur"))
				;;
			esac
		fi
		;;

	help)
		# No completion for help command
		return 0
		;;
	esac

	return 0
}

# Register completion function
complete -F _devbox_completion devbox
