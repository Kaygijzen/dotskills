<#
Windows version of install.sh. Links each skills\<name>\ folder into
~\.claude\skills\<name> so edits in this repo are live in Claude Code immediately.

Usage:
  .\install.ps1                  link every skill (safe to rerun)
  .\install.ps1 NAME [NAME ...]  link only the named skills
  .\install.ps1 -Uninstall       remove every link that points into this repo
  .\install.ps1 -Uninstall NAME  remove only the named skills' links
  .\install.ps1 -Check           validate every SKILL.md (runs scripts/validate.sh; needs bash)
  .\install.ps1 -WithOpenSpec    also install the OpenSpec CLI without asking
  .\install.ps1 -NoOpenSpec      never ask about the OpenSpec CLI
  .\install.ps1 -WithRtk         also install rtk and run `rtk init -g` without asking
  .\install.ps1 -NoRtk           never ask about rtk

If scripts are blocked, run: powershell -ExecutionPolicy Bypass -File .\install.ps1

Set CLAUDE_SKILLS_DIR to link somewhere other than ~\.claude\skills.
Existing folders or foreign links with the same name are never touched.
Links are directory junctions (no admin or Developer Mode needed), so clone the
repo onto a local drive, not a \\wsl$ path. If the openspec CLI (needed by
grill-spec) is missing, install asks whether to install it with npm; likewise
for rtk (token-saving Bash hook), installed with winget. Without a console to
ask on, both only print a hint.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$Names = @(),
  [switch]$Uninstall,
  [switch]$Check,
  [switch]$WithOpenSpec,
  [switch]$NoOpenSpec,
  [switch]$WithRtk,
  [switch]$NoRtk,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

$RepoDir = $PSScriptRoot
$SrcDir = Join-Path $RepoDir 'skills'
$DestDir = if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $HOME '.claude\skills' }

function Show-Usage {
  $lines = Get-Content $PSCommandPath
  $end = [array]::IndexOf($lines, '#>')
  $lines[1..($end - 1)] | ForEach-Object { $_ }
}

