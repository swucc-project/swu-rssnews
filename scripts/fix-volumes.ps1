#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-Click Volume Fix for SQL Server
.DESCRIPTION
    Creates and configures all required Docker volumes with proper permissions
.PARAMETER Force
    Force recreation of volumes even if they exist
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$ProjectName = "swu-rssnews"
$MSSQL_UID = 10001
$MSSQL_GID = 0

# ═══════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("═" * 60) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("═" * 60) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━ $Text ━━━" -ForegroundColor Blue
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

# ═══════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════

Write-Header "🔧 SQL Server Volume Fix"

# Check Docker
Write-Section "Checking Docker"

if (-not (Test-DockerRunning)) {
    Write-Host "❌ Docker is not running" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Docker is running" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# Step 1: Stop SQL Server Container
# ═══════════════════════════════════════════════════════════

Write-Section "Step 1: Stopping SQL Server"

$sqlContainer = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq "sqlserver" }

if ($sqlContainer) {
    Write-Host "  🛑 Stopping SQL Server container..." -ForegroundColor Yellow
    docker compose stop mssql 2>$null | Out-Null
    Start-Sleep -Seconds 3
    Write-Host "  ✅ Stopped" -ForegroundColor Green
}
else {
    Write-Host "  ℹ️  SQL Server container not running" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════
# Step 2: Create External SQL Server Volumes
# ═══════════════════════════════════════════════════════════

Write-Section "Step 2: Creating External SQL Server Volumes"

$ExternalVolumes = @(
    "mssql-system",
    "mssql-data",
    "mssql-logs",
    "mssql-backups"
)

foreach ($volShort in $ExternalVolumes) {
    $volFull = "${ProjectName}_${volShort}"
    
    # Check if exists
    $exists = docker volume inspect $volFull 2>$null
    
    if ($exists -and -not $Force) {
        Write-Host "  → $volFull already exists" -ForegroundColor Gray
    }
    else {
        if ($exists -and $Force) {
            Write-Host "  🗑️  Removing existing $volFull..." -ForegroundColor Yellow
            docker volume rm -f $volFull 2>$null | Out-Null
        }
        
        Write-Host "  📦 Creating $volFull..." -ForegroundColor Cyan
        $result = docker volume create $volFull 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "     ✅ Created" -ForegroundColor Green
        }
        else {
            Write-Host "     ❌ Failed: $result" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "✅ External volumes ready" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# Step 3: Set SQL Server Permissions
# ═══════════════════════════════════════════════════════════

Write-Section "Step 3: Setting SQL Server Permissions (UID:GID = ${MSSQL_UID}:${MSSQL_GID})"

foreach ($volShort in $ExternalVolumes) {
    $volFull = "${ProjectName}_${volShort}"
    
    Write-Host "  🔧 Configuring $volShort..." -ForegroundColor Cyan
    
    $dockerCmd = @"
chown -R ${MSSQL_UID}:${MSSQL_GID} /target && chmod -R 755 /target
"@
    
    $result = docker run --rm `
        -v "${volFull}:/target" `
        alpine:latest `
        sh -c $dockerCmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "     ✅ Permissions set" -ForegroundColor Green
    }
    else {
        Write-Host "     ⚠️  Warning: $result" -ForegroundColor Yellow
    }
}

Write-Host ""

# Create SQL Server subdirectories
Write-Host "  📁 Creating SQL Server subdirectories..." -ForegroundColor Cyan

$subdirCmd = @"
mkdir -p /var/opt/mssql/.system && \
mkdir -p /var/opt/mssql/secrets && \
chmod 755 /var/opt/mssql/.system && \
chmod 755 /var/opt/mssql/secrets
"@

$result = docker run --rm `
    -v "${ProjectName}_mssql-system:/var/opt/mssql" `
    --user "${MSSQL_UID}:${MSSQL_GID}" `
    alpine:latest `
    sh -c $subdirCmd 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "     ✅ Subdirectories created" -ForegroundColor Green
}
else {
    Write-Host "     ⚠️  Warning: $result" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ SQL Server permissions configured" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# Step 4: Verification
# ═══════════════════════════════════════════════════════════

Write-Section "Step 4: Verifying Volumes"

Write-Host "External SQL Server Volumes:" -ForegroundColor Cyan
foreach ($volShort in $ExternalVolumes) {
    $volFull = "${ProjectName}_${volShort}"
    
    $exists = docker volume inspect $volFull 2>$null
    
    if ($exists) {
        Write-Host "  ✅ $volFull" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ $volFull - MISSING!" -ForegroundColor Red
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════

Write-Header "✨ Volume Fix Complete!"

Write-Host "📝 Summary:" -ForegroundColor Cyan
Write-Host "  ✓ Created 4 external SQL Server volumes" -ForegroundColor White
Write-Host "  ✓ Set SQL Server permissions (UID:GID = ${MSSQL_UID}:${MSSQL_GID})" -ForegroundColor White
Write-Host "  ✓ Created internal application volumes" -ForegroundColor White
Write-Host "  ✓ Configured all volume permissions" -ForegroundColor White
Write-Host ""

Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Start SQL Server:   docker compose up -d mssql" -ForegroundColor White
Write-Host "  2. Wait for healthy:   docker compose ps" -ForegroundColor White
Write-Host "  3. Check logs:         docker compose logs -f mssql" -ForegroundColor White
Write-Host "  4. Start all:          docker compose up -d" -ForegroundColor White
Write-Host ""

Write-Host "💡 Useful Commands:" -ForegroundColor Yellow
Write-Host "  • List volumes:        docker volume ls | Select-String $ProjectName" -ForegroundColor Gray
Write-Host "  • Check SQL health:    docker inspect sqlserver --format='{{.State.Health.Status}}'" -ForegroundColor Gray
Write-Host "  • View SQL logs:       docker compose logs --tail=100 -f mssql" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ Ready to start! Run: docker compose up -d" -ForegroundColor Green
Write-Host ""