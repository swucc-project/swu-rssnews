# wsl2-portforward.ps1
# Port Forwarding จาก Windows → WSL2

$ports = @(5000, 5173, 8080, 1433, 13714, 24678)
$wslIP = (wsl hostname -I).Trim()

Write-Host "🔗 WSL2 IP: $wslIP" -ForegroundColor Cyan

foreach ($port in $ports) {
    # ลบ rule เก่า
    netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0
    
    # เพิ่ม rule ใหม่
    netsh interface portproxy add v4tov4 `
        listenport=$port `
        listenaddress=0.0.0.0 `
        connectport=$port `
        connectaddress=$wslIP
    
    Write-Host "✅ Port $port forwarded to WSL2" -ForegroundColor Green
}

# แสดงผลลัพธ์
Write-Host "`n📋 Active Port Proxy Rules:" -ForegroundColor Magenta
netsh interface portproxy show all