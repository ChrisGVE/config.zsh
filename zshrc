#!/usr/bin/env zsh

# disable the use of compaudit 
ZSH_DISABLE_COMPFIX=true
# ZSH_RUN_COMPINIT=false

# For profiling, uncomment:
# zmodload zsh/zprof
# setopt prompt_subst
# PS4='+%x:%I> '  # helps show where you are during tracing

# trace the use of compaudit
# typeset -ft compaudit
# functions compaudit

# run with ZSH_DEBUG=1 zsh -xv

# ─────────────────────────────────────────────────────────────
# CHECKLIST
# ─────────────────────────────────────────────────────────────
# TODO: Replace the manual plugin handling and setup zinit
# TODO: Optimize loading using built-in zinit functionalities 
# TODO: Check unused functions as candidates for removal 
# FIX:  No color in the interface (e.g. with ls or l)
# PERF: Audit performance after the above changes
#
#
# ─────────────────────────────────────────────────────────────
# DETECT OS
# ─────────────────────────────────────────────────────────────
case "$(uname -s)" in
    Darwin*)    
        export OS_TYPE="macos"
        if (( $+commands[brew] )); then
            export HOMEBREW_PREFIX="$(brew --prefix)"
        fi
        ;;
    Linux*)     
        # Check if homebrew is present and if it is run the shell integration
        if [[ -d /home/linuxbrew/.linuxbrew/Homebrew ]]; then
          eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        elif [[ -d /home/linuxbrew/.linuxbrew/homebrew ]]; then
          eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
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

# ─────────────────────────────────────────────────────────────
# INITIAL SETUP
# ─────────────────────────────────────────────────────────────
source ~/.zshenv

# ─────────────────────────────────────────────────────────────
# CORE EXPORTS
# ─────────────────────────────────────────────────────────────
export CASE_SENSITIVE="false"
export HYPHEN_INSENSITIVE="true"
export COMPLETION_WAITING_DOTS="true"

# ─────────────────────────────────────────────────────────────
# PLUGINS REGISTRY
# ─────────────────────────────────────────────────────────────
# typeset -ga OMZ_PLUGIN_FILES=()

# ─────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────
function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}

_source_if_exists() {
    if [[ -f "$1" ]]; then
        source "$1"
    fi
}

# Lazy load completion
_lazy_complete() {
	local cmd=$1
	local compfile=$2
	local def_func="_${cmd}"
	eval "_${cmd}_completion() {
    unfunction _${cmd}_completion
    source $compfile
    compdef $def_func $cmd
  }"
	compdef _${cmd}_completion $cmd
}

_set_fpath_from_candidates() {
  for dir in "$@"; do 
    [[ -d "$dir" ]] && fpath+=("$dir")
  done
}

