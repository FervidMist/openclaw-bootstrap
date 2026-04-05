param(
    [ValidateSet("fat", "slim")]
    [string]$Mode = "fat",
    [string]$OpenClawPath = "",
    [string]$PlaywrightBrowsersPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$WorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $WorkingDir

# ===== 配置 =====
$NodeVersion = "22.22.1"
$Platform = "win32"
$Arch = "x64"
$NodeZipName = "node-v$NodeVersion-win-x64"
$NodeUrl = "https://nodejs.org/dist/v$NodeVersion/$NodeZipName.zip"

function Require-Path {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path $Path)) {
        throw "[ERROR] Missing $Description at: $Path"
    }
}

function Test-DirectoryHasContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    return $null -ne (Get-ChildItem -Path $Path -Force | Select-Object -First 1)
}

function Expand-ArchiveToTargetRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetRoot
    )

    $tempExtractDir = Join-Path ([System.IO.Path]::GetDirectoryName($TargetRoot)) ([System.IO.Path]::GetFileName($TargetRoot) + "-extract")
    if (Test-Path $tempExtractDir) {
        Remove-Item -Path $tempExtractDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempExtractDir | Out-Null

    Expand-Archive -Path $ArchivePath -DestinationPath $tempExtractDir -Force
    $children = Get-ChildItem -Path $tempExtractDir -Force

    if (Test-Path $TargetRoot) {
        Remove-Item -Path $TargetRoot -Recurse -Force
    }

    if (($children.Count -eq 1) -and $children[0].PSIsContainer) {
        Move-Item -Path $children[0].FullName -Destination $TargetRoot
    } else {
        New-Item -ItemType Directory -Path $TargetRoot | Out-Null
        Get-ChildItem -Path $tempExtractDir -Force | Move-Item -Destination $TargetRoot
    }

    if (Test-Path $tempExtractDir) {
        Remove-Item -Path $tempExtractDir -Recurse -Force
    }
}

function Resolve-OpenClawSourceDir {
    param(
        [string]$PreferredPath,
        [string]$RepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredPath)) {
        if (-not (Test-Path $PreferredPath)) {
            throw "[ERROR] OpenClaw source directory not found: $PreferredPath"
        }

        $resolvedPreferredPath = (Resolve-Path $PreferredPath).Path
        Require-Path -Path (Join-Path $resolvedPreferredPath "package.json") -Description "OpenClaw package.json"
        return $resolvedPreferredPath
    }

    $candidatePaths = @(
        (Join-Path $RepoRoot "openclaw"),
        (Join-Path $RepoRoot "openclaw-portable\openclaw")
    )

    foreach ($candidatePath in $candidatePaths) {
        if ((Test-Path $candidatePath) -and (Test-Path (Join-Path $candidatePath "package.json"))) {
            return (Resolve-Path $candidatePath).Path
        }
    }

    $searchedPaths = $candidatePaths -join ", "
    throw "[ERROR] OpenClaw source directory not found. Checked: $searchedPaths"
}

function Assert-LastExitCode {
    param(
        [string]$Description
    )

    if ($LASTEXITCODE -ne 0) {
        throw "[ERROR] $Description failed with exit code $LASTEXITCODE"
    }
}

function Resolve-OptionalDirectoryPath {
    param(
        [string]$PreferredPath,
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($PreferredPath)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($PreferredPath)) {
        return $PreferredPath
    }

    return (Join-Path $RepoRoot $PreferredPath)
}

function Copy-SourceTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    $excludedDirNames = @("node_modules", ".git")
    $excludedDirPaths = Get-ChildItem -Path $SourceRoot -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in $excludedDirNames } |
        Select-Object -ExpandProperty FullName

    if (-not (Test-Path $DestinationRoot)) {
        New-Item -ItemType Directory -Path $DestinationRoot | Out-Null
    }

    $robocopyArgs = @(
        $SourceRoot,
        $DestinationRoot,
        "/E",
        "/R:1",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP"
    )

    if ($excludedDirPaths.Count -gt 0) {
        $robocopyArgs += "/XD"
        $robocopyArgs += $excludedDirPaths
    }

    & robocopy @robocopyArgs | Out-Null
    if ($LASTEXITCODE -gt 7) {
        throw "[ERROR] Failed to copy OpenClaw source tree with robocopy. Exit code: $LASTEXITCODE"
    }
}

