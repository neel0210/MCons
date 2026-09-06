# MCons Build & Automation Script for Windows PowerShell
# Provides native asset validation, project cleanup, GitHub Actions CI dispatch, and downloads.

param (
    [switch]$Debug,
    [switch]$Release,
    [switch]$Universal,
    [switch]$Dmg,
    [switch]$Zip,
    [switch]$Install,
    [switch]$Notarize,
    [switch]$Test,
    [switch]$Validate,
    [switch]$Clean,
    [switch]$Info,
    [switch]$CiBeta,
    [switch]$CiProd,
    [switch]$Download,
    [string]$Version = "",
    [switch]$Help
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration
$AppName = "MCons"
$Repo = "neel0210/MCons"
$OutputDir = "output"

# Detect Version from git or fallback
if ([string]::IsNullOrWhiteSpace($Version)) {
    try {
        $gitTag = git describe --tags --abbrev=0 2>$null
        if ($gitTag) {
            $Version = $gitTag.TrimStart('v')
        } else {
            $Version = "1.0.4"
        }
    } catch {
        $Version = "1.0.4"
    }
}

# Detect Git branch & hash
try {
    $GitHash = git rev-parse --short HEAD 2>$null
    $GitBranch = git rev-parse --abbrev-ref HEAD 2>$null
} catch {
    $GitHash = "unknown"
    $GitBranch = "main"
}

function Show-Help {
    Write-Host ""
    Write-Host "MCons Windows PowerShell Automation Script" -ForegroundColor Cyan -NoNewline
    Write-Host " (v$Version)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usage: .\build.ps1 [flags]" -ForegroundColor White
    Write-Host ""
    Write-Host "Asset & Project Flags:" -ForegroundColor Yellow
    Write-Host "  -Validate       Validate all 14 IconPacks (metadata.json & SVGs)"
    Write-Host "  -Clean          Remove .build\ and output\ directories"
    Write-Host "  -Info           Print project build metadata"
    Write-Host "  -Version <str>  Set build version (default: $Version)"
    Write-Host ""
    Write-Host "CI & Release Flags:" -ForegroundColor Yellow
    Write-Host "  -CiBeta         Dispatch GitHub Actions Beta Build workflow"
    Write-Host "  -CiProd         Dispatch GitHub Actions Production Build workflow"
    Write-Host "  -Download       Download latest compiled release artifact from GitHub"
    Write-Host "  -Help           Show this help"
    Write-Host ""
    Write-Host "Cross-Platform Notice:" -ForegroundColor Gray
    Write-Host "  MCons requires macOS 14.0+ (SwiftUI & AppKit) to compile binary." -ForegroundColor Gray
    Write-Host "  On Windows, use -CiBeta or -CiProd to compile on macOS runner." -ForegroundColor Gray
    Write-Host ""
}

function Show-Info {
    Write-Host "`n━━━ Build Metadata ━━━" -ForegroundColor Cyan
    Write-Host "  App:         $AppName"
    Write-Host "  Version:     $Version"
    Write-Host "  Branch:      $GitBranch"
    Write-Host "  Git Hash:    $GitHash"
    Write-Host "  Platform:    Windows (PowerShell $($PSVersionTable.PSVersion))"
    Write-Host "  Output Dir:  $OutputDir"
    Write-Host ""
}

function Invoke-Validation {
    Write-Host "`n━━━ Validating Icon Packs ━━━" -ForegroundColor Cyan
    $packDir = "MCons\Resources\IconPacks"
    if (-not (Test-Path $packDir)) {
        Write-Error "IconPacks directory not found at $packDir"
        return
    }

    $packs = Get-ChildItem -Path $packDir -Directory
    $totalIcons = 0
    $hasWarnings = $false

    foreach ($pack in $packs) {
        $metaPath = Join-Path $pack.FullName "metadata.json"
        if (-not (Test-Path $metaPath)) {
            Write-Warning "Pack '$($pack.Name)' missing metadata.json"
            $hasWarnings = $true
            continue
        }

        try {
            $jsonContent = Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $jsonContent.id -or -not $jsonContent.name -or -not $jsonContent.emoji) {
                Write-Warning "Pack '$($pack.Name)' metadata.json missing required fields"
                $hasWarnings = $true
                continue
            }
        } catch {
            Write-Warning "Pack '$($pack.Name)' metadata.json invalid JSON: $_"
            $hasWarnings = $true
            continue
        }

        $svgs = Get-ChildItem -Path $pack.FullName -Filter "*.svg" -File
        if ($pack.Name -eq "macos-native-plus") {
            Write-Host "  [OK] " -ForegroundColor Green -NoNewline
            Write-Host "$($pack.Name): " -NoNewline
            Write-Host "CoreGraphics Vector (Programmatic)" -ForegroundColor Gray
            continue
        }

        if ($svgs.Count -eq 0) {
            Write-Warning "Pack '$($pack.Name)' contains 0 SVG icons"
            $hasWarnings = $true
            continue
        }

        $totalIcons += $svgs.Count
        Write-Host "  [OK] " -ForegroundColor Green -NoNewline
        Write-Host "$($pack.Name): " -NoNewline
        Write-Host "$($svgs.Count) icons" -ForegroundColor White
    }

    Write-Host ""
    if ($hasWarnings) {
        Write-Warning "Validation finished with warnings."
    } else {
        Write-Host "SUCCESS: All $($packs.Count) icon packs valid! Total: $totalIcons SVG icons." -ForegroundColor Green
    }
}

