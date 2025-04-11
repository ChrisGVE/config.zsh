#!/usr/bin/zsh

_create_symlink() {
  local target="$1"
  local link="$2"

  # Check if the target exists
  if [[ ! -e "$target" ]]; then
    return
  fi 

  # Check if the link is a file and back it up 
  if [[ -e "$link" ]]; then
    cp $link "${source}.bak"
  fi

  ln -sf "$target" "$link"
}

# Create the symlink
_create_symlink "$/HOME/.config/zsh/zshenv" "$HOME/.zshenv"
_create_symlink "$/HOME/.config/zsh/zshrc" "$HOME/.zshrc"

TRUE=0
FALSE=0

headless=$TRUE

# Check DISPLAY variable
if [[ -n $DISPLAY ]]; then
  headless=$TRUE
fi

# Check for running X or Wayland
if ps aux | grep -E 'X|Xorg|wayland|weston' | grep -v grep > /dev/null; then
  headless=$TRUE
fi

# Check for common desktop environments
if ps aux | grep -E 'gnome-session|kde|xfce|lxde|mate-session|cinnamon' | grep -v grep > /dev/null; then
  headless=$TRUE
fi

# Check if X is installed
if command -v X >/dev/null || command -v Xorg >/dev/null; then
  # Has X but might not be running
  headless=$FALSE
fi
    
# Detect OS
case "$(uname -s)" in
Darwin*)
	export OS_TYPE="macos"
	;;
Linux*)
	export OS_TYPE="linux"
	# More reliable Raspberry Pi detection methods
	if [[ -f /sys/firmware/devicetree/base/model ]]; then
		if grep -q "Raspberry Pi" /sys/firmware/devicetree/base/model; then
			export OS_GENRE="raspberrypi"
		fi
	# Fallback detection method
	elif [[ -f /proc/cpuinfo ]]; then
		if grep -q "^Model.*:.*Raspberry" /proc/cpuinfo; then
			export OS_GENRE="raspberrypi"
		fi
	fi
	;;
*)
	export OS_TYPE="unknown"
	;;
esac

# Install brew if not present
if ! command -v brew >/dev/null 2>&1; then
	echo "Installing brew, password might be needed"

	# In the case of macOS we need to make sure that CLT tools for Xcode are installed
	if [[ $OS_TYPE == "macos" ]]; then
		xcode-select --install
	fi

	# Installation of homebrew
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	case $OS_TYPE in
	macos*)
		if ! command -v brew >/dev/null 2>&1; then
			export PATH="/usr/local/bin:$PATH"
		fi
		export HOMEBREW_PREFIX="$(brew --prefix)"
		;;
	linux*)
		# Check if homebrew is present and if it is run the shell integration
		if [[ -d /home/linuxbrew/.linuxbrew/homebrew ]]; then
			eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
		fi
		;;
	*) ;;
	esac
fi

# Install minimym packages with brew
formulae=("perl" "gcc" "shfmt" "rust" "go" "zig" "ghc" "conda" "uv" "television" "superfile" "bat" "bat-extras" \
  "lazygit" "neovim" "tmux" "yazi" "zoxide" "figlet" "lolcat" "age" "ast-grep" "automake" "black" "btop" "chroma" \
  "cmake" "cmake-docs" "deno" "direnv" "docutils" "fastfetch" "fd" "ffmpeg" "file-formula" "fd" "fzy" "gh" "git" \
  "gitui" "glow" "gnu-sed" "helix" "httrack" "hub" "jq" "utf8proc" "julia" "lazydocker" "lnav" "lua" "luarocks" \
  "node" "markdown-toc" "markdownlint-cli2" "mosh" "multitail" "ocaml" "oh-my-posh" "ollama" "opam" "pandoc" \
  "pipx" "pnpm" "prettier" "prettierd" "pyenv" "pygments" "rage" "ripgrep" "rust-analyzer" "rustc-completion" \
  "sevenzip" "sqlfluff" "showkey" "sphinx-doc" "taview" "task" "taskopen" "taskwarrior-tui" "tenere" "timewarrior" \
  "tree" "trippy" "universal-ctags" "viu" "wget" "wordnet" "xclip" "xsel" "yarn" "yq" "zip" "zsh-autosuggestions" \
  "zsh-fast-syntax-highlighting" "zsh-history-substring-search" "zsh-vi-mode" "cabal-install" "qmk/qmk/qmk")

casks=("1password-cli")

if [[ $headless -eq $FALSE ]]; then
  # Adding the casks for a graphic environment
  # formulae+=()
  casks+=("espanso" "discord" "logseq" "lulu" "qmk-toolbox" "transmission" "vlc" "wezterm" "zed" "zen-browser")
fi

MAX_ITER=5
iter=0
total=0

# Since there can be dependencies that are listed later we need to loop until all have been installed
while true; do
  build_formulae_from_source=()
  build_casks_from_source=()

  for formula in "${forumlae[@]}"; do
    output=$(brew install "$formula" 2>&1)

    #check if stdout/stderr contains the pattern
    if [[ "output" == *"--build-from-source"* ]]; then
      build_formulae_from_source+=("$formula")
    fi
  done

  for cask in "${casks[@]}"; do 
    output=$(brew install --cask "$cask" 2>&1)

    # check if stdout/stderr contains the pattner 
    if [[ output == *"--build-from-source"* ]]; then
      build_casks_from_source+=("$cask")
    fi
  done

  # Build formulae that must be built from source
  for formula in "${build_formulate_from_source[@]}"; do
    brew install --build-from-source "$formula"
  done

  # Build casks that must be built from source 
  for cask in "${build_casks_from_source[@]}"; do 
    brew install --cask --build-from-source "$cask"
  done

  # The list is empty thus all has been installed
  if [[ ${#build_formulae_from_source[@]} -eq 0 && ${#build_casks_from_source} -eq 0 ]]; then
    break 
  else
    current_total=$((${#build_formulae_from_source[@]} + ${#build_casks_from_source[@]}))
    if [[ current_total == total ]]; then
      iter+=1
      if [[ iter -ge MAX_ITER ]]; then
        break
      fi
    else
      iter=0
    fi
  fi
done

# Create PERL install (in $XDG_DATA_HOME/share/perl5)
PERL_MM_OPT="INSTALL_BASE=$XDG_DATA_HOME/perl5" cpan local::lib

# Initialize opam repo 
opam Init

