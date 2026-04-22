; TerminalStack — Inno Setup Installer
; Stackschmiede · https://stackschmiede.de
;
; Build:  iscc TerminalStack.iss
; Output: Output\TerminalStack-Setup.exe
;
; Anforderungen: Inno Setup 6.3+  (https://jrsoftware.org/isinfo.php)

#define AppName    "TerminalStack"
#define AppVersion "0.2.0"
#define AppPublisher "Stackschmiede"
#define AppURL     "https://stackschmiede.de"
#define AppExeName "wezterm.exe"

[Setup]
AppId={{B7C2A3F1-4D8E-4A2B-9F6C-1E5D7B3A8C0F}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL=https://github.com/stackschmiede/stack-terminal/releases

; Kein Admin nötig — alles im User-Profile
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

DefaultDirName={tmp}\TerminalStack
DisableDirPage=yes
DisableProgramGroupPage=yes

; Branding
SetupIconFile=..\config\assets\stackschmiede.ico
WizardImageFile=wizard-panel.png
WizardSmallImageFile=wizard-icon.png
WizardStyle=modern
WizardSizePercent=120

; Output
OutputDir=Output
OutputBaseFilename=TerminalStack-Setup-v{#AppVersion}
Compression=lzma2/ultra
SolidCompression=yes
InternalCompressLevel=ultra

; Kein Startmenü-Eintrag, kein Uninstaller im System (reine Config-Installation)
CreateUninstallRegKey=no
Uninstallable=no

; Windows 10+
MinVersion=10.0

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Files]
; Alle Quell-Dateien werden mit ins Setup-Paket eingebettet
Source: "..\config\wezterm.lua";      DestDir: "{tmp}\ts-src";  Flags: ignoreversion
Source: "..\config\assets\*";         DestDir: "{tmp}\ts-src\assets"; Flags: ignoreversion recursesubdirs
Source: "install.ps1";                DestDir: "{tmp}\ts-src";  Flags: ignoreversion
Source: "paste-image.ps1";            DestDir: "{tmp}\ts-src";  Flags: ignoreversion

[Code]
var
  PageConfig: TInputQueryWizardPage;

procedure InitializeWizard;
var
  DefaultUser: string;
begin
  DefaultUser := LowerCase(GetUserNameString);

  PageConfig := CreateInputQueryPage(wpWelcome,
    'WSL-Konfiguration',
    'Bestätige deine WSL-Details (Defaults passen für Standard-Ubuntu-Setups)',
    'Tipp: Liste der Distros via "wsl -l -q" in PowerShell.');

  PageConfig.Add('WSL-Distribution:', False);
  PageConfig.Add('WSL-Username:',     False);
  PageConfig.Add('Projects-Pfad (WSL):', False);

  PageConfig.Values[0] := 'Ubuntu';
  PageConfig.Values[1] := DefaultUser;
  PageConfig.Values[2] := '/home/' + DefaultUser + '/projects';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  i: Integer;
begin
  Result := True;
  if CurPageID = PageConfig.ID then begin
    for i := 0 to 2 do begin
      if Trim(PageConfig.Values[i]) = '' then begin
        MsgBox('Bitte fülle alle drei Felder aus.', mbError, MB_OK);
        Result := False;
        Exit;
      end;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Distro, Username, Projects, SrcDir, PsScript, Args: string;
  ResultCode: Integer;
begin
  if CurStep = ssInstall then begin
    Distro   := Trim(PageConfig.Values[0]);
    Username := Trim(PageConfig.Values[1]);
    Projects := Trim(PageConfig.Values[2]);
    SrcDir   := ExpandConstant('{tmp}\ts-src');
    PsScript := SrcDir + '\install.ps1';

    Args := '-NoProfile -ExecutionPolicy Bypass -File "' + PsScript + '"' +
            ' -NonInteractive -Force' +
            ' -WslDistro "'    + Distro   + '"' +
            ' -WslUsername "'  + Username + '"' +
            ' -ProjectsPath "' + Projects + '"';

    if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
                Args, SrcDir, SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      MsgBox('PowerShell konnte nicht gestartet werden.' + #13#10 +
             'Bitte install.ps1 manuell ausführen.', mbError, MB_OK);
    end else if ResultCode <> 0 then begin
      MsgBox('Installation fehlgeschlagen (Exit ' + IntToStr(ResultCode) + ').' + #13#10 +
             'Prüfe ob WezTerm installiert ist und WSL konfiguriert ist.',
             mbError, MB_OK);
    end;
  end;
end;
