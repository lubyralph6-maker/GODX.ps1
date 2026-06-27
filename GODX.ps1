param(
    [string]$ExeUrl = 'https://raw.githubusercontent.com/lubyralph6-maker/GODX.ps1/main/Privy64.exe',
    [string]$ScriptUrl = 'https://raw.githubusercontent.com/lubyralph6-maker/GODX.ps1/main/GODX.ps1'
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:MarkerDir = Join-Path $env:LOCALAPPDATA 'GODX-BUILDS'
$script:MarkerFile = Join-Path $script:MarkerDir '.launcher_paths'

function Register-CleanupPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        if (-not (Test-Path $script:MarkerDir)) {
            New-Item -ItemType Directory -Path $script:MarkerDir -Force | Out-Null
        }
        Add-Content -Path $script:MarkerFile -Value $Path -Encoding UTF8
    } catch {}
}

function Invoke-LauncherCleanup {
    param([string[]]$ExtraPaths = @())

    foreach ($p in $ExtraPaths) {
        Register-CleanupPath $p
    }

    if ($PSCommandPath -and ($PSCommandPath.StartsWith($env:TEMP, [System.StringComparison]::OrdinalIgnoreCase))) {
        Register-CleanupPath $PSCommandPath
    }

    $paths = @()
    if (Test-Path $script:MarkerFile) {
        try { $paths = Get-Content $script:MarkerFile -ErrorAction SilentlyContinue } catch {}
    }

    foreach ($p in $paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        try {
            if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
        } catch {}
    }

    $tempRoots = @($env:TEMP)
    $localTemp = Join-Path $env:LOCALAPPDATA 'Temp'
    if (Test-Path $localTemp) { $tempRoots += $localTemp }

    foreach ($root in $tempRoots) {
        foreach ($glob in @('godx_*.ps1', 'god_*.ps1', 'GODX_run.ps1', 'GOD_run.ps1', 'run.ps1', 'god.tmp', 'g.ps1', 'ps-script-*.ps1')) {
            Get-ChildItem -Path $root -Filter $glob -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'GODX|GOD|Privy64|privy64|godxproject|GODX-BUILDS|Libery32|libery32|godx_|god_|l32_' } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    try {
        if (Test-Path $script:MarkerFile) { Remove-Item $script:MarkerFile -Force -ErrorAction SilentlyContinue }
    } catch {}

    $self = $PSCommandPath
    if ($self -and (Test-Path $self) -and ($self.StartsWith($env:TEMP, [System.StringComparison]::OrdinalIgnoreCase))) {
        try {
            Start-Process cmd.exe -WindowStyle Hidden -ArgumentList @(
                '/c', ('timeout /t 2 /nobreak >nul & del /f /q "' + $self + '"')
            ) | Out-Null
        } catch {}
    }
}

function Clear-LauncherHistory {
    param([string]$ExtraPattern = '')

    $historyPattern = 'discord|cmd|godx|GODX|god|GOD|Privy64|privy64|godxproject|GODX-BUILDS|Champions|libery32|Libery32|godx_|god_|l32_|irm|iex|Invoke-WebRequest|Invoke-RestMethod|WebClient|DownloadFile|OutFile|UseBasicParsing|raw\.githubusercontent|lubyralph6-maker|ExecutionPolicy|powershell.*bypass|Start-Process.*powershell|Remove-Item|del /f|timeout /t|launcher_paths|Invoke-LauncherCleanup|wpn_scan|wpn_patch|wpn_float|original_aob|patch_value|keyauth|\.ps1|\.exe'
    if ($ExtraPattern) { $historyPattern += '|' + $ExtraPattern }

    $historyPaths = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'),
        (Join-Path $env:APPDATA 'Microsoft\PowerShell\PSReadLine\ConsoleHost_history.txt'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt')
    )

    foreach ($historyPath in $historyPaths) {
        if (-not (Test-Path $historyPath)) { continue }
        try {
            $keep = Get-Content $historyPath -ErrorAction SilentlyContinue |
                Where-Object { $_ -and ($_ -notmatch $historyPattern) }
            if ($null -eq $keep) { $keep = @() }
            $keep | Set-Content -Path $historyPath -Encoding UTF8
        } catch {}
    }

    try { Clear-History -ErrorAction SilentlyContinue } catch {}
}

function Clear-LauncherPrefetch {
    param([string]$RandomName = '')

    try {
        if ($RandomName) {
            Remove-Item ('C:\Windows\Prefetch\*' + $RandomName + '*') -Force -ErrorAction SilentlyContinue
        }
        Remove-Item 'C:\Windows\Prefetch\*PRIVY64*' -Force -ErrorAction SilentlyContinue
        Remove-Item 'C:\Windows\Prefetch\*LIBERY32*' -Force -ErrorAction SilentlyContinue
        Remove-Item 'C:\Windows\Prefetch\POWERSHELL.EXE*.pf' -Force -ErrorAction SilentlyContinue
        Remove-Item 'C:\Windows\Prefetch\PWSH.EXE*.pf' -Force -ErrorAction SilentlyContinue
        Remove-Item 'C:\Windows\Prefetch\CMD.EXE*.pf' -Force -ErrorAction SilentlyContinue
        Remove-Item 'C:\Windows\Prefetch\CONHOST.EXE*.pf' -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Download-FreshExe {
    param(
        [string]$Url,
        [string]$Destination
    )

    $cacheBust = $Url + '?cb=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $client = New-Object Net.WebClient
    $client.Headers.Add('Cache-Control', 'no-cache')
    $client.Headers.Add('Pragma', 'no-cache')
    $client.DownloadFile($cacheBust, $Destination)
}

function Start-ElevatedSelf {
    $tmp = Join-Path $env:TEMP ('godx_' + [guid]::NewGuid().ToString('N') + '.ps1')
    Register-CleanupPath $tmp
    Download-FreshExe $ScriptUrl $tmp
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-nop', '-ep', 'bypass', '-NoExit', '-File', $tmp)
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'Requesting Administrator...' -ForegroundColor Cyan
    Start-ElevatedSelf
    exit
}

try { Remove-Module PSReadLine -ErrorAction SilentlyContinue } catch {}

$randomName = -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
$tempExe = Join-Path $env:TEMP ($randomName + '.exe')
Register-CleanupPath $tempExe

$downloaded = $false
foreach ($url in @($ExeUrl)) {
    if ([string]::IsNullOrWhiteSpace($url)) { continue }
    try {
        Write-Host ('Downloading: ' + $url) -ForegroundColor Cyan
        Download-FreshExe $url $tempExe
        if ((Test-Path $tempExe) -and ((Get-Item $tempExe).Length -gt 100000)) {
            $downloaded = $true
            break
        }
        Remove-Item $tempExe -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host ('Failed: ' + $url) -ForegroundColor Yellow
        Remove-Item $tempExe -Force -ErrorAction SilentlyContinue
    }
}

if (-not $downloaded) {
    Write-Host 'Download failed. Upload Privy64.exe to GitHub first.' -ForegroundColor Red
    Clear-LauncherHistory -ExtraPattern $randomName
    Clear-LauncherPrefetch -RandomName $randomName
    Invoke-LauncherCleanup
    Read-Host 'Press Enter to close'
    exit 1
}

Write-Host 'Downloaded Privy64' -ForegroundColor Green
$proc = Start-Process -FilePath $tempExe -PassThru
$proc.WaitForExit()
Start-Sleep -Seconds 2

for ($i = 1; $i -le 8; $i++) {
    try {
        if (Test-Path $tempExe) {
            Remove-Item $tempExe -Force -ErrorAction Stop
            Write-Host 'Deleted' -ForegroundColor Green
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (Test-Path $tempExe) {
    try {
        Start-Process cmd.exe -WindowStyle Hidden -ArgumentList @(
            '/c', ('timeout /t 3 /nobreak >nul & del /f /q "' + $tempExe + '"')
        ) | Out-Null
    } catch {}
}

Clear-LauncherHistory -ExtraPattern $randomName
Clear-LauncherPrefetch -RandomName $randomName
Invoke-LauncherCleanup

Write-Host 'Finished' -ForegroundColor Green
Read-Host 'Press Enter to close'
