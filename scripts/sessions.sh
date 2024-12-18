#!/usr/bin/env bash
if [ "$(command -v zellij)" = "" ]; then
    echo "Zellij is not installed"
    exit 1
fi

if [ "$(command -v zoxide)" = "" ]; then
    echo "Zoxide is not installed"
    exit 1
fi

home_replacer() {
    HOME_REPLACER=""                                          # default to a noop
    echo "$HOME" | grep -E "^[a-zA-Z0-9\-_/.@]+$" &>/dev/null # chars safe to use in sed
    HOME_SED_SAFE=$?
    if [ $HOME_SED_SAFE -eq 0 ]; then # $HOME should be safe to use in sed
        HOME_REPLACER="s|^$HOME/|~/|"
    fi
    echo "$HOME_REPLACER"
}

transform_home_path() {
    HOME_SED_SAFE=$?
    if [ $HOME_SED_SAFE -eq 0 ]; then
        echo "$1" | sed -e "s|^~/|$HOME/|"
    else
        echo "$1"
    fi
}

fzf_window() {
	fzf --reverse --border "rounded" --info inline --pointer "→" --prompt "Session > " --header "Select session" --preview "echo {2} | grep -q 'Session' && echo {} || ls {3}"
}

select_project() {
    project_dir=$({ zellij list-sessions -s | awk '{ print "("NR")\t[Session]\t"$1 }'; zoxide query -l | awk '{ print "("NR")\t[Directory]\t"$1 }' ; } | fzf_window)
    if [ "$project_dir" = "" ]; then
        exit
    fi
	echo "$project_dir"
}

is_selected_session(){
	if [ -n "$(echo "$1" | grep "^([0-9]*)\\\t\[Session\]")" ]; then
		echo 1
	fi
}

get_sanitized_selected(){
	echo "$1" | sed "s/^([0-9]*)\t\[[^]]*\]\t//"
}

get_session_name() {
    project_dir=$1
    directory=$(basename "$project_dir")
    session_name=$(echo "$directory" | tr ' .:' '_')
    echo "$session_name"
}

selected=$(select_project)
if [ -z "$selected" ]; then
	exit 0
fi

is_session=$(is_selected_session "$selected")
selected_name=$(get_sanitized_selected "$selected")
session_name=$(get_session_name "$(transform_home_path "$selected_name")")
session=$(zellij list-sessions | grep "$session_name")
# If we're inside of zellij, detach
if [[ -n "$ZELLIJ" ]]; then
	zellij pipe --plugin file:~/Projects/zellij-attach/target/wasm32-wasi/release/zellij-attach.wasm -- "$session_name::$selected_name"
else
	if [[ -n "$is_session" ]]; then
		zellij attach $selected_name -c
	else
		zellij attach $session_name -c options --default-cwd $selected_name
	fi
fi

