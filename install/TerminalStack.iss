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
// ─────────────────────────────────────────────────────────────────────────────
// Globale Variablen
// ─────────────────────────────────────────────────────────────────────────────
var
  PageConfig:      TWizardPage;
  DistroEdit:      TNewEdit;
  DistroLabel:     TNewStaticText;
  UserEdit:        TNewEdit;
  UserLabel:       TNewStaticText;
  ProjectsEdit:    TNewEdit;
  ProjectsLabel:   TNewStaticText;
  DistroHint:      TNewStaticText;

// ─────────────────────────────────────────────────────────────────────────────
// Custom Config-Seite erstellen
// ─────────────────────────────────────────────────────────────────────────────
procedure CreateConfigPage;
var
  DefaultUser: string;
begin
  PageConfig := CreateCustomPage(wpWelcome,
    'WSL-Konfiguration',
    'Gib deine WSL-Details ein (oder bestätige die Defaults).');

  DefaultUser := LowerCase(GetUserNameString);

  // --- Distro ---
  DistroLabel := TNewStaticText.Create(PageConfig);
  DistroLabel.Parent := PageConfig.Surface;
  DistroLabel.Caption := 'WSL-Distribution:';
  DistroLabel.Left := 0;
  DistroLabel.Top := 8;
  DistroLabel.Width := 200;

  DistroEdit := TNewEdit.Create(PageConfig);
  DistroEdit.Parent := PageConfig.Surface;
  DistroEdit.Left := 0;
  DistroEdit.Top := 26;
  DistroEdit.Width := PageConfig.SurfaceWidth;
  DistroEdit.Text := 'Ubuntu';

  DistroHint := TNewStaticText.Create(PageConfig);
  DistroHint.Parent := PageConfig.Surface;
  DistroHint.Caption := 'Liste der installierten Distros: "wsl -l -q" in PowerShell ausführen.';
  DistroHint.Left := 0;
  DistroHint.Top := 50;
  DistroHint.Width := PageConfig.SurfaceWidth;
  DistroHint.Font.Size := 7;

  // --- Username ---
  UserLabel := TNewStaticText.Create(PageConfig);
  UserLabel.Parent := PageConfig.Surface;
  UserLabel.Caption := 'WSL-Username:';
  UserLabel.Left := 0;
  UserLabel.Top := 80;
  UserLabel.Width := 200;

  UserEdit := TNewEdit.Create(PageConfig);
  UserEdit.Parent := PageConfig.Surface;
  UserEdit.Left := 0;
  UserEdit.Top := 98;
  UserEdit.Width := PageConfig.SurfaceWidth;
  UserEdit.Text := DefaultUser;

  // --- Projects-Pfad ---
  ProjectsLabel := TNewStaticText.Create(PageConfig);
  ProjectsLabel.Parent := PageConfig.Surface;
  ProjectsLabel.Caption := 'Projects-Pfad (WSL-Pfad, z.B. /home/user/projects):';
  ProjectsLabel.Left := 0;
  ProjectsLabel.Top := 138;
  ProjectsLabel.Width := PageConfig.SurfaceWidth;

  ProjectsEdit := TNewEdit.Create(PageConfig);
  ProjectsEdit.Parent := PageConfig.Surface;
  ProjectsEdit.Left := 0;
  ProjectsEdit.Top := 156;
  ProjectsEdit.Width := PageConfig.SurfaceWidth;
  ProjectsEdit.Text := '/home/' + DefaultUser + '/projects';
end;

// ─────────────────────────────────────────────────────────────────────────────
// Initialisierung
// ─────────────────────────────────────────────────────────────────────────────
procedure InitializeWizard;
begin
  CreateConfigPage;
end;

// ─────────────────────────────────────────────────────────────────────────────
// Installation: PowerShell-Skript mit gesammelten Parametern aufrufen
// ─────────────────────────────────────────────────────────────────────────────
procedure CurStepChanged(CurStep: TSetupStep);
var
  Distro, Username, Projects, SrcDir, PsScript, Args: string;
  ResultCode: Integer;
begin
  if CurStep = ssInstall then begin
    Distro   := Trim(DistroEdit.Text);
    Username := Trim(UserEdit.Text);
    Projects := Trim(ProjectsEdit.Text);
    SrcDir   := ExpandConstant('{tmp}\ts-src');

    PsScript := SrcDir + '\install.ps1';

    Args := '-NoProfile -ExecutionPolicy Bypass -File "' + PsScript + '"' +
            ' -NonInteractive' +
            ' -Force' +
            ' -WslDistro "' + Distro + '"' +
            ' -WslUsername "' + Username + '"' +
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

// ─────────────────────────────────────────────────────────────────────────────
// Validierung: Pflichtfelder prüfen
// ─────────────────────────────────────────────────────────────────────────────
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = PageConfig.ID then begin
    if Trim(DistroEdit.Text) = '' then begin
      MsgBox('Bitte gib eine WSL-Distribution ein.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    if Trim(UserEdit.Text) = '' then begin
      MsgBox('Bitte gib einen WSL-Username ein.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    if Trim(ProjectsEdit.Text) = '' then begin
      MsgBox('Bitte gib einen Projects-Pfad ein.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;
end;
