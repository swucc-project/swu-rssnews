
---

## 2. สร้างไฟล์ `/scripts/generate-whole-code.ps1`

```powershell
# generate-whole-code.ps1
# Generate all code (GraphQL, gRPC, OpenAPI)

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipGraphQL,
    [Parameter(Mandatory=$false)]
    [switch]$SkipGrpc,
    [Parameter(Mandatory=$false)]
    [switch]$SkipOpenAPI,
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "`n🔧 Code Generation - swu-rssnews" -ForegroundColor Cyan
Write-Host "=" * 60

# Check if backend is running
Write-Host "`n🔍 Checking backend availability..." -ForegroundColor Yellow
$backendRunning = $false
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $backendRunning = $true
        Write-Host "✅ Backend is running" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Backend is not running" -ForegroundColor Yellow
    if (-not $Force) {
        Write-Host "💡 Start backend first or use -Force flag" -ForegroundColor Gray
        Write-Host "   .\scripts\quick-start.ps1" -ForegroundColor Gray
        exit 1
    } else {
        Write-Host "⚠️  Continuing with -Force flag..." -ForegroundColor Yellow
    }
}

# Generate GraphQL
if (-not $SkipGraphQL) {
    Write-Host "`n📝 Generating GraphQL types..." -ForegroundColor Cyan
    try {
        if ($backendRunning) {
            docker-compose exec frontend npm run graphql:generate
            Write-Host "✅ GraphQL types generated" -ForegroundColor Green
        } else {
            docker-compose exec frontend npm run assure-files
            Write-Host "⚠️  Using placeholder GraphQL files" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ GraphQL generation failed: $_" -ForegroundColor Red
        if (-not $Force) { exit 1 }
    }
} else {
    Write-Host "⏭️  Skipping GraphQL generation" -ForegroundColor Gray
}

# Generate gRPC
if (-not $SkipGrpc) {
    Write-Host "`n📝 Generating gRPC code..." -ForegroundColor Cyan
    try {
        docker-compose exec frontend npm run generate-grpc-all
        Write-Host "✅ gRPC code generated" -ForegroundColor Green
    } catch {
        Write-Host "❌ gRPC generation failed: $_" -ForegroundColor Red
        if (-not $Force) { exit 1 }
    }
} else {
    Write-Host "⏭️  Skipping gRPC generation" -ForegroundColor Gray
}

# Generate OpenAPI/Swagger
if (-not $SkipOpenAPI) {
    Write-Host "`n📝 Generating OpenAPI client..." -ForegroundColor Cyan
    try {
        if ($backendRunning) {
            docker-compose exec frontend npm run generate-all
            Write-Host "✅ OpenAPI client generated" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Backend not running, skipping OpenAPI" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ OpenAPI generation failed: $_" -ForegroundColor Red
        if (-not $Force) { exit 1 }
    }
} else {
    Write-Host "⏭️  Skipping OpenAPI generation" -ForegroundColor Gray
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "✅ Code Generation Completed!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Check generated files in:" -ForegroundColor Gray
Write-Host "     - vite-ui/apollo/generated/" -ForegroundColor White
Write-Host "     - vite-ui/grpc/" -ForegroundColor White
Write-Host "     - vite-ui/api/generated/" -ForegroundColor White
Write-Host "  2. Rebuild frontend if needed:" -ForegroundColor Gray
Write-Host "     docker-compose up -d --build frontend" -ForegroundColor White

Write-Host "`n"