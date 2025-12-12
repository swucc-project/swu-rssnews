# docker-maintenance.ps1
# รวมคำสั่งบำรุงรักษา Docker

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Status','Logs','Restart','Rebuild','Backup')]
    [string]$Action = 'Status'
)

$ProjectName = "swu-rssnews"

switch ($Action) {
    'Status' {
        Write-Host "`n📊 Project Status" -ForegroundColor Cyan
        Write-Host "=" * 60
        
        Write-Host "`n🐳 Containers:" -ForegroundColor Yellow
        docker-compose ps
        
        Write-Host "`n💾 Volumes:" -ForegroundColor Yellow
        docker volume ls --filter "name=$ProjectName"
        
        Write-Host "`n🌐 Networks:" -ForegroundColor Yellow
        docker network ls --filter "name=$ProjectName"
        
        Write-Host "`n💿 Disk Usage:" -ForegroundColor Yellow
        docker system df
    }
    
    'Logs' {
        Write-Host "📜 Viewing logs (Ctrl+C to exit)..." -ForegroundColor Cyan
        docker-compose logs -f --tail=100
    }
    
    'Restart' {
        Write-Host "🔄 Restarting services..." -ForegroundColor Yellow
        docker-compose restart
        Write-Host "✅ Restarted" -ForegroundColor Green
    }
    
    'Rebuild' {
        Write-Host "🔨 Rebuilding services..." -ForegroundColor Yellow
        docker-compose up -d --build
        Write-Host "✅ Rebuilt" -ForegroundColor Green
    }
    
    'Backup' {
        $backupDate = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = ".\backups\$backupDate"
        
        Write-Host "💾 Creating backup at $backupPath..." -ForegroundColor Cyan
        
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        
        # Export volumes
        docker run --rm -v swu-rssnews_rssdata:/data -v ${PWD}/backups/${backupDate}:/backup alpine tar czf /backup/rssdata.tar.gz -C /data .
        
        Write-Host "✅ Backup created" -ForegroundColor Green
    }
}