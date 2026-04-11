# install.ps1 - 自动检测系统架构并从中南大学 VPN 门户下载最新 aTrust 客户端 (Windows)
# Auto-detect architecture and download the latest CSU VPN aTrust client for Windows
# Download page: https://vpn.csu.edu.cn/portal/#/down_client_new?moreClient=1
#
# Run from an elevated (Administrator) PowerShell prompt:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\install.ps1

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$PORTAL_URL     = 'https://vpn.csu.edu.cn'
$DOWNLOAD_PAGE  = "$PORTAL_URL/portal/#/down_client_new?moreClient=1"
$ATRUST_CLIENT  = 'aTrust_windows'
$ATRUST_VERSION = '2.5.16.20'

# Detect CPU architecture
function Get-Arch {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { return 'x86_64' }
        'ARM64' { return 'arm64'  }
        'x86'   {
            # Could be a 32-bit shell on a 64-bit OS
            if ($env:PROCESSOR_ARCHITEW6432 -eq 'AMD64') { return 'x86_64' }
            return 'x86'
        }
        default { return '' }
    }
}

# Try to get a download URL from portal REST API
function Get-UrlFromApi {
    param([string]$Client)

    $endpoints = @(
        "/portal/api/v1/download/client?name=$Client&os=windows",
        "/portal/api/v2/client/download?name=$Client&platform=windows",
        "/portal/api/download/client?clientType=$Client",
        "/portal/api/client/download?type=$Client"
    )

    foreach ($ep in $endpoints) {
        try {
            $resp = Invoke-RestMethod -Uri "$PORTAL_URL$ep" -TimeoutSec 10 -ErrorAction Stop
            $url  = if ($resp.url)          { $resp.url }
                    elseif ($resp.download_url) { $resp.download_url }
                    elseif ($resp.file_url)     { $resp.file_url }
                    elseif ($resp.downloadUrl)  { $resp.downloadUrl }
                    else                        { $null }
            if ($url) { return $url }
        } catch { continue }
    }
    return $null
}

# Fallback: scrape portal JS bundles for embedded installer URLs
function Get-UrlFromPortalJs {
    param([string]$Client)

    try {
        $html    = Invoke-WebRequest -Uri "$PORTAL_URL/portal/" -TimeoutSec 10 `
                       -UseBasicParsing -ErrorAction Stop
        $jsPaths = [regex]::Matches($html.Content, 'src="([^"]+\.js)"') |
                   ForEach-Object { $_.Groups[1].Value } |
                   Select-Object -First 10

        foreach ($jsPath in $jsPaths) {
            $jsUrl = if ($jsPath -match '^http') { $jsPath } else { "$PORTAL_URL/portal/$jsPath" }
            try {
                $js = Invoke-WebRequest -Uri $jsUrl -TimeoutSec 10 `
                          -UseBasicParsing -ErrorAction Stop
                $m  = [regex]::Match($js.Content,
                          "https?://[^'`"``\s]*$([regex]::Escape($Client))[^'`"``\s]*\.(exe|msi)")
                if ($m.Success) { return $m.Value }
            } catch { continue }
        }
    } catch {}
    return $null
}

# Build and probe candidate download URLs
function Get-UrlFromCandidates {
    param([string]$Client, [string]$Version, [string]$Arch)

    $exts     = @('exe', 'msi')
    $patterns = @(
        "$PORTAL_URL/portal/download/$Client/$Version/${Client}_${Version}.{0}",
        "$PORTAL_URL/portal/download/$Client/$Version/${Client}_${Version}_${Arch}.{0}",
        "$PORTAL_URL/portal/download/$Client/$Version/${Client}-${Version}.{0}",
        "$PORTAL_URL/portal/download/$Client/$Version/${Client}-${Version}-${Arch}.{0}",
        "$PORTAL_URL/download/$Client/$Version/${Client}_${Version}.{0}",
        "$PORTAL_URL/download/$Client/$Version/${Client}_${Version}_${Arch}.{0}",
        "$PORTAL_URL/portal/api/download?name=$Client&version=$Version",
        "$PORTAL_URL/portal/clientdownload?type=$Client&version=$Version"
    )

    foreach ($pat in $patterns) {
        foreach ($ext in $exts) {
            $url = $pat -f $ext
            try {
                $resp = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 8 `
                            -UseBasicParsing -ErrorAction Stop
                if ($resp.StatusCode -in 200, 301, 302) { return $url }
            } catch { continue }
        }
    }
    return $null
}

# Install a downloaded package
function Install-Package {
    param([string]$FilePath, [string]$Ext)

    switch ($Ext) {
        'msi' {
            Write-Host "Installing .msi package..."
            $proc = Start-Process -FilePath 'msiexec.exe' `
                        -ArgumentList "/i `"$FilePath`" /qn /norestart" `
                        -PassThru -Wait
            if ($proc.ExitCode -notin 0, 3010) {
                throw "msiexec exited with code $($proc.ExitCode)."
            }
        }
        default {
            Write-Host "Running .exe installer..."
            $proc = Start-Process -FilePath $FilePath `
                        -ArgumentList '/S' `
                        -PassThru -Wait
            if ($proc.ExitCode -notin 0, 3010) {
                throw "Installer exited with code $($proc.ExitCode)."
            }
        }
    }
}

# Main logic
function Main {
    $arch = Get-Arch
    if (-not $arch) {
        Write-Error "Unsupported processor architecture: $($env:PROCESSOR_ARCHITECTURE)"
        Write-Host "Please visit $DOWNLOAD_PAGE to download manually."
        exit 1
    }

    Write-Host "Operating system : Windows"
    Write-Host "Architecture     : $($env:PROCESSOR_ARCHITECTURE) ($arch)"
    Write-Host "Target client    : $ATRUST_CLIENT v$ATRUST_VERSION"
    Write-Host "Fetching download URL from $PORTAL_URL ..."

    $downloadUrl = Get-UrlFromApi -Client $ATRUST_CLIENT
    if (-not $downloadUrl) {
        $downloadUrl = Get-UrlFromPortalJs -Client $ATRUST_CLIENT
    }
    if (-not $downloadUrl) {
        $downloadUrl = Get-UrlFromCandidates -Client $ATRUST_CLIENT `
                           -Version $ATRUST_VERSION -Arch $arch
    }

    if (-not $downloadUrl) {
        Write-Host ""
        Write-Error "Could not automatically locate the download URL."
        Write-Host "Please visit the download page and install manually:"
        Write-Host "  $DOWNLOAD_PAGE"
        Write-Host "Look for the aTrust Windows client."
        exit 1
    }

    if (-not ($downloadUrl -match '^http')) {
        $downloadUrl = "$PORTAL_URL$downloadUrl"
    }

    $ext     = if ($downloadUrl -match '\.(exe|msi)$') { $Matches[1] } else { 'exe' }
    $tmpFile = Join-Path $env:TEMP "csu-vpn-install.$ext"

    Write-Host "Downloading: $downloadUrl"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpFile -UseBasicParsing

    Install-Package -FilePath $tmpFile -Ext $ext

    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    Write-Host "Installation complete."
}

Main
