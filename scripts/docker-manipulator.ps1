
---

## 🎁 **Bonus: All-in-One Script**

สร้างไฟล์ `scripts/docker-manipulator.ps1`:

```powershell
# docker-manager.ps1
# All-in-One Docker Management Script

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('start','stop','restart','clean','reset','status','logs','backup')]
    [string]$Command,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ProjectName = "swu-rssnews"

switch ($Command) {
    'start' {
        Write-Host "🚀 Starting $ProjectName..." -ForegroundColor Green
        docker-compose up -d
    }
    
    'stop' {
        Write-Host "🛑 Stopping $ProjectName..." -ForegroundColor Yellow
        docker-compose down
    }
    
    'restart' {
        Write-Host "🔄 Restarting $ProjectName..." -ForegroundColor Cyan
        docker-compose restart
    }
    
    'clean' {
        & "$PSScriptRoot\docker-cleanup.ps1" -Mode Safe -Force:$Force
    }
    
    'reset' {
        & "$PSScriptRoot\docker-cleanup.ps1" -Mode Reset -Force:$Force
    }
    
    'status' {
        & "$PSScriptRoot\docker-manipulator.ps1" -Action Status
    }
    
    'logs' {
        & "$PSScriptRoot\docker-manipulator.ps1" -Action Logs
    }
    
    'backup' {
        & "$PSScriptRoot\docker-manipulator.ps1" -Action Backup
    }
}