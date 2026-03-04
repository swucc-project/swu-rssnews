#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════
# 🔧 Create EF Core Migration (Standalone Script)
# ═══════════════════════════════════════════════════════════
# Usage: .\scripts\create-migration.ps1 [-MigrationName "YourMigration"]
# ═══════════════════════════════════════════════════════════

param(
    [Parameter(Position = 0)]
    [string]$MigrationName = "InitialCreate",
    
    [switch]$ApplyAfterCreate,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot | Split-Path -Parent

# ═══════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════
$MigrationsDir = Join-Path $ProjectRoot "aspnetcore\Migrations"
$PasswordFile = Join-Path $ProjectRoot "secrets\db_password.txt"
$AspnetcoreDir = Join-Path $ProjectRoot "aspnetcore"

# ═══════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════
function Get-NetworkName {
    $projectName = "swu-rssnews"
    $envFile = Join-Path $ProjectRoot ".env"
    
    if (Test-Path $envFile) {
        $content = Get-Content $envFile -Raw
        if ($content -match "(?m)^COMPOSE_PROJECT_NAME=(.+)$") {
            $value = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $projectName = $value
            }
        }
    }
    
    $networks = docker network ls --format "{{.Name}}" 2>$null
    
    $patterns = @(
        "${projectName}_database-network",
        "${projectName}_backend-network"
    )
    
    foreach ($pattern in $patterns) {
        if ($networks -contains $pattern) {
            return $pattern
        }
    }
    
    $newNetwork = "${projectName}_database-network"
    docker network create $newNetwork 2>$null | Out-Null
    return $newNetwork
}

function Get-DatabaseContainer {
    $containers = docker ps --format "{{.Names}}" 2>$null
    $possibleNames = @("sqlserver", "mssql", "sql-server")
    
    foreach ($name in $possibleNames) {
        if ($containers -contains $name) {
            return $name
        }
    }
    
    return $containers | Where-Object { $_ -match "sql|mssql" } | Select-Object -First 1
}

# ═══════════════════════════════════════════════════════════
# Main Script
# ═══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  🔧 EF Core Migration Creator" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# Step 1: Validate prerequisites
Write-Host "📋 Step 1: Validating prerequisites..." -ForegroundColor Cyan

