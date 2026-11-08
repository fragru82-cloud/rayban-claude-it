<#
  RayBan Claude - controllo automatico (watchdog).
  Se http://127.0.0.1:18790/health non risponde:
    1. rilancia start.cmd ridotto a icona (solo se non e' gia' in esecuzione)
    2. manda un WhatsApp a Francesco per ricordare di premere Invio da AnyDesk
  Uso:  watchdog.ps1            (controllo normale)
        watchdog.ps1 -Test      (manda solo un WhatsApp di prova, non rilancia nulla)
  File ASCII-only di proposito (PowerShell 5.1 legge male UTF-8 senza BOM).
#>
param([switch]$Test)

$ErrorActionPreference = 'Stop'
$Root     = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$StartCmd = Join-Path $Root 'start.cmd'
$Port     = if ($env:RAYBANCLAUDE_PORT) { $env:RAYBANCLAUDE_PORT } else { 18790 }
$Health   = "http://127.0.0.1:$Port/health"
$Log      = Join-Path $PSScriptRoot 'watchdog.log'
$WaUrl    = 'https://www.globalinkgroup.it/wa-send'
# Token e numero: vedi token.ps1 (il numero non sta nel codice, il repo e' pubblico)
. (Join-Path $PSScriptRoot 'token.ps1')

function Write-Log($msg) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $Log -Value $line -Encoding ASCII
    if ((Get-Item $Log).Length -gt 512KB) { Move-Item $Log "$Log.old" -Force }
}

function Test-Health {
    try {
        $r = Invoke-RestMethod -Uri $Health -TimeoutSec 5
        return ($r.status -eq 'ok')
    } catch { return $false }
}

function Send-Wa($text) {
    $token = Get-WaToken
    $WaNumber = Get-WaNumber
    if (-not $token) { Write-Log 'ERRORE: token wa-send non trovato (crea tools\watchdog\wa-token.txt)'; return }
    if (-not $WaNumber) { Write-Log 'ERRORE: numero non configurato (esegui tools\personale\configura.ps1 -Numero ...)'; return }
    # Campi duplicati per compatibilita' col formato del webhook; testo senza emoji.
    $body = @{ to = $WaNumber; number = $WaNumber; phone = $WaNumber; message = $text; text = $text } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Uri $WaUrl -Method Post -Headers @{ Authorization = "Bearer $token" } `
            -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 20 | Out-Null
        Write-Log 'WhatsApp inviato'
    } catch { Write-Log "ERRORE invio WhatsApp: $($_.Exception.Message)" }
}

function Test-AlreadyRunning {
    # Claude Code con il canale raybanclaude gia' avviato (es. fermo sull'avviso rosso in attesa di Invio)
    $p = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
         Where-Object { $_.CommandLine -and $_.CommandLine -match 'server:raybanclaude' }
    return [bool]$p
}

if ($Test) { Send-Wa 'RayBan Claude: messaggio di prova dal watchdog del PC ufficio.'; exit 0 }

if (Test-Health) { Write-Log 'OK'; exit 0 }

$ora = Get-Date -Format 'HH:mm'
if (Test-AlreadyRunning) {
    Write-Log 'Health KO ma Claude e'' gia'' avviato: probabilmente attende Invio. Nessun rilancio.'
    Send-Wa "RayBan Claude ($ora): il canale non risponde ma Claude e' gia' aperto sul PC ufficio. Entra con AnyDesk e premi Invio sull'avviso rosso."
    exit 0
}

Write-Log 'Health KO: rilancio start.cmd ridotto a icona'
Start-Process -FilePath $StartCmd -WorkingDirectory $Root -WindowStyle Minimized
Send-Wa "RayBan Claude ($ora): era spento, l'ho rilanciato sul PC ufficio. Entra con AnyDesk e premi Invio sull'avviso rosso, poi lascia aperta la finestra."

# Verifica dopo 3 minuti (se hai gia' premuto Invio, lo registra nel log)
Start-Sleep -Seconds 180
if (Test-Health) { Write-Log 'Ripartito correttamente' } else { Write-Log 'Ancora in attesa di Invio' }
