#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════
# 🔧 Apply EF Core Migrations (Windows)
# ═══════════════════════════════════════════════════════════
$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot | Split-Path -Parent

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  🔧 Applying EF Core Migrations" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# ═══════════════════════════════════════════════════════════
# 🔧 Helper Functions
# ═══════════════════════════════════════════════════════════
function Get-DatabaseContainerName {
    <#
    .SYNOPSIS
        หา database container name แบบ dynamic โดยไม่พึ่ง hardcoded name
    #>
    $possibleNames = @("sqlserver", "mssql", "sql-server", "database", "db")
    
    # ลอง exact match ก่อน
    foreach ($name in $possibleNames) {
        $container = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -eq $name }
        if ($container) {
            return $container
        }
    }
    
    # ถ้าไม่เจอ ลอง partial match
    $container = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -match "sql|mssql|database" } | Select-Object -First 1
    return $container
}

function Get-ComposeProjectName {
    <#
    .SYNOPSIS
        อ่าน COMPOSE_PROJECT_NAME จาก .env
    #>
    $envFile = Join-Path $ProjectRoot ".env"
    if (-not (Test-Path $envFile)) {
        return "swu-rssnews"
    }
    
    $content = Get-Content $envFile -Raw
    if ($content -match "(?m)^COMPOSE_PROJECT_NAME=(.*)$") {
        $value = $Matches[1] -replace '^\s+|\s+$|^["'']|["'']$', ''
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }
    return "swu-rssnews"
}

function Get-DatabaseNetwork {
    <#
    .SYNOPSIS
        หา database network แบบ dynamic โดยตรวจสอบจาก docker network ls
    .DESCRIPTION
        เมื่อลบ name: ออกจาก docker-compose.yml แล้ว Docker Compose จะสร้าง network
        ในรูปแบบ {COMPOSE_PROJECT_NAME}_{network_key} เช่น swu-rssnews_database-network
        
        ฟังก์ชันนี้จะลองหาใน pattern ต่างๆ ดังนี้:
        1. {COMPOSE_PROJECT_NAME}_database-network
        2. database-network (ถ้ามี name: กำหนดไว้)
        3. ชื่ออื่นๆ ที่มี "database" หรือ "backend"
        4. ถ้าไม่เจอเลย จะสร้าง network ใหม่
    #>
    
    $projectName = Get-ComposeProjectName
    Write-Host "  📦 Project name: $projectName" -ForegroundColor Gray
    
    # รายการ network patterns ที่เป็นไปได้ ตามลำดับความน่าจะเป็น
    $networkPatterns = @(
        "${projectName}_database-network",  # รูปแบบ default เมื่อไม่มี name:
        "${projectName}_backend-network",   # อาจมี backend network ด้วย
        "database-network",                 # ถ้ามี name: กำหนดไว้
        "backend-network"                   # ถ้ามี name: กำหนดไว้
    )
    
    # ดึงรายการ networks ทั้งหมดที่มีอยู่
    $existingNetworks = docker network ls --format "{{.Name}}" 2>$null
    
    # ลองหาตาม pattern ที่กำหนด
    foreach ($pattern in $networkPatterns) {
        if ($existingNetworks -contains $pattern) {
            Write-Host "  ✅ Found network: $pattern" -ForegroundColor Green
            return $pattern
        }
    }
    
    # ถ้าไม่เจอตาม pattern ลอง partial match
    Write-Host "  🔍 Searching for database network..." -ForegroundColor Yellow
    foreach ($net in $existingNetworks) {
        if ($net -match "database|backend|rssnews.*default") {
            Write-Host "  ✅ Found network (partial match): $net" -ForegroundColor Green
            return $net
        }
    }
    
    # ถ้ายังไม่เจอ สร้าง network ใหม่
    $newNetwork = "${projectName}_migration-network"
    Write-Host "  ⚠️  No suitable network found" -ForegroundColor Yellow
    Write-Host "  🔧 Creating new network: $newNetwork" -ForegroundColor Cyan
    
    try {
        docker network create $newNetwork 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Created network: $newNetwork" -ForegroundColor Green
            
            # เชื่อมต่อ database container เข้า network ใหม่
            $dbContainer = Get-DatabaseContainerName
            if ($dbContainer) {
                docker network connect $newNetwork $dbContainer 2>&1 | Out-Null
                Write-Host "  🔗 Connected $dbContainer to $newNetwork" -ForegroundColor Green
            }
            
            return $newNetwork
        }
    }
    catch {
        Write-Host "  ❌ Failed to create network: $_" -ForegroundColor Red
    }
    
    # ถ้าสร้างไม่ได้ ใช้ default
    Write-Host "  ⚠️  Using default network: ${projectName}_database-network" -ForegroundColor Yellow
    return "${projectName}_database-network"
}

