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
# Stage directly under the versioned folder name so the zip has a tidy
# FileOrganizerPro-<version>/ top-level folder.
$PortableApp = Join-Path $PortableRoot ('FileOrganizerPro-' + $Version)
$ZipPath = Join-Path $Dist 'FileOrganizerPro-Portable.zip'
if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Path $PortableApp -Force | Out-Null

Write-Host '==> staging portable build' -ForegroundColor Cyan
# robocopy preserves the directory tree exactly. PowerShell's Copy-Item with a
# wildcard source can flatten subdirectories (notably data\, which the Flutter
# engine requires next to the exe) when the destination already exists — the
# portable zip was fine but installed apps crashed with "Can't load AOT data".
robocopy $ReleaseDir $PortableApp /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

Write-Host '==> creating portable zip' -ForegroundColor Cyan
Compress-Archive -Path $PortableApp -DestinationPath $ZipPath -Force

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
    # Pack the same staged folder that went into the zip (it still exists) —
    # never re-copy, so the data\ structure is guaranteed intact.
    & $IsccPath (Join-Path $Root 'tool\installer.iss') /DAppVersion=$Version
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
} else {
    Write-Host 'Inno Setup not found — skipping installer. Install Inno Setup 6 and ensure ISCC.exe is on PATH to build FileOrganizerPro-Setup.exe.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Release artifacts:' -ForegroundColor Green
Get-ChildItem $Dist -File | ForEach-Object { Write-Host "  $($_.FullName)" }
