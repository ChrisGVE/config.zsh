#!/usr/bin/zsh

# For profiling, uncomment:
# zmodload zsh/zprof

# Increase function nesting limit to prevent "maximum nested function level reached" errors
FUNCNEST=100

####################
# DETECT OS
####################
case "$(uname -s)" in
    Darwin*)    
        export OS_TYPE="macos"
        if command -v brew >/dev/null 2>&1; then
            export HOMEBREW_PREFIX="$(brew --prefix)"
        fi
        ;;
    Linux*)     
        export OS_TYPE="linux"
        # More reliable Raspberry Pi detection methods
        if [[ -f /sys/firmware/devicetree/base/model ]]; then
            if grep -q "Raspberry Pi" /sys/firmware/devicetree/base/model; then
                export OS_TYPE="raspberrypi"
            fi
        # Fallback detection method
        elif [[ -f /proc/cpuinfo ]]; then
            if grep -q "^Model.*:.*Raspberry" /proc/cpuinfo; then
                export OS_TYPE="raspberrypi"
            fi
        fi
        ;;
    *)          
        export OS_TYPE="unknown"
        ;;
esac

####################
# INITIAL SETUP
####################
source ~/.zshenv

####################
# CORE EXPORTS
####################
export CASE_SENSITIVE="false"
export HYPHEN_INSENSITIVE="true"
export COMPLETION_WAITING_DOTS="true"
export ZSH_CUSTOM=$XDG_CONFIG_HOME/zsh/custom
export ZSH="$ZDOTDIR/ohmyzsh"

####################
# HELPER FUNCTIONS
####################
function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}

_source_if_exists() {
    if [[ -f "$1" ]]; then
        source "$1"
    fi
}

# Find plugins across multiple locations
_find_plugin() {
    local plugin_name="$1"
    local plugin_file="$2"
    
    # Check in Homebrew location (macOS)
    if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
        local brew_path="$HOMEBREW_PREFIX/opt/$plugin_name/$plugin_file"
        if [[ -f "$brew_path" ]]; then
            echo "$brew_path"
            return
        fi
        
        # Also check share location
        local brew_share_path="$HOMEBREW_PREFIX/share/$plugin_name/$plugin_file"
        if [[ -f "$brew_share_path" ]]; then
            echo "$brew_share_path"
            return
        fi
    fi
    
    # Check in custom plugins directory (should work on all platforms)
    local custom_path="$ZDOTDIR/plugins/$plugin_name/$plugin_file"
    if [[ -f "$custom_path" ]]; then
        echo "$custom_path"
        return
    fi
    
    # Check system locations on Linux
    if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "raspberrypi" ]]; then
        # Check common Linux paths
        local linux_paths=(
            "$HOME/.zsh/plugins/$plugin_name/$plugin_file"
            "/usr/share/zsh/plugins/$plugin_name/$plugin_file"
            "/usr/local/share/zsh/plugins/$plugin_name/$plugin_file"
            "/usr/share/zsh/vendor-completions/$plugin_file"
        )
        for path in "${linux_paths[@]}"; do
            if [[ -f "$path" ]]; then
                echo "$path"
                return
            fi
        done
    fi
    
    # Return empty if not found
    echo ""
}

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
_append_to_env "/usr/local/sbin" ":" "PATH"
_append_to_env "/usr/local/bin" ":" "PATH"
_append_to_env "/opt/local/bin" ":" "PATH"
_append_to_env "$HOME/bin" ":" "PATH"
_append_to_env "$HOME/Scripts" ":" "PATH"
_append_to_env "$XDG_BIN_HOME" ":" "PATH"

