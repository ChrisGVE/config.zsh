#!/usr/bin/env zsh

####################
# XDG Base Directory Specification
####################
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_RUNTIME_DIR="$HOME/.local/runtime"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DESKTOP_DIR="$HOME/Desktop"
export XDG_DOCUMENTS_DIR="$HOME/Documents"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export XDG_BIN_HOME="$HOME/.local/bin"

####################
# Core Environment Variables
####################
export EDITOR="nvim"
export VISUAL="nvim"

####################
# ZSH Configuration
####################
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$ZDOTDIR/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=50000

####################
# Tool-specific Environment Variables
####################
# zoxide
export _ZO_DATA_DIR="$XDG_DATA_HOME"
export _ZO_ECHO=0
export _ZO_EXCLUDE_DIRS=$XDG_DATA_HOME:$XDG_CACHE_HOME:$XDG_STATE_HOME
export _ZO_RESOLVE_SYMLINKS=0

# Include private environment variables if they exist
[[ -f $HOME/.secret/zshenv-private ]] && source $HOME/.secret/zshenv-private
