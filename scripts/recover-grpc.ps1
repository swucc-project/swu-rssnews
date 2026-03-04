# ========================================
# gRPC Recovery PowerShell Script
# ========================================

param(
    [switch]$Force,
    [switch]$NoBackup,
    [switch]$DryRun
)

# Colors for Windows Terminal
$ErrorColor = "Red"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$InfoColor = "Cyan"

# Auto-detect project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Expected namespace
$ExpectedNamespace = "SwuNews"

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor $InfoColor
Write-Host "║       🔄 gRPC Recovery & Reset Utility                ║" -ForegroundColor $InfoColor
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor $InfoColor
Write-Host ""
Write-Host "ℹ  Project root: $ProjectRoot" -ForegroundColor $InfoColor
Write-Host "ℹ  Expected namespace: $ExpectedNamespace" -ForegroundColor $InfoColor
Write-Host ""

# Counter for operations
$OperationsCount = 0
$ErrorsCount = 0

# Function to show help
function Show-Help {
    Write-Host "Usage: .\recover-grpc.ps1 [options]" -ForegroundColor $InfoColor
    Write-Host ""
    Write-Host "Options:" -ForegroundColor $InfoColor
    Write-Host "  -Force        Skip confirmation prompts" -ForegroundColor $WarningColor
    Write-Host "  -NoBackup     Skip creating backup" -ForegroundColor $WarningColor
    Write-Host "  -DryRun       Show what would be done without doing it" -ForegroundColor $InfoColor
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor $InfoColor
    Write-Host "  .\recover-grpc.ps1                    # Interactive mode with backup"
    Write-Host "  .\recover-grpc.ps1 -Force             # Auto-confirm all operations"
    Write-Host "  .\recover-grpc.ps1 -DryRun            # Preview operations"
    Write-Host ""
}

# Check if help requested
if ($args -contains "-h" -or $args -contains "--help" -or $args -contains "/?") {
    Show-Help
    exit 0
}

# Function to create backup
function Invoke-Backup {
    param([string]$Path)
    
    if ($NoBackup) {
        Write-Host "⚠️  Skipping backup (NoBackup flag set)" -ForegroundColor $WarningColor
        return $null
    }
    
    if (Test-Path $Path) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$Path.backup_$timestamp"
        
        if ($DryRun) {
            Write-Host "[DRY RUN] Would backup: $Path → $backupPath" -ForegroundColor $WarningColor
            return $backupPath
        }
        
        try {
            Copy-Item -Path $Path -Destination $backupPath -Recurse -Force
            Write-Host "✅ Backup created: $backupPath" -ForegroundColor $SuccessColor
            return $backupPath
        }
        catch {
            Write-Host "❌ Failed to create backup: $_" -ForegroundColor $ErrorColor
            $script:ErrorsCount++
            return $null
        }
    }
    
    return $null
}

# Function to remove directory safely
function Remove-DirectorySafe {
    param(
        [string]$Path,
        [string]$Description
    )
    
    if (Test-Path $Path) {
        Write-Host "🗑️  Removing: $Description" -ForegroundColor $WarningColor
        Write-Host "    Path: $Path" -ForegroundColor $InfoColor
        
        if ($DryRun) {
            Write-Host "[DRY RUN] Would remove: $Path" -ForegroundColor $WarningColor
            $script:OperationsCount++
            return
        }
        
        # Create backup before removing
        $backup = Invoke-Backup -Path $Path
        
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Host "✅ Removed successfully" -ForegroundColor $SuccessColor
            $script:OperationsCount++
        }
        catch {
            Write-Host "❌ Failed to remove: $_" -ForegroundColor $ErrorColor
            $script:ErrorsCount++
            
            # Try to restore from backup
            if ($backup -and (Test-Path $backup)) {
                Write-Host "🔄 Attempting to restore from backup..." -ForegroundColor $WarningColor
                try {
                    Copy-Item -Path $backup -Destination $Path -Recurse -Force
                    Write-Host "✅ Restored from backup" -ForegroundColor $SuccessColor
                }
                catch {
                    Write-Host "❌ Failed to restore: $_" -ForegroundColor $ErrorColor
                }
            }
        }
    }
    else {
        Write-Host "ℹ  Directory not found (already clean): $Description" -ForegroundColor $InfoColor
    }
}

