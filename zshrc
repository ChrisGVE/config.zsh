#!/usr/bin/zsh

# zmodload zsh/zprof

####################
# LOAD ENVIRONMENT
####################
source ~/.zshenv

export HOMEBREW_PREFIX="$(brew --prefix)"

####################
# HELPER FUNCTIONS
####################

# function to add new path segments only if they are not already there
function _add_path() {
  if [[ -n $* ]]; then
    [[ -d $* ]] && case ":${PATH}:" in *:$*:*)
      ;;
    *)
      export PATH="$*:$PATH"
      ;;
    esac
  fi 
}

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
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
# <<< conda initialize <<<

# Override exit to prevent exiting the last pane in tmux
exit() {
    if [[ -z $TMUX ]]; then
        builtin exit
        return
    fi

    panes=$(tmux list-panes | wc -l)
    wins=$(tmux list-windows | wc -l)
    count=$(($panes + $wins - 1))
    if [ $count -eq 1 ]; then
        tmux detach
    else
        builtin exit
    fi
}

###########################
# Oh-My-Zsh CONFIGURATION
###########################

# Uncomment the following line to use case-sensitive completion.
export CASE_SENSITIVE="false"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
export HYPHEN_INSENSITIVE="true"

# Uncomment the following line to display red dots whilst waiting for completion.
export COMPLETION_WAITING_DOTS="true"

export ZSH_CUSTOM=$XDG_CONFIG_HOME/zsh

# Oh-My-Zsh Config
#
# ZSH History settings
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

# # Enable alias-finder
# zstyle ':omz:plugins:alias-finder' autoload yes # disabled by default
# zstyle ':omz:plugins:alias-finder' longer yes # disabled by default
# zstyle ':omz:plugins:alias-finder' exact yes # disabled by default
# zstyle ':omz:plugins:alias-finder' cheaper yes # disabled by default

# Setting up auto-completions
# zstyle ':completion:*' menu select
# zmodload zsh/complist

# Use vim keys in tab complete menu
# bindkey -M menuselect 'h' vi-backward-char
# bindkey -M menuselect 'k' vi-up-line-or-history
# bindkey -M menuselect 'l' vi-forward-char
# bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char
bindkey '^n' expand-or-complete
bindkey '^p' reverse-menu-complete

# Setting up colorize
export ZSH_COLORIZE_TOOL=chroma
export ZSH_COLORIZE_STYLE="colorful"
export ZSH_COLORIZE_CHROMA_FORMATTER="terminal16m"

#
# zi wait lucid for \
#   blockf \
#   light-mode \
#         OMZL::clipboard.zsh \
#         OMZL::directories.zsh \
#         OMZL::functions.zsh \
#         OMZL::git.zsh \
#         OMZL::history.zsh \
#         OMZL::termsupport.zsh \
#         OMZL::spectrum.zsh \
#         OMZL::grep.zsh \
#         OMZL::theme-and-appearance.zsh \
#         OMZP::alias-finder \
#         OMZP::aliases \
#         OMZP::colorize \
#         OMZP::common-aliases \
#         OMZP::conda \
#         OMZP::dash \
#         OMZP::direnv \
#         OMZP::dotenv \
#         OMZP::fzf \
#         OMZP::git \
#         OMZP::github \
#         OMZP::history \
#         OMZP::kitty \
#         OMZP::mosh \
#         OMZP::pip \
#         OMZP::rust \
#         OMZP::sudo \
#         OMZP::systemd \
#         OMZP::terraform \
#         jeffreytse/zsh-vi-mode \
#         zsh-users/zsh-autosuggestions \
#         zdharma-continuum/history-search-multi-word

plugins=(git)

export ZSH="$ZDOTDIR/ohmyzsh"

source $ZSH/oh-my-zsh.sh

############################
# Other configs
############################

## Setup for man
if type batman >/dev/null 2>&1; then eval "$(batman --export-env)"; fi

