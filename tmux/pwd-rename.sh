#!/bin/sh
# Toggle naming each tmux window after its current directory.
# Bound in tmux.conf to prefix + P.
#
# Only the session you press the key in is touched. Nothing is set globally,
# so other sessions keep the names they have.
#
# Claude Code windows keep the name Claude gives them, in both states. Two
# things mark a Claude pane: the title starts with the character Claude puts
# in front of it, and the process name is a bare version number, which is
# what the Claude binary calls itself.

session=${1:-$(tmux display-message -p '#{session_name}')}

is_claude='#{||:#{m:✳*,#{pane_title}},#{m:[0-9]*.[0-9]*.[0-9]*,#{pane_current_command}}}'

# Claude's own title, without the marker character in front
claude_name='#{s|^✳ ||:#{pane_title}}'

# The last part of the current directory
directory_name='#{b:pane_current_path}'

name_format="#{?$is_claude,$claude_name,$directory_name}"

windows=$(tmux list-windows -t "$session" -F '#{window_index}')
claude_windows=$(tmux list-windows -t "$session" -f "$is_claude" -F '#{window_index}')

if [ "$(tmux show-option -t "$session" -qv @pwd-rename)" = "on" ]; then
	tmux set-option -t "$session" -u @pwd-rename
	# New windows in this session are ordinary again
	tmux set-hook -t "$session" -u after-new-window

	for window in $windows; do
		target="$session:$window"
		tmux set-window-option -t "$target" -u automatic-rename-format
		# Let programs set this window's title again
		tmux set-window-option -t "$target" -u allow-rename
		if echo "$claude_windows" | grep -qx "$window"; then
			# Hold the name Claude gave it until Claude sets the next one
			tmux set-window-option -t "$target" automatic-rename off
		else
			tmux set-window-option -t "$target" -u automatic-rename
		fi
	done
	message="Window names in #$session: back to normal"
else
	tmux set-option -t "$session" @pwd-rename on
	# Windows opened from now on get the same treatment
	tmux set-hook -t "$session" after-new-window \
		"set-window-option automatic-rename-format \"$name_format\" ; set-window-option allow-rename off ; set-window-option -u automatic-rename"

	for window in $windows; do
		target="$session:$window"
		tmux set-window-option -t "$target" automatic-rename-format "$name_format"
		# Stop shells and programs renaming windows out from under us
		tmux set-window-option -t "$target" allow-rename off
		# A window renamed by hand, or by a program, has its own
		# automatic-rename setting and would ignore the format above
		tmux set-window-option -t "$target" -u automatic-rename
	done
	message="Window names in #$session: current directory"
fi

tmux display-message -t "$session" "$message"
