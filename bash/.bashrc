#
# ~/.bashrc
#

# Prefer standalone agent installers over desktop-bundled commands.
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export ROCM_PATH=/opt/rocm
export PATH="$ROCM_PATH/bin:$PATH"

