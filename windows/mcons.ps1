<#
.SYNOPSIS
    MCons for Windows — Native PowerShell Folder Customizer
.DESCRIPTION
    Applies vector icons from bundled packs to Windows folders using desktop.ini & Win32 Shell API
.EXAMPLE
    .\mcons.ps1 -List
    .\mcons.ps1 -Apply -Path "C:\MyFolder" -Icon "MCons\Resources\IconPacks\jujutsu-kaisen\Satoru Gojo.svg"
    .\mcons.ps1 -Restore -Path "C:\MyFolder"
#>

[CmdletBinding()]
param(
    [Parameter()][switch]$List,
    [Parameter()][switch]$Apply,
    [Parameter()][switch]$Restore,
    [Parameter()][string]$Path,
    [Parameter()][string]$Icon
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreScript = Join-Path $ScriptDir "mcons_app.py"

if ($List) {
    & python $CoreScript list
    exit $LASTEXITCODE
}

if ($Restore) {
    if (-not $Path) {
        Write-Error "Please specify target folder with -Path"
        exit 1
    }
    & python $CoreScript restore $Path
    exit $LASTEXITCODE
}

if ($Apply) {
    if (-not $Path -or -not $Icon) {
        Write-Error "Please specify both -Path <Folder> and -Icon <PathOrName>"
        exit 1
    }
    & python $CoreScript apply $Path --icon $Icon
    exit $LASTEXITCODE
}

# Default: Launch GUI
& python $CoreScript
