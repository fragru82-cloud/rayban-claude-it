<#
  Funzioni condivise: token del webhook wa-send e numero dell'utente.
  Il numero NON sta nel codice (repo pubblico): si legge da RAYBANCLAUDE_NOTE_TO
  nel file .env del canale (lo scrive tools\personale\configura.ps1).
#>
$script:Mega = Join-Path $env:USERPROFILE 'Desktop\MEGA CAPANNONE'
$script:ChannelEnv = Join-Path $env:USERPROFILE '.claude\channels\raybanclaude\.env'

function Get-ChannelEnvValue([string]$Key) {
    if (-not (Test-Path $script:ChannelEnv)) { return $null }
    foreach ($l in (Get-Content $script:ChannelEnv)) {
        if ($l -match "^\s*$Key\s*=\s*(.+?)\s*$") { return $Matches[1].Trim('"', "'") }
    }
    return $null
}

function Get-WaToken {
    if ($env:RAYBANCLAUDE_WA_TOKEN) { return $env:RAYBANCLAUDE_WA_TOKEN.Trim() }
    $local = Join-Path $PSScriptRoot 'wa-token.txt'
    if (Test-Path $local) { return (Get-Content $local -Raw).Trim() }
    $fromEnv = Get-ChannelEnvValue 'RAYBANCLAUDE_NOTE_TOKEN'
    if ($fromEnv) { return $fromEnv }
    $files = @(
        (Join-Path $script:Mega 'Sviluppo\Bot e Automazioni\RIPRISTINO-COMPLETO.md'),
        (Join-Path $script:Mega 'GLOBALINK-AI-CONTEXT.md')
    )
    foreach ($f in $files) {
        if (-not (Test-Path $f)) { continue }
        $lines = Get-Content $f -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch 'wa-send') { continue }
            $from = [Math]::Max(0, $i - 15); $to = [Math]::Min($lines.Count - 1, $i + 15)
            foreach ($l in $lines[$from..$to]) {
                if ($l -match 'Bearer\s+([A-Za-z0-9_\-\.~+/=]{16,})') { return $Matches[1] }
            }
        }
    }
    return $null
}

function Get-WaNumber {
    if ($env:RAYBANCLAUDE_WA_TO) { return $env:RAYBANCLAUDE_WA_TO.Trim() }
    $local = Join-Path $PSScriptRoot 'wa-numero.txt'
    if (Test-Path $local) { return (Get-Content $local -Raw).Trim() }
    return (Get-ChannelEnvValue 'RAYBANCLAUDE_NOTE_TO')
}
