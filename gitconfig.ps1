<#
.SYNOPSIS
Configures a Git setup.globally or for large repo (file monitor)

.DESCRIPTION
Runs two modes:

1) Default = configure global .gitconfig:
    - apply Global Git settings
    - setup aliases
    - write 3 identity includeIf files (Github Pro, Github Personal, Gitlab School)
    - set fallback default identity to “joblu”

2) Local repo mode (only if -RepoPath is provided):
    applies only large-repo performance configs to THAT repo:

       core.fsmonitor      = true
       core.untrackedCache = true

.PARAMETER RepoPath
Path to a git repo folder. If present, skip global setup and only apply large repo optimizations locally.

.EXAMPLE
PS> ./git-setup.ps1

- installs global settings, aliases & identities.

.EXAMPLE
PS> ./git-setup.ps1 -RepoPath "C:\dev\huge-repo"

.NOTES
This script is idempotent. You can re-run it safely.
#>
param(
    [string]$RepoPath
)

$erroractionpreference = "stop"

# ================================= constants =================================

# ----------------------------------- paths -----------------------------------
$CONFIG_DIR = $env:USERPROFILE

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$JsonPath = Join-Path $SCRIPT_DIR "gitconfig.json"

if (-not (Test-Path $JsonPath)) {
    throw "Configuration file 'gitconfig.json' not found at $JsonPath"
}

$CONFIG = Get-Content $JsonPath -Raw | ConvertFrom-Json

# =============================================================================

# ================================= Functions =================================
function write-identityfile {
    param(
        [string]$path,
        [string]$name,
        [string]$email
    )

    @"
[user]
    name = $name
    email = $email
[author]
    name = $name
    email = $email
[committer]
    name = $name
    email = $email
"@ | Out-File -FilePath $path -Encoding utf8 -Force

    Write-Host "Created identity file: $path"
}

function add-includeif {
    param(
        [string]$pattern,
        [string]$includefile
    )
    git config --global --remove-section "includeIf.$pattern" 2>$null
    git config --global --add "includeIf.$pattern.path" "$includefile"
    Write-Host "Added includeif for '$pattern' - $includefile"
}

function apply-defaultidentity {
    $id = $CONFIG.defaultIdentity
    Write-Host "Applying default identity..." -ForegroundColor cyan
    git config --global user.name       $id.name
    git config --global user.email      $id.email
    git config --global author.name     $id.name
    git config --global author.email    $id.email
    git config --global committer.name  $id.name
    git config --global committer.email $id.email
    Write-Host "Default identity applied successfully." -ForegroundColor green
}

function apply-globalsettings {
    Write-Host "Configuring global git settings..." -ForegroundColor cyan
    foreach ($kv in $CONFIG.globalSettings.psobject.Properties) {
        git config --global $kv.Name "$($kv.Value)"
    }
    Write-Host "Global settings applied successfully." -ForegroundColor green
}

function apply-aliases {
    Write-Host "Configuring git aliases..." -ForegroundColor cyan
    foreach ($kv in $CONFIG.aliases.psobject.Properties) {
        git config --global "alias.$($kv.Name)" "$($kv.Value)"
    }
    Write-Host "Aliases applied successfully." -ForegroundColor green
}
function apply-identities {
    Write-Host "Applying conditional identities" -ForegroundColor cyan
    foreach ($id in $CONFIG.identities) {
        $path = Join-Path $CONFIG_DIR $id.file
        write-identityfile -path $path -name $id.name -email $id.email

        foreach ($p in $id.patterns) {
            add-includeif -pattern "hasconfig:remote.*.url:$p/**" `
                -includefile $path
        }
    }
    Write-Host "All conditional identities configured successfully." `
        -ForegroundColor green
}

function apply-largerepolocal {
    param([string]$repo)

    if (-not (Test-Path $repo)) { throw "Repo path does not exist." }
    $abs = (Resolve-Path $repo).Path

    Write-Host "Applying large repo optimizations to: $abs" `
        -ForegroundColor Cyan

    foreach ($kv in $CONFIG.largeRepoSettings.psobject.Properties) {
        git -C $abs config $kv.Name $kv.Value
    }

    Write-Host "Large repo optimizations applied locally." `
        -ForegroundColor Green
}
# =============================================================================

if ($RepoPath) {
    apply-largerepolocal $RepoPath
    exit
}

apply-globalsettings
apply-aliases
apply-defaultidentity
apply-identities

Write-Host "`nAll git config applied." -ForegroundColor green

