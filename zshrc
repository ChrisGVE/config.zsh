zmodload zsh/zprof

export ZSH=$XDG_CONFIG_HOME/oh-my-zsh

if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  eval "$(oh-my-posh init zsh --config $XDG_CONFIG_HOME/oh-my-posh/config.yml)"
fi

# ZSH History settings
# setopt BANG_HIST                 # Treat the '!' character specially during expansion.
# setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
# setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
# setopt SHARE_HISTORY             # Share history between all sessions.
# setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
# setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
# setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
# setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
# setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
# setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
# setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
# setopt HIST_VERIFY               # Don't execute immediately upon history expansion.
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

# ZSH_CUSTOM_AUTOUPDATE_QUIET=true

# Colorize the
ZSH_COLORIZE_TOOL=chroma
ZSH_COLORIZE_STYLE="catppuccin-mocha"
ZSH_COLORIZE_CHROMA_FORMATTER=terminal16m

# ZSH-VI-MODE
 ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
 ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
 ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
 ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLOCK
 ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
 ZVM_VI_HIGHLIGHT_BACKGROUND=#45475a

 plugins=(git aliases common-aliases zsh-vi-mode zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)

source $ZSH/oh-my-zsh.sh

# Use vim keys in tab complete menu
# bindkey -M menuselect 'h' vi-backward-char
# bindkey -M menuselect 'k' vi-up-line-or-history
# bindkey -M menuselect 'l' vi-forward-char
# bindkey -M menuselect 'j' vi-down-line-or-history
# bindkey -v '^?' backward-delete-char

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

[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

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
export LDFLAGS="-L/usr/local/opt/mysql@8.4/lib"
export CPPFLAGS="-I/usr/local/opt/mysql@8.4/include"
export PKG_CONFIG_PATH="/usr/local/opt/mysql@8.4/lib/pkgconfig"

# Setup opam
# [[ -f ~/.opam/opam-init/init.zsh ]] && source ~/.opam/opam-init/init.zsh

# Setup broot
# source /Users/chris/Library/Application\ Support/org.dystroy.broot/launcher/bash/br

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
export _ZO_ECHO=1
# export _ZO_FZF_OPTS=
export _ZO_RESOLVE_SYMLINKS=0
eval "$(zoxide init zsh --cmd cd)"

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


# source $(nix eval --raw nixpkgs#zsh-autosuggestions)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# source $(nix eval --raw nixpkgs#zsh-vi-mode)/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
# Aliases
# source $ZSH_CUSTOM/plugins/common-aliases/common-aliases.plugin.zsh
# source $ZSH_CUSTOM/plugins/aliases/aliases.plugin.zsh
#
# Completions
# fpath=(/run/current-system/sw/share/zsh/site-functions $fpath)
#
# autoload -Uz compinit 
#
# for dump in $ZSH_CUSTOM/.zcompdump(N.mh+24); do
#   compinit
# done
#
# compinit -C

# Finally sources the syntax highlighting plugins
# MUST ALWAYS BE LAST

# source ~/.config/themes/zsh-syntax-highlighting/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh
# get the source path of zsh-syntax-highlighting that is now sourced from nix-store.
# source $(nix eval --raw nixpkgs#zsh-syntax-highlighting.outPath)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# source /run/current-system/sw/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh
fast-theme -w XDG:catppuccin-mocha
