# ═══════════════════════════════════════════════════════════
# 🔧 Fix Volumes Script for Windows PowerShell
# แก้ไขปัญหา external volumes สำหรับ SQL Server
# ═══════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"

# Configuration
$ProjectName = "swu-rssnews"
$MssqlUid = 10001
$MssqlGid = 0

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🔧 SQL Server External Volumes Setup                     " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════
# 1. ตรวจสอบ Docker
# ═══════════════════════════════════════════════════════════
Write-Host "━━━ Checking Docker ━━━" -ForegroundColor Blue
Write-Host ""

try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker is installed: $dockerVersion" -ForegroundColor Green
}
catch {
    Write-Host "❌ Docker is not installed" -ForegroundColor Red
    exit 1
}

try {
    docker info | Out-Null
    Write-Host "✅ Docker daemon is running" -ForegroundColor Green
}
catch {
    Write-Host "❌ Docker daemon is not running" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ═══════════════════════════════════════════════════════════
# 2. สร้าง External Volumes
# ═══════════════════════════════════════════════════════════
Write-Host "━━━ Creating External Volumes ━━━" -ForegroundColor Blue
Write-Host ""

$ExternalVolumes = @(
    "mssql-system",
    "mssql-data",
    "mssql-logs",
    "mssql-backups"
)

foreach ($volumeShort in $ExternalVolumes) {
    $volumeFull = "${ProjectName}_${volumeShort}"
    
    $null = docker volume inspect $volumeFull 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "→ Exists: $volumeFull" -ForegroundColor Yellow
    }
    else {
        try {
            docker volume create $volumeFull | Out-Null
            Write-Host "✓ Created: $volumeFull" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed: $volumeFull" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "✅ All external volumes created" -ForegroundColor Green
Write-Host ""

# ═══════════════════════════════════════════════════════════
# 3. ตั้งค่า Permissions
# ═══════════════════════════════════════════════════════════
Write-Host "━━━ Setting Permissions ━━━" -ForegroundColor Blue
Write-Host ""

foreach ($volumeShort in $ExternalVolumes) {
    $volumeFull = "${ProjectName}_${volumeShort}"
    
    Write-Host "🔧 Processing $volumeFull..." -ForegroundColor Cyan
    
    try {
        $command = @"
chown -R ${MssqlUid}:${MssqlGid} /target && chmod -R 755 /target
"@
        
        docker run --rm `
            -v "${volumeFull}:/target" `
            alpine:latest sh -c $command 2>$null | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Permissions set successfully" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠ Warning: Could not set permissions (may need admin)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ⚠ Warning: Could not set permissions (may work anyway)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Permissions configured" -ForegroundColor Green
Write-Host ""

# ═══════════════════════════════════════════════════════════
# 4. สร้าง Subdirectories
# ═══════════════════════════════════════════════════════════
Write-Host "━━━ Creating SQL Server Subdirectories ━━━" -ForegroundColor Blue
Write-Host ""

try {
    $command = @'
mkdir -p /var/opt/mssql/data
mkdir -p /var/opt/mssql/logs
mkdir -p /var/opt/mssql/backups
mkdir -p /var/opt/mssql/.system
chmod 755 /var/opt/mssql/data
chmod 755 /var/opt/mssql/logs
chmod 755 /var/opt/mssql/backups
chmod 755 /var/opt/mssql/.system
'@
    
    docker run --rm `
        -v "${ProjectName}_mssql-system:/var/opt/mssql" `
        --user "${MssqlUid}:${MssqlGid}" `
        alpine:latest sh -c $command 2>$null | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Subdirectories created" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Could not create subdirectories (may work anyway)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️  Could not create subdirectories (may work anyway)" -ForegroundColor Yellow
}

Write-Host ""

# ═══════════════════════════════════════════════════════════
# 5. ตรวจสอบผลลัพธ์
# ═══════════════════════════════════════════════════════════
Write-Host "━━━ Verification ━━━" -ForegroundColor Blue
Write-Host ""

Write-Host "External Volumes Status:" -ForegroundColor Cyan
$allOk = $true

foreach ($volumeShort in $ExternalVolumes) {
    $volumeFull = "${ProjectName}_${volumeShort}"
    
    $null = docker volume inspect $volumeFull 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ $volumeFull" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ $volumeFull - MISSING!" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host ""

if ($allOk) {
    Write-Host "✅ All volumes verified successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  ✨ Setup Complete!                                       " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Volumes are ready for SQL Server"
    Write-Host "  2. Run: docker compose up -d mssql"
    Write-Host "  3. Or run: make dev"
    Write-Host ""
}
else {
    Write-Host "❌ Some volumes failed verification!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check Docker permissions"
    Write-Host "  2. Try running PowerShell as Administrator"
    Write-Host "  3. Restart Docker Desktop"
    Write-Host ""
    exit 1
}