# [[ -d /usr/local/opt/curl/share/zsh/site-functions ]] && zi ice as"completion" \
# 	/usr/local/opt/curl/share/zsh/site-functions/_curl
#
# [[ ! -z "$( ls -A /usr/local/share/zsh/site-functions )" ]] && zi ice as"completion" \
#         /usr/local/share/zsh/site-functions/*
#
# zi for \
#   atload="zicompinit; zicdreplay" \
#   blockf \
#   wait lucid \
#         zsh-users/zsh-completions \
#         zdharma-continuum/fast-syntax-highlighting
#
# Setting up Perl
# PERL_MM_OPT="INSTALL_BASE=$XDG_CACHE_HOME/perl5" cpan local::lib
# eval "$(perl -I$HOME/dev/tools/perl5/lib/perl5 -Mlocal::lib=$HOME/dev/tools/perl5)"


# Setting curl path
_add_path "/usr/local/opt/curl/bin"

# Setting path for ruby
_add_path "/usr/local/opt/ruby/bin"

# Setting up zip path
_add_path "/usr/local/opt/zip/bin"

# Setting up path for avr-gcc@8
_add_path "/usr/local/opt/avr-gcc@8/bin"

# Setting up path for arm-none-eabi-gcc@8 and binutils
_add_path "/usr/local/opt/arm-none-eabi-gcc@8/bin"
_add_path "/usr/local/opt/arm-none-eabi-binutils/bin"

# Setting up path for luarocks
if type luarocks >/dev/null 2>&1; then eval "$(luarocks path --bin)"; fi

# Setup fzf integration
if type fzf >/dev/null 2>&1; then source <(fzf --zsh); fi

fzf_version=$(fzf --version)
fzf_req_version="0.57.0"
if [ "$(printf '%s\n' "$fzf_req_version" "$fzf_version" | sort -V | head -n1)" = "$fzf_req_version" ]; then 
  # FZF theming with catppuccin-mocha
  export FZF_DEFAULT_OPTS=" \
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
    --color=selected-bg:#45475a \
    --multi";
fi
# Trigger sequence instead of default **
export FZF_COMPLETION_TRIGGER='**'
export FZF_COMPLETION_OPTS='--border --info=inline'
export FZF_COMPLETION_PATH_OPTS='--walker file,dir,follow,hidden'
export FZF_COMPLETION_DIR_OPTS='--walker dir,follow'

# Setup taskwarrior
export TASKRC=$XDG_CONFIG_HOME/task/taskrc
export TASKDATA=$XDG_DATA_HOME/tasks task list

# toolchain for go
export GOTOOLCHAIN=local

# User configuration

# Preferred editor for remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#     export EDITOR='vim'
# fi

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
alias zshconfig="nvim $ZDOTDIR/zshrc"
alias zshsource="source $ZDOTDIR/zshrc"

# alias to easily switch between qmk firmware sources.
alias qmk_og="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_firmware"
alias qmk_keychron="qmk config set user.qmk_home=$HOME/dev/keyboard/qmk/qmk_keychron"

# add alias to configure nvim
alias nvimconfig="nvim $XDG_CONFIG_HOME/nvim/lua/config/*.lua $XDG_CONFIG_HOME/nvim/lua/plugins/*.lua"

# aliases for nvim testing in various configurations
alias nvim-telescope='NVIM_APPNAME=nvim-telescope nvim'
alias nvim-fzf='NVIM_APPNAME=nvim-fzf nvim'

# add custom bin path and .local/bin
_add_path "$HOME/bin"

# Add gnubin path to use `sed`
_add_path "/usr/local/opt/gnu-sed/libexec/gnubin"

# Add Homebrew sbin path
_add_path "/usr/local/sbin"

# Allas for taskwarrior-tui
if type taskwarrior-tui > /dev/null 2>&1; then alias tt="taskwarrior-tui"; fi

alias tmux_main="tmux new-session -ADs main"

# autoload -U zmv
alias zcp='zmv -C'
alias zln='zmv -L'

alias luamake=/Users/chris/tools/lua-language-server/3rd/luamake/luamake

_add_path "/usr/local/opt/openjdk/bin"
_add_path "/usr/local/opt/dart@2.18/bin"
_add_path "/usr/local/opt/sphinx-doc/bin"

# Adding path to user bin
_add_path "$HOME/Scripts"

# speed up midnight commander 
alias mc="mc --nosubshell"

