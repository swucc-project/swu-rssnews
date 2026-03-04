# docker.ps1
# Main Docker entrypoint for swu-rssnews

param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'up', 'down', 'restart',
        'status', 'logs',
        'clean', 'reset',
        'rebuild', 'backup'
    )]
    [string]$Command,

    [switch]$Force
)

$ProjectName = "swu-rssnews"

function Compose {
    $null = docker compose version 2>&1
    if ($?) {
        return "docker compose"
    }
    return "docker-compose"
}

$compose = Compose

switch ($Command) {

    'up' {
        Write-Host "🚀 Starting $ProjectName" -ForegroundColor Green
        Invoke-Expression "$compose up -d"
    }

    'down' {
        Write-Host "🛑 Stopping $ProjectName" -ForegroundColor Yellow
        Invoke-Expression "$compose down"
    }

    'restart' {
        Invoke-Expression "$compose restart"
    }

    'status' {
        & "$PSScriptRoot\docker-maintenance.ps1" -Action Status
    }

    'logs' {
        & "$PSScriptRoot\docker-maintenance.ps1" -Action Logs
    }

    'rebuild' {
        & "$PSScriptRoot\docker-maintenance.ps1" -Action Rebuild
    }

    'backup' {
        & "$PSScriptRoot\docker-maintenance.ps1" -Action Backup
    }

    'clean' {
        & "$PSScriptRoot\docker-cleanup.ps1" -Mode Safe -Force:$Force
    }

    'reset' {
        & "$PSScriptRoot\docker-cleanup.ps1" -Mode Reset -Force:$Force
    }
}