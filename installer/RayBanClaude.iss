; RayBan Claude – Windows-Installer (Inno Setup 6)
;
; Baut RayBanClaude-Setup.exe: kopiert Channel und Skripte nach %LOCALAPPDATA%\Programs\RayBanClaude
; (keine Administrator-Rechte nötig), richtet Bun und Claude Code mit den offiziellen Installern ein,
; öffnet auf Wunsch die Windows-Firewall (fragt dann einmal nach Administrator-Rechten) und legt
; „RayBan Claude“ auf den Desktop und ins Startmenü.
;
; Gebaut wird in GitHub Actions (.github/workflows/windows-installer.yml):
;   ISCC.exe /DAppVersion=2.1.0 installer\RayBanClaude.iss

#define AppName "RayBan Claude"
#ifndef AppVersion
  #define AppVersion "2.1.0"
#endif
#define RepoUrl "https://github.com/fragru82-cloud/rayban-claude-it"

[Setup]
AppId={{6C1F3B52-8E47-4C0A-9B6D-2F7E91A4C3D8}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=RayBan Claude (Open Source)
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases
DefaultDirName={localappdata}\Programs\RayBanClaude
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=RayBanClaude-Setup
SetupIconFile=RayBanClaude.ico
UninstallDisplayIcon={app}\RayBanClaude.ico
UninstallDisplayName={#AppName}
LicenseFile=..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=no
; Bun braucht Windows 10 Version 1809 oder neuer
MinVersion=10.0.17763
CloseApplications=yes

[Languages]
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"

[Messages]
it.WelcomeLabel2=Così Claude vede quello che vedi tu – con i tuoi Ray-Ban Meta o con l’iPhone.%n%nL’installer prepara tutto ciò che serve al PC: Bun e Claude Code (installer ufficiali, gratuiti), il canale RayBan Claude e – se installata – il collegamento con l’app Claude Desktop. Serve un abbonamento Claude (Pro o Max).%n%nProgetto open source non ufficiale – non collegato a Meta, Ray-Ban o Anthropic.
it.FinishedLabel=RayBan Claude è installato.%n%nAl primo avvio accedi una volta a Claude (si apre il browser) e confermi «Use this MCP server». Poi si apre la dashboard: inquadra il QR code con la fotocamera dell’iPhone.%n%nL’app per iPhone si installa senza Mac con Sideloadly (guida nel menu Start).

[Tasks]
Name: "desktopicon"; Description: "Crea l’icona «RayBan Claude» sul desktop"
Name: "firewall"; Description: "Apri il firewall di Windows per l’iPhone (solo rete privata e Tailscale – chiede i permessi di amministratore)"

[Files]
Source: "..\channel\*"; DestDir: "{app}\channel"; Excludes: "\node_modules\*,\test\*,*.log"; Flags: recursesubdirs ignoreversion
Source: "..\.mcp.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\setup.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\setup.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\start.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\start.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\firewall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\IPHONE-OHNE-MAC.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "RayBanClaude.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\RayBan Claude\RayBan Claude"; Filename: "{app}\start.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\RayBanClaude.ico"; Comment: "Avvia Claude con Ray-Ban Meta e iPhone"
Name: "{autoprograms}\RayBan Claude\Nuova conversazione"; Filename: "{app}\start.cmd"; Parameters: "-Neu"; WorkingDir: "{app}"; IconFilename: "{app}\RayBanClaude.ico"; Comment: "Avvia RayBan Claude senza l’ultima conversazione"
Name: "{autoprograms}\RayBan Claude\Ripeti configurazione"; Filename: "{app}\setup.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\RayBanClaude.ico"
Name: "{autoprograms}\RayBan Claude\Installa app iPhone (guida)"; Filename: "{#RepoUrl}/blob/main/docs/IPHONE-OHNE-MAC.md"
Name: "{autoprograms}\RayBan Claude\Disinstalla RayBan Claude"; Filename: "{uninstallexe}"
Name: "{autodesktop}\RayBan Claude"; Filename: "{app}\start.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\RayBanClaude.ico"; Comment: "Avvia Claude con Ray-Ban Meta e iPhone"; Tasks: desktopicon

[Run]
; Bun, Claude Code (offizielle Installer) und die Channel-Abhängigkeiten – im sichtbaren Fenster
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\setup.ps1"" -Unattended"; WorkingDir: "{app}"; StatusMsg: "Configuro Bun, Claude Code e il canale …"; Flags: waituntilterminated
; Firewall: nur dieser Schritt braucht Administrator-Rechte
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\firewall.ps1"""; Verb: "runas"; StatusMsg: "Apro il firewall di Windows per l’iPhone …"; Flags: shellexec waituntilterminated; Tasks: firewall
Filename: "{app}\start.cmd"; WorkingDir: "{app}"; Description: "Avvia ora RayBan Claude"; Flags: postinstall shellexec nowait skipifsilent
Filename: "{#RepoUrl}/blob/main/docs/IPHONE-OHNE-MAC.md"; Description: "Apri la guida: app su iPhone (senza Mac)"; Flags: postinstall shellexec nowait skipifsilent unchecked

[UninstallRun]
; Verknüpfung mit der Claude-Desktop-App wieder austragen
Filename: "{%USERPROFILE}\.bun\bin\bun.exe"; Parameters: """{app}\channel\link-desktop.ts"" --remove"; Flags: runhidden waituntilterminated skipifdoesntexist; RunOnceId: "ClaudeAppTrennen"
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\firewall.ps1"" -Remove"; Verb: "runas"; Flags: shellexec waituntilterminated; RunOnceId: "FirewallEntfernen"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\channel\node_modules"
