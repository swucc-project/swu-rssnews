#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick Start Script for SWU RSS News Project - FIXED VERSION
.DESCRIPTION
    Sets up and starts the development environment with proper volume configuration
.PARAMETER Environment
    Target environment (Development/Production)
.PARAMETER SkipMigration
    Skip database migration step
.PARAMETER ForceBuild
    Force rebuild all containers
.PARAMETER SkipVolumeSetup
    Skip volume initialization (use existing volumes)
#>
param(
    [ValidateSet("Development", "Production")]
    [string]$Environment = "Development",
    
    [switch]$SkipMigration,
    [switch]$ForceBuild,
    [switch]$SkipVolumeSetup
)
$ErrorActionPreference = "Stop"
$ProjectName = "swu-rssnews"
$ScriptRoot = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptRoot -Parent
Set-Location $ProjectRoot

# =============================================================
# Configuration
# =============================================================

$ExternalVolumes = @(
    "mssql-system",
    "mssql-data",
    "mssql-logs",
    "mssql-backups"
)

# =============================================================
# Helper Functions
# =============================================================

function Write-Step {
    param(
        [string]$Step,
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host ""
    Write-Host ("[" + $Step + "] " + $Message) -ForegroundColor $Color
    Write-Host ("-" * 60) -ForegroundColor DarkGray
}
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}
function Test-DockerRunning {
    try {
        $null = docker info 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}
function Test-VolumeExists {
    param([string]$VolumeName)
    
    try {
        $null = docker volume inspect $VolumeName 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}
function Get-EnvironmentValue {
    param(
        [string]$Key,
        [string]$Default = $null
    )
    $envFile = Join-Path $ProjectRoot ".env"
    if (-not (Test-Path $envFile)) {
        return $Default
    }
    $content = Get-Content $envFile -Raw
    if ($content -match "(?m)^$Key=(.*)$") {
        return $Matches[1].Trim('"', "'")
    }
    return $Default
}

# =============================================================
# Banner
# =============================================================

Write-Header "SWU RSS News - Quick Start (Fixed)"
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Environment:       $Environment" -ForegroundColor White
Write-Host "  Project:           $ProjectName" -ForegroundColor White
Write-Host "  Skip Migration:    $SkipMigration" -ForegroundColor White
Write-Host "  Skip Volume Setup: $SkipVolumeSetup" -ForegroundColor White
Write-Host "  Force Build:       $ForceBuild" -ForegroundColor White
Write-Host ""
# =============================================================
# Step 1: Prerequisites Check
# =============================================================
Write-Step "1" "[CHECK] Checking prerequisites..." "Cyan"
if (-not (Test-DockerRunning)) {
    Write-Host "[ERROR] Docker is not running" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] Docker is running" -ForegroundColor Green
# Check docker-compose.yml
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "[ERROR] docker-compose.yml not found" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] docker-compose.yml exists" -ForegroundColor Green
# Check secrets
if (-not (Test-Path "secrets/db_password.txt")) {
    Write-Host "[ERROR] Database password not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run: .\scripts\init-project.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] Database password exists" -ForegroundColor Green

$GrpcScript = Join-Path $PSScriptRoot "make-grpc-dirs.sh"

if (Test-Path $GrpcScript) {
    Write-Host "📁 Initializing gRPC directories..." -ForegroundColor Cyan

    $gitBash = "C:\Program Files\Git\bin\bash.exe"

    if (-not (Test-Path($gitBash))) {
        Write-Host "❌ Git Bash not found at: $gitBash" -ForegroundColor Red
        Write-Host "Please install Git for Windows." -ForegroundColor Yellow
        exit 1
    }

    $posixPath = $GrpcScript -replace '\\', '/'
    & "$gitBash" "$posixPath"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ make-grpc-dirs.sh failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host "✅ gRPC directories ready" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚙️ Generating gRPC code..." -ForegroundColor Cyan
    docker compose --profile setup up --build
}
else {
    Write-Host "⚠️ make-grpc-dirs.sh not found" -ForegroundColor Yellow
}
# =============================================================
# Step 2: Volume Setup
# =============================================================
if (-not ($SkipVolumeSetup)) {
    Write-Step "2" "[VOLUME] Setting up Docker volumes..." "Cyan"
    
    $volumesMissing = $false
    
    foreach ($volShort in $ExternalVolumes) {
        $volFull = "${ProjectName}_${volShort}"
        
        if (-not (Test-VolumeExists $volFull)) {
            $volumesMissing = $true
            Write-Host "  [WARN] Missing: $volFull" -ForegroundColor Yellow
        }
        else {
            Write-Host "  [OK] Exists: $volFull" -ForegroundColor Green
        }
    }
    
    if ($volumesMissing) {
        Write-Host ""
        Write-Host "[WARN] Required volumes are missing" -ForegroundColor Yellow
        Write-Host "Running volume fix script..." -ForegroundColor Cyan
        Write-Host ""
        
        # Run the fix-volumes script
        $fixScript = Join-Path $ScriptRoot "fix-volumes.ps1"
        
        if (Test-Path $fixScript) {
            & $fixScript
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Volume setup failed" -ForegroundColor Red
                exit 1
            }
        }
        else {
            Write-Host "[ERROR] fix-volumes.ps1 script not found" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please run manually:" -ForegroundColor Yellow
            Write-Host "  .\scripts\fix-volumes.ps1" -ForegroundColor White
            exit 1
        }
    }
    
    Write-Host "[OK] All volumes ready" -ForegroundColor Green
}
else {
    Write-Host "[SKIP] Skipping volume setup (using existing volumes)" -ForegroundColor Yellow
}
# =============================================================
# Step 3: Stop Running Containers
# =============================================================
Write-Step "3" "[STOP] Stopping existing containers..." "Cyan"
try {
    $runningContainers = docker compose ps -q 2>$null
    
    if ($runningContainers) {
        Write-Host "  Stopping containers..." -ForegroundColor Yellow
        docker compose down 2>&1 | Out-Null
        Write-Host "  [OK] Containers stopped" -ForegroundColor Green
    }
    else {
        Write-Host "  [INFO] No running containers" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  [WARN] Could not stop containers: $_" -ForegroundColor Yellow
}

# =============================================================
# Step 3.5: Clean gRPC Generated Files
# =============================================================
Write-Step "3.5" "[CLEAN] Cleaning old gRPC generated files..." "Cyan"

$aspnetcorePath = Join-Path $ProjectRoot "aspnetcore"
$objPath = Join-Path $aspnetcorePath "obj"
$binaryPath = Join-Path $aspnetcorePath "bin"
$migrationsPath = Join-Path $aspnetcorePath "Migrations"

if (Test-Path $objPath) {
    Write-Host "  Removing obj folder..." -ForegroundColor Yellow
    Remove-Item -Path $objPath -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path $binaryPath) {
    Write-Host "  Removing bin folder..." -ForegroundColor Yellow
    Remove-Item -Path $binaryPath -Recurse -Force -ErrorAction SilentlyContinue
}

$grpcFiles = Get-ChildItem -Path $aspnetcorePath -Include "*Grpc.cs", "Rss.cs" -Recurse -ErrorAction SilentlyContinue
if ($grpcFiles) {
    foreach ($file in $grpcFiles) {
        Write-Host "  Removing: $($file.Name)" -ForegroundColor Yellow
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "  Recreating directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $objPath -Force | Out-Null
New-Item -ItemType Directory -Path $binaryPath -Force | Out-Null

if (-not (Test-Path $migrationsPath)) {
    New-Item -ItemType Directory -Path $migrationsPath -Force | Out-Null
    Write-Host "  Created: Migrations folder" -ForegroundColor Green
}

Write-Host "  [OK] Build directories ready" -ForegroundColor Green

# =============================================================
# Step 4: Build Containers
# =============================================================
Write-Step "4" "[BUILD] Building containers..." "Cyan"
if ($ForceBuild) {
    Write-Host "  Building with --no-cache..." -ForegroundColor Yellow
    docker compose build --no-cache
}
else {
    Write-Host "  Building..." -ForegroundColor Cyan
    docker compose build
}
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Containers built successfully" -ForegroundColor Green
# =============================================================
# Step 5: Start SQL Server
# =============================================================
Write-Step "5" "[SQL] Starting SQL Server..." "Cyan"
try {
    Write-Host "  Starting SQL Server container..." -ForegroundColor Cyan
    docker compose up -d mssql
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to start SQL Server" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  [WAIT] Waiting for SQL Server to be healthy..." -ForegroundColor Yellow
    
    $maxAttempts = 60
    $attempt = 0
    $healthy = $false
    
    while ($attempt -lt $maxAttempts -and -not $healthy) {
        Start-Sleep -Seconds 2
        $attempt++
        
        $health = docker inspect sqlserver --format='{{.State.Health.Status}}' 2>$null
        
        if ($health -eq "healthy") {
            $healthy = $true
            Write-Host ""
            Write-Host "  [OK] SQL Server is healthy" -ForegroundColor Green
            break
        }
        
        if (($attempt % 5) -eq 0) {
            Write-Host "  [WAIT] Waiting... $attempt/$maxAttempts, health: $health" -ForegroundColor Gray
        }
    }
    
    if (-not $healthy) {
        Write-Host ""
        Write-Host "[WARN] SQL Server did not become healthy in time" -ForegroundColor Yellow
        Write-Host "Showing last 30 lines of logs:" -ForegroundColor Yellow
        Write-Host ""
        docker compose logs --tail=30 mssql
        Write-Host "[INFO] SQL Server may still be initializing. You can:" -ForegroundColor Cyan
        Write-Host "  1. Wait and check: docker inspect sqlserver --format='{{.State.Health.Status}}'" -ForegroundColor White
        Write-Host "  2. View logs: docker compose logs -f mssql" -ForegroundColor White
        Write-Host "  3. Continue anyway (SQL Server might be ready soon)" -ForegroundColor White
        Write-Host ""
        
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne "y") {
            exit 1
        }
    }
}
catch {
    Write-Host "[ERROR] SQL Server startup failed: $_" -ForegroundColor Red
    exit 1
}
# =============================================================
# Step 6: Run Database Setup (if needed)
# =============================================================
if (-not $SkipMigration) {
    Write-Step "6" "[SETUP] Running database setup..." "Cyan"
    
    try {
        Write-Host "  Starting database setup..." -ForegroundColor Cyan
        docker compose --profile setup up queue-db-migration 2>&1 | Out-Null
        
        Start-Sleep -Seconds 5
        
        # Check setup logs
        $setupLogs = docker compose logs queue-db-migration 2>$null
        
        if ($setupLogs -match "completed successfully") {
            Write-Host "  [OK] Database setup completed" -ForegroundColor Green
        }
        elseif ($setupLogs -match "error|failed") {
            Write-Host "  [WARN] Database setup had errors" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Setup logs:" -ForegroundColor Yellow
            Write-Host $setupLogs
        }
        else {
            Write-Host "  [INFO] Database setup completed (no specific confirmation)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  [WARN] Database setup had issues: $_" -ForegroundColor Yellow
    }
}
# =============================================================
# Step 7: Create Initial Migration (if needed)
# =============================================================
Write-Step "7" "[MIGRATION] Checking EF Core Migrations..." "Cyan"
$migrationName = Get-EnvironmentValue -Key "MIGRATION_NAME" -Default "InitialCreate"
$migrationsDir = Join-Path $ProjectRoot "aspnetcore\Migrations"
$hasMigrations = $false
if (Test-Path $migrationsDir) {
    $csFiles = Get-ChildItem -Path $migrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue
    if ($csFiles -and $csFiles.Count -gt 0) {
        $hasMigrations = $true
        Write-Host "  [OK] Found $($csFiles.Count) migration file(s)" -ForegroundColor Green
        $csFiles | ForEach-Object { Write-Host "     - $($_.Name)" -ForegroundColor Gray }
    }
}
if (-not $hasMigrations -and -not $SkipMigration) {
    Write-Host "  [INFO] No migrations found, creating initial migration..." -ForegroundColor Yellow
    
    # Call create-migration.ps1
    $createMigrationScript = Join-Path $PSScriptRoot "create-migration.ps1"
    
    if (Test-Path $createMigrationScript) {
        try {
            & $createMigrationScript -MigrationName $migrationName
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Migration created successfully" -ForegroundColor Green
            }
            else {
                Write-Host "  [WARN] Migration creation had issues - check logs" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  [WARN] Migration creation failed: $_" -ForegroundColor Yellow
            Write-Host "  [TIP] You can create migration manually later:" -ForegroundColor Gray
            Write-Host "     .\scripts\create-migration.ps1 -MigrationName $migrationName" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  [WARN] create-migration.ps1 not found" -ForegroundColor Yellow
    }
}
elseif ($SkipMigration) {
    Write-Host "  Migration skipped (--skip-migration flag)" -ForegroundColor Gray
}
# =============================================================
# Step 8: Start All Services
# =============================================================
Write-Step "8" "[START] Starting all services..." "Cyan"
docker compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start services" -ForegroundColor Red
    exit 1
}
Write-Host "[WAIT] Waiting for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
# =============================================================
# Step 9: Verify Services
# =============================================================
Write-Step "9" "[VERIFY] Verifying services..." "Cyan"
$services = @(
    @{ Name = "sqlserver"; Port = 1433; DisplayName = "SQL Server" },
    @{ Name = "aspnetcore"; Port = 5000; DisplayName = "ASP.NET Core" },
    @{ Name = "vite-user-interface"; Port = 5173; DisplayName = "Vite UI" },
    @{ Name = "nginx"; Port = 8080; DisplayName = "Nginx" }
)
foreach ($service in $services) {
    $containerStatus = docker ps --filter "name=$($service.Name)" --format "{{.Status}}" 2>$null
    
    if ($containerStatus) {
        if ($containerStatus -match "Up.*healthy") {
            Write-Host "  [OK] $($service.DisplayName) - Healthy" -ForegroundColor Green
        }
        elseif ($containerStatus -match "Up") {
            Write-Host "  [WARN] $($service.DisplayName) - Running (not yet healthy)" -ForegroundColor Yellow
        }
        else {
            Write-Host "  [FAIL] $($service.DisplayName) - $containerStatus" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  [FAIL] $($service.DisplayName) - Not found" -ForegroundColor Red
    }
}
# =============================================================
# Step 10: Final Health Checks
# =============================================================
Write-Step "10" "[HEALTH] Running health checks..." "Cyan"
# Wait a bit more for services to stabilize
Start-Sleep -Seconds 10
# Check SQL Server specifically
$sqlHealth = docker inspect sqlserver --format='{{.State.Health.Status}}' 2>$null
if ($sqlHealth -eq "healthy") {
    Write-Host "  [OK] SQL Server: Healthy" -ForegroundColor Green
}
else {
    Write-Host "  [WARN] SQL Server: $sqlHealth" -ForegroundColor Yellow
}
# Check if ASP.NET Core is responding
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/health/ready" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "  [OK] ASP.NET Core: Responding" -ForegroundColor Green
    }
}
catch {
    Write-Host "  [WARN] ASP.NET Core: Not yet responding (may still be starting)" -ForegroundColor Yellow
}
# =============================================================
# Summary
# =============================================================
Write-Header "[DONE] Quick Start Complete"
Write-Host "[SUMMARY]" -ForegroundColor Cyan
Write-Host "   - External volumes created and verified" -ForegroundColor White
Write-Host "   - Docker containers built and started" -ForegroundColor White
Write-Host "   - SQL Server initialized" -ForegroundColor White
if (-not $SkipMigration) {
    Write-Host "   - Database setup executed" -ForegroundColor White
}
Write-Host ""
Write-Host "[URLs]" -ForegroundColor Cyan
Write-Host "   Frontend:  http://localhost:8080" -ForegroundColor White
Write-Host "   API:       http://localhost:5000" -ForegroundColor White
Write-Host "   GraphQL:   http://localhost:5000/graphql" -ForegroundColor White
Write-Host "   Vite Dev:  http://localhost:5173" -ForegroundColor White
Write-Host ""
Write-Host "[COMMANDS]" -ForegroundColor Cyan
Write-Host "   View all logs:      docker compose logs -f" -ForegroundColor Gray
Write-Host "   View SQL logs:      docker compose logs -f mssql" -ForegroundColor Gray
Write-Host "   Stop services:      docker compose down" -ForegroundColor Gray
Write-Host "   Restart services:   docker compose restart" -ForegroundColor Gray
Write-Host "   Check health:       docker compose ps" -ForegroundColor Gray
Write-Host ""
Write-Host "[TROUBLESHOOTING]" -ForegroundColor Yellow
Write-Host "   If SQL Server fails:     .\scripts\fix-volumes.ps1" -ForegroundColor Gray
Write-Host "   If services don't start: docker compose logs -f" -ForegroundColor Gray
Write-Host "   To rebuild:              .\scripts\quick-start.ps1 -ForceBuild" -ForegroundColor Gray
Write-Host ""
Write-Host "[OK] Development environment is ready" -ForegroundColor Green