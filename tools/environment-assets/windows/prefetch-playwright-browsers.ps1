param(
    [string]$OpenClawPath = "",
    [ValidateSet("all", "chromium")]
    [string]$BrowserSet = "all",
    [string]$OutputDir = "",
    [switch]$ForceInstall
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$ProgressPreference = "SilentlyContinue"

$ToolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ToolRoot "..\..\..")
$DownloadsDir = Join-Path $ToolRoot "downloads"
$NodeArchive = Get-ChildItem -Path $DownloadsDir -Filter "node-v*-win-x64.zip" | Sort-Object Name -Descending | Select-Object -First 1

function Resolve-BrowserCacheDir {
    param(
        [string]$PreferredPath,
        [string]$ToolRoot
    )

    if ([string]::IsNullOrWhiteSpace($PreferredPath)) {
        return (Join-Path $ToolRoot "playwright-browsers")
    }

    if ([System.IO.Path]::IsPathRooted($PreferredPath)) {
        return $PreferredPath
    }

    return (Join-Path $ToolRoot $PreferredPath)
}

function Get-ObjectPropertyValue {
    param(
        $Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Resolve-ExactPlaywrightVersion {
    param(
        [string]$PackageJsonPath
    )

    $packageJson = Get-Content -Encoding UTF8 -Raw $PackageJsonPath | ConvertFrom-Json
    $candidateSections = @(
        (Get-ObjectPropertyValue -Object $packageJson -PropertyName "dependencies"),
        (Get-ObjectPropertyValue -Object $packageJson -PropertyName "devDependencies")
    )
    $candidateNames = @("playwright", "playwright-core")

    foreach ($section in $candidateSections) {
        foreach ($candidateName in $candidateNames) {
            $version = Get-ObjectPropertyValue -Object $section -PropertyName $candidateName
            if (($version -is [string]) -and ($version -match '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')) {
                return $version
            }
        }
    }

    return ""
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
        if (-not (Test-Path (Join-Path $resolvedPreferredPath "package.json"))) {
            throw "[ERROR] package.json not found under OpenClaw source directory: $resolvedPreferredPath"
        }

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

$FinalBrowsersDir = Resolve-BrowserCacheDir -PreferredPath $OutputDir -ToolRoot $ToolRoot
$OpenClawPath = Resolve-OpenClawSourceDir -PreferredPath $OpenClawPath -RepoRoot $RepoRoot

if ($null -eq $NodeArchive) {
    throw "[ERROR] No cached Node.js archive found under $DownloadsDir. Run fetch-official-assets.ps1 first."
}

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("openclaw-playwright-prefetch-" + [guid]::NewGuid().ToString("N"))
$TempNodeRoot = Join-Path $TempRoot "runtime"
$TempStore = Join-Path $TempRoot "pnpm-store"
$StageBrowsersDir = Join-Path $TempRoot "playwright-browsers-stage"

Write-Host "Preparing temporary Node runtime from $($NodeArchive.Name)..."
New-Item -ItemType Directory -Force -Path $TempNodeRoot | Out-Null
New-Item -ItemType Directory -Force -Path $StageBrowsersDir | Out-Null
Expand-Archive -Path $NodeArchive.FullName -DestinationPath $TempNodeRoot -Force
$ExtractedNodeDir = Get-ChildItem -Path $TempNodeRoot -Directory | Select-Object -First 1
if ($null -eq $ExtractedNodeDir) {
    throw "[ERROR] Failed to extract a Node.js runtime from $($NodeArchive.FullName)"
}

$PortableNodeDir = $ExtractedNodeDir.FullName
$env:PATH = "$PortableNodeDir;" + $env:PATH
$env:npm_config_prefix = $PortableNodeDir
$env:PNPM_STORE_DIR = $TempStore
$env:PLAYWRIGHT_BROWSERS_PATH = $StageBrowsersDir
$playwrightCliArgs = @("install")
$nodeModulesDir = Join-Path $OpenClawPath "node_modules"
$cleanupInstalledNodeModules = $false
$TempPlaywrightCliRoot = Join-Path $TempRoot "playwright-cli"
$PlaywrightCliVersion = Resolve-ExactPlaywrightVersion -PackageJsonPath (Join-Path $OpenClawPath "package.json")
$OriginalPlaywrightSkipBrowserDownload = $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD

if ($BrowserSet -eq "chromium") {
    $playwrightCliArgs += "chromium"
}

Push-Location $OpenClawPath
try {
    Write-Host "Using OpenClaw source: $OpenClawPath"
    Write-Host "Browser set: $BrowserSet"
    Write-Host "Browser cache target: $FinalBrowsersDir"

    $pnpmCmd = Join-Path $PortableNodeDir "pnpm.cmd"
    $playwrightCmd = Join-Path $OpenClawPath "node_modules\.bin\playwright.cmd"
    if (-not (Test-Path $pnpmCmd)) {
        Write-Host "Installing pnpm into temporary portable Node..."
        & (Join-Path $PortableNodeDir "npm.cmd") install -g pnpm --registry=https://registry.npmmirror.com
        if ($LASTEXITCODE -ne 0) {
            throw "[ERROR] Failed to install pnpm into the temporary Node runtime."
        }
    }

    if ($ForceInstall -or -not (Test-Path (Join-Path $OpenClawPath "node_modules\.pnpm"))) {
        $cleanupInstalledNodeModules = -not (Test-Path $nodeModulesDir)
        if ((-not $ForceInstall) -and (-not [string]::IsNullOrWhiteSpace($PlaywrightCliVersion))) {
            Write-Host "Installing temporary Playwright CLI $PlaywrightCliVersion so browser prefetch matches the real app without a full dependency install..."
            New-Item -ItemType Directory -Force -Path $TempPlaywrightCliRoot | Out-Null
            $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"
            & (Join-Path $PortableNodeDir "npm.cmd") install --prefix $TempPlaywrightCliRoot "playwright@$PlaywrightCliVersion" --registry=https://registry.npmmirror.com
            $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = $OriginalPlaywrightSkipBrowserDownload
            if ($LASTEXITCODE -ne 0) {
                throw "[ERROR] Failed to install a temporary Playwright CLI."
            }

            $playwrightCmd = Join-Path $TempPlaywrightCliRoot "node_modules\.bin\playwright.cmd"
            if (-not (Test-Path $playwrightCmd)) {
                throw "[ERROR] Temporary Playwright CLI was installed, but playwright.cmd was not found."
            }
        } else {
            Write-Host "Installing project dependencies so Playwright version matches the real app..."
            & $pnpmCmd install --registry=https://registry.npmmirror.com --ignore-scripts --store-dir $TempStore
            if ($LASTEXITCODE -ne 0) {
                throw "[ERROR] Failed to install OpenClaw dependencies for browser prefetch."
            }
        }
    } else {
        Write-Host "Reusing existing project dependencies under $OpenClawPath"
    }

    Write-Host "Prefetching Playwright browsers into staging dir $StageBrowsersDir ..."
    if (Test-Path $playwrightCmd) {
        & $playwrightCmd @playwrightCliArgs
    } else {
        & $pnpmCmd exec playwright @playwrightCliArgs
    }
    if ($LASTEXITCODE -ne 0) {
        throw "[ERROR] Failed to prefetch Playwright browsers."
    }

    if (-not (Test-Path $FinalBrowsersDir)) {
        New-Item -ItemType Directory -Force -Path $FinalBrowsersDir | Out-Null
    }

    Get-ChildItem -Path $FinalBrowsersDir -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne ".gitkeep" } |
        Remove-Item -Recurse -Force

    Get-ChildItem -Path $StageBrowsersDir -Force |
        Copy-Item -Destination $FinalBrowsersDir -Recurse -Force
}
finally {
    Pop-Location
    $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = $OriginalPlaywrightSkipBrowserDownload
    if ($cleanupInstalledNodeModules -and (Test-Path $nodeModulesDir)) {
        Write-Host "Removing temporary node_modules created for browser prefetch..."
        Remove-Item -Path $nodeModulesDir -Recurse -Force
    }
    if (Test-Path $TempRoot) {
        Remove-Item -Path $TempRoot -Recurse -Force
    }
}

Write-Host ""
Write-Host "Playwright browser prefetch complete."
Write-Host "Browser cache dir: $FinalBrowsersDir"