# Platform-specific paths
if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
    # macOS with Homebrew
    _append_to_env "$HOMEBREW_PREFIX/opt/openjdk/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/dart@2.18/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/sphinx-doc/bin" ":" "PATH"
    
    # Ruby configuration
    _append_to_env "$HOMEBREW_PREFIX/opt/ruby/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/ruby/lib" "-L" "LDFLAGS"
    _append_to_env "$HOMEBREW_PREFIX/opt/ruby/include" "-I" "CPPFLAGS"
    _append_to_env "$HOMEBREW_PREFIX/opt/ruby/lib/pkgconfig" ":" "PKG_CONFIG_PATH"
    
    # Curl configuration
    _append_to_env "$HOMEBREW_PREFIX/opt/curl/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/curl/lib" "-L" "LDFLAGS"
    _append_to_env "$HOMEBREW_PREFIX/opt/curl/include" "-I" "CPPFLAGS"
    _append_to_env "$HOMEBREW_PREFIX/opt/curl/lib/pkgconfig" ":" "PKG_CONFIG_PATH"
    
    # Compiler tools
    _append_to_env "$HOMEBREW_PREFIX/opt/arm-none-eabi-gcc@8/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/arm-none-eabi-binutils/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/avr-gcc@8/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/arm-none-eabi-gcc@8/lib" "-L" "LDFLAGS"
    _append_to_env "$HOMEBREW_PREFIX/opt/avr-gcc@8/lib" "-L" "LDFLAGS"
    
    # MySQL configuration
    _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/bin" ":" "PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/lib/pkgconfig" ":" "PKG_CONFIG_PATH"
    _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/lib" "-L" "LDFLAGS"
    _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/include" "-I" "CPPFLAGS"
    
    # GNU tools
    _append_to_env "$HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin" ":" "PATH"
else
    # Linux-specific paths
    _append_to_env "/usr/lib/dart/bin" ":" "PATH"
fi

####################
# CONDA SETUP (DEFERRED LOADING)
####################
conda() {
    unfunction conda
    
    local conda_path
    case "$OS_TYPE" in
        macos)
            # Try several possible conda locations on macOS
            if [ -d "/usr/local/Caskroom/miniconda/base" ]; then
                conda_path="/usr/local/Caskroom/miniconda/base"
            elif [ -d "$HOMEBREW_PREFIX/Caskroom/miniconda/base" ]; then
                conda_path="$HOMEBREW_PREFIX/Caskroom/miniconda/base"
            elif [ -d "$HOME/miniconda3" ]; then
                conda_path="$HOME/miniconda3"
            else
                conda_path="/opt/local/conda"
            fi
            ;;
        raspberrypi|linux)
            # Try several possible conda locations on Linux
            if [ -d "/opt/local/share/dev/toolchains/conda" ]; then
                conda_path="/opt/local/share/dev/toolchains/conda"
            elif [ -d "/usr/local/share/dev/toolchains/conda" ]; then
                conda_path="/usr/local/share/dev/toolchains/conda" 
            elif [ -d "/opt/conda" ]; then
                conda_path="/opt/conda"
            elif [ -d "$HOME/miniconda3" ]; then
                conda_path="$HOME/miniconda3"
            else
                conda_path="/opt/local/conda"
            fi
            ;;
    esac
    
    if [[ -d "$conda_path" ]]; then
        __conda_setup="$('$conda_path/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        else
            if [ -f "$conda_path/etc/profile.d/conda.sh" ]; then
                . "$conda_path/etc/profile.d/conda.sh"
            else
                export PATH="$conda_path/bin:$PATH"
            fi
        fi
        unset __conda_setup
        conda "$@"
    else
        echo "conda not found in expected location: $conda_path"
    fi
}

####################
# OH-MY-ZSH CONFIGURATION
####################
if [[ -d "$ZSH" ]]; then
    plugins=(git history-substring-search)
    source $ZSH/oh-my-zsh.sh
else
    # Basic history configuration without Oh My Zsh
    autoload -U compinit && compinit
    
    # We need to define history-substring-search manually
    autoload -U history-substring-search-up
    autoload -U history-substring-search-down
    zle -N history-substring-search-up
    zle -N history-substring-search-down
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
fi

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
# ZOXIDE CONFIGURATION 
####################
# Safely implement zoxide functionality with backwards compatibility
if command -v zoxide >/dev/null 2>&1; then
    # Save the original cd function
    if ! function_exists _orig_cd; then
        function _orig_cd() {
            builtin cd "$@"
        }
    fi
    
    # First check if the installed zoxide version supports --no-cmd
    if zoxide init zsh --help 2>&1 | grep -q -- "--no-cmd"; then
        # Newer version - initialize zoxide without overriding cd
        eval "$(zoxide init zsh --hook pwd --no-cmd)"
    else
        # Older version - initialize zoxide normally and then override its cd function
        eval "$(zoxide init zsh --hook pwd)"
        # Immediately redefine the cd function to our version
    fi
    
    # Create our own implementation of cd that uses zoxide
    function cd() {
        if [[ "$#" -eq 0 ]]; then
            # cd with no args goes to $HOME
            _orig_cd "$HOME"
        elif [[ "$#" -eq 1 && "$1" != "-"* && ! -d "$1" ]]; then
            # For directories that don't exist locally, try zoxide
            # Use __zoxide_z directly if it exists, otherwise the z command
            if function_exists __zoxide_z; then
                __zoxide_z "$1"
            else
                # Fall back to external z command if function doesn't exist
                command z "$1"
            fi
        else
            # Use builtin cd for all other cases
            _orig_cd "$@"
        fi
    }
    
    # Provide zi as shortcut for zoxide interactive
    function zi() {
        local result
        result=$(zoxide query -i -- "$@")
        if [[ -n "$result" ]]; then
            _orig_cd "$result"
        fi
    }
    
    # Provide a raw cd command that bypasses zoxide
    alias rawcd="_orig_cd"
