#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════
# 🔧 EF Core Migration Script for Windows (Docker-based)
# ═══════════════════════════════════════════════════════════
param(
    [Parameter(Position = 0)]
    [string]$MigrationName = "",
    
    [switch]$ApplyOnly,
    [switch]$CreateOnly,
    [switch]$Force,
    [switch]$IgnoreEnv
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot | Split-Path -Parent

# ═══════════════════════════════════════════════════════════
# 🔧 Configuration
# ═══════════════════════════════════════════════════════════
$MigrationImage = "rssnews-migration"
$MigrationsDir = Join-Path $ProjectRoot "aspnetcore\Migrations"
$PasswordFile = Join-Path $ProjectRoot "secrets\db_password.txt"

# ═══════════════════════════════════════════════════════════
# 🔧 Helper Functions
# ═══════════════════════════════════════════════════════════

function Read-EnvFileValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [string]$Default = ""
    )
    
    $envFile = Join-Path $ProjectRoot ".env"
    
    if (-not (Test-Path $envFile)) {
        return $Default
    }
    
    try {
        $envContent = Get-Content $envFile -Raw -ErrorAction Stop
        $pattern = "(?m)^${Key}=(.*)$"
        $match = [regex]::Match($envContent, $pattern)
        
        if ($match.Success -and $match.Groups.Count -gt 1) {
            $value = $match.Groups[1].Value -replace '^\s+|\s+$', ''
            $value = $value -replace '^["'']|["'']$', ''
            
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
    }
    catch {
        Write-Host "  ⚠️  Error reading .env: $_" -ForegroundColor Yellow
    }
    
    return $Default
}

function Read-AllEnvValues {
    $values = @{
        MigrationName   = Read-EnvFileValue -Key "MIGRATION_NAME" -Default "InitialCreate"
        AddNewMigration = Read-EnvFileValue -Key "ADD_NEW_MIGRATION" -Default "false"
        DatabaseHost    = Read-EnvFileValue -Key "DATABASE_HOST" -Default "mssql"
        DatabaseName    = Read-EnvFileValue -Key "DATABASE_NAME" -Default "RSSActivityWeb"
        ComposeProject  = Read-EnvFileValue -Key "COMPOSE_PROJECT_NAME" -Default "swu-rssnews"
    }
    
    return $values
}

function Get-DatabaseContainerName {
    <#
    .SYNOPSIS
        หา database container name แบบ dynamic
    #>
    $possibleNames = @("sqlserver", "mssql", "sql-server", "database", "db")
    
    # ลอง exact match ก่อน
    foreach ($name in $possibleNames) {
        $container = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -eq $name }
        if ($container) {
            return $container
        }
    }
    
    # Pattern matching
    $container = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -match "sql|mssql|database" } | Select-Object -First 1
    return $container
}

