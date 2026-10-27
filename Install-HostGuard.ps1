# Run once in an administrator PowerShell window.
$ErrorActionPreference = 'Stop'
$guardPath = Join-Path $PSScriptRoot 'HostGuard.ps1'
$taskName = 'Claude VM PH proxy guard'
$gatewayRule = 'Claude VM kill switch - Clash 7897'

if (-not (Test-Path -LiteralPath $guardPath)) { throw "Missing $guardPath" }
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script in an administrator PowerShell window.'
}

if (-not (Get-NetFirewallRule -DisplayName $gatewayRule -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $gatewayRule -Direction Inbound -Action Block -Enabled True -Profile Any -Protocol TCP -LocalAddress '192.168.50.1' -LocalPort 7897 -RemoteAddress '192.168.50.2' | Out-Null
} else {
    Set-NetFirewallRule -DisplayName $gatewayRule -Enabled True
}
if (-not (Get-NetFirewallRule -DisplayName 'Claude VM block direct proxy' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'Claude VM block direct proxy' -Direction Inbound -Action Block -Enabled True -Profile Any -Protocol TCP -LocalAddress '192.168.50.1' -LocalPort 7897 -RemoteAddress '192.168.50.10' | Out-Null
}
if (-not (Get-NetFirewallRule -DisplayName 'Claude VM block direct proxy IPv6' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'Claude VM block direct proxy IPv6' -Direction Inbound -Action Block -Enabled True -Profile Any -Protocol TCP -InterfaceAlias 'VMware Network Adapter VMnet1' -LocalPort 7897 -RemoteAddress 'fe80::/10' -ErrorAction Stop | Out-Null
}
if (-not (Get-NetFirewallRule -DisplayName 'Claude VM guard heartbeat' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'Claude VM guard heartbeat' -Direction Inbound -Action Allow -Enabled True -Profile Any -Protocol TCP -LocalAddress '192.168.50.1' -LocalPort 7898 -RemoteAddress '192.168.50.2' | Out-Null
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$guardPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -RestartInterval (New-TimeSpan -Minutes 1) -RestartCount 999 -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State
