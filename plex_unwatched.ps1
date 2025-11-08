#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Displays color-coded Plex TV show statistics based on unwatched episode counts.

.DESCRIPTION
    Connects securely to a Plex Server, retrieves information about a specific TV library section,
    and prints a formatted, colorized table of shows sorted by unwatched episode count.

    Thresholds and filtering parameters allow you to highlight shows with a certain number
    of unwatched episodes (e.g., green for low counts, yellow for medium, red for high).

    If no SectionID is provided, the script will query available library sections and prompt
    you to select the correct TV section interactively.

.PARAMETER SectionID
    The numeric key of the Plex library section to query.
    If omitted, the script will automatically list available TV sections for manual selection.

.PARAMETER Lower
    Minimum number of unwatched episodes to include in the output.
    Shows with fewer unwatched episodes are filtered out.

.PARAMETER Upper
    Maximum number of unwatched episodes to include in the output.
    Shows with more unwatched episodes are filtered out.

.PARAMETER RedLimit
    Threshold above which the count of unwatched episodes is shown in red.

.PARAMETER YellowLimit
    Threshold above which the count of unwatched episodes is shown in yellow
    (and below RedLimit if both are defined).

.PARAMETER PlexHost
    The base URL of the Plex Media Server (default: http://localhost).

.PARAMETER Port
    The Plex Media Server port (default: 32400).

.PARAMETER Token
    A secure Plex API token for authentication.
    If not provided, you will be prompted securely at runtime.

.EXAMPLE
    ./plex_unwatched.ps1 -Lower 0 -Upper 200 -RedLimit 100

    Retrieves all TV shows in the default Plex server with unwatched episode counts
    between 0 and 200. Any show with 100 or more unwatched episodes will be highlighted in red.

.EXAMPLE
    ./plex_unwatched.ps1 -Lower 10 -Upper 150 -RedLimit 100 -YellowLimit 50 `
                         -Host http://plex.local

    Connects to the Plex server at http://plex.local and displays all TV shows
    with 10–150 unwatched episodes. Shows are color-coded: green (<50), yellow (≥50), red (≥100).

.NOTES
    Author: George Fam

.LINK
    Plex API Reference: https://support.plex.tv/articles/201638786-plex-media-server-url-commands
/#>

# ================================ Params ====================================
param(
    [int]$SectionID = -1,

    [int]$Lower,
    [int]$Upper,
    [int]$RedLimit,
    [int]$YellowLimit,

    [string]$PlexHost = "http://localhost",
    [int]$Port = 32400,

    [SecureString]$Token
)
# =============================================================================

# ================================= Functions =================================
function Get-Color($episodes) {
    if (-not $hasRed -and -not $hasYellow) { return "" }

    if ($hasRed -and $episodes -ge $RedLimit) {
        return $Colors.Red
    }
    elseif ($hasYellow -and $episodes -ge $YellowLimit) {
        return $Colors.Yellow
    }
    else {
        return $Colors.Green
    }
}

function Get-PlexData($Url) {
    try {
        return Invoke-RestMethod $Url -ErrorAction Stop
    } 
    catch [System.Net.WebException] {
        $statusCode = [int]$_.Exception.Response.StatusCode
        $statusDesc = $_.Exception.Response.StatusDescription
        Write-Error "HTTP error ($statusCode - $statusDesc) from $Url"
        exit 1
    }
    catch [System.Net.Sockets.SocketException] {
        Write-Error "Connection failed: Cannot reach Plex server at $Url"
        exit 1
    }
    catch {
        Write-Error "Failed to fetch data from $Url. Error: $($_.Exception.Message)"
        exit 1
    }
}
# =============================================================================

# ================================== Colors ===================================
$Colors = @{
    Red    = "`e[31m"
    Yellow = "`e[33m"
    Green  = "`e[32m"
    Reset  = "`e[0m"
}
# =============================================================================

# ================================== Flags ====================================
$hasRed     = $PSBoundParameters.ContainsKey('RedLimit')
$hasYellow  = $PSBoundParameters.ContainsKey('YellowLimit')
$hasLower   = $PSBoundParameters.ContainsKey('Lower')
$hasUpper   = $PSBoundParameters.ContainsKey('Upper')

$filterEnabled = ($hasLower -or $hasUpper)
# =============================================================================

# ============================ Boundary Validation ============================
if ($filterEnabled -and $hasLower -and $hasUpper -and ($Upper -le $Lower)) {
    Write-Error "UPPER ($Upper) must be greater than LOWER ($Lower)."
    exit 1
}

if ($hasYellow) {
    if ($hasLower -and $YellowLimit -lt $Lower) {
        Write-Error ("YELLOW_LIMIT ($YellowLimit) must be greater than or ") +
        "equal to LOWER ($Lower).")
        exit 1
    }
    if ($hasUpper -and $YellowLimit -gt $Upper) {
        Write-Error ("YELLOW_LIMIT ($YellowLimit) must be less than or ") +
        "equal to UPPER ($Upper).")
        exit 1
    }
}

