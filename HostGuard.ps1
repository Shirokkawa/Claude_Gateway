$ErrorActionPreference = 'Stop'

$ruleName = 'Claude VM kill switch - Clash 7897'
$logPath = Join-Path $PSScriptRoot 'host-guard.log'
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('192.168.50.1'), 7898)
$lastState = $null

function Write-State($message) {
    Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) $message"
}

function Set-Blocked([bool]$blocked) {
    $desired = if ($blocked) { 'True' } else { 'False' }
    $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
    if ([string]$rule.Enabled -ne $desired) {
        Set-NetFirewallRule -DisplayName $ruleName -Enabled $desired
    }
}

Set-Blocked $true
$listener.Start()
try {
    while ($true) {
        $healthy = $false
        try {
            $tun = Get-NetAdapter -Name 'Mihomo' -ErrorAction Stop
            if ($tun.Status -eq 'Up') {
                $trace = @(& curl.exe --noproxy '' --proxy 'http://127.0.0.1:7897' --connect-timeout 2 --max-time 5 --fail --silent 'https://www.cloudflare.com/cdn-cgi/trace' 2>$null)
                $healthy = ($LASTEXITCODE -eq 0 -and ($trace -contains 'loc=PH'))
            }
        } catch {
            $healthy = $false
        }

        try {
            Set-Blocked (-not $healthy)
        } catch {
            $healthy = $false
            Write-State "firewall error: $($_.Exception.Message)"
        }
        if ($healthy -ne $lastState) {
            Write-State "healthy=$healthy"
            $lastState = $healthy
        }

        $until = [DateTime]::UtcNow.AddSeconds(2)
        while ([DateTime]::UtcNow -lt $until) {
            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                try {
                    if ($client.Client.RemoteEndPoint.Address.ToString() -eq '192.168.50.2') {
                        $body = if ($healthy) { 'PH' } else { 'FAIL' }
                        $status = if ($healthy) { '200 OK' } else { '503 Service Unavailable' }
                        $response = "HTTP/1.1 $status`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n$body"
                        $bytes = [System.Text.Encoding]::ASCII.GetBytes($response)
                        $client.GetStream().Write($bytes, 0, $bytes.Length)
                    }
                } finally {
                    $client.Dispose()
                }
            }
            Start-Sleep -Milliseconds 100
        }
    }
} finally {
    $listener.Stop()
    Set-Blocked $true
}
