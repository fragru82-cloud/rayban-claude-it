<#
  Installa: collegamento sul desktop + task pianificato "RayBan Claude Watchdog" (6:00 e 18:00).
  -AvvioAccesso  aggiunge anche l'avvio all'accesso a Windows (passo 3, facoltativo).
  -Rimuovi       toglie task e collegamento.
  Eseguire come utente normale (non serve amministratore).
#>
param([switch]$AvvioAccesso, [switch]$Rimuovi)
$ErrorActionPreference = 'Stop'
$Root     = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$TaskName = 'RayBan Claude Watchdog'
$Lnk      = Join-Path ([Environment]::GetFolderPath('Desktop')) 'RayBan Claude.lnk'

if ($Rimuovi) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $Lnk -ErrorAction SilentlyContinue
    Write-Host 'Rimossi task e collegamento.'; exit 0
}

# 1. Collegamento sul desktop (solo se manca)
if (-not (Test-Path $Lnk)) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($Lnk)
    $s.TargetPath = Join-Path $Root 'start.cmd'
    $s.WorkingDirectory = "$Root"
    $s.Description = 'Avvia RayBan Claude'
    $s.Save()
    Write-Host "Collegamento creato: $Lnk"
} else { Write-Host 'Collegamento gia'' presente, non toccato.' }

# 2. Task pianificato: gira nella sessione dell'utente (finestra visibile da AnyDesk)
# Sempre Windows PowerShell 5.1: in PowerShell 7 $PSHOME non contiene powershell.exe
$ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$action = New-ScheduledTaskAction -Execute $ps `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\watchdog.ps1`""
$triggers = @(
    (New-ScheduledTaskTrigger -Daily -At '06:00'),
    (New-ScheduledTaskTrigger -Daily -At '18:00')
)
if ($AvvioAccesso) {
    $t = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $t.Delay = 'PT1M'
    $triggers += $t
}
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Export-ScheduledTask -TaskName $TaskName | Out-File (Join-Path $PSScriptRoot "task-backup-$(Get-Date -Format yyyyMMdd-HHmmss).xml") -Encoding UTF8
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings `
    -Description 'Controlla RayBan Claude alle 6 e alle 18; se spento lo rilancia e avvisa su WhatsApp.' | Out-Null
Write-Host "Task '$TaskName' registrato (06:00, 18:00$(if ($AvvioAccesso) {', accesso a Windows'}))."