# The link target of $Path, or $null if it isn't a junction or symlink.
function Get-LinkTarget([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if (-not $item -or -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $null }
  $target = @($item.Target)[0]
  if ($target) { $target -replace '^\\\\\?\\', '' }
}

function Test-Exists([string]$Path) {
  [bool](Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
}

# True if $Path is a link this script created, i.e. it points into $SrcDir.
function Test-Ours([string]$Path) {
  $target = Get-LinkTarget $Path
  $target -and $target.StartsWith("$SrcDir\", [StringComparison]::OrdinalIgnoreCase)
}

# Removes the link itself; never recurses into the skill folder it points to.
function Remove-Link([string]$Path) {
  [IO.Directory]::Delete($Path, $false)
}

function New-SkillLink([string]$Path, [string]$Target) {
  try {
    New-Item -ItemType Junction -Path $Path -Target $Target | Out-Null
  } catch {
    # Junctions can't point at network paths like \\wsl$; symlinks can, with Developer Mode.
    New-Item -ItemType SymbolicLink -Path $Path -Target $Target | Out-Null
  }
}

function Add-Skill([string]$Name) {
  $src = Join-Path $SrcDir $Name
  $dest = Join-Path $DestDir $Name

  if (-not (Test-Path -LiteralPath (Join-Path $src 'SKILL.md'))) {
    Write-Host "skip    ${Name}: $src\SKILL.md not found"
    return $false
  }

  $target = Get-LinkTarget $dest
  if ($target) {
    if ($target -eq $src) {
      Write-Host "ok      $Name"
      return $true
    }
    if (Test-Ours $dest) {
      Remove-Link $dest
      New-SkillLink $dest $src
      Write-Host "relink  $Name"
      return $true
    }
    Write-Host "WARN    ${Name}: $dest is a link to $target, not this repo; skipping"
    return $false
  }

  if (Test-Exists $dest) {
    Write-Host "WARN    ${Name}: $dest already exists and is not a link; skipping"
    return $false
  }

  try {
    New-SkillLink $dest $src
  } catch {
    Write-Host "WARN    ${Name}: could not link ($($_.Exception.Message)). Clone the repo onto a local drive, or turn on Developer Mode"
    return $false
  }
  Write-Host "linked  $Name"
  $true
}

# Removes links into this repo whose skill folder no longer exists.
function Remove-Stale {
  foreach ($link in Get-ChildItem -LiteralPath $DestDir -Force) {
    if ((Test-Ours $link.FullName) -and -not (Test-Path -LiteralPath (Get-LinkTarget $link.FullName))) {
      Remove-Link $link.FullName
      Write-Host "pruned  $($link.Name) (skill no longer in repo)"
    }
  }
}

function Install-Skills([string[]]$Names) {
  $ok = $true
  New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

  if ($Names.Count -gt 0) {
    foreach ($name in $Names) { if (-not (Add-Skill $name)) { $ok = $false } }
  } else {
    foreach ($dir in Get-ChildItem -LiteralPath $SrcDir -Directory) {
      if (-not (Add-Skill $dir.Name)) { $ok = $false }
    }
    Remove-Stale
  }

  Write-Host ''
  Write-Host "Skills directory: $DestDir"
  $ok
}

function Uninstall-Skills([string[]]$Names) {
  $removed = 0
  if (-not (Test-Path -LiteralPath $DestDir)) {
    Write-Host "Nothing to remove: $DestDir does not exist"
    return
  }

  if ($Names.Count -gt 0) {
    foreach ($name in $Names) {
      $link = Join-Path $DestDir $name
      if (Test-Ours $link) {
        Remove-Link $link; Write-Host "removed $name"; $removed++
      } elseif (Test-Exists $link) {
        Write-Host "WARN    ${name}: $link was not created by this script; leaving it"
      } else {
        Write-Host "skip    ${name}: not installed"
      }
    }
  } else {
    foreach ($link in Get-ChildItem -LiteralPath $DestDir -Force) {
      if (Test-Ours $link.FullName) {
        Remove-Link $link.FullName; Write-Host "removed $($link.Name)"; $removed++
      }
    }
  }

  Write-Host ''
  Write-Host "Removed $removed link(s) from $DestDir"
}

function Test-Interactive {
  -not [Console]::IsInputRedirected
}

# True on yes; false on no or when there's no console to ask on.
function Confirm-Step([string]$Question) {
  if (-not (Test-Interactive)) { return $false }
  (Read-Host "$Question [y/N]") -match '^(?i)y(es)?$'
}

function Get-CommandPath([string]$Name) {
  $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { $cmd.Source }
}

# Picks up PATH changes an installer just made, without opening a new console.
function Update-SessionPath {
  $env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine'),
    [Environment]::GetEnvironmentVariable('Path', 'User')
  ) -join ';'
}

$OpenSpecPkg = '@fission-ai/openspec@latest'
# From the package's engines field: npm view @fission-ai/openspec engines
$OpenSpecMinNode = [version]'20.19.0'

# Why openspec can't be installed with npm here, or $null if it can.
function Get-OpenSpecBlocker {
  if (-not (Get-CommandPath 'node') -or -not (Get-CommandPath 'npm')) {
    return "Node.js/npm not found; install Node.js $OpenSpecMinNode or newer"
  }
  $nodeVersion = (& node --version).Trim()
  if ([version]($nodeVersion -replace '^v', '') -lt $OpenSpecMinNode) {
    return "Node.js $nodeVersion is too old; OpenSpec needs $OpenSpecMinNode or newer"
  }
}

# $Choice is ask, yes or no.
function Install-OpenSpec([string]$Choice) {
  if (Get-CommandPath 'openspec') {
    Write-Host "ok      openspec $(& openspec --version 2>$null)"
    return $true
  }
  if ($Choice -eq 'no') { return $true }

  # Check prerequisites before asking, so we never offer an install that can't work.
  # Only a run that explicitly asked for openspec (-WithOpenSpec) fails on this.
  $blocker = Get-OpenSpecBlocker
  if ($blocker) {
    Write-Host "WARN    openspec not found (grill-spec needs it): $blocker, then run: npm install -g $OpenSpecPkg"
    return $Choice -ne 'yes'
  }

  if ($Choice -eq 'ask') {
    if (-not (Test-Interactive)) {
      Write-Host "note    openspec not found; grill-spec needs it. Rerun with -WithOpenSpec or run: npm install -g $OpenSpecPkg"
      return $true
    }
    if (-not (Confirm-Step 'OpenSpec CLI not found (grill-spec needs it). Install with npm now?')) {
      Write-Host 'skip    openspec'
      return $true
    }
  }

  & npm install -g $OpenSpecPkg
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'WARN    openspec: npm install failed'
    return $false
  }
  Update-SessionPath
  Write-Host "installed openspec $(& openspec --version 2>$null)"
  $true
}

$ClaudeSettings = Join-Path $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }) 'settings.json'

