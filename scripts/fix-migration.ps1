# fix-migration.ps1
# Quick Fix Script for Migration Auto-Creation
# Usage: .\fix-migration.ps1

param(
    [Parameter(Mandatory = $false)]
    [switch]$AutoApply,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBackup,
    
    [Parameter(Mandatory = $false)]
    [string]$MigrationName = "SWUNewsEvents"
)

$ErrorActionPreference = "Stop"

Write-Host "`n🔧 Migration Auto-Creation Fix Script" -ForegroundColor Cyan
Write-Host "=" * 60

$ProjectRoot = Get-Location
$EnvFile = Join-Path $ProjectRoot ".env"

# ================== Step 1: Check .env file ==================
Write-Host "`n[1] 🔍 Checking .env file..." -ForegroundColor Cyan

if (-not (Test-Path $EnvFile)) {
    Write-Host "❌ .env file not found!" -ForegroundColor Red
    Write-Host "💡 Please run quick-start.ps1 first or copy from .env.example" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ .env file found" -ForegroundColor Green

# ================== Step 2: Backup .env ==================
if (-not $SkipBackup) {
    Write-Host "`n[2] 💾 Creating backup..." -ForegroundColor Cyan
    $BackupFile = Join-Path $ProjectRoot ".env.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $EnvFile $BackupFile
    Write-Host "✅ Backup created: $BackupFile" -ForegroundColor Green
}
else {
    Write-Host "`n[2] ⏭️  Skipping backup" -ForegroundColor Gray
}

# ================== Step 3: Check current values ==================
Write-Host "`n[3] 📋 Checking current configuration..." -ForegroundColor Cyan

$content = Get-Content $EnvFile -Raw

$currentAddNewMigration = "NOT SET"
$currentMigrationName = "NOT SET"

if ($content -match "(?m)^ADD_NEW_MIGRATION=(.*)$") {
    $currentAddNewMigration = ($content | Select-String "(?m)^ADD_NEW_MIGRATION=(.*)$").Matches.Groups[1].Value.Trim()
}

if ($content -match "(?m)^MIGRATION_NAME=(.*)$") {
    $currentMigrationName = ($content | Select-String "(?m)^MIGRATION_NAME=(.*)$").Matches.Groups[1].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($currentMigrationName)) {
        $currentMigrationName = "(empty)"
    }
}

Write-Host "  Current ADD_NEW_MIGRATION: " -NoNewline
Write-Host $currentAddNewMigration -ForegroundColor $(if ($currentAddNewMigration -eq "true") { "Green" } else { "Yellow" })

Write-Host "  Current MIGRATION_NAME: " -NoNewline
Write-Host $currentMigrationName -ForegroundColor $(if ($currentMigrationName -eq $MigrationName) { "Green" } else { "Yellow" })

# ================== Step 4: Check if update needed ==================
$needsUpdate = $false

if ($currentAddNewMigration -ne "true") {
    Write-Host "`n⚠️  ADD_NEW_MIGRATION needs to be updated to 'true'" -ForegroundColor Yellow
    $needsUpdate = $true
}

if ($currentMigrationName -ne $MigrationName) {
    Write-Host "⚠️  MIGRATION_NAME needs to be updated to '$MigrationName'" -ForegroundColor Yellow
    $needsUpdate = $true
}

if (-not $needsUpdate) {
    Write-Host "`n✅ Configuration is already correct!" -ForegroundColor Green
    Write-Host "💡 Run 'docker compose restart aspdotnetweb' to create migrations" -ForegroundColor Cyan
    exit 0
}

