#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════
# 🚀 Initialize Project - Create Required Directories & Secrets
# ═══════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot | Split-Path -Parent

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🚀 SWU RSS News - Project Initialization" -ForegroundColor Cyan  
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Required directories
$directories = @(
    "secrets",
    "shared/graphql",
    "shared/grpc",
    "aspnetcore/Migrations",
    "aspnetcore/.aspnet/DataProtection-Keys",
    "aspnetcore/bin",
    "aspnetcore/obj",
    "ssl",
    "database"
)

Write-Host "📁 Creating directories..." -ForegroundColor Cyan

foreach ($dir in $directories) {
    $fullPath = Join-Path $ProjectRoot $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "  ✅ Created: $dir" -ForegroundColor Green
    }
    else {
        Write-Host "  ✓ Exists: $dir" -ForegroundColor Gray
    }
}

Write-Host ""

# Create password file if not exists
$passwordFile = Join-Path $ProjectRoot "secrets\db_password.txt"

if (-not (Test-Path $passwordFile)) {
    Write-Host "🔐 Creating database password..." -ForegroundColor Cyan
    
    # Generate strong password
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%"
    $password = -join ((1..16) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    $password = "Swu" + $password + "!"  # Ensure complexity
    
    $password | Out-File -FilePath $passwordFile -NoNewline -Encoding UTF8
    Write-Host "  ✅ Password generated and saved" -ForegroundColor Green
    Write-Host "  📍 Location: $passwordFile" -ForegroundColor Gray
}
else {
    Write-Host "🔐 Password file exists" -ForegroundColor Gray
}

Write-Host ""

# Create .gitignore entries
$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$gitignoreEntries = @(
    "secrets/",
    "*.user",
    ".vs/",
    "bin/",
    "obj/",
    "node_modules/"
)

Write-Host "📝 Checking .gitignore..." -ForegroundColor Cyan

if (Test-Path $gitignorePath) {
    $currentContent = Get-Content $gitignorePath -Raw
    $added = $false
    
    foreach ($entry in $gitignoreEntries) {
        if ($currentContent -notmatch [regex]::Escape($entry)) {
            Add-Content -Path $gitignorePath -Value $entry
            Write-Host "  ✅ Added: $entry" -ForegroundColor Green
            $added = $true
        }
    }
    
    if (-not $added) {
        Write-Host "  ✓ All entries present" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Project Initialized!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Run: .\scripts\fix-volumes.bat" -ForegroundColor Gray
Write-Host "   2. Run: .\scripts\quick-start.bat" -ForegroundColor Gray
Write-Host ""