$DistName = "openclaw-win-$Arch-$Mode"
$DistDir = Join-Path $RepoRoot "dist\$DistName"
$nodeTarget = Join-Path $DistDir "node"
$srcDir = Resolve-OpenClawSourceDir -PreferredPath $OpenClawPath -RepoRoot $RepoRoot
$launchersDir = Join-Path $RepoRoot "launchers\windows"
$portableDir = Join-Path $RepoRoot "portable"
$environmentAssetRoot = Join-Path $RepoRoot "tools\environment-assets\windows"
$environmentDownloadsDir = Join-Path $environmentAssetRoot "downloads"
$defaultEnvironmentBrowsersDir = Join-Path $environmentAssetRoot "playwright-browsers"
$customEnvironmentBrowsersDir = Resolve-OptionalDirectoryPath -PreferredPath $PlaywrightBrowsersPath -RepoRoot $RepoRoot
$environmentBrowsersDir = if ([string]::IsNullOrWhiteSpace($customEnvironmentBrowsersDir)) { $defaultEnvironmentBrowsersDir } else { $customEnvironmentBrowsersDir }
$portableScriptsDir = Join-Path $portableDir "scripts"
$portableDataDir = Join-Path $portableDir "data"
$portableBrowsersDir = Join-Path $portableDir "browsers"
$portableReadme = Join-Path $portableDir "README.md"
$buildCacheDir = Join-Path $RepoRoot "build\cache"
$environmentNodeArchive = Join-Path $environmentDownloadsDir "$NodeZipName.zip"
$buildCacheNodeArchive = Join-Path $buildCacheDir "$NodeZipName.zip"
$minGitArchive = Get-ChildItem -Path $environmentDownloadsDir -Filter "MinGit-*-64-bit.zip" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "busybox" } | Sort-Object Name -Descending | Select-Object -First 1

Write-Host "=========================================="
Write-Host "  OpenClaw Portable Builder - Windows $Mode"
Write-Host "=========================================="
Write-Host "Using OpenClaw source: $srcDir"

Require-Path -Path (Join-Path $srcDir "package.json") -Description "OpenClaw package.json"
Require-Path -Path $launchersDir -Description "Windows launcher directory"
Require-Path -Path $portableScriptsDir -Description "portable scripts directory"
Require-Path -Path $portableDataDir -Description "portable data directory"

