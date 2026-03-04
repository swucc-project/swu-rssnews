# generate-whole-code.ps1
# Generate GraphQL, gRPC, OpenAPI code for swu-rssnews

param(
    [string]$BackendUrl = "http://localhost:5000/health",

    [switch]$SkipGraphQL,
    [switch]$SkipGrpc,
    [switch]$SkipOpenAPI,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectName = "swu-rssnews"

function Get-Compose {
    $null = docker compose version 2>&1
    if ($?) { 
        return "docker compose" 
    }
    return "docker-compose"
}

$compose = Get-Compose

function Initialize-ServiceRunning($service) {
    $running = Invoke-Expression "$compose ps --services --filter status=running"
    if ($running -notcontains $service) {
        Write-Error "❌ Service '$service' is not running"
        exit 1
    }
}

function Invoke-Step {
    param(
        [string]$Title,
        [scriptblock]$Action
    )

    Write-Host "`n📝 $Title" -ForegroundColor Cyan
    try {
        & $Action
        Write-Host "✅ $Title completed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ $Title failed" -ForegroundColor Red
        Write-Host $_ -ForegroundColor DarkRed
        if (-not $Force) { exit 1 }
        Write-Host "⚠️  Continuing because -Force was used" -ForegroundColor Yellow
    }
}

Write-Host "`n🔧 Code Generation - $ProjectName" -ForegroundColor Cyan
Write-Host "=" * 60

# --- Backend Health Check ---
Write-Host "`n🔍 Checking backend availability..." -ForegroundColor Yellow
$backendRunning = $false

try {
    $res = Invoke-WebRequest -Uri $BackendUrl -TimeoutSec 5 -UseBasicParsing
    if ($res.StatusCode -eq 200) {
        $backendRunning = $true
        Write-Host "✅ Backend is running" -ForegroundColor Green
    }
}
catch {
    Write-Host "⚠️  Backend not reachable: $BackendUrl" -ForegroundColor Yellow
    if (-not $Force) {
        Write-Host "💡 Start backend or use -Force" -ForegroundColor Gray
        exit 1
    }
}

Initialize-ServiceRunning "frontend"

# --- GraphQL ---
if (-not $SkipGraphQL) {
    Invoke-Step "Generate GraphQL types" {
        if ($backendRunning) {
            Invoke-Expression "$compose exec frontend npm run graphql:generate"
        }
        else {
            Invoke-Expression "$compose exec frontend npm run assure-files"
        }
    }
}
else {
    Write-Host "⏭️  Skipping GraphQL generation" -ForegroundColor Gray
}

# --- gRPC ---
if (-not $SkipGrpc) {
    Invoke-Step "Generate gRPC code" {
        Invoke-Expression "$compose exec frontend npm run generate-grpc-all"
    }
}
else {
    Write-Host "⏭️  Skipping gRPC generation" -ForegroundColor Gray
}

# --- OpenAPI ---
if (-not $SkipOpenAPI) {
    if ($backendRunning) {
        Invoke-Step "Generate OpenAPI client" {
            Invoke-Expression "$compose exec frontend npm run generate-all"
        }
    }
    else {
        Write-Host "⚠️  Backend not running, skipping OpenAPI" -ForegroundColor Yellow
    }
}
else {
    Write-Host "⏭️  Skipping OpenAPI generation" -ForegroundColor Gray
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Green
Write-Host "✅ Code Generation Completed!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Green

Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
Write-Host "  docker compose up -d --build frontend" -ForegroundColor White
Write-Host ""