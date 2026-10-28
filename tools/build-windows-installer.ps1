#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SenderBundle,
    [Parameter(Mandatory)][string]$ReceiverBundle,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\windows-installer'),
    [string]$IsccPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$SenderBundle = (Resolve-Path -LiteralPath $SenderBundle).Path
$ReceiverBundle = (Resolve-Path -LiteralPath $ReceiverBundle).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

if (-not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) {
    throw "Inno Setup 6 compiler not found: $IsccPath"
}

$versions = foreach ($bundle in @(
    @{ Path = $SenderBundle; Exe = 'diatar_app.exe' },
    @{ Path = $ReceiverBundle; Exe = 'diavetito.exe' }
)) {
    foreach ($file in @($bundle.Exe, 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'data\flutter_assets\AssetManifest.bin')) {
        if (-not (Test-Path -LiteralPath (Join-Path $bundle.Path $file) -PathType Leaf)) {
            throw "Incomplete Windows release bundle: $($bundle.Path)\$file"
        }
    }
    $info = (Get-Item -LiteralPath (Join-Path $bundle.Path $bundle.Exe)).VersionInfo
    if ($info.ProductVersion -notmatch '^(\d+\.\d+\.\d+)\+(\d+)$') {
        throw "Unexpected application version: $($info.ProductVersion)"
    }
    @{ Version = $Matches[1]; FileVersion = "$($Matches[1]).$($Matches[2])" }
}
if ($versions[0].Version -ne $versions[1].Version) {
    throw 'The sender and receiver must have the same release version.'
}

# Keep installer translations in the same ARB source of truth as the sender UI.
$messagesDir = Join-Path $OutputDirectory 'messages'
New-Item -ItemType Directory -Force -Path $messagesDir | Out-Null
$template = Get-Content -LiteralPath (Join-Path $repoRoot 'Diatar\lib\l10n\app_hu.arb') -Raw | ConvertFrom-Json -AsHashtable
$keys = @($template.Keys | Where-Object { $_ -clike 'installer*' } | Sort-Object)
if ($keys.Count -eq 0) {
    throw 'Installer localization keys are missing.'
}
foreach ($language in @('hu', 'en')) {
    $arb = Get-Content -LiteralPath (Join-Path $repoRoot "Diatar\lib\l10n\app_$language.arb") -Raw | ConvertFrom-Json -AsHashtable
    $lines = @('[CustomMessages]')
    foreach ($key in $keys) {
        $text = $arb[$key]
        if ($text -isnot [string] -or [string]::IsNullOrWhiteSpace($text) -or $text -match '[\r\n]') {
            throw "Missing or invalid installer translation: $language.$key"
        }
        $lines += "$key=$text"
    }
    Set-Content -LiteralPath (Join-Path $messagesDir "$language.isl") -Value $lines -Encoding utf8BOM
}

$redist = Join-Path $OutputDirectory 'vc_redist.x64.exe'
$download = Join-Path $OutputDirectory 'vc_redist.download.exe'
Invoke-WebRequest -Uri 'https://aka.ms/vc14/vc_redist.x64.exe' -OutFile $download
$signature = Get-AuthenticodeSignature -LiteralPath $download
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(^|, )CN=Microsoft Corporation(,|$)') {
    Remove-Item -LiteralPath $download
    throw "The VC++ redistributable does not have a valid Microsoft signature: $($signature.Status)"
}
Move-Item -LiteralPath $download -Destination $redist -Force
$runtimeVersion = (Get-Item -LiteralPath $redist).VersionInfo
Write-Host "Bundling Microsoft VC++ $($runtimeVersion.FileVersion)"
Get-FileHash -LiteralPath $redist -Algorithm SHA256 | Format-List

$compilerArgs = @(
    "/DAppVersion=$($versions[0].Version)",
    "/DFileVersion=$($versions[0].FileVersion)",
    "/DSenderBundle=$SenderBundle",
    "/DReceiverBundle=$ReceiverBundle",
    "/DInstallerOutput=$OutputDirectory",
    "/DMessagesDir=$messagesDir",
    "/DVCRedist=$redist",
    "/DVCMajor=$($runtimeVersion.FileMajorPart)",
    "/DVCMinor=$($runtimeVersion.FileMinorPart)",
    "/DVCBuild=$($runtimeVersion.FileBuildPart)",
    "/DVCRevision=$($runtimeVersion.FilePrivatePart)",
    (Join-Path $repoRoot 'packaging\windows\diatar.iss')
)
& $IsccPath @compilerArgs
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}

$installer = Join-Path $OutputDirectory "Diatar-Setup-$($versions[0].Version)-windows-x64.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "Installer output not found: $installer"
}
Get-FileHash -LiteralPath $installer -Algorithm SHA256 | Format-List
Write-Host "Installer: $installer"
