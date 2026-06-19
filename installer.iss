#define MyAppName "TTH Manager"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Tales & Tech HUB"
#define MyAppExeName "tth_manager_app.exe"

[Setup]
AppId={{C7A9D9E1-2A1F-4F9B-8F5E-123456789ABC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=installer_output
OutputBaseFilename=TTHManagerSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}

[Tasks]
Name: "desktopicon"; Description: "Creează pictogramă pe desktop"; GroupDescription: "Opțiuni suplimentare:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Pornește {#MyAppName}"; Flags: nowait postinstall skipifsilent