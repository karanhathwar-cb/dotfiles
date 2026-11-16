# Personal aliases, functions and shell setup
# (no work/Couchbase stuff in here - that lives in couchbase.zsh)

# Directory this file lives in, so paths below work wherever the repo is cloned
_zsh_dir="${0:A:h}"

# --- Plugins ---
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# --- Terminal art on startup ---
if command -v chafa >/dev/null && command -v gshuf >/dev/null; then
  _art=$(ls "$_zsh_dir"/../assets/terminal-art/*.png 2>/dev/null | gshuf -n 1)
  if [ -n "$_art" ]; then
    echo ""
    chafa --symbols block --align center -l --size=60x24 "$_art"
    echo ""
  fi
  unset _art
fi

# --- nvm (lazy-loaded: first call to nvm loads the real thing) ---
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm node npm npx
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh"
  nvm "$@"
}

# --- PATH / env ---
export PATH="$PATH:$HOME/go/bin"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

# --- Prompt ---
eval "$(starship init zsh)"

# --- Shortcuts ---
# Open Claude Code in the dotfiles repo to edit these configs
alias shortcuts='cd ~/dotfiles && claude'
