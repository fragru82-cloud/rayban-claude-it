<#
  RayBan Claude – Windows-Firewall freigeben (braucht Administrator-Rechte)

  Öffnet Port 18790 NUR im privaten Netzwerk (Heim-WLAN) und – falls Tailscale installiert ist –
  NUR auf dem Tailscale-Adapter für Geräte aus deinem eigenen Tailnet (100.64.0.0/10).
  Mit -Remove werden beide Regeln wieder entfernt (Deinstallation).
#>
param(
    [switch]$Remove,
    [int]$Port = 18790
)
$ErrorActionPreference = 'Stop'
$Lan = 'RayBan Claude'
$Tailnet = 'RayBan Claude (Tailscale)'

function Test-Rule($name) { [bool](Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) }

try {
    if ($Remove) {
        foreach ($name in @($Lan, $Tailnet)) {
            if (Test-Rule $name) { Remove-NetFirewallRule -DisplayName $name }
        }
        Write-Host "  ✓ Regole del firewall di RayBan Claude rimosse" -ForegroundColor Green
        exit 0
    }
    if (-not (Test-Rule $Lan)) {
        New-NetFirewallRule -DisplayName $Lan -Direction Inbound -Protocol TCP -LocalPort $Port -Profile Private -Action Allow | Out-Null
    }
    Write-Host "  ✓ Wi-Fi di casa: porta $Port aperta sulla rete privata" -ForegroundColor Green
    if (Get-NetAdapter -Name 'Tailscale' -ErrorAction SilentlyContinue) {
        if (-not (Test-Rule $Tailnet)) {
            New-NetFirewallRule -DisplayName $Tailnet -Direction Inbound -Protocol TCP -LocalPort $Port `
                -InterfaceAlias 'Tailscale' -RemoteAddress 100.64.0.0/10 -Action Allow | Out-Null
        }
        Write-Host "  ✓ Fuori casa: porta $Port aperta per i tuoi dispositivi Tailscale" -ForegroundColor Green
    }
} catch {
    Write-Host "  ! Impossibile configurare il firewall: $($_.Exception.Message)" -ForegroundColor Yellow
    Start-Sleep -Seconds 6
    exit 1
}
