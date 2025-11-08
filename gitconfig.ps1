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

# --------------------------------- settings ----------------------------------
$globalsettings = @{
    "init.defaultBranch"   = "main"
    "column.ui"            = "auto"
    "branch.sort"          = "-committerdate"
    "tag.sort"             = "version:refname"
    "diff.algorithm"       = "histogram"
    "diff.colorMoved"      = "plain"
    "diff.mnemonicPrefix"  = "true"
    "diff.renames"         = "true"
    "push.autoSetupRemote" = "true"
    "push.followTags"      = "true"
    "fetch.prune"          = "true"
    "fetch.pruneTags"      = "true"
    "fetch.all"            = "true"
    "help.autocorrect"     = "prompt"
    "merge.conflictstyle"  = "zdiff3"
}

# ---------------------------------- aliases ----------------------------------
$aliases = @{
    ac       = "commit -am"
    br       = "branch"
    ci       = "commit"
    co       = "checkout"
    st       = "status"
    stashall = "stash push --include-untracked"

    adog     = "log --all --decorate --oneline --graph"
    adogt    = "log --all --decorate --oneline --graph " + 
    "--date=format:'%Y-%m-%d %H:%M:%S' " + 
    "--pretty=format:" +
    "'%C(auto)%h %C(bold blue)%ad%Creset %C(auto)%d %C(reset)%s'"
    adogr    = "log --all --decorate --oneline --graph " + 
    "--date=relative " + 
    "--pretty=format:" +
    "'%C(auto)%h %C(green)(%cr)%Creset %C(auto)%d %C(reset)%s'"
    adoga    = "log --all --decorate --oneline --graph " + 
    "--date=relative " + 
    "--pretty=format:" +
    "'%C(auto)%h %C(green)(%cr)%Creset %C(auto)%d %C(reset)%s " + 
    "%C(dim white)- %an%Creset'"
}

# -------------------------------- identities ---------------------------------
$identities = @(
    @{
        name     = "George Fam"; 
        file     = ".gitconfig_github_pro"; 
        emails   = @("george.fam@famcode.net"); 
        patterns = @(
            "git@githubPro:*"
            "git@github.com:George-Fam*"
        )
    },
    @{
        name     = "joblu";
        file     = ".gitconfig_github_personal";
        emails   = @("georgeramzy13@live.ca");
        patterns = @(
            "git@github:*"
            "git@github.com:joblu*"    
        )
    },
    @{
        name     = "George Fam";
        file     = ".gitconfig_gitlab_school";
        emails   = @("fam.george@courrier.uqam.ca");
        patterns = @(
            "git@gitlabSchool:*"
            "git@gitlab.info.uqam.ca:fam.george*"
        )
    }
)
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
    Write-Host "Applying default identity..." -ForegroundColor cyan
    git config --global user.name       "joblu"
    git config --global user.email      "georgeramzy13@live.ca"
    git config --global author.name     "joblu"
    git config --global author.email    "georgeramzy13@live.ca"
    git config --global committer.name  "joblu"
    git config --global committer.email "georgeramzy13@live.ca"
    Write-Host "Default identity applied successfully." -ForegroundColor green
}

function apply-globalsettings {
    Write-Host "Configuring global git settings..." -ForegroundColor cyan
    foreach ($kv in $globalsettings.getenumerator()) {
        git config --global $kv.key "$($kv.value)"
    }
    Write-Host "Global settings applied successfully." -ForegroundColor green
}

function apply-aliases {
    Write-Host "Configuring git aliases..." -ForegroundColor cyan
    foreach ($kv in $aliases.getenumerator()) {
        git config --global "alias.$($kv.key)" "$($kv.value)"
    }
    Write-Host "Aliases applied successfully." -ForegroundColor green
}
function apply-identities {
    Write-Host "Applying conditional identities" -ForegroundColor cyan
    foreach ($id in $identities) {
        $path = Join-Path $CONFIG_DIR $id.file
        write-identityfile -path $path -name $id.name -email $id.emails[0]

        foreach ($p in $id.patterns) {
            add-includeif -pattern "hasconfig:remote.*.url:$p/**" `
                -includefile $path
        }
    }
    Write-Host "`All conditional identities configured successfully." `
        -ForegroundColor green
}

function apply-largerepolocal {
    param([string]$repo)

    if (-not (Test-Path $repo)) { throw "Repo path does not exist." }
    $abs = (Resolve-Path $repo).Path

    Write-Host "Applying large repo optimizations to: $abs" `
        -ForegroundColor Cyan

    git -C $abs config core.fsmonitor true
    git -C $abs config core.untrackedCache true

    Write-Host "Large repo optimizations applied locally." `
        -ForegroundColor Green
}
# =============================================================================

if ($RepoPath) {
    Apply-LargeRepoLocal $RepoPath
    exit
}

apply-globalsettings
apply-aliases
apply-defaultidentity
apply-identities

Write-Host "`nAll git config applied." -ForegroundColor green

