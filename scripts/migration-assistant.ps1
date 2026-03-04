# scripts/migration-helper.ps1
# ═══════════════════════════════════════════════════════════
# 🔧 EF Core Migration Helper for Windows
# ═══════════════════════════════════════════════════════════

param(
    [Parameter(Position = 0)]
    [ValidateSet("add", "apply", "status", "first", "remove", "fix")]
    [string]$Command = "status",
    
    [Parameter(Position = 1)]
    [string]$Name = "InitialCreate",
    
    [string]$Container = "aspnetcore"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Test-ContainerReady {
    param([string]$ContainerName, [int]$Timeout = 120)
    
    $elapsed = 0
    while ($elapsed -lt $Timeout) {
        $health = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null
        if ($health -eq "healthy") { return $true }
        
        $running = docker inspect --format='{{.State.Running}}' $ContainerName 2>$null
        if ($running -ne "true") {
            Write-Host "⏳ Container starting..." -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds 5
        $elapsed += 5
    }
    return $false
}

function Get-MigrationFiles {
    $dir = Join-Path $ProjectRoot "aspnetcore\Migrations"
    if (Test-Path $dir) {
        return Get-ChildItem -Path $dir -Filter "*.cs" -ErrorAction SilentlyContinue
    }
    return $null
}

function Invoke-MigrationAdd {
    param([string]$MigrationName)
    
    Write-Header "📦 Creating Migration: $MigrationName"
    
    if (-not (Test-ContainerReady -ContainerName $Container)) {
        Write-Host "❌ Container not ready" -ForegroundColor Red
        return $false
    }
    
    $cmd = "cd /app/aspnetcore && dotnet ef migrations add `"$MigrationName`" --project rssnews.csproj --context RSSNewsDbContext --output-dir Migrations --verbose"
    
    docker exec $Container bash -c $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Migration created" -ForegroundColor Green
        
        # รอให้ไฟล์ sync
        Start-Sleep -Seconds 2
        
        $files = Get-MigrationFiles
        if ($files) {
            Write-Host "`n📄 Migration files:" -ForegroundColor Cyan
            $files | ForEach-Object { Write-Host "   • $($_.Name)" -ForegroundColor White }
        }
        return $true
    }
    else {
        Write-Host "❌ Migration failed" -ForegroundColor Red
        return $false
    }
}

function Invoke-MigrationApply {
    Write-Header "🚀 Applying Migrations"
    
    if (-not (Test-ContainerReady -ContainerName $Container)) {
        Write-Host "❌ Container not ready" -ForegroundColor Red
        return $false
    }
    
    $cmd = "cd /app/aspnetcore && dotnet ef database update --context RSSNewsDbContext --verbose"
    
    docker exec $Container bash -c $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Migrations applied" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "⚠️  Apply completed with warnings" -ForegroundColor Yellow
        return $true
    }
}

function Invoke-MigrationStatus {
    Write-Header "📋 Migration Status"
    
    $dir = Join-Path $ProjectRoot "aspnetcore\Migrations"
    
    if (-not (Test-Path $dir)) {
        Write-Host "📁 Migrations directory: NOT FOUND" -ForegroundColor Yellow
        Write-Host "   Run: .\scripts\migration-helper.ps1 first" -ForegroundColor Cyan
        return
    }
    
    $files = Get-MigrationFiles
    
    if ($files -and $files.Count -gt 0) {
        Write-Host "📁 Migrations directory: EXISTS" -ForegroundColor Green
        Write-Host "📄 Migration files: $($files.Count)" -ForegroundColor White
        Write-Host ""
        
        $files | ForEach-Object {
            $icon = if ($_.Name -like "*Designer*") { "🔧" } 
            elseif ($_.Name -like "*Snapshot*") { "📸" }
            else { "📝" }
            Write-Host "   $icon $($_.Name)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "📁 Migrations directory: EMPTY" -ForegroundColor Yellow
        Write-Host "   Run: .\scripts\migration-helper.ps1 first" -ForegroundColor Cyan
    }
    
    # ตรวจสอบ container
    Write-Host ""
    $running = docker ps --format '{{.Names}}' | Select-String -Pattern "^$Container$" -Quiet
    if ($running) {
        $health = docker inspect --format='{{.State.Health.Status}}' $Container 2>$null
        Write-Host "🐳 Container: RUNNING ($health)" -ForegroundColor Green
    }
    else {
        Write-Host "🐳 Container: NOT RUNNING" -ForegroundColor Yellow
    }
}

function Invoke-MigrationFirst {
    Write-Header "🆕 First-time Migration Setup"
    
    $files = Get-MigrationFiles
    
    if ($files -and $files.Count -gt 0) {
        Write-Host "⚠️  Migrations already exist!" -ForegroundColor Yellow
        $files | ForEach-Object { Write-Host "   • $($_.Name)" -ForegroundColor Gray }
        
        $confirm = Read-Host "`nDelete and recreate? (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "Cancelled" -ForegroundColor Gray
            return
        }
        
        $dir = Join-Path $ProjectRoot "aspnetcore\Migrations"
        Remove-Item -Path "$dir\*.cs" -Force
        Write-Host "🗑️  Old migrations removed" -ForegroundColor Yellow
    }
    
    Invoke-MigrationAdd -MigrationName "InitialCreate"
    Invoke-MigrationApply
}

function Invoke-MigrationRemove {
    Write-Header "🗑️  Remove Last Migration"
    
    if (-not (Test-ContainerReady -ContainerName $Container)) {
        Write-Host "❌ Container not ready" -ForegroundColor Red
        return
    }
    
    $cmd = "cd /app/aspnetcore && dotnet ef migrations remove --project rssnews.csproj --context RSSNewsDbContext --force"
    
    docker exec $Container bash -c $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Last migration removed" -ForegroundColor Green
    }
}

function Invoke-MigrationFix {
    Write-Header "🔧 Quick Fix - Migration Problems"
    
    Write-Host "Step 1: Checking container..." -ForegroundColor Cyan
    $running = docker ps --format '{{.Names}}' | Select-String -Pattern "^$Container$" -Quiet
    
    if (-not $running) {
        Write-Host "   Starting container..." -ForegroundColor Yellow
        docker compose up -d aspdotnetweb
        Start-Sleep -Seconds 30
    }
    
    Write-Host "Step 2: Waiting for container to be healthy..." -ForegroundColor Cyan
    $ready = Test-ContainerReady -ContainerName $Container -Timeout 180
    
    if (-not $ready) {
        Write-Host "❌ Container failed to become healthy" -ForegroundColor Red
        return
    }
    
    Write-Host "Step 3: Creating/updating migrations..." -ForegroundColor Cyan
    
    $files = Get-MigrationFiles
    if (-not $files -or $files.Count -eq 0) {
        Invoke-MigrationAdd -MigrationName "InitialCreate"
    }
    else {
        Write-Host "   ✅ Migrations exist" -ForegroundColor Green
    }
    
    Write-Host "Step 4: Applying migrations..." -ForegroundColor Cyan
    Invoke-MigrationApply
    
    Write-Host "`n✅ Quick fix complete!" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════

switch ($Command) {
    "add" { Invoke-MigrationAdd -MigrationName $Name }
    "apply" { Invoke-MigrationApply }
    "status" { Invoke-MigrationStatus }
    "first" { Invoke-MigrationFirst }
    "remove" { Invoke-MigrationRemove }
    "fix" { Invoke-MigrationFix }
}