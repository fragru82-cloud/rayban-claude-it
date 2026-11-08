<#
  Configurazione personale degli occhiali (resta solo su questo PC, non va su GitHub):
    - crea CLAUDE.local.md nella cartella del progetto (briefing vocale e regole);
    - aggiunge al file .env del canale le note su WhatsApp (webhook, token, numero).
  Uso:  configura.ps1 -Numero 39XXXXXXXXXX
  Prima di modificare fa una copia di backup dei file esistenti.
  File ASCII-only di proposito (PowerShell 5.1 legge male UTF-8 senza BOM).
#>
param([Parameter(Mandatory = $true)][ValidatePattern('^\d{8,15}$')][string]$Numero)
$ErrorActionPreference = 'Stop'
$Root    = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Mega    = Join-Path $env:USERPROFILE 'Desktop\MEGA CAPANNONE'
$Svil    = Join-Path $Mega 'Sviluppo'
$EnvDir  = Join-Path $env:USERPROFILE '.claude\channels\raybanclaude'
$EnvFile = Join-Path $EnvDir '.env'
$Stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8    = New-Object System.Text.UTF8Encoding($false)   # UTF-8 senza BOM

# 1. CLAUDE.local.md dal modello
$dest = Join-Path $Root 'CLAUDE.local.md'
if (Test-Path $dest) { Copy-Item $dest "$dest.bak-$Stamp" }
$text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'CLAUDE.local.md.modello'), $Utf8).Replace('{{SVILUPPO}}', $Svil)
[IO.File]::WriteAllText($dest, $text, $Utf8)
Write-Host "Creato $dest"

# 2. Token del webhook (stessa ricerca del watchdog)
. (Join-Path $Root 'tools\watchdog\token.ps1')
$token = Get-WaToken
if (-not $token) { throw 'Token wa-send non trovato: crea tools\watchdog\wa-token.txt e rilancia.' }

# 3. .env del canale: sostituisce solo le righe RAYBANCLAUDE_NOTE_*
New-Item -ItemType Directory -Force -Path $EnvDir | Out-Null
$lines = @()
if (Test-Path $EnvFile) {
    Copy-Item $EnvFile "$EnvFile.bak-$Stamp"
    $lines = @([IO.File]::ReadAllLines($EnvFile, $Utf8) | Where-Object { $_ -notmatch '^\s*RAYBANCLAUDE_NOTE_' })
}
$lines += 'RAYBANCLAUDE_NOTE_URL=https://www.globalinkgroup.it/wa-send'
$lines += "RAYBANCLAUDE_NOTE_TOKEN=$token"
$lines += "RAYBANCLAUDE_NOTE_TO=$Numero"
[IO.File]::WriteAllText($EnvFile, (($lines -join "`n") + "`n"), $Utf8)
Write-Host "Note WhatsApp configurate in $EnvFile"
Write-Host 'Chiudi e riapri RayBan Claude (start.cmd) per attivare le modifiche.'