# Function to remove stale gRPC files
function Remove-StaleGrpcFiles {
    param([string]$BasePath)
    
    Write-Host "🔍 Searching for stale gRPC files in: $BasePath" -ForegroundColor $InfoColor
    
    # ค้นหาไฟล์ gRPC ที่อาจค้างอยู่ (ยกเว้น ServiceInterface)
    $stalePatterns = @("*Grpc.cs", "Rss.cs", "*GrpcReflection.cs")
    $excludePaths = @("ServiceInterface", "Services")
    
    $staleFiles = @()
    foreach ($pattern in $stalePatterns) {
        $files = Get-ChildItem -Path $BasePath -Filter $pattern -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $shouldExclude = $false
            foreach ($exclude in $excludePaths) {
                if ($file.FullName -like "*\$exclude\*") {
                    $shouldExclude = $true
                    break
                }
            }
            if (-not $shouldExclude) {
                $staleFiles += $file
            }
        }
    }
    
    if ($staleFiles.Count -gt 0) {
        Write-Host "⚠️  Found $($staleFiles.Count) stale gRPC file(s):" -ForegroundColor $WarningColor
        foreach ($file in $staleFiles) {
            Write-Host "    ✕ $($file.FullName)" -ForegroundColor $ErrorColor
            
            if (-not $DryRun) {
                try {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    Write-Host "    ✅ Removed" -ForegroundColor $SuccessColor
                    $script:OperationsCount++
                }
                catch {
                    Write-Host "    ❌ Failed to remove: $_" -ForegroundColor $ErrorColor
                    $script:ErrorsCount++
                }
            }
            else {
                Write-Host "    [DRY RUN] Would remove" -ForegroundColor $WarningColor
                $script:OperationsCount++
            }
        }
    }
    else {
        Write-Host "✅ No stale gRPC files found" -ForegroundColor $SuccessColor
    }
}

# Function to check Docker status
function Test-Docker {
    try {
        $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
        if ($dockerVersion) {
            Write-Host "✅ Docker is running (v$dockerVersion)" -ForegroundColor $SuccessColor
            return $true
        }
    }
    catch {
        Write-Host "❌ Docker is not running" -ForegroundColor $ErrorColor
        Write-Host "💡 Please start Docker Desktop" -ForegroundColor $WarningColor
        return $false
    }
    return $false
}

# Function to check proto namespace
function Test-ProtoNamespace {
    $protoFile = "$ProjectRoot\protobuf\rss.proto"
    
    if (Test-Path $protoFile) {
        $content = Get-Content $protoFile -Raw
        
        if ($content -match 'csharp_namespace\s*=\s*"([^"]+)"') {
            $currentNamespace = $Matches[1]
            Write-Host "✅ Proto file found" -ForegroundColor $SuccessColor
            Write-Host "    csharp_namespace: $currentNamespace" -ForegroundColor $InfoColor
            
            if ($currentNamespace -eq $ExpectedNamespace) {
                Write-Host "✅ Namespace matches expected: $ExpectedNamespace" -ForegroundColor $SuccessColor
                return $true
            }
            else {
                Write-Host "⚠️  Namespace mismatch!" -ForegroundColor $WarningColor
                Write-Host "    Expected: $ExpectedNamespace" -ForegroundColor $WarningColor
                Write-Host "    Found: $currentNamespace" -ForegroundColor $ErrorColor
                $script:ErrorsCount++
                return $false
            }
        }
        else {
            Write-Host "❌ csharp_namespace not found in proto file" -ForegroundColor $ErrorColor
            $script:ErrorsCount++
            return $false
        }
    }
    else {
        Write-Host "❌ Proto file not found: $protoFile" -ForegroundColor $ErrorColor
        $script:ErrorsCount++
        return $false
    }
}