fi

####################
# VI MODE AND CURSOR CONFIGURATION
####################
# Set up initial vi mode state
export POSH_VI_MODE="INSERT"

# Flag to prevent recursive calls to _update_vim_mode
typeset -g VIM_MODE_UPDATING=0

# Function to update cursor and mode and refresh prompt
function _update_vim_mode() {
    # Check if we're already updating to prevent recursion
    if (( VIM_MODE_UPDATING )); then
        return
    fi
    
    # Set flag to indicate we're updating
    VIM_MODE_UPDATING=1
    
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
            if [[ -f "$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" ]]; then
                PROMPT="$(oh-my-posh prompt print primary --config="$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" --shell=zsh)"
                zle && zle reset-prompt
            fi
        fi
    fi
    
    # Clear the flag when we're done
    VIM_MODE_UPDATING=0
}

# Initialize zsh-vi-mode
ZVM_PATH=$(_find_plugin "zsh-vi-mode" "zsh-vi-mode.plugin.zsh")
if [[ -n "$ZVM_PATH" ]]; then
    source "$ZVM_PATH"
    
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
else
    # Basic vi mode if plugin not available
    bindkey -v
    # Make Vi mode transitions faster
    export KEYTIMEOUT=1
    
    # Setup similar keybindings without zsh-vi-mode
    bindkey '^n' expand-or-complete
    bindkey '^p' reverse-menu-complete
    
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
    
    # Reset cursor on exit
    function zle-line-finish() {
        echo -ne '\e[5 q'
    }
    zle -N zle-line-finish
fi

####################
# OH-MY-POSH CONFIGURATION
####################
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
    if command -v oh-my-posh >/dev/null 2>&1; then
        if [[ -f "$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" ]]; then
            eval "$(oh-my-posh init zsh --config $XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml)"
        else
            eval "$(oh-my-posh init zsh)"
        fi
    fi
fi

####################
# PLUGIN CONFIGURATION
####################
# ZSH-Autosuggestions configuration
zstyle ':autosuggest:*' min-length 2
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Source zsh-autosuggestions if available
AUTOSUGGESTIONS_PATH=$(_find_plugin "zsh-autosuggestions" "zsh-autosuggestions.zsh")
if [[ -n "$AUTOSUGGESTIONS_PATH" ]]; then
    source "$AUTOSUGGESTIONS_PATH"
fi

# Fast-syntax-highlighting (load last to properly highlight everything)
# First try different potential locations
FSH_PATH=$(_find_plugin "fast-syntax-highlighting" "fast-syntax-highlighting.plugin.zsh")
if [[ -n "$FSH_PATH" ]]; then
    source "$FSH_PATH"
fi

####################
# TOOL CONFIGURATIONS
####################
# Setup luarocks
if type luarocks >/dev/null 2>&1; then eval "$(luarocks path --bin)"; fi