function Read-EnvValue {
    param([string]$Key, [string]$Default = "")
    
    $envFile = Join-Path $ProjectRoot ".env"
    if (-not (Test-Path $envFile)) { return $Default }
    
    $content = Get-Content $envFile -Raw
    if ($content -match "(?m)^${Key}=(.*)$") {
        $value = $Matches[1] -replace '^\s+|\s+$|^["'']|["'']$', ''
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }
    return $Default
}

# ═══════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════
$MigrationsDir = Join-Path $ProjectRoot "aspnetcore\Migrations"
$PasswordFile = Join-Path $ProjectRoot "secrets\db_password.txt"

# 🔧 Dynamic network detection
Write-Host "🌐 Detecting network configuration..." -ForegroundColor Cyan
$NetworkName = Get-DatabaseNetwork

# Check password file
if (-not (Test-Path $PasswordFile)) {
    Write-Host "❌ Password file not found: $PasswordFile" -ForegroundColor Red
    exit 1
}
$Password = (Get-Content $PasswordFile -Raw).Trim()

# Check migrations exist
$csFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue
if ($null -eq $csFiles -or $csFiles.Count -eq 0) {
    Write-Host "⚠️ No migrations found in $MigrationsDir" -ForegroundColor Yellow
    Write-Host "💡 Run: .\scripts\run-migration.ps1 -CreateOnly" -ForegroundColor Gray
    exit 1
}

Write-Host "📄 Found migrations:" -ForegroundColor Cyan
$csFiles | ForEach-Object { Write-Host "   • $($_.Name)" -ForegroundColor Gray }
Write-Host ""

Write-Host "🌐 Using network: $NetworkName" -ForegroundColor Cyan

# 🔧 Dynamic database host detection
$dbContainer = Get-DatabaseContainerName
$dbHost = if ($dbContainer) { $dbContainer } else { Read-EnvValue -Key "DATABASE_HOST" -Default "sqlserver" }
$dbName = Read-EnvValue -Key "DATABASE_NAME" -Default "RSSActivityWeb"

Write-Host "📡 Database: $dbHost/$dbName" -ForegroundColor Cyan

# Apply migrations using SDK image
$aspnetcorePath = (Join-Path $ProjectRoot "aspnetcore").Replace('\', '/')
$connectionString = "Server=$dbHost;Database=$dbName;User ID=sa;Password=$Password;TrustServerCertificate=True;Encrypt=False;"

Write-Host "🚀 Applying migrations..." -ForegroundColor Yellow

$result = docker run --rm `
    --network $NetworkName `
    -e "ConnectionStrings__DefaultConnection=$connectionString" `
    -v "${aspnetcorePath}:/app" `
    -w /app `
    mcr.microsoft.com/dotnet/sdk:9.0 `
    sh -c "dotnet tool install --global dotnet-ef --version 9.0.* 2>/dev/null || true; export PATH=${PATH}:/root/.dotnet/tools; dotnet ef database update --connection '$connectionString' --context RSSNewsDbContext --project rssnews.csproj --verbose" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Migrations applied successfully!" -ForegroundColor Green
}
else {
    if ($result -match "already up to date|No migrations") {
        Write-Host ""
        Write-Host "✅ Database is already up to date" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "⚠️ Migration completed with warnings:" -ForegroundColor Yellow
        $result | Select-Object -Last 15 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
}

# 🔧 Dynamic ASP.NET Core container detection
Write-Host ""
Write-Host "🔄 Restarting ASP.NET Core..." -ForegroundColor Cyan

$aspnetContainer = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -match "aspnet|aspdotnet" } | Select-Object -First 1
if ($aspnetContainer) {
    docker restart $aspnetContainer 2>$null
    Write-Host "  ✅ Restarted: $aspnetContainer" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  ASP.NET Core container not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Migration Apply Complete" -ForegroundColor Green  
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Yellow
Write-Host "   docker logs $aspnetContainer" -ForegroundColor Gray
Write-Host "   curl http://localhost:5000/health" -ForegroundColor Gray