# 清理旧产物
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
if (Test-Path $DistDir) {
    Remove-Item -Path $DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DistDir | Out-Null

# [1/6] 下载 Node.js
Write-Host "`n[1/6] Node.js v$NodeVersion ($Arch)..."
if (Test-Path $environmentNodeArchive) {
    Write-Host "Using reusable environment asset cache: $environmentNodeArchive"
} elseif (-Not (Test-Path $buildCacheNodeArchive)) {
    New-Item -ItemType Directory -Force -Path $buildCacheDir | Out-Null
    Write-Host "Downloading..."
    Invoke-WebRequest -Uri $NodeUrl -OutFile $buildCacheNodeArchive
}
Write-Host "Extracting..."
Expand-Archive -Path $(if (Test-Path $environmentNodeArchive) { $environmentNodeArchive } else { $buildCacheNodeArchive }) -DestinationPath $DistDir -Force
Rename-Item -Path (Join-Path $DistDir $NodeZipName) -NewName "node"

# [2/6] 复制源码
Write-Host "`n[2/6] Copying OpenClaw source..."
$dstSrc = Join-Path $DistDir "openclaw"
Copy-SourceTree -SourceRoot $srcDir -DestinationRoot $dstSrc
$gitDir = Join-Path $dstSrc ".git"
if (Test-Path $gitDir) { Remove-Item $gitDir -Recurse -Force }
$nodeModulesDir = Join-Path $dstSrc "node_modules"
if (Test-Path $nodeModulesDir) {
    Write-Host "Removing copied source node_modules so the package is rebuilt cleanly..."
    Remove-Item -Path $nodeModulesDir -Recurse -Force
}

# [3/6] 复制启动器和共享文件
Write-Host "`n[3/6] Copying launchers and shared files..."
Get-ChildItem $launchersDir -File | Copy-Item -Destination $DistDir
Copy-Item -Path $portableScriptsDir -Destination (Join-Path $DistDir "scripts") -Recurse -Force
Copy-Item -Path $portableDataDir -Destination (Join-Path $DistDir "data") -Recurse -Force
if (Test-Path $portableReadme) {
    Copy-Item $portableReadme -Destination $DistDir
}
if (Test-DirectoryHasContent -Path $portableBrowsersDir) {
    Write-Host "Copying prebuilt Playwright browsers..."
    Copy-Item -Path $portableBrowsersDir -Destination (Join-Path $DistDir "browsers") -Recurse -Force
} elseif (Test-DirectoryHasContent -Path $environmentBrowsersDir) {
    if ([string]::IsNullOrWhiteSpace($customEnvironmentBrowsersDir)) {
        Write-Host "Copying reusable environment Playwright browsers..."
    } else {
        Write-Host "Copying Playwright browsers from custom cache: $environmentBrowsersDir"
    }
    Copy-Item -Path $environmentBrowsersDir -Destination (Join-Path $DistDir "browsers") -Recurse -Force
} elseif (-not [string]::IsNullOrWhiteSpace($customEnvironmentBrowsersDir)) {
    Write-Warning "Requested Playwright browser cache path has no content: $environmentBrowsersDir"
}
if ($null -ne $minGitArchive) {
    $gitTarget = Join-Path $DistDir "git"
    Write-Host "Extracting reusable MinGit runtime..."
    Expand-ArchiveToTargetRoot -ArchivePath $minGitArchive.FullName -TargetRoot $gitTarget
} else {
    Write-Warning "No reusable MinGit archive found under $environmentDownloadsDir. Compatibility update script will not have an embedded Git runtime."
}

# 创建目录结构
@("browsers", "data\workspace") | ForEach-Object {
    $p = Join-Path $DistDir $_
    if (-Not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

# [4/6] 安装依赖 (fat 模式)
if ($Mode -eq "fat") {
    Write-Host "`n[4/6] Installing dependencies (fat mode)..."
    $env:PATH = "$nodeTarget;" + $env:PATH
    $env:npm_config_prefix = $nodeTarget
    $storeDir = Join-Path $DistDir "temp-pnpm-store"
    $env:PNPM_STORE_DIR = $storeDir

    Push-Location $dstSrc
    try {
        & "$nodeTarget\npm.cmd" install -g pnpm --registry=https://registry.npmmirror.com
        Assert-LastExitCode -Description "pnpm bootstrap"
        & "$nodeTarget\pnpm.cmd" install --registry=https://registry.npmmirror.com --ignore-scripts --store-dir $storeDir
        Assert-LastExitCode -Description "dependency installation"
    }
    finally {
        Pop-Location
    }

    # [5/6] 平台瘦身
    Write-Host "`n[5/6] Pruning non-$Platform packages..."
    $pruneScript = Join-Path $WorkingDir "prune-platform.js"
    $nmPath = Join-Path $dstSrc "node_modules"
    & "$nodeTarget\node.exe" $pruneScript --platform $Platform --arch $Arch --path $nmPath
    Assert-LastExitCode -Description "platform prune"

    if (Test-Path $storeDir) {
        Remove-Item $storeDir -Recurse -Force
        Write-Host "Removed temp pnpm store"
    }
} else {
    Write-Host "`n[4/6] Skipping dependency install (slim mode)"
    Write-Host "[5/6] Skipping platform prune (slim mode)"
}

# [6/6] 修复编码
Write-Host "`n[6/6] Fixing .bat encoding (UTF-8 BOM + CRLF)..."
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
Get-ChildItem -Path $DistDir -Filter "*.bat" | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    $content = $content -replace "`r`n", "`n" -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($_.FullName, $content, $utf8Bom)
    Write-Host "Fixed: $($_.Name)"
}

if (Test-DirectoryHasContent -Path (Join-Path $DistDir "browsers")) {
    Write-Host "Bundled prebuilt Playwright browsers."
} else {
    Write-Warning "No prebuilt Playwright browsers were bundled. This package can still be built, but it is not yet a true novice-friendly offline release."
}

Write-Host "`n=========================================="
Write-Host "Build complete: $DistName"
Write-Host "Output: $DistDir"
Write-Host "=========================================="
