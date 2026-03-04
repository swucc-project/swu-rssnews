# stop-entire.ps1
# Safe & graceful stop for entire swu-rssnews stack

param(
    [switch]$RemoveVolumes,
    [switch]$Force,
    [switch]$DryRun,
    [int]$Timeout = 30
)

$ProjectName = "swu-rssnews"

function Get-ComposeCommand {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        return "docker-compose"
    }
    return "docker compose"
}

$compose = Get-ComposeCommand

Write-Host "`n🛑 Stopping $ProjectName" -ForegroundColor Yellow
Write-Host "=" * 60

# Check Docker
try {
    docker info | Out-Null
} catch {
    Write-Host "❌ Docker Engine is not running" -ForegroundColor Red
    exit 1
}

# Confirm volume removal
if ($RemoveVolumes -and -not $Force) {
    Write-Host "⚠️  WARNING: Volumes (data) will be removed!" -ForegroundColor Red
    if ((Read-Host "Type 'yes' to continue") -ne "yes") {
        Write-Host "❌ Cancelled" -ForegroundColor Red
        exit 0
    }
}

# Show running services
Write-Host "`n📦 Running containers:" -ForegroundColor Cyan
& $compose ps

if ($DryRun) {
    Write-Host "`n🧪 Dry Run mode (no changes will be made)" -ForegroundColor Yellow
    Write-Host "Command:" -ForegroundColor Gray
    Write-Host "  $compose down $(if ($RemoveVolumes) {'-v'}) --timeout $Timeout" -ForegroundColor White
    exit 0
}

Write-Host "`n🛑 Stopping services gracefully..." -ForegroundColor Yellow

try {
    if ($RemoveVolumes) {
        & $compose down -v --timeout $Timeout
        Write-Host "✅ Services stopped & volumes removed" -ForegroundColor Green
    } else {
        & $compose down --timeout $Timeout
        Write-Host "✅ Services stopped (volumes preserved)" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to stop services" -ForegroundColor Red
    if (-not $Force) { exit 1 }
}

# Final summary
Write-Host "`n📊 Summary:" -ForegroundColor Cyan
docker ps --filter "name=$ProjectName"

Write-Host "`n💡 Tips:" -ForegroundColor Cyan
Write-Host "  Start again:   .\scripts\quick-start.ps1" -ForegroundColor Gray
Write-Host "  Cleanup safe:  .\scripts\docker-cleanup.ps1 -Mode Safe" -ForegroundColor Gray
Write-Host "  Full reset:    .\scripts\docker-cleanup.ps1 -Mode Reset -Force" -ForegroundColor Gray
Write-Host "`n"