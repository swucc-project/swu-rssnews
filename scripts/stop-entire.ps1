# stop-entire.ps1
# Stop all services safely

param(
    [Parameter(Mandatory=$false)]
    [switch]$RemoveVolumes,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ProjectName = "swu-rssnews"

Write-Host "`n🛑 Stopping $ProjectName..." -ForegroundColor Yellow
Write-Host "=" * 60

# Confirm if removing volumes
if ($RemoveVolumes -and -not $Force) {
    Write-Host "⚠️  WARNING: This will remove volumes (including data)!" -ForegroundColor Red
    $response = Read-Host "Are you sure? (yes/no)"
    
    if ($response -ne "yes") {
        Write-Host "❌ Cancelled" -ForegroundColor Red
        exit 0
    }
}

# Show current status
Write-Host "`n📊 Current Status:" -ForegroundColor Cyan
docker-compose ps

# Stop services
Write-Host "`n🛑 Stopping services..." -ForegroundColor Yellow

if ($RemoveVolumes) {
    docker-compose down -v
    Write-Host "✅ Services stopped and volumes removed" -ForegroundColor Green
} else {
    docker-compose down
    Write-Host "✅ Services stopped (volumes preserved)" -ForegroundColor Green
}

# Show final status
Write-Host "`n📊 Final Status:" -ForegroundColor Cyan
docker-compose ps

Write-Host "`n💡 Tips:" -ForegroundColor Cyan
Write-Host "  To start again:  .\scripts\quick-start.ps1" -ForegroundColor Gray
Write-Host "  To cleanup:      .\scripts\docker-cleanup.ps1 -Mode Safe" -ForegroundColor Gray
Write-Host "`n"