# Setup lazygit config with Catppuccin
alias lazygit='lazygit --use-config-file="/Users/chris/.config/lazygit/config.yml,/Users/chris/.config/lazygit/catppuccin/themes-mergable/mocha/blue.yml"'

# Enable/Disable Gatekeeper 
# alias enable_gatekeeper="sudo spctl --master-enable"  ## Deprecated
alias disable_gatekeeper="sudo spctl --master-disable"

# Setup for MySQL
#
_add_path "/usr/local/opt/mysql@8.4/bin"
export PKG_CONFIG_PATH="/usr/local/opt/mysql@8.4/lib/pkgconfig"
# Setup for compiler
export LDFLAGS="-L/usr/local/opt/arm-none-eabi-gcc@8/lib -L/usr/local/opt/avr-gcc@8/lib -L/usr/local/opt/mysql@8.4/lib -L/usr/local/opt/curl/lib -L/usr/local/opt/ruby/lib"
export CPPFLAGS="-I/usr/local/opt/mysql@8.4/include -I/usr/local/opt/curl/include -I/usr/local/opt/ruby/include"

# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
# [[ ! -r '/Users/chris/.opam/opam-init/init.zsh' ]] || source '/Users/chris/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration

###################
# BAT CONFIGURATION
###################
alias cat="bat --style=numbers --color=always"

TAIL_BIN=$(which tail)

function tail() {
  if [[ -n $1 && $1 == "-f" ]]; then
    $TAIL_BIN $* | bat --paging=never -l log 
  else
    $TAIL_BIN $*
  fi
}
# Highlighting help messages
alias bathelp="bat --plain --language=help"
function help() {
  "$@" --help 2>&1 | bathelp
}

# fzf alias to show preview 
if type bat >/dev/null 2>&1; then 
  alias fzf="fzf --preview 'bat --style=numbers --color=always {}' --preview-window '~3'"
fi

# setup zoxide
if type zoxide >/dev/null 2>&1; then eval "$(zoxide init zsh --cmd cd)"; fi

if type fast-theme > /dev/null 2>&1; then fast-theme XDG:catppuccin-mocha > /dev/null 2>&1; fi

# Setup the ssh-agent if it is not yet running
if [ $(ps ax | grep ssh-agent | wc -l) -gt 0 ] ; then
  echo "ssh-agent already running" > /dev/null
else
  eval $(ssh-agent -s)
  if [ "$(ssh-add -l)" == "The agent has no identities."]; then
    ssh-add ~/.ssh/id_rsa
  fi
fi

# autoload -Uz compinit
# compinit
# zi cdreplay -q 
#
############################
# Oh-My-Posh CONFIGURATION
############################

############################
# Plugins
############################

# zsh-autosuggestions
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh


# OMP zsh-vi-mode integration
_omp_redraw-prompt() {
  # local precmd
  for precmd in "${precmd_functions[@]}"; do
    "$precmd"
  done
  zle && zle reset-prompt
}

export POSH_VI_MODE="INSERT"

function zvm_after_select_vi_mode() {
  case $ZVM_MODE in
  $ZVM_MODE_NORMAL)
    POSH_VI_MODE="NORMAL"
    ;;
  $ZVM_MODE_INSERT)
    POSH_VI_MODE="INSERT"
    ;;
  $ZVM_MODE_VISUAL)
    POSH_VI_MODE="VISUAL"
    ;;
  $ZVM_MODE_VISUAL_LINE)
    POSH_VI_MODE="V-LINE"
    ;;
  $ZVM_MODE_REPLACE)
    POSH_VI_MODE="REPLACE"
    ;;
  esac
  _omp_redraw-prompt
}

if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  eval "$(oh-my-posh init zsh --config $XDG_CONFIG_HOME/zsh/oh-my-posh/config.yml)"
fi

# ZSH-VI-MODE
export ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
export ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
export ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
export ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLOCK
export ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
export ZVM_VI_HIGHLIGHT_BACKGROUND=#45475a

# Vi mode
source $HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# Syntax highlighting
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $HOMEBREW_PREFIX/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
# Auto completion
source $HOMEBREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
# zprof
