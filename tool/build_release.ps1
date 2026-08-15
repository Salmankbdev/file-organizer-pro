# Builds the File Organizer Pro release artifacts.
#
# Requirements:
#   - Flutter SDK (stable) on PATH
#   - Visual Studio 2022 with the "Desktop development with C++" workload
#   - (optional) Inno Setup 6 with ISCC.exe on PATH, to produce the installer
#
# Output (in ./dist):
#   FileOrganizerPro-Portable.zip   — run without installing
#   FileOrganizerPro-Setup.exe      — installer (only if Inno Setup is found)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
# CI sets APP_VERSION from the git tag (e.g. v1.2.0 -> 1.2.0); local runs
# default to 1.0.0.
$Version = if ($env:APP_VERSION) { $env:APP_VERSION } else { '1.0.0' }
$AppName = 'File Organizer Pro'
$ExeName = 'file_organizer_pro.exe'

Set-Location $Root

Write-Host '==> flutter pub get' -ForegroundColor Cyan
flutter pub get

Write-Host '==> flutter analyze' -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }

Write-Host '==> flutter test' -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test failed.' }

Write-Host '==> flutter build windows --release' -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed.' }

$ReleaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $ReleaseDir $ExeName))) {
    throw "Expected build output not found: $ReleaseDir\$ExeName"
}

$Dist = Join-Path $Root 'dist'
$PortableRoot = Join-Path $Dist 'portable'
$PortableApp = Join-Path $PortableRoot $AppName
if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Path $PortableApp -Force | Out-Null

Write-Host '==> staging portable build' -ForegroundColor Cyan
Copy-Item (Join-Path $ReleaseDir '*') $PortableApp -Recurse -Force

Write-Host '==> creating portable zip' -ForegroundColor Cyan
# Rename the staged folder in place (Rename-Item takes a name, not a path),
# so the zip contains a tidy FileOrganizerPro-<version>/ top-level folder.
$ZipFolderName = 'FileOrganizerPro-' + $Version
Rename-Item -Path $PortableApp -NewName $ZipFolderName
$ZipFolder = Join-Path $PortableRoot $ZipFolderName
$ZipPath = Join-Path $Dist 'FileOrganizerPro-Portable.zip'
Compress-Archive -Path $ZipFolder -DestinationPath $ZipPath -Force
Remove-Item $ZipFolder -Recurse -Force

# --- Optional installer (Inno Setup) ---
$IsccPath = $null
# Get-Command returns an ApplicationInfo whose executable is .Source;
# Test-Path candidates are FileInfo objects with .FullName. Normalize to a
# plain path so the invocation below works in both cases.
$cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($cmd) { $IsccPath = $cmd.Source }
if (-not $IsccPath) {
    # Inno Setup 6 commonly installs to the user or Program Files paths.
    foreach ($candidate in @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )) {
        if (Test-Path $candidate) { $IsccPath = $candidate; break }
    }
}
if ($IsccPath) {
    Write-Host '==> building installer with Inno Setup' -ForegroundColor Cyan
    # Keep the staged build for the installer to pack.
    Copy-Item (Join-Path $ReleaseDir '*') $PortableApp -Recurse -Force
    & $IsccPath (Join-Path $Root 'tool\installer.iss') /DAppVersion=$Version
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
} else {
    Write-Host 'Inno Setup not found — skipping installer. Install Inno Setup 6 and ensure ISCC.exe is on PATH to build FileOrganizerPro-Setup.exe.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Release artifacts:' -ForegroundColor Green
Get-ChildItem $Dist -File | ForEach-Object { Write-Host "  $($_.FullName)" }
