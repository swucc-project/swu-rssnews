# docker-cleanup.ps1
param(
    [ValidateSet('Quick', 'Safe', 'Full', 'Reset')]
    [string]$Mode = 'Safe',
    [switch]$Force
)
$ProjectName = "swu-rssnews"

function Confirm($msg) {
    if ($Force) { return $true }
    (Read-Host "$msg (yes/no)") -eq "yes"
}

$compose = (docker compose version 2>$null) ? "docker compose" : "docker-compose"
Write-Host "`n📦 Cleaning project: $ProjectName" -ForegroundColor Yellow
Write-Host "🧹 Cleanup mode: $Mode" -ForegroundColor Cyan

if ($Mode -eq 'Reset' -and -not (Confirm "⚠️ RESET ALL DATA? This will destroy database volumes!")) {
    return
}

# 1. Stop containers first
Invoke-Expression "$compose down -v"

switch ($Mode) {
    'Quick' {
        docker container prune -f
        docker image prune -f
    }
    'Safe' {
        docker image prune -a -f
        docker network prune -f
    }
    'Full' {
        docker system prune -a -f
    }
    'Reset' {
        # ลบ System objects ทั่วไปก่อน
        docker system prune -a --volumes -f
        
        # ✅ เพิ่มส่วนนี้: ลบ Named Volumes ของโปรเจ็กต์นี้โดยเฉพาะ
        Write-Host "🔥 Removing specific project volumes..." -ForegroundColor Red
        
        # ค้นหา Volume ที่มีชื่อประกอบด้วย ProjectName
        $volumes = docker volume ls -q --filter "name=${ProjectName}"
        
        if ($volumes) {
            foreach ($vol in $volumes) {
                Write-Host "   Removing volume: $vol" -ForegroundColor DarkGray
                try {
                    docker volume rm $vol | Out-Null
                    Write-Host "   ✅ Deleted: $vol" -ForegroundColor Green
                }
                catch {
                    Write-Host "   ❌ Failed to delete: $vol (might be in use)" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "   ℹ️  No project volumes found." -ForegroundColor Gray
        }
    }
}

docker system df