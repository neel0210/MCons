; MCons Windows Installer Script (Inno Setup 6)
; Produces professional distributable installer with Windows Shell Context Menu integration

#define MyAppName "MCons"
#define MyAppVersion "1.0.4"
#define MyAppPublisher "Neel J"
#define MyAppURL "https://github.com/neel0210/MCons"
#define MyAppExeName "MCons.exe"

[Setup]
AppId={{A94F1283-7F02-4A8E-981F-E9F3D8C8B101}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=MCons-Windows-Setup
SetupIconFile=mcons.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog commandline
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "contextmenu"; Description: "Add 'Customize with MCons' to Windows Explorer folder right-click menu"; GroupDescription: "Windows Shell Integration:"

[Files]
Source: "dist\MCons-Windows.exe"; DestDir: "{app}"; DestName: "{#MyAppExeName}"; Flags: ignoreversion
Source: "mcons.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\mcons.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\mcons.ico"; Tasks: desktopicon

[Registry]
; Windows Explorer folder right-click integration
Root: HKA; Subkey: "Software\Classes\Directory\shell\MCons"; ValueType: string; ValueData: "Customize with MCons"; Tasks: contextmenu; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Directory\shell\MCons"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#MyAppExeName}"""; Tasks: contextmenu; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Directory\shell\MCons\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: contextmenu; Flags: uninsdeletekey

; Windows Explorer inside-folder background right-click integration
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\MCons"; ValueType: string; ValueData: "Customize folder with MCons"; Tasks: contextmenu; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\MCons"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#MyAppExeName}"""; Tasks: contextmenu; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\MCons\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%V"""; Tasks: contextmenu; Flags: uninsdeletekey

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
