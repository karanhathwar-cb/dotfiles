# Dotfiles setup for native Windows PowerShell (safe to re-run).
#   .\setup.ps1                 full setup
#   .\setup.ps1 -SkipInstall    skip winget installs
# If scripts are blocked, run once:  powershell -ExecutionPolicy Bypass -File .\setup.ps1
param([switch]$SkipInstall)

$ErrorActionPreference = 'Stop'
$Dotfiles = $PSScriptRoot

function Say($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }

# --- 1. Packages via winget ---
if (-not $SkipInstall) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Say 'Checking winget packages'
    $packages = @(
      'Starship.Starship',
      'hpjansson.Chafa',
      'Alacritty.Alacritty',
      'DEVCOM.JetBrainsMonoNerdFont'
    )
    foreach ($id in $packages) {
      winget list --id $id --exact --accept-source-agreements *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Host "  ok       $id"
      } else {
        Write-Host "  install  $id"
        winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
      }
    }
  } else {
    Warn 'winget not found - skipping installs (Starship, Chafa, Alacritty, JetBrainsMono Nerd Font)'
  }
}

# --- 2. Allow profile scripts to run (current user only) ---
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('Undefined', 'Restricted')) {
  Say 'Setting execution policy to RemoteSigned for the current user'
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

# --- 3. Hook the PowerShell files into both profiles (PS 7 and Windows PowerShell 5.1) ---
$docs = [Environment]::GetFolderPath('MyDocuments')
$profiles = @(
  (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
  (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)
$loader = "Get-ChildItem `"$Dotfiles\powershell\*.ps1`" | ForEach-Object { . `$_.FullName }"
Say 'Configuring PowerShell profiles'
foreach ($p in $profiles) {
  New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
  if (-not (Test-Path $p)) { New-Item -ItemType File -Path $p | Out-Null }
  if (Select-String -Path $p -SimpleMatch 'powershell\*.ps1' -Quiet) {
    Write-Host "  already hooked up: $p"
  } else {
    Add-Content -Path $p -Value "`n# Dotfiles PowerShell setup`n$loader"
    Write-Host "  added loader to $p"
  }
}

# --- 4. Link app configs (existing files are backed up) ---
function Link($src, $dst) {
  if (-not (Test-Path $src)) { return }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  $item = Get-Item $dst -Force -ErrorAction SilentlyContinue
  if ($item -and $item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $src) {
    Write-Host "  ok       $dst"; return
  }
  if ($item) {
    $backup = "$dst.bak.$(Get-Date -Format yyyyMMddHHmmss)"
    Move-Item $dst $backup
    Write-Host "  backup   $dst -> $backup"
  }
  try {
    New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
    Write-Host "  link     $dst -> $src"
  } catch {
    Copy-Item $src $dst
    Warn "symlink needs Developer Mode or admin; copied instead: $dst (re-run setup after editing the repo copy)"
  }
}

Say 'Linking configs'
Link "$Dotfiles\starship\starship.toml"   "$HOME\.config\starship.toml"
Link "$Dotfiles\alacritty\alacritty.toml" "$env:APPDATA\alacritty\alacritty.toml"

Say 'Done. Open a new PowerShell window.'
