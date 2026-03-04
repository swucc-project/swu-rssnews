# ═══════════════════════════════════════════════════════════
# 🔧 Apply GraphQL Connection Fixes
# ═══════════════════════════════════════════════════════════
# PowerShell Script for Windows
# ═══════════════════════════════════════════════════════════

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔧 Applying GraphQL Connection Fixes" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Function to check if file exists
function Test-FileExists {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        Write-Host "✅ Found: $FilePath" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "❌ Not found: $FilePath" -ForegroundColor Red
        return $false
    }
}

# Function to backup file
function Backup-File {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $backupPath = "$FilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $FilePath $backupPath
        Write-Host "📦 Backup created: $backupPath" -ForegroundColor Yellow
    }
}

# Step 1: Stop containers
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Step 1: Stopping containers..." -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

docker compose down
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Containers stopped successfully" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Warning: Could not stop containers" -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Backup existing files
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Step 2: Creating backups..." -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$filesToBackup = @(
    "./aspnetcore/Program.cs",
    "./aspnetcore/Properties/launchSettings.json",
    "./.env"
)

foreach ($file in $filesToBackup) {
    if (Test-Path $file) {
        Backup-File $file
    }
}
Write-Host ""

# Step 3: Apply fixes
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Step 3: Applying fixes..." -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Check if fix files exist
$fixFiles = @{
    "Program.cs"          = "./aspnetcore/Program.cs"
    "launchSettings.json" = "./aspnetcore/Properties/launchSettings.json"
    ".env"                = "./.env"
}

$allFilesExist = $true
foreach ($file in $fixFiles.Keys) {
    if (-not (Test-FileExists $file)) {
        $allFilesExist = $false
        Write-Host "❌ Fix file not found: $file" -ForegroundColor Red
        Write-Host "   Please ensure you have downloaded all the fix files" -ForegroundColor Yellow
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "❌ Cannot proceed - missing fix files" -ForegroundColor Red
    exit 1
}

# Copy fix files
Write-Host ""
Write-Host "Copying fixed files..." -ForegroundColor White

Copy-Item "Program.cs" -Destination "./aspnetcore/Program.cs" -Force
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Program.cs updated" -ForegroundColor Green
}

Copy-Item "launchSettings.json" -Destination "./aspnetcore/Properties/launchSettings.json" -Force
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ launchSettings.json updated" -ForegroundColor Green
}

Copy-Item ".env" -Destination "./.env" -Force
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ .env updated" -ForegroundColor Green
}

Write-Host ""

# Step 4: Rebuild containers
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Step 4: Rebuilding containers..." -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "Building backend..." -ForegroundColor White
docker compose build --no-cache aspdotnetweb

Write-Host "Building frontend..." -ForegroundColor White
docker compose build --no-cache frontend

Write-Host "✅ Containers rebuilt" -ForegroundColor Green
Write-Host ""

# Step 5: Start containers
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Step 5: Starting containers..." -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

docker compose up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Containers started successfully" -ForegroundColor Green
}
else {
    Write-Host "❌ Failed to start containers" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 6: Wait and verify
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Step 6: Waiting for services to be ready..." -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "Waiting 30 seconds for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Verify backend
Write-Host ""
Write-Host "Checking backend health..." -ForegroundColor White
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Backend is healthy" -ForegroundColor Green
    }
}
catch {
    Write-Host "⚠️  Backend health check failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Verify GraphQL
Write-Host ""
Write-Host "Checking GraphQL endpoint..." -ForegroundColor White
try {
    $graphqlQuery = @{
        query = "{ __typename }"
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "http://localhost:5000/graphql" `
        -Method POST `
        -ContentType "application/json" `
        -Body $graphqlQuery `
        -TimeoutSec 10 `
        -UseBasicParsing

    if ($response.StatusCode -eq 200) {
        Write-Host "✅ GraphQL endpoint is responding" -ForegroundColor Green
    }
}
catch {
    Write-Host "⚠️  GraphQL check failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Step 7: Show logs
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Step 7: Checking for warnings..." -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host ""
Write-Host "Backend logs (checking for override warning):" -ForegroundColor White
$backendLogs = docker logs aspnetcore 2>&1 | Select-String "override" -CaseSensitive
if ($backendLogs) {
    Write-Host "⚠️  Warning found:" -ForegroundColor Yellow
    $backendLogs | ForEach-Object { Write-Host "   $_" -ForegroundColor Yellow }
}
else {
    Write-Host "✅ No override warnings found" -ForegroundColor Green
}

Write-Host ""
Write-Host "Frontend logs (checking GraphQL connection):" -ForegroundColor White
$frontendLogs = docker logs vite-user-interface 2>&1 | Select-String "GraphQL" | Select-Object -Last 5
if ($frontendLogs) {
    $frontendLogs | ForEach-Object { Write-Host "   $_" -ForegroundColor Cyan }
}
else {
    Write-Host "ℹ️  No GraphQL messages found yet" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✨ Fix Application Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor White
Write-Host "   1. Monitor logs: docker compose logs -f" -ForegroundColor Gray
Write-Host "   2. Check backend: http://localhost:5000/health" -ForegroundColor Gray
Write-Host "   3. Check GraphQL: http://localhost:5000/graphql" -ForegroundColor Gray
Write-Host "   4. Access app: http://localhost:8080" -ForegroundColor Gray
Write-Host ""
Write-Host "📝 To view detailed logs:" -ForegroundColor White
Write-Host "   Backend:  docker logs -f aspnetcore" -ForegroundColor Gray
Write-Host "   Frontend: docker logs -f vite-user-interface" -ForegroundColor Gray
Write-Host ""