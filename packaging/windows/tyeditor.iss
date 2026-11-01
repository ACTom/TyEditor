; Inno Setup 6 script for TyEditor (Windows).
; Build from the repository root:
;   ./scripts/package/installer.sh
;
; The uninstaller intentionally does not remove %APPDATA%\TyEditor (settings,
; session, backups) so user data survives upgrades and uninstalls.

#define AppName "TyEditor"
#ifndef AppVersion
#define AppVersion "0.0.0"
#endif
#define AppPublisher "TyEditor"
#define AppExe "TyEditor.exe"
#define DistDir "..\..\dist\win32-i386"

[Setup]
AppId={{6B9D0D3A-5A1B-4D64-9E6E-123456789ABC}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\TyEditor
DefaultGroupName=TyEditor
OutputDir=..\..\dist
OutputBaseFilename=TyEditorSetup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExe}
PrivilegesRequired=lowest
ChangesAssociations=yes

[Tasks]
Name: "associate_txt"; Description: "Associate .txt files with TyEditor"; GroupDescription: "File associations:"; Flags: unchecked

[Files]
Source: "{#DistDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#DistDir}\languages\*"; DestDir: "{app}\languages"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#DistDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\NOTICE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\TyEditor"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall TyEditor"; Filename: "{uninstallexe}"
Name: "{userdesktop}\TyEditor"; Filename: "{app}\{#AppExe}"

[Registry]
Root: HKCU; Subkey: "Software\Classes\TyEditor.Document"; ValueType: string; ValueName: ""; ValueData: "TyEditor text document"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\TyEditor.Document\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\data\icons\tyeditor.ico"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\TyEditor.Document\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\.txt\OpenWithProgids"; ValueType: string; ValueName: "TyEditor.Document"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associate_txt

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch TyEditor"; Flags: nowait postinstall skipifsilent
