#!/usr/bin/zsh

# zmodload zsh/zprof

####################
# INITIAL SETUP
####################
source ~/.zshenv
export HOMEBREW_PREFIX="$(brew --prefix)"

####################
# CORE EXPORTS
####################
export CASE_SENSITIVE="false"
export HYPHEN_INSENSITIVE="true"
export COMPLETION_WAITING_DOTS="true"
export ZSH_CUSTOM=$XDG_CONFIG_HOME/zsh
export ZSH="$ZDOTDIR/ohmyzsh"

####################
# TOOL EXPORTS
####################
# Colorize settings
export ZSH_COLORIZE_TOOL=chroma
export ZSH_COLORIZE_STYLE="colorful"
export ZSH_COLORIZE_CHROMA_FORMATTER="terminal16m"

# FZF configuration
export FZF_COMPLETION_TRIGGER='**'
export FZF_COMPLETION_OPTS='--border --info=inline'
export FZF_COMPLETION_PATH_OPTS='--walker file,dir,follow,hidden'
export FZF_COMPLETION_DIR_OPTS='--walker dir,follow'

# Task warrior
export TASKRC=$XDG_CONFIG_HOME/task/taskrc
export TASKDATA=$XDG_DATA_HOME/tasks task list

# Go toolchain
export GOTOOLCHAIN=local

####################
# HELPER FUNCTIONS
####################
_append_to_env() {
    local path_segment=$1
    local separator=$2
    local env_var_name=$3
    
    local current_value=${(P)env_var_name}
    
    if [[ "$separator" == ":" ]]; then
        if [[ ":$current_value:" != *":$path_segment:"* ]]; then
            if [[ -z $current_value ]]; then
                export $env_var_name="$path_segment"
            else
                export $env_var_name="$current_value$separator$path_segment"
            fi
        fi
    else
        if [[ " $current_value " != *"$separator$path_segment "* ]]; then
            if [[ -z $current_value ]]; then
                export $env_var_name="$separator$path_segment"
            else
                export $env_var_name="$current_value$separator$path_segment"
            fi
        fi
    fi
}

####################
# PATH CONFIGURATIONS
####################
# Core system paths
_append_to_env "$HOME/bin" ":" "PATH"
_append_to_env "$HOME/Scripts" ":" "PATH"
_append_to_env "/usr/local/sbin" ":" "PATH"

# Development tools
_append_to_env "/usr/local/opt/openjdk/bin" ":" "PATH"
_append_to_env "/usr/local/opt/dart@2.18/bin" ":" "PATH"
_append_to_env "/usr/local/opt/sphinx-doc/bin" ":" "PATH"

# Ruby configuration
_append_to_env "/usr/local/opt/ruby/bin" ":" "PATH"
_append_to_env "/usr/local/opt/ruby/lib" "-L" "LDFLAGS"
_append_to_env "/usr/local/opt/ruby/include" "-I" "CPPFLAGS"
_append_to_env "/usr/local/opt/ruby/lib/pkgconfig" ":" "PKG_CONFIG_PATH"

# Curl configuration
_append_to_env "/usr/local/opt/curl/bin" ":" "PATH"
_append_to_env "/usr/local/opt/curl/lib" "-L" "LDFLAGS"
_append_to_env "/usr/local/opt/curl/include" "-I" "CPPFLAGS"
_append_to_env "/usr/local/opt/curl/lib/pkgconfig" ":" "PKG_CONFIG_PATH"

# Compiler tools
_append_to_env "/usr/local/opt/arm-none-eabi-gcc@8/bin" ":" "PATH"
_append_to_env "/usr/local/opt/arm-none-eabi-binutils/bin" ":" "PATH"
_append_to_env "/usr/local/opt/avr-gcc@8/bin" ":" "PATH"
_append_to_env "/usr/local/opt/arm-none-eabi-gcc@8/lib" "-L" "LDFLAGS"
_append_to_env "/usr/local/opt/avr-gcc@8/lib" "-L" "LDFLAGS"