if (-not (Test-Path $PasswordFile)) {
    Write-Host "  ❌ Password file not found: $PasswordFile" -ForegroundColor Red
    Write-Host "  💡 Run: .\scripts\init-project.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✅ Password file found" -ForegroundColor Green

$Password = (Get-Content $PasswordFile -Raw).Trim()
if ($Password.Length -lt 8) {
    Write-Host "  ❌ Password too short (min 8 chars)" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Password loaded ($($Password.Length) chars)" -ForegroundColor Green

# Check database container
$dbContainer = Get-DatabaseContainer
if (-not $dbContainer) {
    Write-Host "  ❌ Database container not running" -ForegroundColor Red
    Write-Host "  💡 Run: docker compose up -d mssql" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✅ Database container: $dbContainer" -ForegroundColor Green

# Get network
$NetworkName = Get-NetworkName
Write-Host "  ✅ Network: $NetworkName" -ForegroundColor Green

# Ensure directories exist
if (-not (Test-Path $MigrationsDir)) {
    New-Item -ItemType Directory -Path $MigrationsDir -Force | Out-Null
    Write-Host "  ✅ Created Migrations directory" -ForegroundColor Green
}

# ✅ ตรวจสอบ shared directories
$sharedGrpcDir = Join-Path $ProjectRoot "shared\grpc"
$sharedGraphqlDir = Join-Path $ProjectRoot "shared\graphql"

if (-not (Test-Path $sharedGrpcDir)) {
    New-Item -ItemType Directory -Path $sharedGrpcDir -Force | Out-Null
}
if (-not (Test-Path $sharedGraphqlDir)) {
    New-Item -ItemType Directory -Path $sharedGraphqlDir -Force | Out-Null
}

Write-Host ""

# Step 2: Check existing migrations
Write-Host "📋 Step 2: Checking existing migrations..." -ForegroundColor Cyan
$existingFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue

if ($existingFiles) {
    Write-Host "  📄 Found $($existingFiles.Count) existing migration file(s):" -ForegroundColor Yellow
    $existingFiles | ForEach-Object { Write-Host "     • $($_.Name)" -ForegroundColor Gray }
    
    $existingMigration = $existingFiles | Where-Object { $_.Name -match "_$MigrationName\.cs$" }
    if ($existingMigration -and -not $Force) {
        Write-Host ""
        Write-Host "  ⚠️  Migration '$MigrationName' already exists!" -ForegroundColor Yellow
        Write-Host "  💡 Use -Force to recreate or choose a different name" -ForegroundColor Gray
        exit 0
    }
}
else {
    Write-Host "  ℹ️  No existing migrations (first migration)" -ForegroundColor Gray
}

Write-Host ""

# Step 3: Build migration image
Write-Host "📋 Step 3: Building migration image..." -ForegroundColor Cyan
$dockerfilePath = Join-Path $ProjectRoot "aspnetcore\Dockerfile"

Write-Host "  🔨 Building migration stage..." -ForegroundColor Yellow
$buildOutput = docker build `
    --target migration `
    -t rssnews-migration:latest `
    -f $dockerfilePath `
    $ProjectRoot 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Build failed!" -ForegroundColor Red
    $buildOutput | Select-Object -Last 20 | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
    exit 1
}
Write-Host "  ✅ Migration image built successfully" -ForegroundColor Green
Write-Host ""

# Step 4: Create migration
Write-Host "📋 Step 4: Creating migration '$MigrationName'..." -ForegroundColor Cyan

# Convert paths for Docker (Windows to Linux)
$aspnetcorePath = $AspnetcoreDir.Replace('\', '/')
$sharedGraphqlPath = $sharedGraphqlDir.Replace('\', '/')

# Ensure container is on network
docker network connect $NetworkName $dbContainer 2>$null

# ✅ สร้าง Connection String ที่ถูกต้อง
$connectionString = "Server=$dbContainer;Database=RSSActivityWeb;User ID=sa;Password=$Password;TrustServerCertificate=True;Encrypt=False;"

Write-Host "  🚀 Running migration command..." -ForegroundColor Yellow
Write-Host "     Target: $dbContainer/RSSActivityWeb" -ForegroundColor Gray
Write-Host "     Migration: $MigrationName" -ForegroundColor Gray

# ✅ รัน migration ด้วย environment variables ที่ถูกต้อง
$migrationOutput = docker run --rm `
    --network $NetworkName `
    -e "ConnectionStrings__DefaultConnection=$connectionString" `
    -e "MSSQL_SA_PASSWORD=$Password" `
    -e "DATABASE_HOST=$dbContainer" `
    -e "DATABASE_NAME=RSSActivityWeb" `
    -e "ASPNETCORE_ENVIRONMENT=Development" `
    -v "${aspnetcorePath}:/app/aspnetcore" `
    -v "${sharedGraphqlPath}:/app/apollo" `
    -w /app/aspnetcore `
    --entrypoint dotnet `
    rssnews-migration:latest `
    ef migrations add $MigrationName `
    --project rssnews.csproj `
    --context RSSNewsDbContext `
    --output-dir Migrations `
    --verbose 2>&1

# Analyze result
$success = $false
$errorMessages = @()

foreach ($line in $migrationOutput) {
    if ($line -match "Done\.|Successfully|migration has been created|scaffolded") {
        $success = $true
    }
    if ($line -match "error|Error|fail|Fail" -and $line -notmatch "EnableRetryOnFailure") {
        $errorMessages += $line
    }
}

# Also check exit code
if ($LASTEXITCODE -eq 0) {
    $success = $true
}

# Display output
Write-Host ""
$migrationOutput | ForEach-Object {
    if ($_ -match "error|Error|fail|Fail") {
        Write-Host "     $_" -ForegroundColor Red
    }
    elseif ($_ -match "warn|Warn") {
        Write-Host "     $_" -ForegroundColor Yellow
    }
    elseif ($_ -match "Done|Success|Created|Building|scaffolded") {
        Write-Host "     $_" -ForegroundColor Green
    }
    else {
        Write-Host "     $_" -ForegroundColor Gray
    }
}

if ($success) {
    Write-Host ""
    Write-Host "  ✅ Migration created successfully!" -ForegroundColor Green
    
    Start-Sleep -Seconds 2
    
    $newFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue
    if ($newFiles) {
        Write-Host ""
        Write-Host "  📄 Migration files:" -ForegroundColor Cyan
        $newFiles | ForEach-Object { 
            Write-Host "     ✅ $($_.Name)" -ForegroundColor Green 
        }
    }
}
else {
    Write-Host ""
    Write-Host "  ❌ Migration creation failed!" -ForegroundColor Red
    
    if ($errorMessages.Count -gt 0) {
        Write-Host ""
        Write-Host "  📋 Errors:" -ForegroundColor Red
        $errorMessages | ForEach-Object { Write-Host "     • $_" -ForegroundColor Red }
    }
    
    Write-Host ""
    Write-Host "  📋 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "     1. Check DbContext configuration" -ForegroundColor Gray
    Write-Host "     2. Ensure entities are defined" -ForegroundColor Gray
    Write-Host "     3. Check: docker compose logs mssql" -ForegroundColor Gray
    Write-Host "     4. Verify password: cat secrets/db_password.txt" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# Step 5: Apply migration (if requested)
if ($ApplyAfterCreate) {
    Write-Host "📋 Step 5: Applying migrations..." -ForegroundColor Cyan
    
    $applyOutput = docker run --rm `
        --network $NetworkName `
        -e "ConnectionStrings__DefaultConnection=$connectionString" `
        -e "MSSQL_SA_PASSWORD=$Password" `
        -e "DATABASE_HOST=$dbContainer" `
        -e "DATABASE_NAME=RSSActivityWeb" `
        -v "${aspnetcorePath}:/app/aspnetcore" `
        -w /app/aspnetcore `
        rssnews-migration:latest `
        dotnet ef database update `
        --connection "$connectionString" `
        --context RSSNewsDbContext `
        --project rssnews.csproj `
        --verbose 2>&1
    
    if ($LASTEXITCODE -eq 0 -or $applyOutput -match "already up to date|Applied migration") {
        Write-Host "  ✅ Migrations applied successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠️  Migration apply had issues:" -ForegroundColor Yellow
        $applyOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "     $_" -ForegroundColor Yellow }
    }
    
    Write-Host ""
}

# Step 6: Restart ASP.NET Core
Write-Host "📋 Step 6: Restarting ASP.NET Core..." -ForegroundColor Cyan

$aspnetContainer = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -match "aspnet" } | Select-Object -First 1
if ($aspnetContainer) {
    docker restart $aspnetContainer 2>$null | Out-Null
    Write-Host "  ✅ Restarted: $aspnetContainer" -ForegroundColor Green
}
else {
    Write-Host "  ℹ️  ASP.NET Core container not found (will start with docker compose up)" -ForegroundColor Gray
}

Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Migration Process Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "📄 Migration Name: $MigrationName" -ForegroundColor Cyan
Write-Host "📂 Location: $MigrationsDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Yellow
if (-not $ApplyAfterCreate) {
    Write-Host "   1. Apply migration: .\scripts\create-migration.ps1 -ApplyAfterCreate" -ForegroundColor Gray
}
Write-Host "   2. Start services: docker compose up -d" -ForegroundColor Gray
Write-Host "   3. Check API: curl http://localhost:5000/health" -ForegroundColor Gray
Write-Host "   4. Commit: git add aspnetcore/Migrations" -ForegroundColor Gray
Write-Host ""