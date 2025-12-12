# update-dependencies.ps1
# Update project dependencies

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('backend','frontend','all')]
    [string]$Target = 'all',
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

Write-Host "`n📦 Update Dependencies" -ForegroundColor Cyan
Write-Host "=" * 60

function Update-BackendDependencies {
    Write-Host "`n🔧 Updating .NET packages..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would update .NET packages" -ForegroundColor Gray
        docker-compose exec aspdotnetweb dotnet list package --outdated
    } else {
        docker-compose exec aspdotnetweb dotnet outdated -u
        Write-Host "✅ .NET packages updated" -ForegroundColor Green
    }
}

function Update-FrontendDependencies {
    Write-Host "`n⚡ Updating Node packages..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would update Node packages" -ForegroundColor Gray
        docker-compose exec frontend npm outdated
    } else {
        docker-compose exec frontend npm update
        docker-compose exec frontend npm audit fix
        Write-Host "✅ Node packages updated" -ForegroundColor Green
    }
}

# Execute based on target
switch ($Target) {
    'backend' {
        Update-BackendDependencies
    }
    'frontend' {
        Update-FrontendDependencies
    }
    'all' {
        Update-BackendDependencies
        Update-FrontendDependencies
    }
}

Write-Host "`n✅ Dependencies update completed" -ForegroundColor Green
Write-Host "💡 Rebuild containers: docker-compose up -d --build" -ForegroundColor Cyan