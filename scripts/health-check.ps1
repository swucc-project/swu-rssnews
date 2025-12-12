# health-check.ps1
# Health check for all services

param(
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [switch]$Continuous,
    
    [Parameter(Mandatory=$false)]
    [int]$Interval = 30
)

$ProjectName = "swu-rssnews"

function Test-ServiceHealth {
    param(
        [string]$Name,
        [string]$Url,
        [string]$ExpectedStatus = "200"
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        
        $status = $response.StatusCode
        $statusColor = if ($status -eq 200) { "Green" } else { "Yellow" }
        
        Write-Host "  ✅ " -ForegroundColor $statusColor -NoNewline
        Write-Host "$Name " -NoNewline
        Write-Host "[$status]" -ForegroundColor $statusColor
        
        if ($Detailed) {
            Write-Host "     URL: $Url" -ForegroundColor Gray
            Write-Host "     Response Time: $($response.Headers.'X-Response-Time')" -ForegroundColor Gray
        }
        
        return $true
    } catch {
        Write-Host "  ❌ $Name " -ForegroundColor Red -NoNewline
        Write-Host "[FAILED]" -ForegroundColor Red
        
        if ($Detailed) {
            Write-Host "     URL: $Url" -ForegroundColor Gray
            Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return $false
    }
}

function Test-SQLServerHealth {
    try {
        $password = Get-Content "./secrets/db_password.txt" -Raw -ErrorAction Stop
        $result = docker-compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$password" -Q "SELECT @@VERSION" -C 2>$null
        
        if ($?) {
            Write-Host "  ✅ SQL Server " -ForegroundColor Green -NoNewline
            Write-Host "[HEALTHY]" -ForegroundColor Green
            
            if ($Detailed) {
                Write-Host "     Version: $($result -split "`n" | Select-Object -First 1)" -ForegroundColor Gray
            }
            
            return $true
        } else {
            throw "Connection failed"
        }
    } catch {
        Write-Host "  ❌ SQL Server " -ForegroundColor Red -NoNewline
        Write-Host "[FAILED]" -ForegroundColor Red
        
        if ($Detailed) {
            Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return $false
    }
}

function Show-HealthCheck {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "`n🏥 Health Check - $ProjectName" -ForegroundColor Cyan
    Write-Host "Time: $timestamp" -ForegroundColor Gray
    Write-Host "=" * 60
    
    # Check Docker
    Write-Host "`n🐳 Docker Status:" -ForegroundColor Yellow
    try {
        docker info | Out-Null
        Write-Host "  ✅ Docker Engine" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Docker Engine [NOT RUNNING]" -ForegroundColor Red
        return
    }
    
    # Check Containers
    Write-Host "`n📦 Containers:" -ForegroundColor Yellow
    $containers = docker-compose ps --format json | ConvertFrom-Json
    
    if ($containers) {
        foreach ($container in $containers) {
            $statusColor = if ($container.State -eq "running") { "Green" } else { "Red" }
            $statusIcon = if ($container.State -eq "running") { "✅" } else { "❌" }
            
            Write-Host "  $statusIcon " -ForegroundColor $statusColor -NoNewline
            Write-Host "$($container.Service) " -NoNewline
            Write-Host "[$($container.State)]" -ForegroundColor $statusColor
            
            if ($Detailed) {
                Write-Host "     Health: $($container.Health)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  ⚠️  No containers running" -ForegroundColor Yellow
    }
    
    # Check Services
    Write-Host "`n🌐 Services:" -ForegroundColor Yellow
    
    $sqlHealthy = Test-SQLServerHealth
    $backendHealthy = Test-ServiceHealth -Name "ASP.NET Core API" -Url "http://localhost:5000/health"
    $nginxHealthy = Test-ServiceHealth -Name "Nginx" -Url "http://localhost:8080/health"
    $viteHealthy = Test-ServiceHealth -Name "Vite Dev Server" -Url "http://localhost:5173"
    $ssrHealthy = Test-ServiceHealth -Name "SSR Server" -Url "http://localhost:13714/health"
    
    # GraphQL
    try {
        $graphqlBody = '{"query":"{ __typename }"}'
        $response = Invoke-RestMethod -Uri "http://localhost:5000/graphql" -Method Post -Body $graphqlBody -ContentType "application/json" -TimeoutSec 5
        Write-Host "  ✅ GraphQL Endpoint" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ GraphQL Endpoint [FAILED]" -ForegroundColor Red
    }
    
    # Summary
    Write-Host "`n📊 Summary:" -ForegroundColor Yellow
    
    $totalServices = 6
    $healthyServices = @($sqlHealthy, $backendHealthy, $nginxHealthy, $viteHealthy, $ssrHealthy).Where({$_}).Count + 1
    
    $healthPercentage = [math]::Round(($healthyServices / $totalServices) * 100)
    $summaryColor = if ($healthPercentage -eq 100) { "Green" } elseif ($healthPercentage -ge 50) { "Yellow" } else { "Red" }
    
    Write-Host "  Services: $healthyServices/$totalServices healthy ($healthPercentage%)" -ForegroundColor $summaryColor
    
    if ($healthPercentage -eq 100) {
        Write-Host "  ✅ All systems operational" -ForegroundColor Green
    } elseif ($healthPercentage -ge 50) {
        Write-Host "  ⚠️  Some services degraded" -ForegroundColor Yellow
    } else {
        Write-Host "  ❌ Critical: Multiple services down" -ForegroundColor Red
    }
    
    Write-Host "`n"
}

# Main execution
do {
    Show-HealthCheck
    
    if ($Continuous) {
        Write-Host "⏳ Next check in $Interval seconds... (Press Ctrl+C to stop)" -ForegroundColor Gray
        Start-Sleep -Seconds $Interval
        Clear-Host
    }
} while ($Continuous)