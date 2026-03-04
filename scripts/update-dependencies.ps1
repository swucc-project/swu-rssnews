# update-dependencies.ps1
# Safe dependency update for swu-rssnews

param(
    [ValidateSet('backend', 'frontend', 'all')]
    [string]$Target = 'all',

    [switch]$DryRun,
    [switch]$Force
)

$ProjectName = "swu-rssnews"

function Get-ComposeCommand {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        return "docker-compose"
    }
    return "docker compose"
}

$compose = Get-ComposeCommand

function Test-ContainerRunning {
    param([string]$Service)
    $state = & $compose ps --services --filter "status=running" | Select-String "^$Service$"
    if (-not $state) {
        Write-Host "❌ Service '$Service' is not running" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n📦 Dependency Update - $ProjectName" -ForegroundColor Cyan
Write-Host "=" * 60

function Update-Backend {
    Test-ContainerRunning "aspdotnetweb"

    Write-Host "`n🔧 .NET Dependencies" -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "📋 Outdated packages:" -ForegroundColor Gray
        & $compose exec aspdotnetweb dotnet list package --outdated
        return
    }

    # Check dotnet-outdated
    $toolCheck = & $compose exec aspdotnetweb dotnet tool list -g | Select-String dotnet-outdated
    if (-not $toolCheck) {
        Write-Host "⚠️  dotnet-outdated not installed (skipping auto-upgrade)" -ForegroundColor Yellow
        Write-Host "   Install manually if needed:" -ForegroundColor Gray
        Write-Host "   dotnet tool install -g dotnet-outdated-tool" -ForegroundColor Gray
        return
    }

    if (-not $Force) {
        Write-Host "⚠️  Auto-upgrading .NET packages can break the build" -ForegroundColor Yellow
        if ((Read-Host "Continue? (yes/no)") -ne "yes") { return }
    }

    & $compose exec aspdotnetweb dotnet outdated -u
    Write-Host "✅ .NET packages upgraded" -ForegroundColor Green
}

function Update-Frontend {
    Test-ContainerRunning "frontend"

    Write-Host "`n⚡ Frontend Dependencies" -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "📋 Outdated npm packages:" -ForegroundColor Gray
        & $compose exec frontend npm outdated
        return
    }

    if (-not $Force) {
        Write-Host "⚠️  npm update may change dependency versions" -ForegroundColor Yellow
        if ((Read-Host "Continue? (yes/no)") -ne "yes") { return }
    }

    & $compose exec frontend npm update
    Write-Host "✅ npm packages updated" -ForegroundColor Green

    Write-Host "🔍 Running npm audit (report only)" -ForegroundColor Cyan
    & $compose exec frontend npm audit
}

switch ($Target) {
    'backend' { Update-Backend }
    'frontend' { Update-Frontend }
    'all' { Update-Backend; Update-Frontend }
}

Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review changes in package files" -ForegroundColor Gray
Write-Host "  2. Rebuild containers:" -ForegroundColor Gray
Write-Host "     docker-compose up -d --build" -ForegroundColor White
Write-Host "  3. Run health check:" -ForegroundColor Gray
Write-Host "     .\scripts\health-check.ps1" -ForegroundColor White
Write-Host "`n"