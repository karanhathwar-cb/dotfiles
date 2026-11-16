# Personal PowerShell setup (Windows counterpart of zsh/personal.zsh)
# Loaded from your PowerShell profile by setup.ps1. Keep this file ASCII-only.

# Repo root, so paths below work wherever the repo is cloned
$DotfilesRoot = Split-Path -Parent $PSScriptRoot

# --- Autosuggestions (PSReadLine predictions from history) ---
try {
  Set-PSReadLineOption -PredictionSource History
  Set-PSReadLineOption -PredictionViewStyle InlineView
} catch { }

# --- Terminal art on startup ---
if (Get-Command chafa -ErrorAction SilentlyContinue) {
  $art = Get-ChildItem "$DotfilesRoot\assets\terminal-art\*.png" -ErrorAction SilentlyContinue | Get-Random
  if ($art) {
    Write-Host ""
    chafa --symbols block --align center -l --size=60x24 $art.FullName
    Write-Host ""
  }
  Remove-Variable art -ErrorAction SilentlyContinue
}

# --- PATH / env ---
$env:PATH += ";$HOME\go\bin"
$env:TF_PLUGIN_CACHE_DIR = "$env:APPDATA\terraform.d\plugin-cache"
New-Item -ItemType Directory -Force -Path $env:TF_PLUGIN_CACHE_DIR | Out-Null

# --- Shortcuts ---
# Open Claude Code in the dotfiles repo to edit these configs
function shortcuts { Set-Location $DotfilesRoot; claude }

# --- Prompt (keep last) ---
if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (&starship init powershell)
}