# $Choice is ask, yes or no.
function Install-Rtk([string]$Choice) {
  if ($Choice -eq 'no') { return $true }
  $rtk = Get-CommandPath 'rtk'

  if ($rtk) {
    # A different crate is also called rtk; only the right one has `gain`.
    & $rtk gain *> $null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "WARN    rtk: $rtk is not rtk-ai/rtk (``rtk gain`` failed); skipping"
      return $false
    }
    Write-Host "ok      rtk $((& $rtk --version 2>$null) -replace '^rtk ', '')"
  } else {
    if ($Choice -eq 'ask') {
      if (-not (Test-Interactive)) {
        Write-Host 'note    rtk not found (optional, saves tokens on Bash output). Rerun with -WithRtk or see https://github.com/rtk-ai/rtk'
        return $true
      }
      if (-not (Confirm-Step 'rtk not found (optional, saves tokens on Bash output). Install it now?')) {
        Write-Host 'skip    rtk'
        return $true
      }
    }
    if (-not (Get-CommandPath 'winget')) {
      Write-Host 'WARN    rtk: winget not found; install App Installer from the Microsoft Store, then rerun with -WithRtk'
      return $false
    }
    & winget install --id rtk-ai.rtk --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
      Write-Host 'WARN    rtk: winget install failed'
      return $false
    }
    Update-SessionPath
    $rtk = Get-CommandPath 'rtk'
    if (-not $rtk) {
      Write-Host 'WARN    rtk: installed, but rtk is not on PATH yet; open a new terminal and run: rtk init -g'
      return $false
    }
    Write-Host "installed rtk $((& $rtk --version 2>$null) -replace '^rtk ', '')"
  }

  # Rough check for an existing hook; `rtk init -g` writes it to settings.json.
  if ((Test-Path -LiteralPath $ClaudeSettings) -and (Select-String -LiteralPath $ClaudeSettings -Pattern 'rtk' -Quiet)) {
    Write-Host "ok      rtk hook in $ClaudeSettings"
    return $true
  }
  # `rtk init -g` can ask its own questions, so it only runs with a console.
  if (-not (Test-Interactive)) {
    Write-Host 'note    rtk hook not set up; run: rtk init -g'
    return $true
  }
  if ($Choice -eq 'yes' -or (Confirm-Step 'Run `rtk init -g` to add rtk''s hook to your Claude Code settings?')) {
    & $rtk init -g
    if ($LASTEXITCODE -ne 0) {
      Write-Host 'WARN    rtk: `rtk init -g` failed'
      return $false
    }
    Write-Host 'note    restart Claude Code to load the rtk hook'
  } else {
    Write-Host 'skip    rtk init (run `rtk init -g` later)'
  }
  $true
}

if ($Help) { Show-Usage; exit 0 }
$Names = @($Names | ForEach-Object { $_.TrimEnd('\', '/') })
$openSpecChoice = if ($WithOpenSpec) { 'yes' } elseif ($NoOpenSpec) { 'no' } else { 'ask' }
$rtkChoice = if ($WithRtk) { 'yes' } elseif ($NoRtk) { 'no' } else { 'ask' }

if ($Check) {
  if (-not (Get-CommandPath 'bash')) {
    Write-Error 'Validation needs bash (Git Bash or WSL).'
    exit 2
  }
  Push-Location $RepoDir
  try { & bash ./scripts/validate.sh @Names } finally { Pop-Location }
  exit $LASTEXITCODE
}

if ($Uninstall) {
  Uninstall-Skills $Names
  exit 0
}

$ok = Install-Skills $Names
if (-not (Install-OpenSpec $openSpecChoice)) { $ok = $false }
if (-not (Install-Rtk $rtkChoice)) { $ok = $false }
if ($ok) { exit 0 } else { exit 1 }
