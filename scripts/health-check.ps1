# health-check.ps1
# Comprehensive health monitoring for swu-rssnews

param(
    [switch]$Detailed,
    [switch]$Continuous,
    [int]$Interval = 30,
    [switch]$Json,
    [switch]$Silent,

    # ✅ ใช้ localhost แทน service name เพราะเรียกจากนอก container
    [string]$BackendUrl = "http://localhost:5000",
    [string]$GraphQLUrl = "http://localhost:5000/graphql",
    [string]$NginxUrl = "http://localhost:8080",
    [string]$ViteUrl = "http://localhost:5173"
)

$ProjectName = "swu-rssnews"
$ErrorActionPreference = "Continue"

# ✅ Helper Functions
function Get-ComposeCommand {
    try {
        $null = docker compose version 2>$null
        if ($LASTEXITCODE -eq 0) { return "docker compose" }
    }
    catch {}
    return "docker-compose"
}

$compose = Get-ComposeCommand

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    if (-not $Silent) {
        if ($NoNewline) {
            Write-Host $Message -ForegroundColor $Color -NoNewline
        }
        else {
            Write-Host $Message -ForegroundColor $Color
        }
    }
}

function Test-HttpEndpoint {
    param(
        [string]$Name,
        [string]$Url,
        [hashtable]$Headers = @{},
        [int]$TimeoutSec = 5
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec -UseBasicParsing -Headers $Headers -ErrorAction Stop
        
        $result = @{
            Name         = $Name
            Status       = "healthy"
            StatusCode   = $response.StatusCode
            ResponseTime = 0
            Url          = $Url
        }

        if ($Detailed) {
            Write-ColorOutput "  ✅ $Name [$($response.StatusCode)] - $Url" "Green"
        }
        else {
            Write-ColorOutput "  ✅ $Name" "Green"
        }

        return $result
    }
    catch {
        $result = @{
            Name         = $Name
            Status       = "unhealthy"
            StatusCode   = 0
            ResponseTime = 0
            Url          = $Url
            Error        = $_.Exception.Message
        }

        if ($Detailed) {
            Write-ColorOutput "  ❌ $Name [FAILED] - $Url" "Red"
            Write-ColorOutput "     Error: $($_.Exception.Message)" "DarkRed"
        }
        else {
            Write-ColorOutput "  ❌ $Name" "Red"
        }

        return $result
    }
}

function Test-ContainerHealth {
    try {
        $containers = Invoke-Expression "$compose ps --format json" 2>$null | ConvertFrom-Json
        
        if (-not $containers) {
            return @{
                running    = 0
                healthy    = 0
                unhealthy  = 0
                total      = 0
                containers = @()
            }
        }

        $total = $containers.Count
        $running = ($containers | Where-Object { $_.State -eq "running" }).Count
        $healthy = ($containers | Where-Object { $_.Health -eq "healthy" }).Count
        
        return @{
            running    = $running
            healthy    = $healthy
            unhealthy  = $total - $healthy
            total      = $total
            containers = $containers
        }
    }
    catch {
        return @{
            running    = 0
            healthy    = 0
            unhealthy  = 0
            total      = 0
            containers = @()
            error      = $_.Exception.Message
        }
    }
}

function Test-DatabaseConnection {
    try {
        if (-not (Test-Path "./secrets/db_password.txt")) {
            return @{ status = "skipped"; reason = "No password file" }
        }

        $password = Get-Content "./secrets/db_password.txt" -Raw
        $null = Invoke-Expression "$compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P `"$password`" -Q `"SELECT 1`" -C -b" 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  ✅ SQL Server" "Green"
            return @{ status = "healthy" }
        }
        else {
            Write-ColorOutput "  ❌ SQL Server" "Red"
            return @{ status = "unhealthy" }
        }
    }
    catch {
        Write-ColorOutput "  ❌ SQL Server" "Red"
        return @{ status = "unhealthy"; error = $_.Exception.Message }
    }
}

