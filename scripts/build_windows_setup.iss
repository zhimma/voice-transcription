; Windows 安装包脚本 (Inno Setup)
; 使用方法: 用 Inno Setup 编译此文件
; 下载地址: https://jrsoftware.org/isinfo.php

#define MyAppName "智能录音转写助手"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Hulumibao"
#define MyAppURL "https://gitlab.hulumibao.com/voice-transcription/frontend"
#define MyAppExeName "voice_transcription.exe"

[Setup]
; 应用信息
AppId={{8A8C8D8E-8F8A-8B8C-8D8E-8F8A8B8C8D8E}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; 默认安装路径
DefaultDirName={autopf}\VoiceTranscription
DefaultGroupName={#MyAppName}

; 输出设置
OutputDir=..\build_outputs
OutputBaseFilename=VoiceTranscription-Windows-{#MyAppVersion}-Setup

; 压缩设置
Compression=lzma2
SolidCompression=yes

; 安装权限
PrivilegesRequiredOverridesAllowed=dialog

; 界面设置
WizardStyle=modern
SetupIconFile=..\assets\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; 版本信息
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} 安装程序
VersionInfoVersion={#MyAppVersion}

; 其他设置
DisableWelcomePage=no
DisableReadyPage=no
DisableFinishedPage=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Flutter 应用文件
Source: "..\frontend\build\windows\x64\Release\bundle\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Python 后端
Source: "..\backend\*"; DestDir: "{app}\python"; Flags: ignoreversion recursesubdirs createallsubdirs

; 图标文件
Source: "..\assets\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; 开始菜单
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; 桌面快捷方式
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; 快速启动
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; 安装完成后可选启动
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 卸载时删除的文件和目录
Type: filesandordirs; Name: "{app}\config"
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\models"

[Registry]
; 可选：注册文件关联
; Root: HKCR; Subkey: ".vtt"; ValueType: string; ValueName: ""; ValueData: "VoiceTranscriptionFile"; Flags: uninsdeletevalue
; Root: HKCR; Subkey: "VoiceTranscriptionFile"; ValueType: string; ValueName: ""; ValueData: "语音转写文件"; Flags: uninsdeletekey
; Root: HKCR; Subkey: "VoiceTranscriptionFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\app_icon.ico"
; Root: HKCR; Subkey: "VoiceTranscriptionFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}""""%1"""

[Code]
; 安装前检查
function InitializeSetup(): Boolean;
begin
  Result := true;
  
  ; 检查 Windows 版本 (Windows 10+)
  if not IsWindowsVersionOrNewer(10, 0) then begin
    MsgBox('此应用需要 Windows 10 或更高版本。', mbError, MB_OK);
    Result := false;
  end;
end;

; 安装完成后消息
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    ; 安装完成后的操作
  end;
end;
