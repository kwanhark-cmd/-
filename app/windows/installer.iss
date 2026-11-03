; 윈도우 설치 프로그램 (Inno Setup). GitHub Actions 가 만든다.
; AppId·설치 폴더·실행 파일 이름은 절대 바꾸지 않는다: 바꾸면 업데이트가 덮어쓰기가 아니라 새 앱으로 설치된다.
; 사용자 자료는 설치 폴더가 아닌 %APPDATA% 에 있어 설치·업데이트·제거로 지워지지 않는다.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{CD2DFF57-56A7-48BC-9257-59C453116D1F}
AppName=채널관리비서
AppVersion={#AppVersion}
AppPublisher=채널관리비서
DefaultDirName={localappdata}\Programs\ChannelBiseo
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\build
OutputBaseFilename=channel-biseo-windows-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\channel_biseo.exe
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
WizardStyle=modern

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕화면에 바로가기 만들기"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\채널관리비서"; Filename: "{app}\channel_biseo.exe"
Name: "{autodesktop}\채널관리비서"; Filename: "{app}\channel_biseo.exe"; Tasks: desktopicon

[Run]
; 업데이트(조용한 설치) 뒤에도 앱을 다시 연다
Filename: "{app}\channel_biseo.exe"; Description: "채널관리비서 열기"; Flags: nowait postinstall