# ================== Step 5: Ask for confirmation ==================
if (-not $AutoApply) {
    Write-Host "`n[4] ❓ Confirm changes" -ForegroundColor Cyan
    Write-Host "  The following changes will be made to .env:" -ForegroundColor White
    Write-Host "    ADD_NEW_MIGRATION: $currentAddNewMigration → true" -ForegroundColor Yellow
    Write-Host "    MIGRATION_NAME: $currentMigrationName → $MigrationName" -ForegroundColor Yellow
    Write-Host ""
    
    $response = Read-Host "  Apply these changes? (Y/n)"
    if ($response -eq 'n' -or $response -eq 'N') {
        Write-Host "❌ Cancelled by user" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "`n[4] ⚡ Auto-applying changes..." -ForegroundColor Cyan
}

# ================== Step 6: Apply changes ==================
Write-Host "`n[5] 🔧 Updating .env file..." -ForegroundColor Cyan

# Update ADD_NEW_MIGRATION
if ($content -match "(?m)^ADD_NEW_MIGRATION=.*$") {
    $content = $content -replace "(?m)^ADD_NEW_MIGRATION=.*$", "ADD_NEW_MIGRATION=true"
    Write-Host "  ✓ Updated ADD_NEW_MIGRATION=true" -ForegroundColor Green
}
else {
    # Add after Migration Configuration header
    if ($content -match "(?s)(# Migration Configuration.*?)\r?\n") {
        $content = $content -replace "(?s)(# Migration Configuration.*?)\r?\n", "`$1`nADD_NEW_MIGRATION=true`n"
    }
    else {
        $content += "`nADD_NEW_MIGRATION=true"
    }
    Write-Host "  ✓ Added ADD_NEW_MIGRATION=true" -ForegroundColor Green
}

# Update MIGRATION_NAME
if ($content -match "(?m)^MIGRATION_NAME=.*$") {
    $content = $content -replace "(?m)^MIGRATION_NAME=.*$", "MIGRATION_NAME=$MigrationName"
    Write-Host "  ✓ Updated MIGRATION_NAME=$MigrationName" -ForegroundColor Green
}
else {
    # Add after ADD_NEW_MIGRATION
    $content = $content -replace "(?m)^ADD_NEW_MIGRATION=true\r?\n", "ADD_NEW_MIGRATION=true`nMIGRATION_NAME=$MigrationName`n"
    Write-Host "  ✓ Added MIGRATION_NAME=$MigrationName" -ForegroundColor Green
}

# Save changes
Set-Content -Path $EnvFile -Value $content -NoNewline
Write-Host "`n✅ .env file updated successfully" -ForegroundColor Green

# ================== Step 7: Verify changes ==================
Write-Host "`n[6] ✅ Verifying changes..." -ForegroundColor Cyan

$verifyContent = Get-Content $EnvFile -Raw

$verifyAddNewMigration = "NOT FOUND"
$verifyMigrationName = "NOT FOUND"

if ($verifyContent -match "(?m)^ADD_NEW_MIGRATION=(.*)$") {
    $verifyAddNewMigration = ($verifyContent | Select-String "(?m)^ADD_NEW_MIGRATION=(.*)$").Matches.Groups[1].Value.Trim()
}

if ($verifyContent -match "(?m)^MIGRATION_NAME=(.*)$") {
    $verifyMigrationName = ($verifyContent | Select-String "(?m)^MIGRATION_NAME=(.*)$").Matches.Groups[1].Value.Trim()
}

Write-Host "  ADD_NEW_MIGRATION: " -NoNewline
Write-Host $verifyAddNewMigration -ForegroundColor $(if ($verifyAddNewMigration -eq "true") { "Green" } else { "Red" })

Write-Host "  MIGRATION_NAME: " -NoNewline
Write-Host $verifyMigrationName -ForegroundColor $(if ($verifyMigrationName -eq $MigrationName) { "Green" } else { "Red" })

if ($verifyAddNewMigration -eq "true" -and $verifyMigrationName -eq $MigrationName) {
    Write-Host "`n✅ Verification passed!" -ForegroundColor Green
}
else {
    Write-Host "`n❌ Verification failed!" -ForegroundColor Red
    exit 1
}

# ================== Step 8: Next steps ==================
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "✅ Fix Applied Successfully!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Restart the ASP.NET Core container:" -ForegroundColor White
Write-Host "   docker compose restart aspdotnetweb" -ForegroundColor Green
Write-Host ""
Write-Host "2. Wait 30 seconds for migration to be created:" -ForegroundColor White
Write-Host "   Start-Sleep -Seconds 30" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Verify migration files were created:" -ForegroundColor White
Write-Host "   ls aspnetcore/Migrations/*.cs" -ForegroundColor Green
Write-Host ""
Write-Host "4. Check the logs (optional):" -ForegroundColor White
Write-Host "   docker compose logs aspdotnetweb | Select-String migration" -ForegroundColor Gray
Write-Host ""

# ================== Offer to restart container ==================
$restart = Read-Host "🐳 Restart aspdotnetweb container now? (Y/n)"
if ($restart -ne 'n' -and $restart -ne 'N') {
    Write-Host "`n🔄 Restarting container..." -ForegroundColor Cyan
    
    try {
        docker compose restart aspdotnetweb
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Container restarted successfully" -ForegroundColor Green
            
            Write-Host "`n⏳ Waiting 30 seconds for migration to be created..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
            
            Write-Host "`n📁 Checking for migration files..." -ForegroundColor Cyan
            $migrationsDir = Join-Path $ProjectRoot "aspnetcore\Migrations"
            
            if (Test-Path $migrationsDir) {
                $csFiles = Get-ChildItem -Path $migrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue
                
                if ($csFiles -and $csFiles.Count -gt 0) {
                    Write-Host "✅ Migration files created:" -ForegroundColor Green
                    foreach ($file in $csFiles) {
                        Write-Host "   - $($file.Name)" -ForegroundColor Cyan
                    }
                }
                else {
                    Write-Host "⚠️  No migration files found yet" -ForegroundColor Yellow
                    Write-Host "💡 Check logs: docker compose logs aspdotnetweb" -ForegroundColor Gray
                }
            }
            else {
                Write-Host "⚠️  Migrations directory not found" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "❌ Failed to restart container" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error restarting container: $_" -ForegroundColor Red
    }
}

Write-Host "`n💾 Backup saved at:" -ForegroundColor Cyan
Write-Host "   $BackupFile" -ForegroundColor Gray

Write-Host "`n✨ Done!`n" -ForegroundColor Green