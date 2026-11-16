# Personal aliases, functions and shell setup
# (no work/Couchbase stuff in here - that lives in couchbase.zsh)

# Keep PATH entries unique, so nested shells (zellij panes) don't keep growing it.
# Only array assignments (path=...) dedupe, so re-assign once and use path+= below.
typeset -U path
path=($path)

# Directory this file lives in, so paths below work wherever the repo is cloned
_zsh_dir="${0:A:h}"
_brew="${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null)}"

# --- Plugins ---
[ -r "$_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] &&
  source "$_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# --- Terminal art on startup ---
if command -v chafa >/dev/null; then
  _arts=("$_zsh_dir"/../assets/terminal-art/*.png(N))
  if (( $#_arts )); then
    echo ""
    chafa --symbols block --align center -l --size=60x24 "$_arts[RANDOM % $#_arts + 1]"
    echo ""
  fi
  unset _arts
fi

# --- nvm (lazy-loaded: first call to nvm, node, npm or npx loads the real thing) ---
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm node npm npx
  [ -s "$_brew/opt/nvm/nvm.sh" ] && source "$_brew/opt/nvm/nvm.sh"
  nvm "$@"
}
for _c in node npm npx; do
  eval "$_c() { nvm --version >/dev/null; $_c \"\$@\"; }"
done
unset _c

# --- PATH / env ---
path+=("$HOME/go/bin")
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

# --- Prompt ---
command -v starship >/dev/null && eval "$(starship init zsh)"

# --- Shortcuts ---
# Open Claude Code in the dotfiles repo to edit these configs
alias shortcuts="cd ${(q)_zsh_dir:h} && claude"