# Setup fzf
if command -v fzf >/dev/null 2>&1; then 
    # Try different potential sources for fzf completion
    if [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
        source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
    elif [[ -f "/usr/share/doc/fzf/examples/completion.zsh" ]]; then
        source "/usr/share/doc/fzf/examples/completion.zsh"
        source "/usr/share/doc/fzf/examples/key-bindings.zsh"
    elif [[ -f "$ZDOTDIR/plugins/fzf/completion.zsh" ]]; then
        source "$ZDOTDIR/plugins/fzf/completion.zsh"
        source "$ZDOTDIR/plugins/fzf/key-bindings.zsh"
    else
        # Try using the built-in completion generator if available
        source <(fzf --zsh 2>/dev/null) || true
    fi
    
    # FZF theming with catppuccin-mocha
    fzf_version=$(fzf --version | awk '{print $1}')
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

# Detect and set up bat/batcat
if command -v bat >/dev/null 2>&1; then
    export BAT_CMD="bat"
elif command -v batcat >/dev/null 2>&1; then
    export BAT_CMD="batcat"
    # Optional: create bat alias if you want to always use 'bat' command
    alias bat="batcat"
fi

# Setup bat theme
if command -v fast-theme > /dev/null 2>&1; then
    if [[ -d "$XDG_DATA_HOME/zsh-fast-syntax-highlighting/themes" ]]; then
        fast-theme XDG:catppuccin-mocha > /dev/null 2>&1
    fi
fi

# Setup batman (only if it exists and supports --export-env)
if command -v batman >/dev/null 2>&1; then
    # Check if batman supports --export-env by testing with --help
    if batman --help 2>&1 | grep -q -- "--export-env"; then
        eval "$(batman --export-env)"
    else
        # In case it doesn't support the flag, create a simple alias
        alias batman="man"
    fi
fi

# Setup ssh-agent
if [ $(ps -p 1 -o comm=) != "systemd" ]; then
    # Non-systemd systems
    if [ $(ps ax | grep ssh-agent | wc -l) -gt 0 ] ; then
        echo "ssh-agent already running" > /dev/null
    else
        eval $(ssh-agent -s)
        if [ "$(ssh-add -l)" = "The agent has no identities." ]; then
            if [[ -f ~/.ssh/id_rsa ]]; then
                ssh-add ~/.ssh/id_rsa
            elif [[ -f ~/.ssh/id_ed25519 ]]; then
                ssh-add ~/.ssh/id_ed25519
            fi
        fi
    fi
else
    # On systemd systems, check if ssh-agent is running via systemd
    if ! systemctl --user is-active ssh-agent >/dev/null 2>&1; then
        # If not, start it
        systemctl --user start ssh-agent.service >/dev/null 2>&1
    fi
fi

####################
# ALIASES
####################

# Platform-specific aliases
if [[ "$OS_TYPE" == "macos" ]]; then
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

    # Tool aliases
    alias lazygit='lazygit --use-config-file="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/catppuccin/themes-mergable/mocha/blue.yml"'
    alias disable_gatekeeper="sudo spctl --master-disable"
else
    # Linux-specific aliases
    alias zshconfig="vim $ZDOTDIR/zshrc"
    alias zshsource="source $ZDOTDIR/zshrc"
    alias nvimconfig="vim $XDG_CONFIG_HOME/nvim/lua/config/*.lua $XDG_CONFIG_HOME/nvim/lua/plugins/*.lua"
    
    # System utilities specific to Linux
    alias apt-upgrade="sudo apt-get update && sudo apt-get upgrade"
    alias apt-clean="sudo apt-get autoremove && sudo apt-get autoclean"
fi

# Cross-platform aliases
if command -v taskwarrior-tui > /dev/null 2>&1; then alias tt="taskwarrior-tui"; fi

# Tmux aliases
alias tmux_main="tmux new-session -ADs main"

# File operation aliases
alias zcp='zmv -C'
alias zln='zmv -L'

# Provide a raw cd command that bypasses zoxide
alias rawcd="_orig_cd"

# Bat configuration
if [[ -n "$BAT_CMD" ]]; then
    alias cat="$BAT_CMD --style=numbers --color=always"
    alias bathelp="$BAT_CMD --plain --language=help"

    # Update your tail function
    TAIL_BIN=$(which tail)
    function tail() {
        if [[ -n $1 && $1 == "-f" ]]; then
            $TAIL_BIN $* | $BAT_CMD --paging=never -l log 
        else
            $TAIL_BIN $*
        fi
    }

    function help() {
        "$@" --help 2>&1 | $BAT_CMD --plain --language=help
    }

    # Update FZF with bat preview
    if command -v fzf >/dev/null 2>&1; then 
        alias fzf="fzf --preview '$BAT_CMD --style=numbers --color=always {}' --preview-window '~3'"
    fi
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

# Load custom local configuration if it exists
[[ -f $ZDOTDIR/zshrc.local ]] && source $ZDOTDIR/zshrc.local

# For profiling, uncomment:
# zprof
