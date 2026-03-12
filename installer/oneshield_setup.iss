[Setup]
AppId={{B8E5F2A1-3C7D-4E9F-A1B2-C3D4E5F6A7B8}
AppName=OneShield
AppVersion={#MyAppVersion}
AppVerName=OneShield {#MyAppVersion}
AppPublisher=Masud Rana
AppPublisherURL=https://github.com/masudranaxpert/OneShield
DefaultDirName={autopf}\OneShield
DefaultGroupName=OneShield
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=OneShield-Windows-{#MyAppVersion}
SetupIconFile=..\assets\logo\OneShield_logo.ico
UninstallDisplayIcon={app}\one_shield.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startupicon"; Description: "Launch at Windows startup"; GroupDescription: "Additional options:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\OneShield"; Filename: "{app}\one_shield.exe"
Name: "{group}\Uninstall OneShield"; Filename: "{uninstallexe}"
Name: "{autodesktop}\OneShield"; Filename: "{app}\one_shield.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "OneShield"; ValueData: """{app}\one_shield.exe"""; Flags: uninsdeletevalue; Tasks: startupicon

[Run]
Filename: "{app}\one_shield.exe"; Description: "Launch OneShield"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
