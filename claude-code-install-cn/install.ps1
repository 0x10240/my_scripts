[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "ClaudeCodeCN"),
    [string]$NodeMirrorBaseUrl = "https://npmmirror.com/mirrors/node",
    [string]$NpmRegistry = "https://registry.npmmirror.com",
    [string]$PackageName = "@anthropic-ai/claude-code",
    [switch]$InstallGit,
    [string]$BaseUrl,
    [string]$AuthToken,
    [string]$ApiKey,
    [string]$CustomModel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Get-CommandPath {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }
    return $null
}

function Get-NodeMajorVersion {
    param([string]$VersionText)
    if ($VersionText -match "^v?(?<major>\d+)\.") {
        return [int]$Matches["major"]
    }
    return $null
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Add-ToUserPath {
    param([string]$PathToAdd)
    if ([string]::IsNullOrWhiteSpace($PathToAdd)) {
        return
    }

    $normalized = [System.IO.Path]::GetFullPath($PathToAdd.Trim())
    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @()
    if (-not [string]::IsNullOrWhiteSpace($currentUserPath)) {
        $entries = $currentUserPath.Split(";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    $alreadyExists = $false
    foreach ($entry in $entries) {
        try {
            if ([System.StringComparer]::OrdinalIgnoreCase.Equals([System.IO.Path]::GetFullPath($entry.Trim()), $normalized)) {
                $alreadyExists = $true
                break
            }
        } catch {
        }
    }

    if (-not $alreadyExists) {
        $newUserPath = if ([string]::IsNullOrWhiteSpace($currentUserPath)) {
            $normalized
        } else {
            "$currentUserPath;$normalized"
        }
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    }

    $processEntries = @()
    if (-not [string]::IsNullOrWhiteSpace($env:Path)) {
        $processEntries = $env:Path.Split(";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }
    $inProcess = $false
    foreach ($entry in $processEntries) {
        try {
            if ([System.StringComparer]::OrdinalIgnoreCase.Equals([System.IO.Path]::GetFullPath($entry.Trim()), $normalized)) {
                $inProcess = $true
                break
            }
        } catch {
        }
    }
    if (-not $inProcess) {
        $env:Path = if ([string]::IsNullOrWhiteSpace($env:Path)) {
            $normalized
        } else {
            "$normalized;$($env:Path)"
        }
    }
}

function Refresh-ProcessPath {
    $pathParts = @()
    foreach ($scope in @("Machine", "User")) {
        $scopePath = [Environment]::GetEnvironmentVariable("Path", $scope)
        if (-not [string]::IsNullOrWhiteSpace($scopePath)) {
            $pathParts += $scopePath.Split(";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }
    }
    $env:Path = ($pathParts | Select-Object -Unique) -join ";"
}

function Set-UserEnvironmentVariable {
    param(
        [string]$Name,
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    Set-Item -Path "Env:$Name" -Value $Value
    Write-Info "Saved user environment variable $Name"
}

function Get-LatestLtsNodeVersion {
    param([string]$RequiredFileKey)
    $indexUrl = "$NodeMirrorBaseUrl/index.json"
    $releases = Invoke-RestMethod -Uri $indexUrl -UseBasicParsing
    $match = $releases |
        Where-Object { $_.lts -and ($_.files -contains $RequiredFileKey) } |
        Select-Object -First 1

    if (-not $match) {
        throw "Could not find a Node.js LTS release for $RequiredFileKey from $indexUrl."
    }

    return [string]$match.version
}

function Find-GitExePath {
    $commandPath = Get-CommandPath -Candidates @("git.exe", "git")
    if ($commandPath) {
        return $commandPath
    }

    $candidatePaths = @(
        (Join-Path $env:ProgramFiles "Git\cmd\git.exe"),
        (Join-Path $env:ProgramFiles "Git\bin\git.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Git\cmd\git.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Git\cmd\git.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\git.exe")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    return $candidatePaths | Select-Object -First 1
}

function Find-GitBashPath {
    if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_CODE_GIT_BASH_PATH) -and (Test-Path -LiteralPath $env:CLAUDE_CODE_GIT_BASH_PATH)) {
        return [System.IO.Path]::GetFullPath($env:CLAUDE_CODE_GIT_BASH_PATH)
    }

    $candidatePaths = @(
        (Join-Path $env:ProgramFiles "Git\bin\bash.exe"),
        (Join-Path $env:ProgramFiles "Git\usr\bin\bash.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Git\bin\bash.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Git\usr\bin\bash.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Git\usr\bin\bash.exe")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    return $candidatePaths | Select-Object -First 1
}

function Get-WindowsArchitecture {
    $candidates = @(
        $env:PROCESSOR_ARCHITEW6432,
        $env:PROCESSOR_ARCHITECTURE
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        switch ($candidate.Trim().ToUpperInvariant()) {
            "AMD64" { return "X64" }
            "X64" { return "X64" }
            "X86_64" { return "X64" }
            "ARM64" { return "Arm64" }
        }
    }

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        switch ([int]$cpu.Architecture) {
            9 { return "X64" }
            12 { return "Arm64" }
        }
    } catch {
    }

    if ([Environment]::Is64BitOperatingSystem) {
        return "X64"
    }

    throw "Unsupported Windows architecture. Only x64 and arm64 are supported."
}

function Ensure-WindowsGit {
    param([switch]$AutoInstall)

    $gitExePath = Find-GitExePath
    $gitBashPath = Find-GitBashPath

    if (-not $gitExePath -or -not $gitBashPath) {
        if (-not $AutoInstall) {
            Write-WarnLine "git/git-bash was not found. Claude Code on Windows requires Git Bash."
            Write-WarnLine "Install Git for Windows manually, or rerun this script with -InstallGit."
            $wingetPath = Get-CommandPath -Candidates @("winget.exe", "winget")
            if ($wingetPath) {
                Write-WarnLine "Optional command: winget install Git.Git"
            }
            return $false
        }

        $wingetPath = Get-CommandPath -Candidates @("winget.exe", "winget")
        if (-not $wingetPath) {
            throw "Git for Windows is required on Windows, but git was not found and winget is unavailable. Install Git from https://git-scm.com/download/win and rerun this script."
        }

        Write-WarnLine "git was not found. Installing Git for Windows with winget."
        & $wingetPath install --id Git.Git --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        Refresh-ProcessPath

        $gitExePath = Find-GitExePath
        $gitBashPath = Find-GitBashPath
    }

    if (-not $gitExePath) {
        throw "Git for Windows installation finished, but git.exe was still not found."
    }

    $gitCmdDir = Split-Path -Parent $gitExePath
    if (-not (Get-CommandPath -Candidates @("git.exe", "git"))) {
        Add-ToUserPath -PathToAdd $gitCmdDir
    }

    if (-not $gitBashPath) {
        throw "Git for Windows installation finished, but bash.exe was still not found. Set CLAUDE_CODE_GIT_BASH_PATH manually if Git is installed in a custom location."
    }

    Set-UserEnvironmentVariable -Name "CLAUDE_CODE_GIT_BASH_PATH" -Value $gitBashPath
    & $gitExePath --version | Out-Null
    Write-Success "Git for Windows is ready"
    return $true
}

function Install-PortableNode {
    Ensure-Directory -Path $InstallRoot

    $osArchitecture = Get-WindowsArchitecture
    switch ($osArchitecture) {
        "X64" {
            $requiredFileKey = "win-x64-zip"
            $archiveName = { param($version) "node-$version-win-x64.zip" }
        }
        "Arm64" {
            $requiredFileKey = "win-arm64-zip"
            $archiveName = { param($version) "node-$version-win-arm64.zip" }
        }
        default {
            throw "Unsupported Windows architecture: $osArchitecture"
        }
    }

    $nodeVersion = Get-LatestLtsNodeVersion -RequiredFileKey $requiredFileKey
    $archiveFileName = & $archiveName $nodeVersion
    $downloadUrl = "$NodeMirrorBaseUrl/$nodeVersion/$archiveFileName"
    $downloadPath = Join-Path $env:TEMP $archiveFileName
    $extractRoot = Join-Path $InstallRoot "tmp-node"
    $finalNodeDir = Join-Path $InstallRoot "node"

    Write-Info "No usable Node.js found. Installing portable Node.js $nodeVersion from the CN mirror."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing

    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    Ensure-Directory -Path $extractRoot
    Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractRoot -Force

    $expandedDir = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
    if (-not $expandedDir) {
        throw "Node.js extraction failed: extracted directory not found."
    }

    if (Test-Path -LiteralPath $finalNodeDir) {
        Remove-Item -LiteralPath $finalNodeDir -Recurse -Force
    }
    Move-Item -LiteralPath $expandedDir.FullName -Destination $finalNodeDir

    Remove-Item -LiteralPath $extractRoot -Recurse -Force
    Remove-Item -LiteralPath $downloadPath -Force

    return $finalNodeDir
}

function Resolve-NodeToolchain {
    $systemNode = Get-CommandPath -Candidates @("node.exe", "node")
    $systemNpm = Get-CommandPath -Candidates @("npm.cmd", "npm")

    if ($systemNode -and $systemNpm) {
        $versionText = & $systemNode --version
        $major = Get-NodeMajorVersion -VersionText $versionText
        if ($null -ne $major -and $major -ge 18) {
            Write-Info "Detected system Node.js $versionText"
            return @{
                NodePath   = $systemNode
                NpmPath    = $systemNpm
                NodeHome   = Split-Path -Parent $systemNode
                IsPortable = $false
            }
        }

        Write-WarnLine "System Node.js version is $versionText, below Claude Code's >= 18 requirement. Installing a portable Node.js."
    } else {
        Write-WarnLine "Node.js/npm not found. Installing a portable Node.js."
    }

    $portableNodeDir = Install-PortableNode
    return @{
        NodePath   = Join-Path $portableNodeDir "node.exe"
        NpmPath    = Join-Path $portableNodeDir "npm.cmd"
        NodeHome   = $portableNodeDir
        IsPortable = $true
    }
}

try {
    Write-Info "Install root: $InstallRoot"
    Ensure-Directory -Path $InstallRoot

    $gitReady = Ensure-WindowsGit -AutoInstall:$InstallGit

    $toolchain = Resolve-NodeToolchain
    $nodePath = $toolchain.NodePath
    $npmPath = $toolchain.NpmPath
    $nodeHome = $toolchain.NodeHome
    $isPortableNode = [bool]$toolchain.IsPortable

    $prefixDir = Join-Path $InstallRoot "npm-global"
    $cacheDir = Join-Path $InstallRoot "npm-cache"
    Ensure-Directory -Path $prefixDir
    Ensure-Directory -Path $cacheDir

    if ($isPortableNode) {
        Add-ToUserPath -PathToAdd $nodeHome
    }
    Add-ToUserPath -PathToAdd $prefixDir

    $env:NPM_CONFIG_REGISTRY = $NpmRegistry
    $env:NPM_CONFIG_PREFIX = $prefixDir
    $env:NPM_CONFIG_CACHE = $cacheDir
    $env:NPM_CONFIG_UPDATE_NOTIFIER = "false"
    $env:NPM_CONFIG_FUND = "false"
    $env:NPM_CONFIG_AUDIT = "false"

    Write-Info "Installing $PackageName from the CN npm mirror"
    & $npmPath install --global $PackageName --prefix $prefixDir --registry $NpmRegistry --cache $cacheDir --no-fund --no-audit

    $claudeCmd = Join-Path $prefixDir "claude.cmd"
    if (-not (Test-Path -LiteralPath $claudeCmd)) {
        throw "Install completed but $claudeCmd was not found."
    }

    $claudePs1 = Join-Path $prefixDir "claude.ps1"
    if (Test-Path -LiteralPath $claudePs1) {
        Remove-Item -LiteralPath $claudePs1 -Force
        Write-Info "Removed claude.ps1 so PowerShell resolves claude.cmd"
    }

    Set-UserEnvironmentVariable -Name "ANTHROPIC_BASE_URL" -Value $BaseUrl
    Set-UserEnvironmentVariable -Name "ANTHROPIC_AUTH_TOKEN" -Value $AuthToken
    Set-UserEnvironmentVariable -Name "ANTHROPIC_API_KEY" -Value $ApiKey
    Set-UserEnvironmentVariable -Name "ANTHROPIC_CUSTOM_MODEL_OPTION" -Value $CustomModel

    $claudeVersion = & $claudeCmd --version
    Write-Success "Claude Code installed successfully: $claudeVersion"

    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Reopen your terminal, or run: `$env:Path = `"$env:Path`""
    if (-not $gitReady) {
        Write-Host "2. Install Git for Windows, or rerun this script with -InstallGit."
        Write-Host "3. Run: claude"
    } else {
        Write-Host "2. Run: claude"
    }
    if ([string]::IsNullOrWhiteSpace($BaseUrl) -and [string]::IsNullOrWhiteSpace($AuthToken) -and [string]::IsNullOrWhiteSpace($ApiKey)) {
        if (-not $gitReady) {
            Write-Host "4. If you use a CN gateway/proxy, rerun this script with -BaseUrl plus -AuthToken or -ApiKey."
        } else {
            Write-Host "3. If you use a CN gateway/proxy, rerun this script with -BaseUrl plus -AuthToken or -ApiKey."
        }
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] Install failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
