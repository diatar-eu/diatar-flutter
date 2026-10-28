[Setup]
AppId={{B488802A-933D-4CF1-9730-B4BD1CB89288}
AppName={cm:installerAppName}
AppVersion={#AppVersion}
VersionInfoVersion={#FileVersion}
VersionInfoProductName=Diatár / DiaVetítő
VersionInfoDescription=Diatár / DiaVetítő
AppPublisher=Diatár
AppPublisherURL=https://diatar.eu
DefaultDirName={autopf}\Diatar
DefaultGroupName=Diatár
DisableProgramGroupPage=yes
DisableDirPage=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0.17763
UninstallDisplayIcon={uninstallexe}
OutputDir={#InstallerOutput}
OutputBaseFilename=Diatar-Setup-{#AppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
SetupLogging=yes

[Languages]
Name: "hu"; MessagesFile: "compiler:Languages\Hungarian.isl,{#MessagesDir}\hu.isl"
Name: "en"; MessagesFile: "compiler:Default.isl,{#MessagesDir}\en.isl"

[Types]
Name: "full"; Description: "{cm:installerFull}"
Name: "sender"; Description: "{cm:installerSenderOnly}"
Name: "receiver"; Description: "{cm:installerReceiverOnly}"
Name: "custom"; Description: "{cm:installerCustom}"; Flags: iscustom

[Components]
Name: "sender"; Description: "{cm:installerSenderComponent}"; Types: full sender
Name: "receiver"; Description: "{cm:installerReceiverComponent}"; Types: full receiver

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#VCRedist}"; Flags: dontcopy
Source: "{#SenderBundle}\*"; DestDir: "{app}\Diatar"; Components: sender; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#ReceiverBundle}\*"; DestDir: "{app}\DiaVetito"; Components: receiver; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Diatár"; Filename: "{app}\Diatar\diatar_app.exe"; WorkingDir: "{app}\Diatar"; Components: sender
Name: "{group}\DiaVetítő"; Filename: "{app}\DiaVetito\diavetito.exe"; WorkingDir: "{app}\DiaVetito"; Components: receiver
Name: "{autodesktop}\Diatár"; Filename: "{app}\Diatar\diatar_app.exe"; WorkingDir: "{app}\Diatar"; Components: sender; Tasks: desktopicon
Name: "{autodesktop}\DiaVetítő"; Filename: "{app}\DiaVetito\diavetito.exe"; WorkingDir: "{app}\DiaVetito"; Components: receiver; Tasks: desktopicon

[Run]
Filename: "{app}\Diatar\diatar_app.exe"; Description: "{cm:installerLaunchSender}"; WorkingDir: "{app}\Diatar"; Components: sender; Flags: postinstall nowait skipifsilent runasoriginaluser unchecked; Check: CanLaunch
Filename: "{app}\DiaVetito\diavetito.exe"; Description: "{cm:installerLaunchReceiver}"; WorkingDir: "{app}\DiaVetito"; Components: receiver; Flags: postinstall nowait skipifsilent runasoriginaluser unchecked; Check: CanLaunch

[Code]
var
  RuntimeNeedsRestart: Boolean;

function RuntimeInstalled: Boolean;
var
  Installed, Major, Minor, Build, Revision: Cardinal;
  Key: String;
begin
  Key := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  Result :=
    RegQueryDWordValue(HKLM64, Key, 'Installed', Installed) and
    (Installed = 1) and
    RegQueryDWordValue(HKLM64, Key, 'Major', Major) and
    RegQueryDWordValue(HKLM64, Key, 'Minor', Minor) and
    RegQueryDWordValue(HKLM64, Key, 'Bld', Build) and
    RegQueryDWordValue(HKLM64, Key, 'Rbld', Revision);
  if Result then
    Result := ComparePackedVersion(
      PackVersionComponents(Major, Minor, Build, Revision),
      PackVersionComponents({#VCMajor}, {#VCMinor}, {#VCBuild}, {#VCRevision})) >= 0;
end;

function HasComponent: Boolean;
begin
  Result := WizardIsComponentSelected('sender') or
    WizardIsComponentSelected('receiver');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpSelectComponents) and not HasComponent then
  begin
    SuppressibleMsgBox(CustomMessage('installerSelectComponent'), mbError, MB_OK, IDOK);
    Result := False;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExitCode: Integer;
begin
  Result := '';
  if not HasComponent then
  begin
    Result := CustomMessage('installerSelectComponent');
    Exit;
  end;
  if RuntimeInstalled then
    Exit;

  ExtractTemporaryFile('vc_redist.x64.exe');
  if not Exec(ExpandConstant('{tmp}\vc_redist.x64.exe'),
    '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
  begin
    Log(Format('VC++ runtime could not start: %d', [ExitCode]));
    Result := FmtMessage(CustomMessage('installerRuntimeError'), [IntToStr(ExitCode)]);
    Exit;
  end;

  Log(Format('VC++ runtime exit code: %d', [ExitCode]));
  if ((ExitCode = 0) or (ExitCode = 3010) or (ExitCode = 1638)) and
    RuntimeInstalled then
    RuntimeNeedsRestart := RuntimeNeedsRestart or (ExitCode = 3010)
  else
  begin
    NeedsRestart := (ExitCode = 3010) or (ExitCode = 1641);
    Result := FmtMessage(CustomMessage('installerRuntimeError'), [IntToStr(ExitCode)]);
  end;
end;

function NeedRestart: Boolean;
begin
  Result := RuntimeNeedsRestart;
end;

function CanLaunch: Boolean;
begin
  Result := not RuntimeNeedsRestart;
end;