if ($hasRed) {
    if ($hasLower -and $RedLimit -lt $Lower) {
        Write-Error ("RED_LIMIT ($RedLimit) must be greater than or equal ") +
        "to LOWER ($Lower).")
        exit 1
    }
    if ($hasUpper -and $RedLimit -gt $Upper) {
        Write-Error ("RED_LIMIT ($RedLimit) must be less than or equal ") +
        "to UPPER ($Upper).")
        exit 1
    }
}
# =============================================================================

# ============================== Secure Token =================================
if (-not $Token) {
    $Token = Read-Host `
    "Enter your Plex token (found by viewing XML of Library Item)" `
    -AsSecureString
}

# TODO: Token is decrypted to plain text here for use in URL parameters.
# Will consider exploring PSCredential later.
$tokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
)
# =============================================================================

# ================================== SectionID ================================
$baseUrl = "$PlexHost`:$Port"

if ($SectionID -eq -1) {
    $url = "$baseUrl/library/sections?" + 
    "X-Plex-Token=$([Uri]::EscapeDataString($tokenPlain))"
    $libs = Get-PlexData $url

    # Extract only TV sections (type: 'show') 
    # (careful: @() to force even single tv section to be array)
    $tvSections = @($libs.MediaContainer.Directory |
        Where-Object { $_.type -eq "show" })

    if (-not $tvSections) {
        Write-Error "No TV sections found!"
        exit 1
    }

    if ($tvSections.Count -eq 1) { 
        $section = $tvSections[0]
        $SectionID = [int]$section.key
    }
    else {
        Write-Host "Multiple TV sections found:`n"
        $i = 1

        foreach($s in $tvSections) {
            Write-Host ("[$i] key = $($s.key)`tTitle = $($s.title)")
            $i++
        }

        do {
            $choice = Read-Host "Enter the number of the section to use"
        } until($choice -match '^\d+$' -and
        [int]$choice -ge 1 -and
        [int]$choice -lt $i)

        $section = $tvSections[[int]$choice - 1]
        $SectionID = [int]$section.key
    }

    Write-Host ("Using section: $($section.title) " +
    "(key=$SectionID)") -ForegroundColor Green
}
# =============================================================================

# ================================= Plex Data =================================
$url = "$baseUrl/library/sections/$SectionID/all?includeGuids=1" +
"&X-Plex-Token=$([Uri]::EscapeDataString($tokenPlain))"
$shows = Get-PlexData $url
# =============================================================================

# ============================= Process & Display =============================

# Force table headers to white (works only in PowerShell 7.2+)
# DISABLED FOR POWERSHELL 5 COMPATIBILITY
#$PSStyle.Formatting.TableHeader = $PSStyle.Foreground.White

$shows.MediaContainer.Directory |
Sort-Object { [int]$_.leafCount - [int]$_.viewedLeafCount } |
ForEach-Object {
    $total   = [int]$_.leafCount
    $watched = [int]$_.viewedLeafCount
    $left    = $total - $watched

    if ($total -eq 0)               { $status = "No Episodes" }
    elseif ($watched -eq $total)    { $status = "Completed" }
    elseif ($watched -gt 0)         { $status = "Partially Watched" }
    else                            { $status = "Unwatched" }

    $withinLower = (-not $hasLower) -or ($left -ge $Lower)
    $withinUpper = (-not $hasUpper) -or ($left -le $Upper)

    if ($withinLower -and $withinUpper) {
        $color = Get-Color $left
        $coloredLeft   = "$color$left$($Colors.Reset)"
        $coloredStatus = "$color$status$($Colors.Reset)"
        $coloredTitle  = "$color$($_.title)$($Colors.Reset)"

        [PSCustomObject]@{
            Title     = $coloredTitle
            Status    = $coloredStatus
            Unwatched = $coloredLeft
        }
    }
} | Format-Table -AutoSize
# =============================================================================
