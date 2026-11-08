<#
  RayBan Claude – Einrichtung unter Windows
  Ausführen: setup.cmd doppelklicken (oder den Windows-Installer RayBanClaude-Setup.exe nutzen)
  oder:      powershell -ExecutionPolicy Bypass -File .\setup.ps1

  -Unattended: ohne Rückfragen (für den Installer) – installiert Bun und Claude Code bei Bedarf
  mit den offiziellen Installern, überspringt den optionalen Gateway; die Firewall richtet der
  Installer selbst ein.
#>
param([switch]$Unattended)
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot
$Port = 18790

function Write-Step($text) { Write-Host "`n▸ $text" -ForegroundColor DarkYellow }
function Write-Ok($text)   { Write-Host "  ✓ $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "  ! $text" -ForegroundColor Yellow }
function Ask($question, [bool]$UnattendedAnswer = $true) {
    if ($Unattended) { return $UnattendedAnswer }
    (Read-Host "  $question (s/n)") -match '^(s|si|sì|j|ja|y|yes)$'
}
function Test-Command($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Test-Rule($name) { [bool](Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) }

# Frisch installierte Werkzeuge sofort finden (der Installer erbt noch den alten PATH)
$env:Path = "$env:USERPROFILE\.bun\bin;$env:USERPROFILE\.local\bin;$env:Path"

try {
    Write-Host ""
    Write-Host "  ◉ RayBan Claude – Installazione" -ForegroundColor DarkYellow
    Write-Host "    Claude vede quello che vedi tu (Ray-Ban Meta Gen 2 & iPhone)" -ForegroundColor Gray
    Write-Host "    Progetto open source non ufficiale, non affiliato a Meta, Ray-Ban o Anthropic." -ForegroundColor DarkGray

    # ── 1. Bun (führt den Channel-Server aus) ────────────────────────────────
    Write-Step "Verifica di Bun"
    if (-not (Test-Command 'bun')) {
        Write-Warn "Bun non è installato (gratuito, https://bun.sh)."
        if (Ask "Installare ora Bun con l'installer ufficiale?") {
            powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://bun.sh/install.ps1 | iex"
        } else {
            Write-Warn "Senza Bun il canale non funziona. Più tardi: irm https://bun.sh/install.ps1 | iex"
            exit 1
        }
    }
    if (-not (Test-Command 'bun')) { throw "Bun non trovato: avvia di nuovo setup.cmd." }
    Write-Ok "Bun $(bun --version)"

    # ── 2. Claude Code ───────────────────────────────────────────────────────
    Write-Step "Verifica di Claude Code"
    if (-not (Test-Command 'claude')) {
        Write-Warn "Claude Code non è installato."
        if (Ask "Installare ora Claude Code con l'installer ufficiale?") {
            powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex"
        } else {
            Write-Warn "Installalo più tardi: https://claude.com/claude-code"
        }
    }
    if (Test-Command 'claude') { Write-Ok "Claude Code $(claude --version)" }

    # ── 3. Abhängigkeiten des Channels ───────────────────────────────────────
    Write-Step "Installazione delle dipendenze del canale"
    Push-Location channel
    bun install --frozen-lockfile
    if ($LASTEXITCODE -ne 0) { throw "bun install non riuscito (connessione a Internet?)" }
    bun audit
    Pop-Location
    Write-Ok "Canale pronto"

    # ── 4. Verknüpfung mit der Claude-Desktop-App ─────────────────────────────
    # Claude in deinen normalen Chats kann dann den Brillen-Verlauf lesen und Wissen an die Brille geben.
    Write-Step "Collegamento con l'app Claude"
    Write-Host "  Poi nelle tue chat con Claude potrai dire per es.: «Cosa ho chiesto oggi agli occhiali?»" -ForegroundColor Gray
    Write-Host "  oppure «Trasferisci agli occhiali quello che sai di me»." -ForegroundColor Gray
    if (Ask "Collegare all'app Claude Desktop su questo PC?") {
        bun channel\link-desktop.ts
    }

    # ── 5. Optional: Gateway-Modus (eigener Anthropic-API-Key, kostet pro Anfrage) ──
    if (Test-Path server) {
        Write-Step "Modalità gateway (opzionale)"
        Write-Host "  Serve solo se vuoi lavorare SENZA Claude Code, con una tua chiave API." -ForegroundColor Gray
        if ((Test-Command 'npm') -and (Ask "Configurare il server gateway?" $false)) {
            Push-Location server
            npm ci
            npm run build
            npm audit --audit-level=high
            if (-not (Test-Path .env)) {
                Copy-Item .env.example .env
                Write-Warn "Creato server\.env: inserisci lì la tua ANTHROPIC_API_KEY."
            }
            Pop-Location
            Write-Ok "Gateway compilato (avvio: cd server; npm start)"
        }
    }

    # ── 6. Windows-Firewall: iPhone muss den PC erreichen (WLAN und ggf. Tailscale) ──
    if (-not $Unattended) {
        Write-Step "Firewall di Windows"
        $hasTailscale = [bool](Get-NetAdapter -Name 'Tailscale' -ErrorAction SilentlyContinue)
        $missing = (-not (Test-Rule 'RayBan Claude')) -or ($hasTailscale -and -not (Test-Rule 'RayBan Claude (Tailscale)'))
        if (-not $missing) {
            Write-Ok "Regole del firewall presenti"
        } else {
            Write-Host "  Perché l'iPhone raggiunga il PC, la porta $Port deve essere aperta sulla rete PRIVATA" -ForegroundColor Gray
            Write-Host "  (e, se installato, per i tuoi dispositivi Tailscale)." -ForegroundColor Gray
            if (Ask "Aprirla ora? Windows chiederà i diritti di amministratore.") {
                Start-Process powershell -Verb RunAs -Wait -ArgumentList @(
                    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSScriptRoot\firewall.ps1`"", '-Port', $Port)
            } else {
                Write-Warn "In alternativa, al primo avvio rispondi 'Consenti' alla richiesta di Windows per le 'Reti private'."
            }
        }
        if (-not $hasTailscale) {
            Write-Host "  Vuoi usarlo fuori casa col tuo abbonamento Claude? Installa Tailscale (gratuito) su PC e iPhone" -ForegroundColor Gray
            Write-Host "  (https://tailscale.com/download) e avvia di nuovo setup.cmd." -ForegroundColor Gray
        }
    }

    $profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq 'Public' }
    if ($profiles) {
        Write-Warn "La tua Wi-Fi è impostata come 'Pubblica': così Windows blocca l'iPhone."
        Write-Host "    Impostazioni → Rete e Internet → Wi-Fi → Tipo di profilo di rete: Privata" -ForegroundColor Cyan
    }

    # ── Fertig ───────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  ✅ Fatto! Ecco come proseguire:" -ForegroundColor Green
    Write-Host "   1. Avvia 'RayBan Claude' (icona sul desktop o start.cmd)"
    Write-Host "      La prima volta: accedi a Claude, conferma 'Use this MCP server' e"
    Write-Host "      'I am using this for local development'."
    Write-Host "   2. Si apre la dashboard: http://localhost:$Port"
    Write-Host "   3. Installa l'app per iPhone: docs\IPHONE-OHNE-MAC.md (gratis, con Sideloadly)"
    Write-Host "   4. Scansiona il codice QR della dashboard con la fotocamera dell'iPhone: fatto."
    Write-Host "   5. Fuori casa: con Tailscale l'indirizzo per fuori casa è già incluso nel codice QR."
    Write-Host ""
    if ($Unattended) { Start-Sleep -Seconds 3 }
} catch {
    Write-Host ""
    Write-Host "  ✗ Installazione interrotta: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Suggerimento: controlla la connessione a Internet e avvia di nuovo l'installazione (setup.cmd)." -ForegroundColor Gray
    if ($Unattended) { Read-Host "  Premi Invio per chiudere" | Out-Null }
    exit 1
}