function Get-HealthReport {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    if (-not $Silent) {
        Write-ColorOutput "`n🏥 Health Check - $ProjectName" "Cyan"
        Write-ColorOutput "Time: $timestamp" "Gray"
        Write-ColorOutput ("=" * 60)
    }

    $report = @{
        timestamp = $timestamp
        project   = $ProjectName
        checks    = @{}
    }

    # ✅ 1. Docker Engine
    if (-not $Silent) { Write-ColorOutput "`n🐳 Docker:" "Yellow" }
    try {
        docker version | Out-Null 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  ✅ Docker Engine" "Green"
            $report.checks["docker"] = @{ status = "healthy" }
        }
        else {
            Write-ColorOutput "  ❌ Docker not running" "Red"
            $report.checks["docker"] = @{ status = "unhealthy" }
            return $report
        }
    }
    catch {
        Write-ColorOutput "  ❌ Docker not running" "Red"
        $report.checks["docker"] = @{ status = "unhealthy" }
        return $report
    }

    # ✅ 2. Containers
    if (-not $Silent) { Write-ColorOutput "`n📦 Containers:" "Yellow" }
    $containerHealth = Test-ContainerHealth
    $report.checks["containers"] = $containerHealth

    if ($containerHealth.total -gt 0) {
        Write-ColorOutput "  Running: $($containerHealth.running)/$($containerHealth.total)" "Cyan"
        if ($containerHealth.healthy -gt 0) {
            Write-ColorOutput "  Healthy: $($containerHealth.healthy)" "Green"
        }
        if ($containerHealth.unhealthy -gt 0) {
            Write-ColorOutput "  Unhealthy: $($containerHealth.unhealthy)" "Red"
        }
    }
    else {
        Write-ColorOutput "  ⚠️  No containers running" "Yellow"
    }

    # ✅ 3. Database
    if (-not $Silent) { Write-ColorOutput "`n🗄️  Database:" "Yellow" }
    $report.checks["database"] = Test-DatabaseConnection

    # ✅ 4. HTTP Services
    if (-not $Silent) { Write-ColorOutput "`n🌐 HTTP Services:" "Yellow" }
    
    $httpChecks = @()
    
    # Backend - lightweight health check
    $httpChecks += Test-HttpEndpoint "Backend API" "$BackendUrl/health"
    
    # Backend Ready check
    if ($Detailed) {
        $httpChecks += Test-HttpEndpoint "Backend (Ready)" "$BackendUrl/health/ready"
    }
    
    # Nginx
    $httpChecks += Test-HttpEndpoint "Nginx" "$NginxUrl/health"
    
    # Vite Dev
    $httpChecks += Test-HttpEndpoint "Vite Dev" $ViteUrl

    # GraphQL
    try {
        $body = '{"query":"{ __typename }"}'
        $headers = @{
            "Content-Type"          = "application/json"
            "X-Allow-Introspection" = "true"
        }
        
        $null = Invoke-RestMethod -Uri $GraphQLUrl -Method Post -Body $body -Headers $headers -TimeoutSec 5 -ErrorAction Stop
        
        Write-ColorOutput "  ✅ GraphQL Endpoint" "Green"
        $httpChecks += @{
            Name   = "GraphQL"
            Status = "healthy"
            Url    = $GraphQLUrl
        }
    }
    catch {
        Write-ColorOutput "  ❌ GraphQL Endpoint" "Red"
        $httpChecks += @{
            Name   = "GraphQL"
            Status = "unhealthy"
            Url    = $GraphQLUrl
            Error  = $_.Exception.Message
        }
    }

    $report.checks["http"] = $httpChecks

    # ✅ 5. Summary
    $healthyCount = ($httpChecks | Where-Object { $_.Status -eq "healthy" }).Count
    $totalCount = $httpChecks.Count + 1  # +1 for database
    
    if ($report.checks["database"].status -eq "healthy") {
        $healthyCount++
    }

    $healthPercent = [math]::Round(($healthyCount / $totalCount) * 100)

    $summaryColor = if ($healthPercent -eq 100) { "Green" }
    elseif ($healthPercent -ge 70) { "Yellow" }
    else { "Red" }

    if (-not $Silent) {
        Write-ColorOutput "`n📊 Summary:" "Yellow"
        Write-ColorOutput "  Services: $healthyCount/$totalCount healthy ($healthPercent%)" $summaryColor
    }

    $report["summary"] = @{
        healthy = $healthyCount
        total   = $totalCount
        percent = $healthPercent
        status  = if ($healthPercent -eq 100) { "healthy" } 
        elseif ($healthPercent -ge 70) { "degraded" } 
        else { "unhealthy" }
    }

    return $report
}

# ✅ Main Execution
do {
    $report = Get-HealthReport

    if ($Json) {
        $report | ConvertTo-Json -Depth 10
    }

    if ($Continuous) {
        if (-not $Silent) {
            Write-ColorOutput "`n⏳ Next check in $Interval seconds (Ctrl+C to stop)" "Gray"
        }
        Start-Sleep $Interval
        Clear-Host
    }
} while ($Continuous)

# ✅ Exit code based on health
if ($report.summary.status -eq "healthy") {
    exit 0
}
elseif ($report.summary.status -eq "degraded") {
    exit 1
}
else {
    exit 2
}