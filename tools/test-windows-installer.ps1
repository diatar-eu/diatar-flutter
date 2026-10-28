#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Installer,
    [Parameter(Mandatory)][string]$SenderBundle,
    [Parameter(Mandatory)][string]$ReceiverBundle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') {
    throw 'Run this installation/uninstallation smoke test only on a disposable GitHub Actions runner.'
}
$Installer = (Resolve-Path -LiteralPath $Installer).Path
$installDir = Join-Path $env:RUNNER_TEMP 'diatar-installer-smoke'
$logDir = Join-Path $env:RUNNER_TEMP 'diatar-installer-logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (Test-Path -LiteralPath $installDir) {
    throw "Smoke test destination already exists: $installDir"
}

function Invoke-Setup([string]$Executable, [string[]]$SetupArguments) {
    $process = Start-Process -FilePath $Executable -ArgumentList $SetupArguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "Setup failed ($($process.ExitCode)): $Executable $SetupArguments"
    }
}

function Assert-Bundle([string]$Source, [string]$Destination) {
    $Source = (Resolve-Path -LiteralPath $Source).Path
    foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File) {
        $installed = Join-Path $Destination ([IO.Path]::GetRelativePath($Source, $file.FullName))
        if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) {
            throw "Missing installed file: $installed"
        }
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $installed).Hash) {
            throw "Installed file differs from release bundle: $installed"
        }
    }
}

function Uninstall-Suite([string]$Name) {
    Invoke-Setup (Join-Path $installDir 'unins000.exe') @(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART',
        "/LOG=`"$logDir\$Name-uninstall.log`""
    )
    foreach ($app in @('Diatar', 'DiaVetito')) {
        if (Test-Path -LiteralPath (Join-Path $installDir $app)) {
            throw "Uninstall left application files behind: $app"
        }
    }
}

$emptySelection = Start-Process -FilePath $Installer -Wait -PassThru -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    "/DIR=`"$installDir`"", '/TYPE=custom', '/COMPONENTS=""',
    "/LOG=`"$logDir\empty-selection.log`""
)
if ($emptySelection.ExitCode -eq 0 -or (Test-Path -LiteralPath (Join-Path $installDir 'unins000.exe'))) {
    throw 'Setup accepted an empty component selection.'
}

# Test a sender-only install, an upgrade adding the receiver, then a fresh receiver-only install.
foreach ($type in @('sender', 'full', 'receiver')) {
    $language = if ($type -eq 'receiver') { 'en' } else { 'hu' }
    Invoke-Setup $Installer @(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
        "/DIR=`"$installDir`"", "/TYPE=$type", "/LANG=$language", '/TASKS=',
        "/LOG=`"$logDir\$type-install.log`""
    )
    if ($type -ne 'receiver') {
        Assert-Bundle $SenderBundle (Join-Path $installDir 'Diatar')
    } elseif (Test-Path -LiteralPath (Join-Path $installDir 'Diatar')) {
        throw 'Receiver-only installation unexpectedly installed the sender.'
    }
    if ($type -ne 'sender') {
        Assert-Bundle $ReceiverBundle (Join-Path $installDir 'DiaVetito')
    } elseif (Test-Path -LiteralPath (Join-Path $installDir 'DiaVetito')) {
        throw 'Sender-only installation unexpectedly installed the receiver.'
    }
    if ($type -ne 'sender') {
        Uninstall-Suite $type
    }
}
Write-Host 'Installer component selection, upgrade, payload hashes, and uninstall passed.'
