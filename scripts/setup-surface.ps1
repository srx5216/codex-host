[CmdletBinding()]
param(
    [switch]$SkipPathUpdate
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or newer is required. Run this script with pwsh.exe.'
}

if ($env:OS -ne 'Windows_NT') {
    throw 'This profile is for the Windows Surface host only.'
}

$desktop = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($null -eq $desktop) {
    throw 'OpenAI.Codex (Codex Desktop) was not found in the current Windows user profile.'
}

$globalPrefix = (npm prefix -g).Trim()
if ([string]::IsNullOrWhiteSpace($globalPrefix) -or -not (Test-Path -LiteralPath $globalPrefix)) {
    throw 'Could not resolve the npm global prefix.'
}

$codexHostBin = Join-Path $env:LOCALAPPDATA 'Programs\codexhost\bin'
if (-not (Test-Path -LiteralPath $codexHostBin -PathType Container)) {
    throw "CodexHost was not found at the expected per-user install path: $codexHostBin"
}

$piCommand = Join-Path $globalPrefix 'pi.cmd'
$claudeCommand = Join-Path $globalPrefix 'claude.cmd'
foreach ($candidate in @($piCommand, $claudeCommand)) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Required harness command was not found: $candidate"
    }
}

function Set-UserEnvironmentValue {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Value
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path "Env:$Name" -Value $Value
}

Set-UserEnvironmentValue -Name 'CODEXHOST_PI_COMMAND' -Value $piCommand
Set-UserEnvironmentValue -Name 'CODEXHOST_CLAUDE_COMMAND' -Value $claudeCommand

if (-not $SkipPathUpdate) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathEntries = @(
        $userPath -split ';' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    $pathEntriesToAdd = @($globalPrefix, $codexHostBin) |
        Where-Object {
            $candidate = $_
            -not ($pathEntries | Where-Object { $_.TrimEnd('\') -ieq $candidate.TrimEnd('\') })
        }
    if ($pathEntriesToAdd.Count -gt 0) {
        $newUserPath = (($pathEntries + $pathEntriesToAdd) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        $env:Path = (($pathEntriesToAdd -join ';') + ';' + $env:Path)
    }
}

# AppX Codex Desktop is auto-discovered by codexhost. Do not set
# CODEXHOST_INSTALL_ROOT for this installation type.
Write-Output ('Codex Desktop: ' + $desktop.Version + ' (' + $desktop.InstallLocation + ')')
Write-Output ('Pi command: ' + $piCommand)
Write-Output ('Claude Code command: ' + $claudeCommand)
Write-Output ('CodexHost binary: ' + (Join-Path $codexHostBin 'codexhost.exe'))
Write-Output 'Persisted: CODEXHOST_PI_COMMAND, CODEXHOST_CLAUDE_COMMAND'
Write-Output 'CODEXHOST_INSTALL_ROOT: not set (AppX auto-discovery)'
