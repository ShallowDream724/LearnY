#define MyAppName "LearnY"

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

#ifndef SourceDir
  #error SourceDir define is required.
#endif

#ifndef OutputDir
  #define OutputDir "..\\..\\dist\\windows"
#endif

#ifndef OutputBaseFilename
  #define OutputBaseFilename "LearnY-Setup-" + AppVersion
#endif

[Setup]
AppId={{7DA1A357-7C56-4A47-9040-9E08A2A0D2B0}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppVerName={#MyAppName} {#AppVersion}
AppPublisher=LearnY
AppPublisherURL=https://github.com/ShallowDream724/LearnY
AppSupportURL=https://github.com/ShallowDream724/LearnY/issues
AppUpdatesURL=https://github.com/ShallowDream724/LearnY/releases
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\learn_y.exe
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
CloseApplications=yes
RestartApplications=no
UsePreviousAppDir=yes
UsePreviousLanguage=yes

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: unchecked; Languages: chinesesimp
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional tasks:"; Flags: unchecked; Languages: english

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\learn_y.exe"; WorkingDir: "{app}"; IconFilename: "{app}\learn_y.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\learn_y.exe"; WorkingDir: "{app}"; IconFilename: "{app}\learn_y.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\learn_y.exe"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
