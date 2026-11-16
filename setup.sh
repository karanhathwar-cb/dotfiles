#!/usr/bin/env bash
# Dotfiles setup: run once on any machine (safe to re-run).
#   ./setup.sh              full setup
#   SKIP_BREW=1 ./setup.sh  skip Homebrew installs
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# Dotfiles zsh aliases"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

# --- 1. Homebrew packages the configs rely on ---
if [ "${SKIP_BREW:-0}" != "1" ]; then
  if command -v brew >/dev/null 2>&1; then
    say "Checking Homebrew packages"
    for pkg in zsh-autosuggestions starship chafa coreutils zellij nvm; do
      if brew list --formula "$pkg" >/dev/null 2>&1; then
        echo "  ok       $pkg"
      else
        echo "  install  $pkg"
        brew install "$pkg"
      fi
    done
  else
    warn "Homebrew not found - skipping package installs (zsh-autosuggestions, starship, chafa, coreutils, zellij, nvm)"
  fi
fi

# --- 2. Hook the zsh files into ~/.zshrc ---
say "Configuring $ZSHRC"
touch "$ZSHRC"
if grep -qF "zsh/*.zsh(N)" "$ZSHRC"; then
  echo "  already hooked up, nothing to do"
else
  {
    echo ""
    echo "$MARKER"
    echo "for f in \"$DOTFILES\"/zsh/*.zsh(N); do source \"\$f\"; done"
  } >> "$ZSHRC"
  echo "  added loader for $DOTFILES/zsh/*.zsh"
fi

# --- 3. Symlink app configs into ~/.config (existing files are backed up) ---
link() {
  local src="$1" dst="$2"
  [ -e "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  ok       $dst"
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup"
    echo "  backup   $dst -> $backup"
  fi
  ln -s "$src" "$dst"
  echo "  link     $dst -> $src"
}

say "Linking configs"
link "$DOTFILES/starship/starship.toml"     "$HOME/.config/starship.toml"
link "$DOTFILES/alacritty/alacritty.toml"   "$HOME/.config/alacritty/alacritty.toml"
link "$DOTFILES/zellij/config.kdl"          "$HOME/.config/zellij/config.kdl"

say "Done. Open a new terminal (or run: source ~/.zshrc)"
