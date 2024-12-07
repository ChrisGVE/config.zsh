#!/usr/bin/zsh
#
zmodload zsh/zprof

# Configure zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
# Download, install, and start Zinit
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit ice atinit'zmodload zsh/zprof' \
    atload'zprof | head -n 20; zmodload -u zsh/zprof'

if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  eval "$(oh-my-posh init zsh --config $XDG_CONFIG_HOME/oh-my-posh/config.yml)"
fi


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

## Setup for man
export MANPAGER="nvim +Man!"
# export MANPAGER="sh -c 'col -bx | bat -l man -p'"
# export MANROFFOPT="-c"

# Uncomment the following line to use case-sensitive completion.
CASE_SENSITIVE="false"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

export ZSH_CUSTOM=$XDG_CONFIG_HOME/zsh

# ZSH-VI-MODE
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
ZVM_VI_HIGHLIGHT_BACKGROUND=#45475a

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
#
zi wait lucid for \
  blockf \
  light-mode \
        OMZL::clipboard.zsh \
        OMZL::directories.zsh \
        OMZL::functions.zsh \
        OMZL::git.zsh \
        OMZL::history.zsh \
        OMZL::termsupport.zsh \
        OMZL::spectrum.zsh \
        OMZL::grep.zsh \
        OMZL::theme-and-appearance.zsh \
        OMZP::alias-finder \
        OMZP::aliases \
        OMZP::colorize \
        OMZP::common-aliases \
        OMZP::conda \
        OMZP::dash \
        OMZP::direnv \
        OMZP::dotenv \
        OMZP::fzf \
        OMZP::git \
        OMZP::github \
        OMZP::history \
        OMZP::kitty \
        OMZP::mosh \
        OMZP::pip \
        OMZP::rust \
        OMZP::sudo \
        OMZP::systemd \
        OMZP::terraform \
        jeffreytse/zsh-vi-mode \
        zsh-users/zsh-autosuggestions \
        zdharma-continuum/history-search-multi-word