# Use om-my-zsh components
_use_omz_components_locally() {
  local type="$1" name="$2"
  local target_dir="$ZSH_CONFIG_DIR/${type}s/$name"
  local archive_url="https://codeload.github.com/ohmyzsh/ohmyzsh/tar.gz/refs/heads/master"

  # If the target directory exists and is not empty, skip download
  if [[ -d "$target_dir" && -n "$(ls -A "$target_dir" 2>/dev/null)" ]]; then
    local plugin_file=("$target_dir"/*.plugin.zsh(N))
    if [[ -n $plugin_file ]]; then
      OMZ_PLUGIN_FILES+=("$plugin_file")
    fi
    return 0
  fi

  echo "Downloading OMZ ${type}: $name..."

  local tempdir tempdest
  tempdir="$(mktemp -d)" || {
    echo "⚠️ Failed to create temp dir" >&2
    return 1
  }
  tempdest="$tempdir/ohmyzsh.tar.gz"

  if ! curl -fsSL "$archive_url" -o "$tempdest"; then
    echo "⚠️ Failed to download archive from $archive_url" >&2
    rm -rf "$tempdir"
    return 1
  fi

  if ! tar -xzf "$tempdest" -C "$tempdir" --strip-components=1 "ohmyzsh-master/${type}s/$name" 2>/dev/null; then
    echo "⚠️ Directory ${type}s/$name not found in archive." >&2
    rm -rf "$tempdir"
    return 1
  fi

  mkdir -p "$target_dir"
  mv "$tempdir/${type}s/$name"/* "$target_dir/" 2>/dev/null

  local plugin_file=("$target_dir"/*.plugin.zsh(N))
  if [[ -n $plugin_file ]]; then
    OMZ_PLUGIN_FILES+=("$plugin_file")
  else
    echo "⚠️ No loadable file found for ${type} $name" >&2
  fi

  rm -rf "$tempdir"
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

_prefix_to_env() {
    local path_segment=$1
    local separator=$2
    local env_var_name=$3
    
    local current_value=${(P)env_var_name}
    
    if [[ "$separator" == ":" ]]; then
        if [[ ":$current_value:" != *":$path_segment:"* ]]; then
            if [[ -z $current_value ]]; then
                export $env_var_name="$path_segment"
            else
                export $env_var_name="$path_segment$separator$current_value"
            fi
        fi
    else
        if [[ " $current_value " != *"$separator$path_segment "* ]]; then
            if [[ -z $current_value ]]; then
                export $env_var_name="$separator$path_segment"
            else
                export $env_var_name="$separator$path_segment $current_value"
            fi
        fi
    fi
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

# ─────────────────────────────────────────────────────────────
# PATH CONFIGURATIONS
# ─────────────────────────────────────────────────────────────
# Core system paths
_append_to_env "$HOME/Scripts" ":" "PATH"
_append_to_env "$HOME/bin" ":" "PATH"
_append_to_env "$XDG_BIN_HOME" ":" "PATH"
_append_to_env "/opt/local/bin" ":" "PATH"
_append_to_env "/usr/local/bin" ":" "PATH"
_append_to_env "/usr/local/opt/file-formula/bin" ":" "PATH"
_append_to_env "/usr/local/sbin" ":" "PATH"

# Rust paths
_append_to_env "$HOME/.cargo/bin" ":" "PATH"

# Homebrew configuration
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  # GNU COREUTILS take precedence
  export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"

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

  # LLVM config 
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm/bin" ":" "PATH"
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm/lib" "-L" "LDFLAGS"
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm/include" "-I" "CPPFLAGS"
  
  # LLVM@18 config 
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm@18/bin" ":" "PATH"
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm@18/lib" "-L" "LDFLAGS"
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm@18/include" "-I" "CPPFLAGS"

  # LLVM@19 config 
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm@19/bin" ":" "PATH"
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm@19/lib" "-L" "LDFLAGS"
  _append_to_env "$HOMEBREW_PREFIX/opt/llvm@19/include" "-I" "CPPFLAGS"

  # MySQL configuration
  _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/bin" ":" "PATH"
  _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/lib/pkgconfig" ":" "PKG_CONFIG_PATH"
  _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/lib" "-L" "LDFLAGS"
  _append_to_env "$HOMEBREW_PREFIX/opt/mysql@8.4/include" "-I" "CPPFLAGS"
  
  # OpenMP
  _append_to_env "$HOMEBREW_PREFIX/opt/libomp" ";" "CMAKE_PREFIX_PATH"

  # Rust
  _prefix_to_env "$HOME/.cargo/bin" ":" "PATH"
  _prefix_to_env "$HOMEBREW_PREFIX/opt/rustup/bin" ":" "PATH"
  _append_to_env "$HOME/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/x86_64-apple-darwin/bin/llvm-cov" ":" "LLVM_COV" 
  _append_to_env "$HOME/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/x86_64-apple-darwin/bin/llvm-profdata" ":" "LLVM_PROFDATA"

  # GNU tools
  _append_to_env "$HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin" ":" "PATH"

  _append_to_env "$HOMEBREW_PREFIX/bin" ":" "PATH"
fi

# Platform-specific paths
if [[ "$OS_TYPE" == "macos" ]]; then
  # expat
  _prefix_to_env "/usr/local/opt/expat/bin" ":" "PATH"
  _append_to_env "/usr/local/opt/expat/lib" "-L" "LDFLAGS"
  _append_to_env "/usr/local/opt/expat/include" "-I" "CPPFLAGS"
  _append_to_env "/usr/local/opt/expat/lib/pkgconfig" ":" "PKG_CONFIG_PATH"

  # ollama
  _append_to_env "/usr/local/opt/ollama/bin" ":" "PATH"

  # MacTex
  eval "$(/usr/libexec/path_helper)"

  # jpeg
  _append_to_env "/usr/local/opt/jpeg/bin" ":" "PATH"
  _append_to_env "/usr/local/opt/jpeg/lib" "-L" "LDFLAGS"
  _append_to_env "/usr/local/opt/jpeg/include" "-I" "CPPFLAGS"
  _append_to_env "/usr/local/opt/jpeg/lib/pkgconfig/" ":" "PKG_CONFIG_PATH"
else
  # Linux-specific paths
  _append_to_env "/usr/lib/dart/bin" ":" "PATH"

  if [[ "$OS_TYPE" == "raspberrypi" ]]; then
    # Place ghcup folder first such that homebrew can find it
    _prefix_to_env "$HOME/.ghcup/bin" ":" "PATH"
  fi
fi

# ─────────────────────────────────────────────────────────────
# CONDA SETUP (LAZY LOADING)
# ─────────────────────────────────────────────────────────────
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
                conda_pa:wth="/opt/local/share/dev/toolchains/conda"
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

# ─────────────────────────────────────────────────────────────
# MICROMAMBA SETUP (LAZY LOADING)
# ─────────────────────────────────────────────────────────────
mamba() {
    unfunction mamba
    
    local mamba_path
    case "$OS_TYPE" in
        macos)
            # Try several possible micromamba locations on macOS
            if [[ -d "$HOMEBREW_PREFIX/opt/micromamba" ]]; then
                mamba_path="$HOMEBREW_PREFIX/opt/micromamba"
            elif [[ -d "$HOMEBREW_PREFIX/Caskroom/micromamba" ]]; then
                mamba_path="$HOMEBREW_PREFIX/Caskroom/micromamba"
            elif [[ -d "$HOME/micromamba" ]]; then
                mamba_path="$HOME/micromamba"
            elif [[ -d "$HOME/.micromamba" ]]; then
                mamba_path="$HOME/.micromamba"
            else
                mamba_path="/opt/local/micromamba"
            fi
            export CONDA_OVERRIDE_OSX=10.15
            ;;
        raspberrypi|linux)
            # Try several possible micromamba locations on Linux
            if [[ -d "/opt/micromamba" ]]; then
                mamba_path="/opt/micromamba"
            elif [[ -d "/usr/local/micromamba" ]]; then
                mamba_path="/usr/local/micromamba"
            elif [[ -d "$HOME/micromamba" ]]; then
                mamba_path="$HOME/micromamba"
            elif [[ -d "$HOME/.micromamba" ]]; then
                mamba_path="$HOME/.micromamba"
            elif [[ -d "/opt/local/share/dev/toolchains/micromamba" ]]; then
                mamba_path="/opt/local/share/dev/toolchains/micromamba"
            else
                mamba_path="/opt/local/micromamba"
            fi
            ;;
    esac
    
    if [[ -d "$mamba_path" ]]; then
        # Initialize micromamba shell
        eval "$("$mamba_path/bin/mamba" shell hook -s zsh)"
        
        # Add micromamba bin to PATH if not already present
        if [[ ":$PATH:" != *":$mamba_path/bin:"* ]]; then
            export PATH="$mamba_path/bin:$PATH"
        fi
        
        mamba "$@"
    else
        echo "micromamba not found in expected location: $mamba_path"
    fi
}


# ─────────────────────────────────────────────────────────────
# Bootstrap Zinit Plugin Manager
# ─────────────────────────────────────────────────────────────
if [[ ! -d "$ZINIT_HOME" ]]; then
	echo "Installing zinit to $ZINIT_HOME..."
	git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

# ─────────────────────────────────────────────────────────────
# HISTORY CONFIGURATION
# ─────────────────────────────────────────────────────────────
setopt BANG_HIST
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
# setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# Explicitly set the search behavior
HISTORY_SUBSTRING_SEARCH_PREFIXED=1

# ─────────────────────────────────────────────────────────────
# LS COLORS & CORE ALIASES ( <<< NEW SECTION >>> )
# ─────────────────────────────────────────────────────────────
# Setup LS_COLORS using dircolors if available
if (( $+commands[dircolors] )); then
  # Example using standard theme:
  eval "$(dircolors -b)"
  # Example using custom file (if you have one):
  # [[ -f "$XDG_CONFIG_HOME/dircolors/config" ]] && eval "$(dircolors -b "$XDG_CONFIG_HOME/dircolors/config")"

  # Optional: Use LS_COLORS for Zsh completion coloring
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

# Basic Aliases including LS coloring based on OS
alias ..="cd .."
alias ...="cd ../.."

# Determine if 'ls' supports '--color' (GNU) or '-G' (BSD)
local ls_cmd='ls'
if GRC=$(which grc); then # Use grc if available
    ls_cmd='grc --colour=auto ls'
elif ls --color=auto -d / >/dev/null 2>&1; then # GNU ls
    alias ls='ls --color=auto -F' # -F adds indicators (/, *, @)
    alias l='ls -lAh --color=auto'
    alias la='ls -A --color=auto'
    alias ll='ls -lh --color=auto' # long format, human-readable sizes
else # BSD ls (macOS default)
    alias ls='ls -GF' # -G enables color, -F adds indicators
    alias l='ls -lAh' # -G implicit via ls alias
    alias la='ls -A'  # -G implicit
    alias ll='ls -lh' # -G implicit
fi
# Add any other preferred aliases, e.g., grep
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# ─────────────────────────────────────────────────────────────
# HISTORY CONFIGURATION
# ─────────────────────────────────────────────────────────────
# autoload -Uz history-substring-search-up history-substring-search-down
# zle -N history-substring-search-up
# zle -N history-substring-search-down

# ─────────────────────────────────────────────────────────────
# VI MODE AND CURSOR CONFIGURATION
# ─────────────────────────────────────────────────────────────
# Set up initial vi mode state
export POSH_VI_MODE="INSERT"

# Flag to prevent recursive calls to _update_vim_mode
typeset -g VIM_MODE_UPDATING=0

# Function to update cursor and mode and refresh prompt
# function _update_vim_mode() {
#     # Check if we're already updating to prevent recursion
#     if (( VIM_MODE_UPDATING )); then
#         return
#     fi
#
#     # Set flag to indicate we're updating
#     VIM_MODE_UPDATING=1
#
#     local mode=$1
#     export POSH_VI_MODE="$mode"
#
#     # Set cursor shape based on mode
#     # 1: blinking block, 2: steady block, 3: blinking underline, 4: steady underline, 5: blinking bar, 6: steady bar
#     case $mode in
#         "INSERT")
#             echo -ne '\e[5 q' # Blinking bar
#             ;;
#         *)
#             echo -ne '\e[2 q' # Block cursor
#             ;;
#     esac
#
#
#     if [[ -n "$POSH_SHELL_VERSION" ]] && (( $+commands[oh-my-posh] )) && [[ -f "$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" ]]; then
#         # Use zle reset-prompt for efficient refresh
#           zle && zle reset-prompt
#     fi
#
#     # if [[ -n "$POSH_SHELL_VERSION" ]]; then
#     #   if (( $+commands[oh-my-posh] )); then
#     #         if [[ -f "$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" ]]; then
#     #             PROMPT="$(oh-my-posh prompt print primary --config="$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" --shell=zsh)"
#     #             zle && zle reset-prompt
#     #         fi
#     #     fi
#     # fi
#
#     # Clear the flag when we're done
#     VIM_MODE_UPDATING=0
# }
function _update_vim_mode() {
    # Uncomment for debugging if issues persist:
    # echo "DEBUG: _update_vim_mode called with mode: $1. Current POSH_VI_MODE: $POSH_VI_MODE. Updating: $VIM_MODE_UPDATING" >&2

    if (( VIM_MODE_UPDATING )); then return; fi
    VIM_MODE_UPDATING=1
    local target_mode="$1"

    # Update cursor shape first
    case "$target_mode" in
        "INSERT")
            echo -ne '\e[5 q' ;; # Blinking beam
        *)
            echo -ne '\e[2 q' ;; # Steady block (for NORMAL, VISUAL, etc.)
    esac

    # Update POSH_VI_MODE only if it changed, then refresh prompt
    if [[ "$POSH_VI_MODE" != "$target_mode" ]]; then
        export POSH_VI_MODE="$target_mode"
        # echo "DEBUG: POSH_VI_MODE exported as $POSH_VI_MODE" >&2 # For debugging

        # If Oh My Posh is active, trigger a prompt refresh.
        # OMP's own hooks set by 'oh-my-posh init zsh' should handle the update.
        if [[ -n "$POSH_SHELL_VERSION" ]] && (( $+commands[oh-my-posh] )); then
            # echo "DEBUG: Calling zle reset-prompt for OMP" >&2 # For debugging
            zle reset-prompt
        fi
    fi
    VIM_MODE_UPDATING=0
}


# Initialize zsh-vi-mode
# ZVM_PATH=$(_find_plugin "zsh-vi-mode" "zsh-vi-mode.plugin.zsh")

# if [[ -n "$ZVM_PATH" ]]; then
#     source "$ZVM_PATH"
#
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
        *)
            _update_vim_mode "$ZVM_MODE"  # Fallback if needed
            ;;
    esac
}
    
# Handle key bindings after vi-mode initialization
function zvm_after_init() {
    # Set initial cursor shape
    echo -ne '\e[5 q'
    
    # # History search bindings for both modes
    # bindkey -M vicmd '^[[A' history-substring-search-up
    # bindkey -M vicmd '^[[B' history-substring-search-down
    # bindkey -M viins '^[[A' history-substring-search-up
    # bindkey -M viins '^[[B' history-substring-search-down
  # bindkey -M vicmd "${terminfo[kcuu1]:-^[[A]}" up-line-or-beginning-search
  # bindkey -M vicmd "${terminfo[kcud1]:-^[[B]}" down-line-or-beginning-search
  # bindkey -M viins "${terminfo[kcuu1]:-^[[A]}" up-line-or-beginning-search
  # bindkey -M viins "${terminfo[kcud1]:-^[[B]}" down-line-or-beginning-search
    if [[ "$OS_TYPE" == "macos" ]]; then
      bindkey -M vicmd '^[[A' up-line-or-beginning-search
      bindkey -M vicmd '^[[B' down-line-or-beginning-search
      bindkey -M viins '^[[A' up-line-or-beginning-search
      bindkey -M viins '^[[B' down-line-or-beginning-search
    else
      bindkey -M vicmd "${terminfo[kcuu1]:-^[[A]}" history-substring-search-up
      bindkey -M vicmd "${terminfo[kcud1]:-^[[B]}" history-substring-search-down
      bindkey -M viins "${terminfo[kcuu1]:-^[[A]}" history-substring-search-up
      bindkey -M viins "${terminfo[kcud1]:-^[[B]}" history-substring-search-down
    fi
    
    # Additional key bindings
    bindkey -M viins '^?' backward-delete-char
    # bindkey -M viins '^n' expand-or-complete
    # bindkey -M viins '^p' reverse-menu-complete
}
# else
#     # Basic vi mode if plugin not available
#     bindkey -v
#     # Make Vi mode transitions faster
#     export KEYTIMEOUT=1
#
#     # Setup similar keybindings without zsh-vi-mode
#     bindkey '^n' expand-or-complete
#     bindkey '^p' reverse-menu-complete
#
#     # Set up line init handler
#     function zle-line-init() {
#         _update_vim_mode "INSERT"
#         zle -K viins # Ensure we're in insert mode
#     }
#     zle -N zle-line-init
#
#     # Set up keymap handler
#     function zle-keymap-select() {
#         case ${KEYMAP} in
#             vicmd)
#                 _update_vim_mode "NORMAL"
#                 ;;
#             main|viins)
#                 _update_vim_mode "INSERT"
#                 ;;
#         esac
#     }
#     zle -N zle-keymap-select
#
#     # Reset cursor on exit
#     function zle-line-finish() {
#         echo -ne '\e[5 q'
#     }
#     zle -N zle-line-finish
# fi

# ─────────────────────────────────────────────────────────────
# ZINIT PLUGINS
# ─────────────────────────────────────────────────────────────
# Oh-my-zsh plugins
# _use_omz_components_locally plugin common-aliases
# _use_omz_components_locally plugin aliases
# _use_omz_components_locally plugin git
# _use_omz_components_locally plugin docker
#
# zinit light zsh-users/zsh-history-substring-search
# zinit light zdharma-continuum/history-search-multi-word
# zinit light zdharma-continuum/fast-syntax-highlighting

# --- Oh My Zsh Libs/Plugins ---
# Use 'snippet' for OMZ components. OMZP:: shorthand for ohmyzsh/ohmyzsh/plugins/
# OMZL:: shorthand for ohmyzsh/ohmyzsh/lib/
# Consider adding 'defer' if they aren't needed immediately at startup
# zinit snippet OMZL::theme-and-appearance.zsh defer'1' # If dircolors isn't enough
zinit snippet OMZP::common-aliases/common-aliases.plugin.zsh #defer'1'
zinit snippet OMZP::aliases/aliases.plugin.zsh #defer'1'
zinit snippet OMZP::git/git.plugin.zsh #defer'1'
# zinit snippet OMZP::docker/docker.plugin.zsh #defer'1'

# Resetting aliases for cp, mv, and rm
unalias cp
unalias mv
unalias rm
unalias gk

# --- Core Functionality Plugins ---
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-history-substring-search # Let this load relatively early
zinit light zsh-users/zsh-completions
zinit light zdharma-continuum/history-search-multi-word
zinit light jeffreytse/zsh-vi-mode # Loads the plugin, will use hooks defined above

# --- FZF Integration ---
# Let Zinit handle sourcing fzf's keybindings and completions.
# Use 'load' to apply 'ice' commands if needed, or 'light' if defaults work.
zinit light junegunn/fzf

# zinit load junegunn/fzf \
#     id-as"fzf" \
#     as"program" \
#     atclone"./install --bin; exec zsh" \
#     atpull"%atclone" \
#     pick"$ZINIT_HOME/plugins/junegunn---fzf/bin/fzf" \
#     src"shell/key-bindings.zsh" \
#     src"shell/completion.zsh"

# --- Syntax Highlighting ---
# Load fast-syntax-highlighting late. `defer'3'` is typically safe.
zinit light zdharma-continuum/fast-syntax-highlighting #defer'3'

# ─────────────────────────────────────────────────────────────
# OH-MY-POSH CONFIGURATION
# ─────────────────────────────────────────────────────────────
if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]] && (( $+commands[oh-my-posh]));then
    if [[ -f "$XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml" ]]; then
        eval "$(oh-my-posh init zsh --config $XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml)"
    else
        eval "$(oh-my-posh init zsh)"
    fi
fi

# ─────────────────────────────────────────────────────────────
# PLUGIN CONFIGURATION
# ─────────────────────────────────────────────────────────────
# ZSH-Autosuggestions configuration
# zstyle ':autosuggest:*' min-length 2
# ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
# ZSH_AUTOSUGGEST_STRATEGY=(history completion)
#
# # Source zsh-autosuggestions if available
# AUTOSUGGESTIONS_PATH=$(_find_plugin "zsh-autosuggestions" "zsh-autosuggestions.zsh")
# if [[ -n "$AUTOSUGGESTIONS_PATH" ]]; then
#     source "$AUTOSUGGESTIONS_PATH"
# fi
#
# # Fast-syntax-highlighting (load last to properly highlight everything)
# # First try different potential locations
# FSH_PATH=$(_find_plugin "fast-syntax-highlighting" "fast-syntax-highlighting.plugin.zsh")
# if [[ -n "$FSH_PATH" ]]; then
#     source "$FSH_PATH"
# fi


# --- ZSH-Autosuggestions ---
zstyle ':autosuggest:*' min-length 2
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
# Bind keys if defaults conflict or you prefer others
# bindkey '^ ' autosuggest-accept # Example: Ctrl+Space to accept suggestion

# --- FZF Configuration ---
# Keep your FZF_DEFAULT_OPTS export here
# Ensure fzf command is available before getting version
if (( $+commands[fzf] )); then
  fzf_version=$(fzf --version | awk '{print $1}')
  fzf_req_version="0.57.0" # Your required version for the theme
  if [ "$(printf '%s\n' "$fzf_req_version" "$fzf_version" | sort -V | head -n1)" = "$fzf_req_version" ]; then
    export FZF_DEFAULT_OPTS=" \
      --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
      --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
      --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
      --color=selected-bg:#45475a \
      --multi \
      --height=80% \
      --layout=reverse \
      --border=rounded \
      --preview-window='right:60%:border-sharp' \
      --bind='ctrl-/:toggle-preview' \
      --bind='?:toggle-preview' "
      # Add preview settings here if desired globally
      # --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
  fi
fi

# <<< CHANGE >>> Removed manual FZF sourcing block

# --- History Substring Search ---
# Configuration for zsh-history-substring-search (place after Zinit load & compinit)
# The zle -N calls and bindkey commands are usually best placed after compinit.
# Moved to Completion section below.

# --- zsh-vi-mode ---
# Specific zsh-vi-mode settings could go here if needed, beyond the hooks.
export KEYTIMEOUT=1 # Make ESC transition faster (useful for Vi mode)

# <<< CHANGE >>> Removed manual autosuggestions source block

# <<< CHANGE >>> Removed manual fast-syntax-highlighting source block

# ─────────────────────────────────────────────────────────────
# LUAROCKS CONFIGURATION
# ─────────────────────────────────────────────────────────────
if type luarocks >/dev/null 2>&1; then
  # Get LuaRocks path output
  LUAROCKS_ENV=$(luarocks path --bin)

  # Extract LUA_PATH and LUA_CPATH, but not PATH
  LUA_PATH_LINE=$(echo "$LUAROCKS_ENV" | grep "LUA_PATH")
  LUA_CPATH_LINE=$(echo "$LUAROCKS_ENV" | grep "LUA_CPATH")

  # Set up environment without affecting PATH
  eval "$LUA_PATH_LINE"
  eval "$LUA_CPATH_LINE"

  # Add LuaRocks bin to PATH only if its not already there
  [[ ":$PATH:" != *":$HOME/.luarocks/bin:"* ]] && export PATH="$HOME/.luarocks/bin:$PATH"
fi

# ─────────────────────────────────────────────────────────────
# OLLAMA CONFIGURATION
# ─────────────────────────────────────────────────────────────
export OLLAMA_API_BASE=http://localhost:11434

# ─────────────────────────────────────────────────────────────
# PYTHON CONFIGURATION
# ─────────────────────────────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# ─────────────────────────────────────────────────────────────
# GO CONFIGURATION
# ─────────────────────────────────────────────────────────────
export GOPATH=$XDG_DATA_HOME/go
_prefix_to_env "$XDG_DATA_HOME/go/bin" ":" "PATH"

# ─────────────────────────────────────────────────────────────
# PERL CONFIGURATION
# ─────────────────────────────────────────────────────────────
eval "$(perl -I$XDG_DATA_HOME/perl5/lib/perl5 -Mlocal::lib=$XDG_DATA_HOME/perl5)"

# ─────────────────────────────────────────────────────────────
# FZF HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────
# if (( $+commands[fzf] )); then
#     # Try different potential sources for fzf completion
#     if [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
#         source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
#         source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
#     elif [[ -f "/usr/share/doc/fzf/examples/completion.zsh" ]]; then
#         source "/usr/share/doc/fzf/examples/completion.zsh"
#         source "/usr/share/doc/fzf/examples/key-bindings.zsh"
#     elif [[ -f "$ZDOTDIR/plugins/fzf/completion.zsh" ]]; then
#         source "$ZDOTDIR/plugins/fzf/completion.zsh"
#         source "$ZDOTDIR/plugins/fzf/key-bindings.zsh"
#     else
#         # Try using the built-in completion generator if available
#         source <(fzf --zsh 2>/dev/null) || true
#     fi
#
#     # FZF theming with catppuccin-mocha
#     fzf_version=$(fzf --version | awk '{print $1}')
#     fzf_req_version="0.57.0"
#     if [ "$(printf '%s\n' "$fzf_req_version" "$fzf_version" | sort -V | head -n1)" = "$fzf_req_version" ]; then 
#         export FZF_DEFAULT_OPTS=" \
#         --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
#         --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
#         --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
#         --color=selected-bg:#45475a \
#         --multi"
#     fi
# fi

# fzf_live_grep() {
#   rg --files | fzf --preview="bat --color=always {}" | \
#     xargs -I{} rg --color=always --line-number --no-heading --smart-case "" {} | \
#     fzf --ansi \
#         --preview="echo {} | cut -d':' -f1 | xargs bat --color=always --line-range $(echo {} | cut -d':' -f2):"
# }
#
# fzf_content_search() {
#   local query="$1"
#   rg --color=always --line-number --no-heading --smart-case "$query" | \
#     fzf --ansi \
#         --query="$query" \
#         --preview="echo {} | cut -d':' -f1 | xargs bat --color=always --line-range $(echo {} | cut -d':' -f2):" \
#         --preview-window=right:60%
# }
#
# live_search() {
#   sk --ansi -i -c 'rg --color=always --line-number "{}"' \
#      --preview 'file=$(echo {1} | cut -d":" -f1); line=$(echo {1} | cut -d":" -f2); bat --color=always --line-range "$line": "$file"'
# }

# ─────────────────────────────────────────────────────────────
# BAT CONFIGURATION
# ─────────────────────────────────────────────────────────────
# Detect and set up bat/batcat
# if (( $+commands[bat] )); then
#     export BAT_CMD="bat"
#   elif (( $+commands[batcat] )); then
#     export BAT_CMD="batcat"
#     # Optional: create bat alias if you want to always use 'bat' command
#     alias bat="batcat"
# fi
#
# # Setup bat theme
# if (( $+commands[fast-theme] )); then
#     if [[ -d "$XDG_DATA_HOME/zsh-fast-syntax-highlighting/themes" ]]; then
#         fast-theme XDG:catppuccin-mocha > /dev/null 2>&1
#     fi
# fi
#
# # Setup batman (only if it exists and supports --export-env)
# if (( $+commands[batman] )); then
#     # Check if batman supports --export-env by testing with --help
#     if batman --help 2>&1 | grep -q -- "--export-env"; then
#         eval "$(batman --export-env)"
#     else
#         # In case it doesn't support the flag, create a simple alias
#         alias batman="man"
#     fi
# fi
#
# # Bat configuration
# if [[ -n "$BAT_CMD" ]]; then
#     alias cat="$BAT_CMD --style=numbers --color=always"
#     alias bathelp="$BAT_CMD --plain --language=help"
#
#   # Define 'less' to use bat if available, otherwise system less
#    export LESS='-R' # Enable raw control chars for color in less
#    export PAGER="$BAT_CMD" # Use bat as the default pager
#
#     function help() {
#         "$@" --help 2>&1 | $BAT_CMD --plain --language=help
#     }
#
#     # Update FZF with bat preview
#     # if (( $+commands[fzf] )); then
#     #     alias fzf="fzf --preview '$BAT_CMD --style=numbers --color=always {}' --preview-window '~3'"
#     # fi
#     # Update FZF preview to use bat (can be set in FZF_DEFAULT_OPTS too)
#     # export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"' # Example: Use rg
#     # export FZF_CTRL_T_OPTS="--preview '$BAT_CMD --color=always --style=numbers --line-range=:500 {}'"
#     # export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
# fi

# ─────────────────────────────────────────────────────────────
# SSH CONFIGURATION
# ─────────────────────────────────────────────────────────────
# Setup ssh-agent
if [[ "$OS_TYPE" != "macos" ]]; then
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
else
  # Start SSH agent and load keys from keychain
  eval "$(ssh-agent -s)" > /dev/null 
  ssh-add --apple-load-keychain 2>/dev/null
fi

# ─────────────────────────────────────────────────────────────
# ALIASES
# ─────────────────────────────────────────────────────────────
# Platform-specific aliases
if [[ "$OS_TYPE" == "macos" ]]; then
    # Config aliases
    alias zshconfig="nvim $ZDOTDIR/zshrc"
    alias zshsource="source $ZDOTDIR/zshrc"
    alias nvimconfig="nvim $XDG_CONFIG_HOME/nvim/lua/config/*.lua $XDG_CONFIG_HOME/nvim/lua/plugins/*.lua"

    # QMK aliases
    alias qmk_dztech="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_dztech"
    alias qmk_keychron="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_keychron"
    alias qmk_neo="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_neo"
    alias qmk_og="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_firmware"
    alias qmk_ydkb="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_ydkb"

    # Nvim testing aliases
    alias nvim-telescope='NVIM_APPNAME=nvim-telescope nvim'
    alias nvim-fzf='NVIM_APPNAME=nvim-fzf nvim'

    # Tool aliases
    alias lazygit='lazygit --use-config-file="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/catppuccin/themes-mergable/mocha/blue.yml"'
    alias disable_gatekeeper="sudo spctl --master-disable"

    # nproc 
    alias nproc="sysctl -n hw.physicalcpu"

    # luarocks
    alias luarocks-5.4='luarocks --tree=/Users/chris/.local/share/luarocks'
    alias luarocks-5.1='luarocks --lua-version=5.1 --tree=/Users/chris/.local/share/luarocks-5.1'
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
if (( $+commands[taskwarrior-tui] )); then alias tt="taskwarrior-tui"; fi
if (( $+commands[nvim] )); then alias vim="nvim"; fi # Prefer nvim if available
alias claude="$HOME/.local/bin/claude"
# alias claude-start='ANTHROPIC_API_KEY= specstory run claude -c "$HOME/.claude/local/claude --dangerously-skip-permissions"'

alias claude-start="CLAUDE_NATIVE_CD=1 ANTHROPIC_API_KEY= $HOME/.local/bin/claude --dangerously-skip-permissions"
alias codex-start="codex --dangerously-bypass-approvals-and-sandbox"

# Tmux aliases
alias tmux_main="tmux new-session -ADs main"

# File operation aliases (zmv provided by zsh)
# alias zcp='zmv -C'
# alias zln='zmv -L'
alias zcp='noglob zmv -C' # Use noglob to prevent globbing before zmv runs
alias zln='noglob zmv -L'

# ─────────────────────────────────────────────────────────────
# Completion System Setup
# ─────────────────────────────────────────────────────────────
#
# Helper function to determine Zsh's main function directory
_get_zsh_main_functions_dir() {
    # Try Homebrew Zsh first if on macOS
    if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
        local brew_zsh_func_dir="$HOMEBREW_PREFIX/share/zsh/functions"
        if [[ -d "$brew_zsh_func_dir" ]]; then
            echo "$brew_zsh_func_dir"
            return 0
        fi
        # Fallback for older Homebrew Zsh versions with versioned dirs
        local brew_zsh_ver_func_dir="$HOMEBREW_PREFIX/share/zsh/$ZSH_VERSION/functions"
         if [[ -d "$brew_zsh_ver_func_dir" ]]; then
            echo "$brew_zsh_ver_func_dir"
            return 0
        fi
    fi

    # Try common system locations
    local sys_paths=(
        "/usr/local/share/zsh/functions"
        "/usr/local/share/zsh/$ZSH_VERSION/functions"
        "/usr/share/zsh/functions"
        "/usr/share/zsh/$ZSH_VERSION/functions"
    )
    for path_to_check in "${sys_paths[@]}"; do
        if [[ -d "$path_to_check" ]]; then
            echo "$path_to_check"
            return 0
        fi
    done

    echo "Error: Could not determine Zsh's main function directory." >&2
    return 1
}

local zsh_main_funcs_dir
zsh_main_funcs_dir=$(_get_zsh_main_functions_dir)


fpath=() # Start with an empty fpath to control it precisely

# PRIORITY 1: Zsh's own main function directory
if [[ -n "$zsh_main_funcs_dir" && -d "$zsh_main_funcs_dir" ]]; then
    fpath+=("$zsh_main_funcs_dir")
    # Some Zsh installations place Completion functions in a subdirectory
    if [[ -d "$zsh_main_funcs_dir/Completion" ]]; then
        fpath+=("$zsh_main_funcs_dir/Completion")
    fi
else
    echo "Warning: Zsh main function directory not found or not added to fpath. Completions may fail." >&2
fi

# Add ZDOTDIR specific paths (your custom functions/completions)
_set_fpath_from_candidates \
  "$ZDOTDIR/functions" \
  "$ZDOTDIR/completions"

# Add ZSH_CONFIG_DIR if it's different from ZDOTDIR and used for more functions/completions
if [[ -n "$ZSH_CONFIG_DIR" && "$ZSH_CONFIG_DIR" != "$ZDOTDIR" ]]; then
    _set_fpath_from_candidates \
        "$ZSH_CONFIG_DIR/functions" \
        "$ZSH_CONFIG_DIR/completions"
fi

# Add Homebrew site-functions (if not already covered by zsh_main_funcs_dir)
if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" && "$HOMEBREW_PREFIX/share/zsh/functions" != "$zsh_main_funcs_dir" ]]; then
  _set_fpath_from_candidates "$HOMEBREW_PREFIX/share/zsh/site-functions"
fi

# Add standard system site-functions (if not already covered)
_set_fpath_from_candidates \
  "/usr/local/share/zsh/site-functions" \
  "/usr/share/zsh/site-functions"

# Zinit loaded plugins might also add to fpath if they have completions.

# Ensure essential Zsh autoloaded functions are available
# Explicitly autoload compinit, compaudit, and compdef.
# promptinit is generally for prompt themes, but good to have.
autoload -Uz compinit promptinit compaudit compdef

# Completion system setup
local compdump_dir="${ZSH_COMPLETION_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}"
mkdir -p "$compdump_dir" # Ensure cache directory exists
ZSH_COMPDUMP="${compdump_dir}/.zcompdump-${HOST}-${ZSH_VERSION}"

# For debugging fpath issues:
# echo "Final fpath before compinit:" >&2
# for _fp_entry in $fpath; do echo "  $_fp_entry" >&2; done

# Initialize completion system
compinit -i -C -d "$ZSH_COMPDUMP"

# For debugging: Check if compaudit is available AFTER the first compinit
# if type compaudit >/dev/null 2>&1; then
#     echo "DEBUG: compaudit IS available after first compinit." >&2
# else
#     echo "DEBUG: compaudit IS NOT available after first compinit. Critical error." >&2
# fi

# Recompile if compaudit finds issues or dump file is invalid/missing
# <<< MODIFIED LINE BELOW >>> Use 'compaudit' directly
if [[ ! -s "$ZSH_COMPDUMP" ]] || compaudit | grep -q '.'; then
  echo "Compdump invalid or compaudit found issues. Recompiling..." >&2
  compinit -i -u -d "$ZSH_COMPDUMP"
fi

# Completion cache configuration
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$compdump_dir"

# Completion Styling & Options (your existing settings)
zstyle ':completion:*' menu select
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-suffixes true
zstyle ':completion:*' auto-description 'specify: %d'
if (( $+commands[dircolors] )) && [[ -n "$LS_COLORS" ]]; then
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

# Lazy loading of specific completion functions (your existing settings)
for cmd in fastfetch opam pipx pnpm rage sqlfluff; do
  for dir in "$HOMEBREW_PREFIX/share/zsh/site-functions" /usr/local/share/zsh/site-functions /usr/share/zsh/site-functions; do
    local compfile="$dir/_$cmd"
    if [[ -f "$compfile" ]]; then
      _lazy_complete "$cmd" "$compfile"
      break
    fi
  done
done

# History Substring Search ZLE Setup (your existing settings, ensure it's after compinit)
autoload -Uz history-substring-search-up history-substring-search-down up-line-or-beginning-search down-line-or-beginning-search
zle -N history-substring-search-up
zle -N history-substring-search-down
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
# Keybindings are likely handled in your zsh-vi-mode zvm_after_init hook
# Bind keys within your zsh-vi-mode's zvm_after_init function for consistency,
# or uncomment specific global bindings if needed:
# bindkey "${terminfo[kcuu1]}" history-substring-search-up # Up Arrow
# bindkey "${terminfo[kcud1]}" history-substring-search-down # Down Arrow
# bindkey '^[[A' up-line-or-beginning-search
# bindkey '^[[B' down-line-or-beginning-search
# ─────────────────────────────────────────────────────────────
# FINAL SETUP
# ─────────────────────────────────────────────────────────────
# Load the plugins
# for file in "${OMZ_PLUGIN_FILES[@]}"; do
#   source "$file"
# done

# Load custom local configuration if it exists
# [[ -f $ZDOTDIR/zshrc.local ]] && source $ZDOTDIR/zshrc.local
_source_if_exists "$ZDOTDIR/zshrc.local"

# For profiling, uncomment:
# zprof

# bun completions
[ -s "/Users/chris/.bun/_bun" ] && source "/Users/chris/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Task Master aliases added on 8/15/2025
alias tm='task-master'
alias taskmaster='task-master'

# ─────────────────────────────────────────────────────────────
# ZOXIDE CONFIGURATION 
# ─────────────────────────────────────────────────────────────
# Safely implement zoxide functionality with backwards compatibility
if (( $+commands[zoxide] )); then
    if [[ -n "${CLAUDE_NATIVE_CD:-}" ]]; then
        # Claude session: keep native cd while still enabling zoxide via `z`
        eval "$(zoxide init zsh --hook pwd --cmd z)"

        alias zi="z -i"       # interactive mode
        alias zz="z -"        # previous directory
        alias zb="z .."       # parent directory
        alias zc="z -c"       # children only
        alias zh="z ~"        # home directory

        alias zdev="z ~/dev"
        alias zdl="z ~/Downloads"
        alias zdocs="z ~/Documents"
    else
        # Default shell behavior: zoxide overrides cd
        eval "$(zoxide init zsh --hook pwd --cmd cd)"

        alias zi="cd -i"       # interactive mode
        alias zz="cd -"        # previous directory
        alias zb="cd .."       # parent directory
        alias zc="cd -c"       # children only
        alias zh="cd ~"        # home directory

        alias zdev="cd ~/dev"
        alias zdl="cd ~/Downloads"
        alias zdocs="cd ~/Documents"
    fi
fi


fpath+=~/.zfunc; autoload -Uz compinit; compinit
export PATH="$HOME/.local/bin:$PATH"

# Task Master aliases added on 12/6/2025
alias hamster='task-master'
alias ham='task-master'


# ─────────────────────────────────────────────────────────────
# AI SETTINGS
# ─────────────────────────────────────────────────────────────

# Opencode
export OPENCODE_EXPERIMENTAL='true'

# Claude Code deferred MCP loading (added by Taskmaster)
export ENABLE_EXPERIMENTAL_MCP_CLI='true'
# gh wrapper to strip ANSI escape codes from PR titles/bodies/release notes
alias gh='~/.local/bin/gh-clean'

# Abacus AI 
alias abacus="abacusai-app"
