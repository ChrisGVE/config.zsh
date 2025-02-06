#!/usr/bin/zsh

# zmodload zsh/zprof

#!/usr/bin/zsh

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
# HISTORY CONFIGURATION
####################
setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY               # Don't execute immediately upon history expansion.

# Custom history search widget
function history_search_up() {
    local prefix=${BUFFER}
    zle up-history
    while [[ -n $prefix && $BUFFER != ${prefix}* ]]; do
        zle up-history
    done
}

function history_search_down() {
    local prefix=${BUFFER}
    zle down-history
    while [[ -n $prefix && $BUFFER != ${prefix}* ]]; do
        zle down-history
    done
}

zle -N history_search_up
zle -N history_search_down

# Clear existing bindings
bindkey -r '^[OA'
bindkey -r '^[OB'
bindkey -r '^[[A'
bindkey -r '^[[B'

# Bind both sequences
bindkey '^[OA' history_search_up
bindkey '^[OB' history_search_down

####################
# OH-MY-ZSH CONFIGURATION
####################
plugins=(git)
source $ZSH/oh-my-zsh.sh

####################
# PLUGIN CONFIGURATION
####################
# ZSH-Autosuggestions configuration
zstyle ':autosuggest:*' min-length 2
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Fast-syntax-highlighting
source $HOMEBREW_PREFIX/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

# Auto completion
source $HOMEBREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh

####################
# KEY BINDINGS
####################
bindkey -v '^?' backward-delete-char
bindkey '^n' expand-or-complete
bindkey '^p' reverse-menu-complete

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

####################
# VI MODE CONFIGURATION
####################
export POSH_VI_MODE="INSERT"
export ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
export ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
export ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
export ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLOCK
export ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
export ZVM_VI_HIGHLIGHT_BACKGROUND=#45475a

source $HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

function zvm_after_select_vi_mode() {
    case $ZVM_MODE in
        $ZVM_MODE_NORMAL)   POSH_VI_MODE="NORMAL"   ;;
        $ZVM_MODE_INSERT)   POSH_VI_MODE="INSERT"   ;;
        $ZVM_MODE_VISUAL)   POSH_VI_MODE="VISUAL"   ;;
        $ZVM_MODE_VISUAL_LINE) POSH_VI_MODE="V-LINE"   ;;
        $ZVM_MODE_REPLACE)  POSH_VI_MODE="REPLACE"  ;;
    esac
    _omp_redraw-prompt
}

####################
# OH-MY-POSH CONFIGURATION
####################
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
    eval "$(oh-my-posh init zsh --config $XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml)"
fi

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
