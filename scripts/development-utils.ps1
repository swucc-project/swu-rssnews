# development-utils.ps1
# Development tools and utilities

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('shell','db','migrate','seed','generate-proto','generate-graphql','test')]
    [string]$Tool,
    
    [Parameter(Mandatory=$false)]
    [string]$Service = "aspdotnetweb",
    
    [Parameter(Mandatory=$false)]
    [string]$Command
)

$ProjectName = "swu-rssnews"

Write-Host "`n🔧 Dev Tools - $ProjectName" -ForegroundColor Cyan
Write-Host "=" * 60

switch ($Tool) {
    'shell' {
        # Open shell in container
        Write-Host "🐚 Opening shell in $Service..." -ForegroundColor Yellow
        
        if ($Service -eq "mssql") {
            $password = Get-Content "./secrets/db_password.txt"
            docker-compose exec $Service /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$password" -C
        } else {
            docker-compose exec $Service /bin/bash
        }
    }
    
    'db' {
        # Database operations
        Write-Host "🗄️  Opening SQL Server..." -ForegroundColor Yellow
        $password = Get-Content "./secrets/db_password.txt"
        docker-compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$password" -C
    }
    
    'migrate' {
        # Run EF migrations
        Write-Host "🔄 Running migrations..." -ForegroundColor Yellow
        docker-compose run --rm migration-db
    }
    
    'seed' {
        # Seed database
        Write-Host "🌱 Seeding database..." -ForegroundColor Yellow
        docker-compose exec aspdotnetweb dotnet run --project /app/aspnetcore/SeedData.csproj
    }
    
    'generate-proto' {
        # Generate gRPC code
        Write-Host "📝 Generating gRPC code..." -ForegroundColor Yellow
        docker-compose exec frontend npm run generate:proto
    }
    
    'generate-graphql' {
        # Generate GraphQL types
        Write-Host "📝 Generating GraphQL types..." -ForegroundColor Yellow
        docker-compose exec frontend npm run generate:graphql
    }
    
    'test' {
        # Run tests
        Write-Host "🧪 Running tests..." -ForegroundColor Yellow
        
        if ($Command) {
            docker-compose exec $Service $Command
        } else {
            docker-compose exec aspdotnetweb dotnet test
            docker-compose exec frontend npm test
        }
    }
}

Write-Host "`n✅ Done" -ForegroundColor Green