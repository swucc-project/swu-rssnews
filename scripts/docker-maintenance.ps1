# docker-maintenance.ps1
param(
    [ValidateSet('Status', 'Logs', 'Restart', 'Rebuild', 'Backup')]
    [string]$Action = 'Status'
)

$ProjectName = "swu-rssnews"
$compose = (docker compose version 2>$null) ? "docker compose" : "docker-compose"

switch ($Action) {
    'Status' {
        Invoke-Expression "$compose ps"
        Write-Host "`n📊 Docker Volumes:" -ForegroundColor Cyan
        docker volume ls --filter "name=$ProjectName"
        Write-Host "`n🌐 Docker Networks:" -ForegroundColor Cyan
        docker network ls --filter "name=$ProjectName"
        Write-Host "`n💾 Disk Usage:" -ForegroundColor Cyan
        docker system df
    }
    'Logs' {
        Invoke-Expression "$compose logs -f --tail=100"
    }
    'Restart' {
        Invoke-Expression "$compose restart"
    }
    'Rebuild' {
        Invoke-Expression "$compose up -d --build"
    }
    # ✅ แก้ไขส่วน Backup ให้รองรับ Volume ใหม่ทั้ง 4 ตัว
    'Backup' {
        $date = Get-Date -Format yyyyMMdd-HHmmss
        $backupRoot = ".\backups\$date"
        New-Item $backupRoot -ItemType Directory -Force | Out-Null
        
        Write-Host "📦 Starting Backup to: $backupRoot" -ForegroundColor Yellow

        # รายชื่อ Volume ใหม่ที่ต้อง Backup
        $volumes = @("mssql-data", "mssql-logs", "mssql-backups", "mssql-system")

        foreach ($vol in $volumes) {
            $fullVolName = "${ProjectName}_${vol}"
            
            # ตรวจสอบว่ามี Volume อยู่จริงไหม
            if (docker volume ls -q -f name=$fullVolName) {
                Write-Host "  backing up $vol..." -NoNewline
                
                try {
                    docker run --rm `
                        -v "${fullVolName}:/source:ro" `
                        -v "${PWD}\backups\${date}:/backup" `
                        alpine tar czf "/backup/${vol}.tar.gz" -C /source .
                    
                    Write-Host " Done" -ForegroundColor Green
                }
                catch {
                    Write-Host " Failed" -ForegroundColor Red
                }
            }
            else {
                Write-Host "  ⚠️ Volume $fullVolName not found, skipping." -ForegroundColor DarkGray
            }
        }
        Write-Host "✅ All backups completed." -ForegroundColor Green
    }
}