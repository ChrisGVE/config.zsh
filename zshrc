# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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
setopt HIST_BEEP                 # Beep when accessing nonexistent history.

## Setup for bat
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Path to your oh-my-zsh installation.
export ZSH="$XDG_CONFIG_HOME/oh-my-zsh"
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="agnoster"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=7

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(1password aliases autoupdate brew common-aliases conda conda-env dash docker docker-compose \
         fzf gh git gitfast gnu-utils kitty macos mosh rust terraform tmux zsh-autosuggestions \
         zsh-completions zsh-vi-mode \
         ) # zsh-vim-mode)
autoload -U compinit && compinit

ZSH_CUSTOM_AUTOUPDATE_QUIET=true

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

source $ZSH/oh-my-zsh.sh

# Use vim keys in tab complete menu
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

# User configuration

# FZF theming with catppuccin-mocha
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for remote sessions
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
alias zshconfig="nvim $ZDOTDIR/zshrc"

# add custom bin path and .local/bin
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Add gnubin path to use `sed`
export PATH="/use/local/opt/gnu-sed/libexec/gnubin:$PATH"

# Add Homebrew sbin path
export PATH="/usr/local/sbin:$PATH"

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

autoload -U zmv
alias zcp='zmv -C'
alias zln='zmv -L'

alias luamake=/Users/chris/tools/lua-language-server/3rd/luamake/luamake

export PATH="/usr/local/opt/openjdk/bin:$PATH"
export PATH="/usr/local/opt/dart@2.18/bin:$PATH"
export PATH="/usr/local/opt/sphinx-doc/bin:$PATH"

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
[[ -f ~/.opam/opam-init/init.zsh ]] && source ~/.opam/opam-init/init.zsh

# Setup broot
source /Users/chris/Library/Application\ Support/org.dystroy.broot/launcher/bash/br

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

# Setup qmk
alias cdqmk="cd ~/dev/Keyboard/qmk/"

source ~/.config/themes/zsh-syntax-highlighting/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
