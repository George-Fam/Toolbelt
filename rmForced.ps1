<#
.SYNOPSIS
Force-remove paths on Windows by taking ownership and granting Administrators full control.

.DESCRIPTION
This script accepts one or more paths as positional arguments and performs the following for each:
 - Take ownership (Takeown)
 - Grant Administrators full control (icacls)
 - Remove inheritance and enforce Administrators only (icacls)
 - Recursively delete the path (Remove-Item)

Since this is destructive, this script will only work when launched as admin.

.EXAMPLE
.\rmforced.ps1 "C:\Program Files\SomeLockedFolder" "D:\Games\SomeBrokenFolder"

.EXAMPLE (multiple)
.\rmforced.ps1 'C:\Program Files\WindowsApps\*EA' 'D:\Temp\StuckFolder'
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0,
        ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

if (-not (
        [Security.Principal.WindowsPrincipal]`
            [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
    throw "Must run elevated as Administrator!"
}

foreach ($Path in $Paths) {
    if (-not (Test-Path $Path)) {
        Write-Warning "Path not found: $Path"
        continue
    }

    Write-Host "Taking ownership of $Path ..."
    if (Test-Path $Path -PathType Container) {
        takeown /F $Path /A /R /D Y | Out-Null
    }
    else {
        takeown /F $Path /A /D Y | Out-Null
    }

    Write-Host "Granting full control to Administrators ..."
    icacls $Path /grant Administrators:F /t | Out-Null 2>$null

    Write-Host "Removing all other permissions and enforcing Administrators only ..."
    icacls $Path /inheritance:r /grant:r Administrators:F /t | Out-Null 2>$null

    Write-Host "Deleting $Path ..."
    Remove-Item -Path $Path -Recurse -Force

    Write-Host "Completed removal of $Path"
}