# MySQL configuration
_append_to_env "/usr/local/opt/mysql@8.4/bin" ":" "PATH"
_append_to_env "/usr/local/opt/mysql@8.4/lib/pkgconfig" ":" "PKG_CONFIG_PATH"
_append_to_env "/usr/local/opt/mysql@8.4/lib" "-L" "LDFLAGS"
_append_to_env "/usr/local/opt/mysql@8.4/include" "-I" "CPPFLAGS"

# GNU tools
_append_to_env "/usr/local/opt/gnu-sed/libexec/gnubin" ":" "PATH"

####################
# CONDA SETUP (DEFERRED LOADING)
####################
conda() {
    # Remove this function
    unfunction conda
    
    # Setup conda
    __conda_setup="$('/usr/local/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/usr/local/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
            . "/usr/local/Caskroom/miniconda/base/etc/profile.d/conda.sh"
        else
            export PATH="/usr/local/Caskroom/miniconda/base/bin:$PATH"
        fi
    fi
    unset __conda_setup
    
    # Now run the actual conda command
    conda "$@"
}

####################
# OH-MY-ZSH CONFIGURATION
####################
plugins=(git history-substring-search)
source $ZSH/oh-my-zsh.sh

####################
# HISTORY CONFIGURATION
####################
setopt BANG_HIST
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# Explicitly set the search behavior
HISTORY_SUBSTRING_SEARCH_PREFIXED=1

####################
# VI MODE AND CURSOR CONFIGURATION
####################
# Set up initial vi mode state
export POSH_VI_MODE="INSERT"

# Initialize zsh-vi-mode first
source $HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# Function to update cursor and mode and refresh prompt
function _update_vim_mode() {
    local mode=$1
    export POSH_VI_MODE="$mode"
    
    case $mode in
        "INSERT")
            echo -ne '\e[5 q' # Beam cursor
            ;;
        *)
            echo -ne '\e[1 q' # Block cursor
            ;;
    esac
    
    if [[ -n "$POSH_SHELL_VERSION" ]]; then
        if command -v oh-my-posh >/dev/null 2>&1; then
            PROMPT="$(oh-my-posh prompt print primary --config="$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" --shell=zsh)"
            zle && zle reset-prompt
        fi
    fi
}

# Define mode switching function
function zvm_after_select_vi_mode() {
    case $ZVM_MODE in
        $ZVM_MODE_NORMAL)
            _update_vim_mode "NORMAL"
            ;;
        $ZVM_MODE_INSERT)
            _update_vim_mode "INSERT"
            ;;
        $ZVM_MODE_VISUAL)
            _update_vim_mode "VISUAL"
            ;;
        $ZVM_MODE_VISUAL_LINE)
            _update_vim_mode "V-LINE"
            ;;
        $ZVM_MODE_REPLACE)
            _update_vim_mode "REPLACE"
            ;;
    esac
}

# Set up line init handler
function zle-line-init() {
    _update_vim_mode "INSERT"
    zle -K viins # Ensure we're in insert mode
}
zle -N zle-line-init

# Set up keymap handler
function zle-keymap-select() {
    case ${KEYMAP} in
        vicmd)
            _update_vim_mode "NORMAL"
            ;;
        main|viins)
            _update_vim_mode "INSERT"
            ;;
    esac
}
zle -N zle-keymap-select

# Handle key bindings after vi-mode initialization
function zvm_after_init() {
    # Set initial cursor shape
    echo -ne '\e[5 q'
    
    # History search bindings for both modes
    bindkey -M vicmd '^[[A' history-substring-search-up
    bindkey -M vicmd '^[[B' history-substring-search-down
    bindkey -M viins '^[[A' history-substring-search-up
    bindkey -M viins '^[[B' history-substring-search-down
    
    # Additional key bindings
    bindkey -M viins '^?' backward-delete-char
    bindkey -M viins '^n' expand-or-complete
    bindkey -M viins '^p' reverse-menu-complete
}

