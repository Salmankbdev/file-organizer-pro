; File Organizer Pro — Inno Setup installer script.
; Build with: ISCC.exe tool\installer.iss /DAppVersion=1.0.0
; Expects the release build staged in dist\portable\File Organizer Pro\
; (see tool\build_release.ps1).

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "File Organizer Pro"
#define AppPublisher "File Organizer Pro Contributors"
#define AppExeName "file_organizer_pro.exe"

[Setup]
AppId={{8F3C4B2A-9E51-4C7D-A1D6-3B9E4F0C5A21}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=FileOrganizerPro-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; User data (SQLite db + preferences) lives in the app-support folder and is
; preserved across upgrades and uninstalls on purpose.
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\dist\portable\{#AppName}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Nothing app-specific: user data is intentionally preserved.
