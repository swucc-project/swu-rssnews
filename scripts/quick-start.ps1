# quick-start.ps1
# Quick Start Script for swu-rssnews project

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Development','Production')]
    [string]$Environment = 'Development',
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipFirewall,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPortForward
)

$ErrorActionPreference = "Stop"
$ProjectName = "swu-rssnews"

Write-Host "`n🚀 Quick Start - $ProjectName" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "=" * 60

# ================== Helper Functions ==================

function Test-DockerRunning {
    try {
        docker info | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-WSL2Running {
    try {
        $wslStatus = wsl --status 2>&1
        return $?
    } catch {
        return $false
    }
}

function Write-Step {
    param([int]$Step, [string]$Message, [string]$Color = "Cyan")
    Write-Host "`n[$Step] $Message" -ForegroundColor $Color
}

# ================== Pre-flight Checks ==================

Write-Step 0 "🔍 Checking prerequisites..." "Yellow"

# Check Docker
if (-not (Test-DockerRunning)) {
    Write-Host "❌ Docker is not running!" -ForegroundColor Red
    Write-Host "💡 Please start Docker Desktop first." -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Docker is running" -ForegroundColor Green

# Check WSL2
if (-not (Test-WSL2Running)) {
    Write-Host "⚠️  WSL2 is not available" -ForegroundColor Yellow
    Write-Host "💡 WSL2 port forwarding will be skipped" -ForegroundColor Gray
    $SkipPortForward = $true
}

# ================== Setup Firewall ==================

if (-not $SkipFirewall) {
    Write-Step 1 "🔥 Setting up Windows Firewall..." "Cyan"
    
    try {
        & "$PSScriptRoot\firewall-setup.ps1" -Action Enable -Environment $Environment
    } catch {
        Write-Host "⚠️  Firewall setup failed: $_" -ForegroundColor Yellow
        Write-Host "💡 Continuing anyway..." -ForegroundColor Gray
    }
} else {
    Write-Host " ⏭️  Skipping firewall setup" -ForegroundColor Gray
}

# ================== WSL2 Port Forwarding ==================

if (-not $SkipPortForward) {
    Write-Step 2 "🔗 Setting up WSL2 port forwarding..." "Cyan"
    
    try {
        & "$PSScriptRoot\wsl2-portforward.ps1"
    } catch {
        Write-Host "⚠️  Port forwarding failed: $_" -ForegroundColor Yellow
        Write-Host "💡 Continuing anyway..." -ForegroundColor Gray
    }
} else {
    Write-Host " ⏭️  Skipping WSL2 port forwarding" -ForegroundColor Gray
}

# ================== Create External Volumes ==================

Write-Step 3 "💾 Checking external volumes..." "Cyan"

$requiredVolumes = @(
    "swu-rssnews_rssdata",
    "swu-rssnews_db-backups",
    "swu-rssnews_rssdata-logs"
)

foreach ($volumeName in $requiredVolumes) {
    $exists = docker volume ls --format "{{.Name}}" | Select-String -Pattern "^$volumeName$"
    
    if ($exists) {
        Write-Host "✅ Volume exists: $volumeName" -ForegroundColor Green
    } else {
        Write-Host "📦 Creating volume: $volumeName" -ForegroundColor Yellow
        docker volume create $volumeName
        Write-Host "✅ Created: $volumeName" -ForegroundColor Green
    }
}

# ================== Setup Database ==================

Write-Step 4 "🗄️  Setting up database..." "Cyan"

$setupExists = docker-compose ps --services --filter "name=queue-db-migration" 2>$null

if ($setupExists) {
    Write-Host "Running database setup..." -ForegroundColor Yellow
    docker-compose --profile setup up --abort-on-container-exit
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database setup completed" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Database setup completed with warnings" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️  Database setup profile not found, skipping..." -ForegroundColor Gray
}

# ================== Start Services ==================

Write-Step 5 "🐳 Starting Docker containers..." "Cyan"

if ($Environment -eq 'Production') {
    Write-Host "Starting production services..." -ForegroundColor Yellow
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
} else {
    Write-Host "Starting development services..." -ForegroundColor Yellow
    docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Services started successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to start services" -ForegroundColor Red
    exit 1
}

# ================== Wait for Services ==================

Write-Step 6 "⏳ Waiting for services to be ready..." "Cyan"

Write-Host "Waiting 15 seconds for services to initialize..." -ForegroundColor Gray
Start-Sleep -Seconds 15

# Check service health
Write-Host "`nChecking service health:" -ForegroundColor Yellow

$services = @{
    "SQL Server" = "http://localhost:1433"
    "ASP.NET Core" = "http://localhost:5000/health"
    "Nginx" = "http://localhost:8080/health"
}

if ($Environment -eq 'Development') {
    $services["Vite Dev"] = "http://localhost:5173"
    $services["SSR Server"] = "http://localhost:13714/health"
}

foreach ($name in $services.Keys) {
    $url = $services[$name]
    
    # Special handling for SQL Server
    if ($name -eq "SQL Server") {
        $sqlHealthy = docker-compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$(Get-Content ./secrets/db_password.txt)" -Q "SELECT 1" -C 2>$null
        if ($?) {
            Write-Host "  ✅ $name" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  $name (might still be initializing)" -ForegroundColor Yellow
        }
        continue
    }
    
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "  ✅ $name" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  $name (status: $($response.StatusCode))" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ❌ $name (not responding)" -ForegroundColor Red
    }
}

# ================== Show Status ==================

Write-Step 7 "📊 System Status" "Cyan"

docker-compose ps

# ================== Open Browser ==================

Write-Host "`n🌐 Opening browser..." -ForegroundColor Cyan

if ($Environment -eq 'Development') {
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:8080"
    Start-Process "http://localhost:5173"
    Start-Process "http://localhost:5000/swagger"
} else {
    Start-Process "https://news.swu.ac.th"
}

# ================== Summary ==================

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "✅ Quick Start Completed!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "`n📋 Useful URLs:" -ForegroundColor Cyan
if ($Environment -eq 'Development') {
    Write-Host "  🌐 Nginx:        http://localhost:8080" -ForegroundColor White
    Write-Host "  ⚡ Vite Dev:     http://localhost:5173" -ForegroundColor White
    Write-Host "  🔧 ASP.NET API:  http://localhost:5000" -ForegroundColor White
    Write-Host "  📚 Swagger:      http://localhost:5000/swagger" -ForegroundColor White
    Write-Host "  🎨 GraphQL:      http://localhost:5000/graphql" -ForegroundColor White
    Write-Host "  💾 SQL Server:   localhost:1433" -ForegroundColor White
} else {
    Write-Host "  🌐 Production:   https://news.swu.ac.th" -ForegroundColor White
}

Write-Host "`n📝 Useful Commands:" -ForegroundColor Cyan
Write-Host "  View logs:       .\scripts\docker-maintenance.ps1 -Action Logs" -ForegroundColor Gray
Write-Host "  Check status:    .\scripts\docker-maintenance.ps1 -Action Status" -ForegroundColor Gray
Write-Host "  Stop services:   .\scripts\stop-entire.ps1" -ForegroundColor Gray
Write-Host "  Cleanup:         .\scripts\docker-cleanup.ps1 -Mode Safe" -ForegroundColor Gray

Write-Host "`n"