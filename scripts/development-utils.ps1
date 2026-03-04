# development-utils.ps1
# Development utilities for swu-rssnews

param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'shell', 'db',
        'migrate', 'seed',
        'generate-proto', 'generate-graphql',
        'test'
    )]
    [string]$Tool,

    [string]$Service = "aspdotnetweb",
    [string]$Command
)

$ProjectName = "swu-rssnews"

function Get-Compose {
    try {
        & docker compose version | Out-Null
        return "docker compose"
    }
    catch {
        return "docker-compose"
    }
}

$compose = Get-Compose

function Test-ServiceRunning {
    param([string]$name)

    $composeArgs = $compose.Split(" ")
    $running = & $composeArgs $composeArgs 'ps' '--services' '--filter' 'status=running'

    if ($running -notcontains $name) {
        Write-Error "❌ Service '$name' is not running"
        exit 1
    }
}

function Get-DbPassword {
    $file = "./secrets/db_password.txt"
    if (-not (Test-Path $file)) {
        Write-Error "❌ DB password file not found: $file"
        exit 1
    }
    return (Get-Content $file -Raw).Trim()
}

Write-Host "`n🔧 Development Utils - $ProjectName" -ForegroundColor Cyan
Write-Host "=" * 60

switch ($Tool) {
    'shell' {
        Test-ServiceRunning $Service
        Write-Host "🐚 Shell → $Service" -ForegroundColor Yellow

        if ($Service -eq "mssql") {
            $db_password = Get-DbPassword
            $cmd = "$compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '{0}' -C" -f $db_password
            & cmd /c $cmd  # หรือใช้ Invoke-Expression $cmd ก็ได้ถ้ามั่นใจ
        }
        else {
            $composeArgs = $compose.Split(" ")
            & $composeArgs $composeArgs 'exec' $Service '/bin/bash'
        }
    }

    'db' {
        Test-ServiceRunning "mssql"
        Write-Host "🗄️ SQL Server Shell" -ForegroundColor Yellow
        $db_password = Get-DbPassword
        $cmd = "$compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '{0}' -C" -f $db_password
        & cmd /c $cmd
    }

    'migrate' {
        Write-Host "🔄 Running DB migrations" -ForegroundColor Yellow
        $composeArgs = $compose.Split(" ")
        & $composeArgs $composeArgs 'run' '--rm' 'migration-db'
    }

    'seed' {
        Test-ServiceRunning "aspdotnetweb"
        Write-Host "🌱 Seeding database" -ForegroundColor Yellow
        $composeArgs = $compose.Split(" ")
        & $composeArgs $composeArgs 'exec' 'aspdotnetweb' 'dotnet' 'run' '--project' '/app/aspnetcore/SeedData.csproj'
    }

    'generate-proto' {
        Test-ServiceRunning "frontend"
        Write-Host "📝 Generating gRPC code" -ForegroundColor Yellow
        $composeArgs = $compose.Split(" ")
        & $composeArgs $composeArgs 'exec' 'frontend' 'npm' 'run' 'generate:proto'
    }

    'generate-graphql' {
        Test-ServiceRunning "frontend"
        Write-Host "📝 Generating GraphQL types" -ForegroundColor Yellow
        $composeArgs = $compose.Split(" ")
        & $composeArgs $composeArgs 'exec' 'frontend' 'npm' 'run' 'generate:graphql'
    }

    'test' {
        Write-Host "🧪 Running tests" -ForegroundColor Yellow

        if ($Command) {
            Test-ServiceRunning $Service
            $composeArgs = $compose.Split(" ")
            & $composeArgs $composeArgs 'exec' $Service $Command
        }
        else {
            Test-ServiceRunning "aspdotnetweb"
            Test-ServiceRunning "frontend"
            $composeArgs = $compose.Split(" ")
            & $composeArgs $composeArgs 'exec' 'aspdotnetweb' 'dotnet' 'test'
            & $composeArgs $composeArgs 'exec' 'frontend' 'npm' 'test'
        }
    }
}

Write-Host "`n✅ Done" -ForegroundColor Green