zi ice as"completion" \
        /usr/local/opt/curl/share/zsh/site-functions/_curl \
        /usr/local/share/zsh/site-functions/*

zi for \
  atload="zicompinit; zicdreplay" \
  blockf \
  wait lucid \
        zsh-users/zsh-completions \
        zdharma-continuum/fast-syntax-highlighting

# Enable alias-finder
zstyle ':omz:plugins:alias-finder' autoload yes # disabled by default
zstyle ':omz:plugins:alias-finder' longer yes # disabled by default
zstyle ':omz:plugins:alias-finder' exact yes # disabled by default
zstyle ':omz:plugins:alias-finder' cheaper yes # disabled by default

# Setting up auto-completions
zstyle ':completion:*' menu select
zmodload zsh/complist

# Use vim keys in tab complete menu
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char
bindkey '^n' expand-or-complete
bindkey '^p' reverse-menu-complete

# Setting up colorize
export ZSH_COLORIZE_TOOL=chroma
export ZSH_COLORIZE_STYLE="colorful"
export ZSH_COLORIZE_CHROMA_FORMATTER="terminal16m"

# Setting up Perl
# PERL_MM_OPT="INSTALL_BASE=$XDG_CACHE_HOME/perl5" cpan local::lib
eval "$(perl -I$XDG_CACHE_HOME/perl5/lib/perl5 -Mlocal::lib=$XDG_CACHE_HOME/perl5)"

# Setting curl path
export PATH="/usr/local/opt/curl/bin:$PATH"

# Setting path for ruby
export PATH="/usr/local/opt/ruby/bin:$PATH"

# Setting up zip path
export PATH="/usr/local/opt/zip/bin:$PATH"

# Setting up path for avr-gcc@8
export PATH="/usr/local/opt/avr-gcc@8/bin:$PATH"

# Setting up path for arm-none-eabi-gcc@8 and binutils
export PATH="/usr/local/opt/arm-none-eabi-gcc@8/bin:/usr/local/opt/arm-none-eabi-binutils/bin:$PATH"

# Setup fzf integration
source <(fzf --zsh)

# toolchain for go
export GOTOOLCHAIN=local

# User configuration

# FZF theming with catppuccin-mocha
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"

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

# alias to easily switch between qmk firmware sources.
alias qmk_og="qmk config set user.qmk_home=$HOME/dev/Keyboard/qmk/qmk_firmware"
alias qmk_keychron="qmk config set user.qmk_home=$HOME/dev/Keyboard/qmk/qmk_keychron"

# add alias to configure nvim
alias nvimconfig="nvim $XDG_CONFIG_HOME/nvim/lua/config/*.lua $XDG_CONFIG_HOME/nvim/lua/plugins/*.lua"

# add custom bin path and .local/bin
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Add gnubin path to use `sed`
export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"

# Add Homebrew sbin path
export PATH="/usr/local/sbin:$PATH"

# Kitty useful aliases
alias icat="kitten icat"

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

autoload -U zmv
alias zcp='zmv -C'
alias zln='zmv -L'

alias luamake=/Users/chris/tools/lua-language-server/3rd/luamake/luamake

export PATH="/usr/local/opt/openjdk/bin:$PATH"
export PATH="/usr/local/opt/dart@2.18/bin:$PATH"
export PATH="/usr/local/opt/sphinx-doc/bin:$PATH"

# Adding path to user bin
export PATH="$HOME/bin:$HOME/Scripts:$PATH"

# speed up midnight commander 
alias mc="mc --nosubshell"

# Setup lazygit config with Catppuccin
alias lazygit='lazygit --use-config-file="/Users/chris/.config/lazygit/config.yml,/Users/chris/.config/lazygit/catppuccin/mocha/blue.yml"'

# Enable/Disable Gatekeeper 
# alias enable_gatekeeper="sudo spctl --master-enable"  ## Deprecated
alias disable_gatekeeper="sudo spctl --master-disable"

# Setup for MySQL
#
export PATH="/usr/local/opt/mysql@8.4/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/opt/mysql@8.4/lib/pkgconfig"
# Setup for compiler
export LDFLAGS="-L/usr/local/opt/arm-none-eabi-gcc@8/lib -L/usr/local/opt/avr-gcc@8/lib -L/usr/local/opt/mysql@8.4/lib -L/usr/local/opt/curl/lib -L/usr/local/opt/ruby/lib"
export CPPFLAGS="-I/usr/local/opt/mysql@8.4/include -I/usr/local/opt/curl/include -I/usr/local/opt/ruby/include"

# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/Users/chris/.opam/opam-init/init.zsh' ]] || source '/Users/chris/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration

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

# fzf alias to show preview 
alias fzf="fzf --preview 'bat --style=numbers --color=always {}'" # --preview-window '~3'"

# setup zoxide
export _ZO_DATA_DIR="$XDG_DATA_HOME"
export _ZO_ECHO=0
export _ZO_EXCLUDE_DIRS=$XDG_DATA_HOME:$XDG_CACHE_HOME:$XDG_STATE_HOME:$XDG_DATA_DIRS:$XDG_CONFIG_DIRS
# export _ZO_FZF_OPTS=
export _ZO_RESOLVE_SYMLINKS=0
eval "$(zoxide init zsh --cmd cd)"

# Setup broot
source /Users/chris/.config/broot/launcher/bash/br

# V3
# ###############################################
# # SMART CD THAT RELIES ON ZOXIDE TO MOVE AROUND
#
# function zoxide_interactive_with_preview() {
#     # Run zoxide interactive and pass the selected folder to fzf for choosing files
#     local dir=$(zoxide query --interactive -- "$@")  # Select folder using zoxide
#     [[ -z "$dir" ]] && return  # Exit if no selection
#
#     # Open a second fzf to select files/folders from the chosen directory
#     local file=$(ls -A "$dir" | fzf --height=40% --border --preview "file {}" --preview-window=up:3)
#     [[ -z "$file" ]] && builtin cd "$dir" && return  # If no file selected, cd to the folder
#
#     builtin cd "$dir" && echo "$dir/$file"           # Echo the full path to the chosen file/folder
# }
#
# function zoxide_cd_tab() {
#     BUFFER="cd $(zoxide_interactive_with_preview)"
#     zle accept-line
# }
#
# zle -N zoxide_cd_tab
# bindkey "^I" zoxide_cd_tab
# ###############################################

# V2
###############################################
# SMART CD THAT RELIES ON ZOXIDE TO MOVE AROUND

# # Function to trigger zoxide interactive
# function zoxide_interactive_tab() {
#     if [[ "$BUFFER" == "cd" ]]; then
#         BUFFER="cd $(zoxide query --interactive)"
#     else
#         local incomplete_path="${BUFFER#cd }"
#         BUFFER="cd $(zoxide query --interactive -- $incomplete_path)"
#     fi
#
#     zle accept-line
# }
#
# # Function to check context and conditionally trigger zoxide or completion
# function custom_cd_tab_binding() {
#     if [[ "$BUFFER" == "cd"* ]]; then
#         zoxide_interactive_tab
#     else
#         zle complete-word
#     fi
# }
#
# # Bind Tab (^I) to our custom handler
# zle -N custom_cd_tab_binding
# bindkey "^I" custom_cd_tab_binding

###############################################

# V1
# ###############################################
# # SMART CD THAT RELIES ON ZOXIDE TO MOVE AROUND
#
# # Function to trigger zoxide interactive
# function zoxide_interactive_tab() {
#     BUFFER="cd $(zoxide query --interactive)"  # Replace the buffer with the interactive query
#     zle accept-line                           # Execute the modified command
# }
#
# # Function to check context and conditionally trigger zoxide or completion
# function custom_cd_tab_binding() {
#     if [[ "$BUFFER" == "cd"* ]]; then         # If the current buffer starts with "cd"
#         zoxide_interactive_tab               # Trigger zoxide interactive
#     else
#         zle complete-word                   # Otherwise, perform regular completion
#     fi
# }
#
# # Bind Tab (^I) to our custom handler
# zle -N custom_cd_tab_binding
# bindkey "^I" custom_cd_tab_binding
# ###############################################

# The next line updates PATH for the Google Cloud SDK.
# if [ -f '/Users/chris/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/chris/google-cloud-sdk/path.zsh.inc'; fi


fast-theme XDG:catppuccin-mocha > /dev/null 2>&1

autoload -Uz compinit
compinit
zi cdreplay -q 