# Reset cursor on exit
function zle-line-finish() {
    echo -ne '\e[5 q'
}
zle -N zle-line-finish

####################
# OH-MY-POSH CONFIGURATION
####################
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
    eval "$(oh-my-posh init zsh --config $XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml)"
fi

####################
# PLUGIN CONFIGURATION
####################
# ZSH-Autosuggestions configuration
zstyle ':autosuggest:*' min-length 2
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Fast-syntax-highlighting (load last to properly highlight everything)
source $HOMEBREW_PREFIX/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

####################
# TOOL CONFIGURATIONS
####################
# Setup luarocks
if type luarocks >/dev/null 2>&1; then eval "$(luarocks path --bin)"; fi

# Setup fzf
if type fzf >/dev/null 2>&1; then 
    source <(fzf --zsh)
    # FZF theming with catppuccin-mocha
    fzf_version=$(fzf --version)
    fzf_req_version="0.57.0"
    if [ "$(printf '%s\n' "$fzf_req_version" "$fzf_version" | sort -V | head -n1)" = "$fzf_req_version" ]; then 
        export FZF_DEFAULT_OPTS=" \
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
        --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
        --color=selected-bg:#45475a \
        --multi"
    fi
fi

# Setup zoxide
if type zoxide >/dev/null 2>&1; then eval "$(zoxide init zsh --cmd cd)"; fi

# Setup bat theme
if type fast-theme > /dev/null 2>&1; then fast-theme XDG:catppuccin-mocha > /dev/null 2>&1; fi

# Setup ssh-agent
if [ $(ps ax | grep ssh-agent | wc -l) -gt 0 ] ; then
    echo "ssh-agent already running" > /dev/null
else
    eval $(ssh-agent -s)
    if [ "$(ssh-add -l)" == "The agent has no identities."]; then
        ssh-add ~/.ssh/id_rsa
    fi
fi

# Setup batman
eval "$(batman --export-env)"

####################
# ALIASES
####################
# Config aliases
alias zshconfig="nvim $ZDOTDIR/zshrc"
alias zshsource="source $ZDOTDIR/zshrc"
alias nvimconfig="nvim $XDG_CONFIG_HOME/nvim/lua/config/*.lua $XDG_CONFIG_HOME/nvim/lua/plugins/*.lua"

# QMK aliases
alias qmk_og="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_firmware"
alias qmk_keychron="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_keychron"

# Nvim testing aliases
alias nvim-telescope='NVIM_APPNAME=nvim-telescope nvim'
alias nvim-fzf='NVIM_APPNAME=nvim-fzf nvim'

# Tmux aliases
alias tmux_main="tmux new-session -ADs main"

# File operation aliases
alias zcp='zmv -C'
alias zln='zmv -L'

# Tool aliases
alias mc="mc --nosubshell"
alias lazygit='lazygit --use-config-file="/Users/chris/.config/lazygit/config.yml,/Users/chris/.config/lazygit/catppuccin/themes-mergable/mocha/blue.yml"'
alias disable_gatekeeper="sudo spctl --master-disable"
if type taskwarrior-tui > /dev/null 2>&1; then alias tt="taskwarrior-tui"; fi

# Bat configuration
alias cat="bat --style=numbers --color=always"
alias bathelp="bat --plain --language=help"

TAIL_BIN=$(which tail)
function tail() {
    if [[ -n $1 && $1 == "-f" ]]; then
        $TAIL_BIN $* | bat --paging=never -l log 
    else
        $TAIL_BIN $*
    fi
}

function help() {
    "$@" --help 2>&1 | bathelp
}

# FZF with bat preview
if type bat >/dev/null 2>&1; then 
    alias fzf="fzf --preview 'bat --style=numbers --color=always {}' --preview-window '~3'"
fi

####################
# FINAL SETUP
####################
# Load completions
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# zprof
