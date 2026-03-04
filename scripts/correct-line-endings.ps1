# correct-line-endings.ps1
# แก้ไข Windows CRLF เป็น Unix LF - Enhanced Version

param(
    [string]$Path = ".",
    [switch]$Verbose,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "`n🔧 Fixing Line Endings (CRLF → LF)" -ForegroundColor Cyan
Write-Host "=" * 60

# กำหนด root path
if ($Path -eq ".") {
    $RootPath = (Get-Location).Path
}
else {
    $RootPath = (Resolve-Path $Path).Path
}

Write-Host "📂 Root Path: $RootPath" -ForegroundColor Gray

# รายการไฟล์ที่ต้องแก้ไข (เพิ่มเติม)
$ShellFiles = @(
    "vite-ui/scripts/debug-graphql.sh",
    "vite-ui/scripts/configure.sh",
    "vite-ui/scripts/docker-entrypoint.sh",
    "vite-ui/scripts/download-schema.sh",
    "vite-ui/scripts/fix-entrypoint.sh",
    "vite-ui/scripts/generate-fragments.sh",
    "vite-ui/scripts/initialize.sh",
    "vite-ui/scripts/install-graphql.sh",
    "vite-ui/scripts/logging.sh",
    "vite-ui/scripts/manage-graphql.sh",
    "vite-ui/scripts/repair-dependencies.sh",
    "vite-ui/scripts/rover-introspect.sh",
    "vite-ui/scripts/rover-introspect-publish.sh",
    "vite-ui/scripts/rover-publish.sh",
    "vite-ui/scripts/rover-setup.sh",
    "vite-ui/scripts/secure-graphql-client.sh",
    "vite-ui/scripts/trigger-dev.sh",
    "vite-ui/scripts/validate-env.sh"
    "vite-ui/scripts/validate-graphql.sh",
    "vite-ui/scripts/wait-for-graphql.sh",
    "vite-ui/scripts/graphql/codegen-fallback.sh",
    "vite-ui/scripts/graphql/graphql-utils.sh",
    "aspnetcore/kestrel-improvement.sh",
    "aspnetcore/entrypoint.sh",
    "aspnetcore/add-migration.sh",
    "aspnetcore/boost-grpc.sh",
    "database/begin-volumes.sh",
    "database/mssql-volume-solution.sh",
    "database/wait-for-db.sh",
    "scripts/firewall/linux/firewalld-setup.sh",
    "scripts/firewall/linux/selinux-setup.sh",
    "scripts/setup/install-openssh.sh",
    "scripts/setup/manage-ssh-keys.sh",
    "scripts/setup/ssh-hardening.sh",
    "scripts/check-volume-matching.sh",
    "scripts/cleanup-grpc.sh",
    "scripts/fix-volumes.sh",
    "scripts/implement-fix.sh",
    "scripts/make-grpc-dirs.sh",
    "scripts/verify-grpc-setup.sh",
    "scripts/verify-password.sh"
)

$FixedCount = 0
$SkippedCount = 0
$ErrorCount = 0

function Convert-ToUnixLineEndings {
    param(
        [string]$FilePath,
        [switch]$DryRun
    )
    
    try {
        $content = [System.IO.File]::ReadAllBytes($FilePath)
        $text = [System.Text.Encoding]::UTF8.GetString($content)
        
        # ตรวจสอบว่ามี CRLF หรือไม่
        if ($text -match "`r") {
            $newText = $text -replace "`r`n", "`n"
            $newText = $newText -replace "`r", "`n"
            
            # ลบ BOM ถ้ามี
            if ($newText.StartsWith([char]0xFEFF)) {
                $newText = $newText.Substring(1)
            }
            
            if (-not $DryRun) {
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($FilePath, $newText, $utf8NoBom)
            }
            
            return $true
        }
        return $false
    }
    catch {
        throw $_
    }
}

# ========================================
# ส่วนที่ 1: แก้ไขไฟล์ที่ระบุไว้
# ========================================
Write-Host "`n📋 Phase 1: Processing specified shell scripts..." -ForegroundColor Yellow

foreach ($file in $ShellFiles) {
    $fullPath = Join-Path $RootPath $file
    
    if (Test-Path $fullPath) {
        try {
            $wasFixed = Convert-ToUnixLineEndings -FilePath $fullPath -DryRun:$DryRun
            
            if ($wasFixed) {
                if ($DryRun) {
                    Write-Host "   🔍 Would fix: $file" -ForegroundColor Yellow
                }
                else {
                    Write-Host "   ✅ Fixed: $file" -ForegroundColor Green
                }
                $FixedCount++
            }
            else {
                if ($Verbose) {
                    Write-Host "   ⏭️  Already LF: $file" -ForegroundColor DarkGray
                }
                $SkippedCount++
            }
        }
        catch {
            Write-Host "   ❌ Error: $file - $_" -ForegroundColor Red
            $ErrorCount++
        }
    }
    else {
        if ($Verbose) {
            Write-Host "   ⚠️  Not found: $file" -ForegroundColor DarkYellow
        }
    }
}

# ========================================
# ส่วนที่ 2: สแกนไฟล์ .sh ทั้งหมด
# ========================================
Write-Host "`n📋 Phase 2: Scanning all .sh files recursively..." -ForegroundColor Yellow

$allShFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.sh" -File -ErrorAction SilentlyContinue | 
Where-Object { $_.FullName -notmatch "node_modules|\.git|vendor" }

foreach ($shFile in $allShFiles) {
    try {
        $wasFixed = Convert-ToUnixLineEndings -FilePath $shFile.FullName -DryRun:$DryRun
        
        if ($wasFixed) {
            $relativePath = $shFile.FullName.Replace($RootPath + [System.IO.Path]::DirectorySeparatorChar, "")
            if ($DryRun) {
                Write-Host "   🔍 Would fix: $relativePath" -ForegroundColor Yellow
            }
            else {
                Write-Host "   ✅ Fixed: $relativePath" -ForegroundColor Green
            }
            $FixedCount++
        }
    }
    catch {
        Write-Host "   ❌ Error: $($shFile.Name) - $_" -ForegroundColor Red
        $ErrorCount++
    }
}

# ========================================
# ส่วนที่ 3: สแกนไฟล์ Docker และ config
# ========================================
Write-Host "`n📋 Phase 3: Scanning Dockerfiles and configs..." -ForegroundColor Yellow

$configPatterns = @("Dockerfile*", "docker-compose*.yml", "*.yaml", "Makefile")

foreach ($pattern in $configPatterns) {
    $files = Get-ChildItem -Path $RootPath -Recurse -Filter $pattern -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "node_modules|\.git|vendor" }
    
    foreach ($file in $files) {
        try {
            $wasFixed = Convert-ToUnixLineEndings -FilePath $file.FullName -DryRun:$DryRun
            
            if ($wasFixed) {
                $relativePath = $file.FullName.Replace($RootPath + [System.IO.Path]::DirectorySeparatorChar, "")
                if ($DryRun) {
                    Write-Host "   🔍 Would fix: $relativePath" -ForegroundColor Yellow
                }
                else {
                    Write-Host "   ✅ Fixed: $relativePath" -ForegroundColor Green
                }
                $FixedCount++
            }
        }
        catch {
            Write-Host "   ❌ Error: $($file.Name)" -ForegroundColor Red
            $ErrorCount++
        }
    }
}

# ========================================
# Summary
# ========================================
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "   🔍 Mode: DRY RUN (no files modified)" -ForegroundColor Yellow
}

Write-Host "   ✅ Fixed: $FixedCount files" -ForegroundColor Green
Write-Host "   ⏭️  Skipped: $SkippedCount files (already LF)" -ForegroundColor Gray
Write-Host "   ❌ Errors: $ErrorCount files" -ForegroundColor $(if ($ErrorCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($FixedCount -gt 0 -and -not $DryRun) {
    Write-Host "✅ Line endings fix complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Next steps:" -ForegroundColor Yellow
    Write-Host "   1. Rebuild Docker containers: docker compose build --no-cache frontend" -ForegroundColor Gray
    Write-Host "   2. Restart services: docker compose up -d" -ForegroundColor Gray
    Write-Host "   3. Check logs: docker logs vite-user-interface" -ForegroundColor Gray
}
elseif ($FixedCount -eq 0) {
    Write-Host "✅ All files already have correct line endings!" -ForegroundColor Green
}

Write-Host ""

# Return exit code
if ($ErrorCount -gt 0) {
    exit 1
}
exit 0