function Invoke-Clean {
    Write-Host "`n━━━ Cleaning Project ━━━" -ForegroundColor Cyan
    if (Test-Path ".build") {
        Remove-Item -Path ".build" -Recurse -Force
        Write-Host "  Removed .build\" -ForegroundColor Gray
    }
    if (Test-Path $OutputDir) {
        Remove-Item -Path $OutputDir -Recurse -Force
        Write-Host "  Removed $OutputDir\" -ForegroundColor Gray
    }
    Write-Host "SUCCESS: Clean complete." -ForegroundColor Green
}

function Invoke-CiDispatch ([string]$BuildType) {
    Write-Host "`n━━━ GitHub Actions CI Dispatch ━━━" -ForegroundColor Cyan
    Write-Host "  Build Type: $BuildType" -ForegroundColor White
    Write-Host "  Branch:     $GitBranch" -ForegroundColor White

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "Dispatching via GitHub CLI (gh)..." -ForegroundColor Cyan
        gh workflow run build.yml --ref $GitBranch -f build_type="$BuildType"
        Write-Host "SUCCESS: Dispatched! Check status with: gh run list --workflow=build.yml" -ForegroundColor Green
    } else {
        $token = $env:GITHUB_TOKEN
        if (-not $token) { $token = $env:GH_TOKEN }
        if (-not $token) {
            Write-Error "GitHub CLI (gh) not installed and GITHUB_TOKEN not set.`nInstall gh CLI (winget install GitHub.cli) or set `$env:GITHUB_TOKEN."
            return
        }

        Write-Host "Dispatching via GitHub REST API..." -ForegroundColor Cyan
        $headers = @{
            "Authorization" = "token $token"
            "Accept"        = "application/vnd.github.v3+json"
            "User-Agent"    = "MCons-PowerShell"
        }
        $body = @{
            "ref"    = $GitBranch
            "inputs" = @{ "build_type" = $BuildType }
        } | ConvertTo-Json

        $url = "https://api.github.com/repos/$Repo/actions/workflows/build.yml/dispatches"
        $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
        Write-Host "SUCCESS: GitHub Actions workflow dispatched successfully!" -ForegroundColor Green
    }
}

function Invoke-DownloadRelease {
    Write-Host "`n━━━ Downloading Latest Release ━━━" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

    try {
        $releaseUrl = "https://api.github.com/repos/$Repo/releases/latest"
        $release = Invoke-RestMethod -Uri $releaseUrl -Method Get -Headers @{ "User-Agent" = "MCons-PowerShell" }
        $asset = $release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        
        if ($asset) {
            $dlUrl = $asset.browser_download_url
            $targetFile = Join-Path $OutputDir $asset.name
            Write-Host "Downloading $($asset.name) from $dlUrl..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $dlUrl -OutFile $targetFile
            $fileMb = [math]::Round((Get-Item $targetFile).Length / 1048576, 2)
            Write-Host "SUCCESS: Downloaded to $targetFile ($fileMb MB)" -ForegroundColor Green
        } else {
            Write-Warning "No .zip asset found in latest release."
        }
    } catch {
        Write-Error "Failed to download release: $_"
    }
}

# Main Execution Switch
if ($Help) {
    Show-Help
    exit 0
}

if ($Clean) {
    Invoke-Clean
    if (-not $Validate -and -not $CiBeta -and -not $CiProd -and -not $Download) { exit 0 }
}

if ($Info) {
    Show-Info
    exit 0
}

if ($Validate) {
    Invoke-Validation
    exit 0
}

if ($CiBeta) {
    Invoke-CiDispatch "Test Build (Beta)"
    exit 0
}

if ($CiProd) {
    Invoke-CiDispatch "Production Build"
    exit 0
}

if ($Download) {
    Invoke-DownloadRelease
    exit 0
}

# Default behavior when run without flags on Windows
Show-Info
Invoke-Validation

Write-Host ""
Write-Host "Cross-Platform Notice:" -ForegroundColor Yellow
Write-Host "  MCons requires macOS 14.0+ (SwiftUI & AppKit) to compile binary." -ForegroundColor White
Write-Host "  To build on macOS runner via GitHub Actions, run:" -ForegroundColor White
Write-Host "    .\build.ps1 -CiBeta" -ForegroundColor Cyan
Write-Host "    .\build.ps1 -CiProd" -ForegroundColor Cyan
Write-Host "  To download the latest compiled release, run:" -ForegroundColor White
Write-Host "    .\build.ps1 -Download" -ForegroundColor Cyan
Write-Host ""