# Function to check ServiceInterface namespace
function Test-ServiceInterfaceNamespace {
    $serviceFile = "$ProjectRoot\aspnetcore\ServiceInterface\RSSItemService.cs"
    
    if (Test-Path $serviceFile) {
        $content = Get-Content $serviceFile -Raw
        
        Write-Host "✅ RSSItemService.cs found" -ForegroundColor $SuccessColor
        
        # ตรวจสอบ using statement
        if ($content -match "using\s+$ExpectedNamespace\s*;") {
            Write-Host "✅ Correct namespace import: using $ExpectedNamespace;" -ForegroundColor $SuccessColor
        }
        else {
            Write-Host "⚠️  Namespace import may be incorrect" -ForegroundColor $WarningColor
            Write-Host "    Expected: using $ExpectedNamespace;" -ForegroundColor $WarningColor
            $script:ErrorsCount++
        }
        
        # ตรวจสอบ base class
        if ($content -match "$ExpectedNamespace\.RSSItemService\.RSSItemServiceBase") {
            Write-Host "✅ Correct base class inheritance" -ForegroundColor $SuccessColor
        }
        else {
            Write-Host "⚠️  Base class may not match expected namespace" -ForegroundColor $WarningColor
        }
        
        return $true
    }
    else {
        Write-Host "⚠️  RSSItemService.cs not found" -ForegroundColor $WarningColor
        return $false
    }
}

# Main execution
Write-Host "[1/8] Pre-flight checks" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if we're in the right directory
if (-not (Test-Path "$ProjectRoot\docker-compose.yml")) {
    Write-Host "❌ docker-compose.yml not found!" -ForegroundColor $ErrorColor
    Write-Host "💡 Make sure you're running this from the /scripts directory" -ForegroundColor $WarningColor
    exit 1
}

Write-Host "✅ Project structure validated" -ForegroundColor $SuccessColor
Write-Host ""

# Check proto namespace
Write-Host "[2/8] Checking proto file namespace" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$null = Test-ProtoNamespace
Write-Host ""

# Check ServiceInterface namespace
Write-Host "[3/8] Checking ServiceInterface namespace" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Test-ServiceInterfaceNamespace | Out-Null
Write-Host ""

# Check Docker
Write-Host "[4/8] Checking Docker status" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$dockerRunning = Test-Docker
Write-Host ""

# Confirm operation
if (-not $Force -and -not $DryRun) {
    Write-Host "⚠️  This will:" -ForegroundColor $WarningColor
    Write-Host "   • Stop all running containers" -ForegroundColor $WarningColor
    Write-Host "   • Remove generated gRPC files" -ForegroundColor $WarningColor
    Write-Host "   • Remove obj/bin folders" -ForegroundColor $WarningColor
    Write-Host "   • Clean Docker build cache" -ForegroundColor $WarningColor
    if (-not $NoBackup) {
        Write-Host "   • Create backups before removing" -ForegroundColor $InfoColor
    }
    Write-Host ""
    
    $confirmation = Read-Host "Continue? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "❌ Recovery cancelled" -ForegroundColor $ErrorColor
        exit 0
    }
}

Write-Host ""
Write-Host "[5/8] Stopping containers" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ($dockerRunning) {
    if ($DryRun) {
        Write-Host "[DRY RUN] Would stop containers" -ForegroundColor $WarningColor
    }
    else {
        Push-Location $ProjectRoot
        try {
            docker compose down 2>$null
            Write-Host "✅ Containers stopped" -ForegroundColor $SuccessColor
            $script:OperationsCount++
        }
        catch {
            Write-Host "⚠️  Warning: Could not stop containers: $_" -ForegroundColor $WarningColor
        }
        Pop-Location
    }
}
else {
    Write-Host "⚠️  Docker not running, skipping container stop" -ForegroundColor $WarningColor
}
Write-Host ""

Write-Host "[6/8] Cleaning generated files and directories" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Define directories to clean
$directoriesToClean = @(
    @{Path = "$ProjectRoot\aspnetcore\obj"; Description = "ASP.NET obj folder" },
    @{Path = "$ProjectRoot\aspnetcore\bin"; Description = "ASP.NET bin folder" },
    @{Path = "$ProjectRoot\aspnetcore\Grpc"; Description = "ASP.NET Grpc folder" },
    @{Path = "$ProjectRoot\shared\grpc"; Description = "C# generated files" },
    @{Path = "$ProjectRoot\shared\graphql"; Description = "GraphQL schemas" },
    @{Path = "$ProjectRoot\vite-ui\grpc-generated"; Description = "Frontend gRPC" },
    @{Path = "$ProjectRoot\vite-ui\apollo\generated"; Description = "GraphQL codegen" }
)