function Get-DatabaseServiceName {
    <#
    .SYNOPSIS
        หา database service name จาก docker-compose.yml
    #>
    $composeFile = Join-Path $ProjectRoot "docker-compose.yml"
    
    if (Test-Path $composeFile) {
        $content = Get-Content $composeFile -Raw
        $possibleServices = @("sqlserver", "mssql", "sql-server", "database")
        
        foreach ($svc in $possibleServices) {
            if ($content -match "(?m)^\s+${svc}:") {
                return $svc
            }
        }
    }
    return "sqlserver"
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
        2. {COMPOSE_PROJECT_NAME}_backend-network
        3. database-network (ถ้ามี name: กำหนดไว้)
        4. backend-network (ถ้ามี name: กำหนดไว้)
        5. ชื่ออื่นๆ ที่มี "database", "backend", หรือ "rssnews"
        6. ถ้าไม่เจอเลย จะสร้าง network ใหม่
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
    
    # ลองหาตาม pattern ที่กำหนด (exact match)
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

function Connect-ContainerToNetwork {
    <#
    .SYNOPSIS
        เชื่อมต่อ container เข้า network (ถ้ายังไม่ได้เชื่อมต่อ)
    #>
    param(
        [string]$ContainerName,
        [string]$NetworkName
    )
    
    if ([string]::IsNullOrWhiteSpace($ContainerName) -or [string]::IsNullOrWhiteSpace($NetworkName)) {
        return
    }
    
    try {
        $isConnected = docker network inspect $NetworkName --format "{{range .Containers}}{{.Name}} {{end}}" 2>$null
        if ($isConnected -notmatch $ContainerName) {
            docker network connect $NetworkName $ContainerName 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  🔗 Connected $ContainerName to $NetworkName" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  ℹ  $ContainerName already connected to $NetworkName" -ForegroundColor Gray
        }
    }
    catch {
        # Ignore errors
    }
}

function Test-FirstMigration {
    if (-not (Test-Path $MigrationsDir)) { return $true }
    $csFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue
    return ($null -eq $csFiles -or $csFiles.Count -eq 0)
}

# ═══════════════════════════════════════════════════════════
# 📖 Main Script Start
# ═══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  🔧 EF Core Migration Tool (Docker-based)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# ═══════════════════════════════════════════════════════════
# Step 0: Read Configuration
# ═══════════════════════════════════════════════════════════
$envValues = $null
if (-not $IgnoreEnv) {
    Write-Host "📋 Reading configuration from .env..." -ForegroundColor Cyan
    $envValues = Read-AllEnvValues
    
    if ([string]::IsNullOrWhiteSpace($MigrationName)) {
        $MigrationName = $envValues.MigrationName
        Write-Host "  ✅ MIGRATION_NAME from .env: $MigrationName" -ForegroundColor Green
    }
    else {
        Write-Host "  ✅ MIGRATION_NAME from parameter: $MigrationName" -ForegroundColor Green
    }
    Write-Host "  ✅ ADD_NEW_MIGRATION: $($envValues.AddNewMigration)" -ForegroundColor Gray
    Write-Host "  ✅ DATABASE_HOST: $($envValues.DatabaseHost)" -ForegroundColor Gray
    Write-Host "  ✅ DATABASE_NAME: $($envValues.DatabaseName)" -ForegroundColor Gray
    Write-Host ""
}
else {
    Write-Host "📋 Using parameter values (--IgnoreEnv specified)..." -ForegroundColor Yellow
    if ([string]::IsNullOrWhiteSpace($MigrationName)) {
        $MigrationName = "InitialCreate"
    }
    $envValues = @{
        DatabaseHost = "mssql"
        DatabaseName = "RSSActivityWeb"
    }
    Write-Host ""
}

# Validate migration name
if ([string]::IsNullOrWhiteSpace($MigrationName)) {
    Write-Host "❌ Migration name is required" -ForegroundColor Red
    Write-Host "   Usage: .\run-migration.ps1 -MigrationName 'YourMigrationName'" -ForegroundColor Yellow
    exit 1
}

$null = Test-FirstMigration

# ═══════════════════════════════════════════════════════════
# Step 1: Detect Network
# ═══════════════════════════════════════════════════════════
Write-Host "📋 Step 1: Detecting network configuration..." -ForegroundColor Cyan
$NetworkName = Get-DatabaseNetwork
Write-Host ""

# ═══════════════════════════════════════════════════════════
# Step 2: Check Prerequisites
# ═══════════════════════════════════════════════════════════
Write-Host "📋 Step 2: Checking prerequisites..." -ForegroundColor Cyan

# Check password file
if (-not (Test-Path $PasswordFile)) {
    Write-Host "  ❌ Password file not found: $PasswordFile" -ForegroundColor Red
    Write-Host "  💡 Run: .\scripts\quick-start.ps1 to generate password" -ForegroundColor Yellow
    exit 1
}

$Password = (Get-Content $PasswordFile -Raw).Trim()
if ($Password.Length -lt 8) {
    Write-Host "  ❌ Password too short (minimum 8 characters)" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Password file found ($($Password.Length) chars)" -ForegroundColor Green

# Check database container
$mssqlContainer = Get-DatabaseContainerName
if (-not $mssqlContainer) {
    Write-Host "  ❌ Database container not found" -ForegroundColor Red
    Write-Host "  💡 Run: docker compose up -d sqlserver" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✅ Database container: $mssqlContainer" -ForegroundColor Green

# Ensure container is connected to network
Connect-ContainerToNetwork -ContainerName $mssqlContainer -NetworkName $NetworkName

# Database config
$dbHost = if ($mssqlContainer) { $mssqlContainer } else { $envValues.DatabaseHost }
$dbName = $envValues.DatabaseName

Write-Host "  📡 Using: $dbHost/$dbName" -ForegroundColor Gray
Write-Host "  🌐 Network: $NetworkName" -ForegroundColor Gray
Write-Host ""

# ═══════════════════════════════════════════════════════════
# Step 2.5: Build Migration Image
# ═══════════════════════════════════════════════════════════
Write-Host "📋 Building migration image..." -ForegroundColor Cyan
$dockerfilePath = Join-Path $ProjectRoot "aspnetcore\Dockerfile"

docker build --target migration -t $MigrationImage -f $dockerfilePath $ProjectRoot 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Failed to build migration image" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Migration image ready" -ForegroundColor Green
Write-Host ""

# ═══════════════════════════════════════════════════════════
# Step 3: Create Migration (if not ApplyOnly)
# ═══════════════════════════════════════════════════════════
if (-not $ApplyOnly) {
    Write-Host "📋 Step 3: Creating migration '$MigrationName'..." -ForegroundColor Cyan
    
    # Check if migration already exists
    if (-not $Force) {
        $existingMigration = Get-ChildItem -Path $MigrationsDir -Filter "*_$MigrationName.cs" -ErrorAction SilentlyContinue
        if ($existingMigration) {
            Write-Host "  ⚠️  Migration '$MigrationName' already exists" -ForegroundColor Yellow
            Write-Host "  📄 Found: $($existingMigration.Name)" -ForegroundColor Gray
            Write-Host "  💡 Use -Force to recreate or choose a different name" -ForegroundColor Yellow
            
            if (-not $CreateOnly) {
                Write-Host "  ⏭️  Skipping to apply step..." -ForegroundColor Cyan
            }
            else {
                exit 0
            }
        }
        else {
            # Create new migration
            $aspnetcorePath = (Resolve-Path (Join-Path $ProjectRoot "aspnetcore")).Path.Replace('\', '/')
            $connectionString = "Server=$dbHost;Database=$dbName;User ID=sa;Password=$Password;TrustServerCertificate=True;Encrypt=False;"
            
            Write-Host "  🚀 Generating migration files..." -ForegroundColor Cyan
            Write-Host "     Name: $MigrationName" -ForegroundColor Gray
            Write-Host "     Target: $dbHost/$dbName" -ForegroundColor Gray
            
            # ใช้ SDK image โดยตรง (ไม่ต้องพึ่ง custom image)
            if ($MigrationImage -eq "mcr.microsoft.com/dotnet/sdk:9.0") {
                $createResult = docker run --rm `
                    --network $NetworkName `
                    -e "MSSQL_SA_PASSWORD=$Password" `
                    -e "ASPNETCORE_ENVIRONMENT=Development" `
                    -e "ConnectionStrings__DefaultConnection=$connectionString" `
                    -v "${aspnetcorePath}:/app/aspnetcore" `
                    -w /app/aspnetcore `
                    $MigrationImage `
                    bash -c "dotnet tool install --global dotnet-ef --version 9.0.* 2>/dev/null || true; export PATH=`"`$PATH:/root/.dotnet/tools`"; dotnet ef migrations add $MigrationName --project rssnews.csproj --context RSSNewsDbContext --output-dir Migrations --verbose" 2>&1
            }
            else {
                # ใช้ custom migration image (มี ef tool แล้ว)
                $createResult = docker run --rm `
                    --network $NetworkName `
                    -e "MSSQL_SA_PASSWORD=$Password" `
                    -e "ASPNETCORE_ENVIRONMENT=Development" `
                    -e "ConnectionStrings__DefaultConnection=$connectionString" `
                    -v "${aspnetcorePath}:/app/aspnetcore" `
                    -w /app/aspnetcore `
                    --entrypoint dotnet `
                    $MigrationImage `
                    ef migrations add $MigrationName `
                    --project rssnews.csproj `
                    --context RSSNewsDbContext `
                    --output-dir Migrations `
                    --verbose 2>&1
            }
            
            # แสดง output
            $createResult | ForEach-Object { 
                if ($_ -match "error|Error|fail|Fail") {
                    Write-Host "     $_" -ForegroundColor Red
                }
                elseif ($_ -match "warn|Warn") {
                    Write-Host "     $_" -ForegroundColor Yellow
                }
                elseif ($_ -match "Done|Success|Created") {
                    Write-Host "     $_" -ForegroundColor Green
                }
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "  ✅ Migration '$MigrationName' created successfully" -ForegroundColor Green
                
                # ตรวจสอบว่าไฟล์ถูกสร้างจริง
                Start-Sleep -Seconds 2
                $newFiles = Get-ChildItem -Path $MigrationsDir -Filter "*_$MigrationName*.cs" -ErrorAction SilentlyContinue
                if ($newFiles) {
                    Write-Host ""
                    Write-Host "  📄 Generated files:" -ForegroundColor Cyan
                    $newFiles | ForEach-Object {
                        Write-Host "     ✅ $($_.Name)" -ForegroundColor Green
                    }
                }
                else {
                    Write-Host "  ⚠️  Files may not be visible yet, checking..." -ForegroundColor Yellow
                    Get-ChildItem -Path $MigrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue | ForEach-Object {
                        Write-Host "     • $($_.Name)" -ForegroundColor Gray
                    }
                }
            }
            else {
                Write-Host "  ❌ Failed to create migration" -ForegroundColor Red
                
                # แสดง error ที่เกี่ยวข้อง
                $errorLines = $createResult | Where-Object { $_ -match "error|Error|exception|Exception|fail" }
                if ($errorLines) {
                    Write-Host ""
                    Write-Host "  📋 Error details:" -ForegroundColor Yellow
                    $errorLines | Select-Object -First 10 | ForEach-Object {
                        Write-Host "     $_" -ForegroundColor Red
                    }
                }
                
                Write-Host ""
                Write-Host "  💡 Troubleshooting Tips:" -ForegroundColor Yellow
                Write-Host "     1. Check if password file exists: secrets/db_password.txt" -ForegroundColor Gray
                Write-Host "     2. Check if SQL Server is running: docker ps | grep sql" -ForegroundColor Gray
                Write-Host "     3. Check network connectivity: docker network inspect $NetworkName" -ForegroundColor Gray
                Write-Host "     4. Check DbContext configuration in Configure.Db.cs" -ForegroundColor Gray
                Write-Host "     5. Try manually: docker exec -it $mssqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P `"$Password`" -Q `"SELECT 1`" -C" -ForegroundColor Gray
                
                if (-not $CreateOnly) {
                    exit 1
                }
            }
        }
    }
    
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════
# Step 4: Apply Migration (if not CreateOnly)
# ═══════════════════════════════════════════════════════════
if (-not $CreateOnly) {
    Write-Host "📋 Step 4: Applying migrations to database..." -ForegroundColor Cyan
    
    # ตรวจสอบว่ามี migration files หรือไม่
    $csFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue
    if ($null -eq $csFiles -or $csFiles.Count -eq 0) {
        Write-Host "  ⚠️  No migrations to apply" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "  📄 Migrations to apply: $($csFiles.Count) files" -ForegroundColor Gray
    
    $aspnetcorePath = (Resolve-Path (Join-Path $ProjectRoot "aspnetcore")).Path.Replace('\', '/')
    $connectionString = "Server=$dbHost;Database=$dbName;User ID=sa;Password=$Password;TrustServerCertificate=True;Encrypt=False;"
    
    Write-Host "  🚀 Applying to: $dbHost/$dbName" -ForegroundColor Cyan
    Write-Host "  🌐 Using network: $NetworkName" -ForegroundColor Cyan
    
    if ($MigrationImage -eq "mcr.microsoft.com/dotnet/sdk:9.0") {
        $applyResult = docker run --rm `
            --network $NetworkName `
            -e "MSSQL_SA_PASSWORD=$Password" `
            -e "ConnectionStrings__DefaultConnection=$connectionString" `
            -v "${aspnetcorePath}:/app/aspnetcore" `
            -w /app/aspnetcore `
            $MigrationImage `
            bash -c "dotnet tool install --global dotnet-ef --version 9.0.* 2>/dev/null || true; export PATH=`"`$PATH:/root/.dotnet/tools`"; dotnet ef database update --connection '$connectionString' --context RSSNewsDbContext --project rssnews.csproj --verbose" 2>&1
    }
    else {
        $applyResult = docker run --rm `
            --network $NetworkName `
            -e "MSSQL_SA_PASSWORD=$Password" `
            -e "ConnectionStrings__DefaultConnection=$connectionString" `
            -v "${aspnetcorePath}:/app/aspnetcore" `
            -w /app/aspnetcore `
            $MigrationImage `
            dotnet ef database update `
            --connection "$connectionString" `
            --context RSSNewsDbContext `
            --project rssnews.csproj `
            --verbose 2>&1
    }
    
    # แสดง output
    $applyResult | ForEach-Object { 
        if ($_ -match "Applying|Applied") {
            Write-Host "     $_" -ForegroundColor Green
        }
        elseif ($_ -match "error|Error") {
            Write-Host "     $_" -ForegroundColor Red
        }
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  ✅ Migrations applied successfully" -ForegroundColor Green
    }
    else {
        if ($applyResult -match "No migrations were applied|already up to date|Database is already") {
            Write-Host ""
            Write-Host "  ✅ Database is already up to date" -ForegroundColor Green
        }
        else {
            Write-Host ""
            Write-Host "  ⚠️  Migration apply completed with warnings" -ForegroundColor Yellow
            $lastLines = ($applyResult -split "`n" | Select-Object -Last 5) -join "`n"
            Write-Host $lastLines -ForegroundColor Gray
        }
    }
    
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════
# Step 5: Restart ASP.NET Core (optional)
# ═══════════════════════════════════════════════════════════
$aspnetcoreContainer = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -match "aspnet|aspdotnet" } | Select-Object -First 1

if ($aspnetcoreContainer) {
    Write-Host "📋 Step 5: Restarting ASP.NET Core..." -ForegroundColor Cyan
    docker restart $aspnetcoreContainer 2>$null | Out-Null
    Write-Host "  ✅ ASP.NET Core restarted: $aspnetcoreContainer" -ForegroundColor Green
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Migration Process Completed" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "📄 Migration files: $MigrationsDir" -ForegroundColor Cyan

# แสดงรายการไฟล์
$finalFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.cs" -ErrorAction SilentlyContinue
if ($finalFiles) {
    Write-Host "   Found $($finalFiles.Count) migration file(s):" -ForegroundColor Gray
    $finalFiles | ForEach-Object {
        Write-Host "   • $($_.Name)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "📝 Migration name: $MigrationName" -ForegroundColor Cyan
Write-Host "🌐 Network used: $NetworkName" -ForegroundColor Cyan
Write-Host "📡 Database: $dbHost/$dbName" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Check app: docker logs $aspnetcoreContainer" -ForegroundColor Gray
Write-Host "   2. Test: curl http://localhost:5000/health" -ForegroundColor Gray
Write-Host "   3. Commit: git add aspnetcore/Migrations" -ForegroundColor Gray
Write-Host ""