foreach ($dir in $directoriesToClean) {
    Remove-DirectorySafe -Path $dir.Path -Description $dir.Description
}
Write-Host ""

# Remove stale gRPC files
Write-Host "[7/8] Removing stale gRPC files" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Remove-StaleGrpcFiles -BasePath "$ProjectRoot\aspnetcore"
Write-Host ""

Write-Host "[8/8] Cleaning Docker resources" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ($dockerRunning) {
    if ($DryRun) {
        Write-Host "[DRY RUN] Would prune Docker build cache" -ForegroundColor $WarningColor
    }
    else {
        Write-Host "🧹 Pruning Docker build cache..." -ForegroundColor $InfoColor
        try {
            docker builder prune -f 2>$null
            Write-Host "✅ Docker cache cleaned" -ForegroundColor $SuccessColor
            $script:OperationsCount++
        }
        catch {
            Write-Host "⚠️  Warning: Could not clean Docker cache: $_" -ForegroundColor $WarningColor
        }
    }
}
else {
    Write-Host "⚠️  Docker not running, skipping cache cleanup" -ForegroundColor $WarningColor
}
Write-Host ""

# Summary
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Summary" -ForegroundColor $WarningColor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ($DryRun) {
    Write-Host "✅ Dry run completed - no changes made" -ForegroundColor $SuccessColor
    Write-Host "ℹ  Would perform $OperationsCount operations" -ForegroundColor $InfoColor
}
else {
    Write-Host "✅ Recovery completed!" -ForegroundColor $SuccessColor
    Write-Host "ℹ  Operations performed: $OperationsCount" -ForegroundColor $InfoColor
    if ($ErrorsCount -gt 0) {
        Write-Host "⚠️  Errors/warnings encountered: $ErrorsCount" -ForegroundColor $WarningColor
    }
}
Write-Host ""

# Show next steps
if (-not $DryRun) {
    Write-Host "💡 Next steps to regenerate gRPC code:" -ForegroundColor $InfoColor
    Write-Host ""
    Write-Host "   1. Rebuild images (with no cache):" -ForegroundColor $InfoColor
    Write-Host "      docker compose build --no-cache aspdotnetweb migration-db" -ForegroundColor $SuccessColor
    Write-Host ""
    Write-Host "   2. Start database:" -ForegroundColor $InfoColor
    Write-Host "      docker compose up -d mssql" -ForegroundColor $SuccessColor
    Write-Host ""
    Write-Host "   3. Run database setup:" -ForegroundColor $InfoColor
    Write-Host "      docker compose --profile setup up queue-db-migration" -ForegroundColor $SuccessColor
    Write-Host ""
    Write-Host "   4. Run migrations:" -ForegroundColor $InfoColor
    Write-Host "      docker compose --profile migration up migration-db" -ForegroundColor $SuccessColor
    Write-Host ""
    Write-Host "   5. Start all services:" -ForegroundColor $InfoColor
    Write-Host "      docker compose up -d" -ForegroundColor $SuccessColor
    Write-Host ""
    Write-Host "   Or use quick-start script:" -ForegroundColor $InfoColor
    Write-Host "      .\scripts\quick-start.ps1 -ForceBuild" -ForegroundColor $SuccessColor
    Write-Host ""
    
    # Show backup locations if created
    if (-not $NoBackup) {
        Write-Host "📦 Backups created with timestamp suffix: *_backup_$(Get-Date -Format 'yyyyMMdd')*" -ForegroundColor $InfoColor
        Write-Host ""
    }
}

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor $InfoColor
Write-Host "║  📖 Expected namespace: $ExpectedNamespace                        ║" -ForegroundColor $InfoColor
Write-Host "║  📁 Run .\scripts\debug-grpc.sh for diagnostics       ║" -ForegroundColor $InfoColor
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor $InfoColor

# Exit with appropriate code
exit $ErrorsCount