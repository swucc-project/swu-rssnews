# docker-cleanup.ps1
# Optimized for swu-rssnews project

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Quick','Safe','Full','Reset')]
    [string]$Mode = 'Safe',
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepData,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ProjectName = "swu-rssnews"

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`n$Message" -ForegroundColor $Color
}

function Confirm-Cleanup {
    param([string]$Message)
    if ($Force) { return $true }
    $response = Read-Host "$Message (yes/no)"
    return ($response -eq "yes")
}

Write-Host "`n🧹 Docker Cleanup - $ProjectName" -ForegroundColor Cyan
Write-Host "=" * 60

# แสดง disk usage ก่อน
Write-Step "📊 Disk Usage (Before):" "Yellow"
docker system df

switch ($Mode) {
    'Quick' {
        # ลบเฉพาะสิ่งที่ปลอดภัย
        Write-Step "🗑️  Quick Cleanup (ปลอดภัย)" "Green"
        
        docker container prune -f
        docker image prune -f
        docker network prune -f
        
        Write-Host "✅ Quick cleanup เสร็จสิ้น" -ForegroundColor Green
    }
    
    'Safe' {
        # ลบทุกอย่างยกเว้น volumes
        Write-Step "🗑️  Safe Cleanup (เก็บข้อมูล)" "Yellow"
        
        if (Confirm-Cleanup "ลบ containers, images และ networks ที่ไม่ใช้งาน?") {
            # Stop containers
            docker-compose -f docker-compose.yml -f docker-compose.override.yml down
            
            # Clean up
            docker container prune -f
            docker image prune -a -f
            docker network prune -f
            docker builder prune -f
            
            Write-Host "✅ Safe cleanup เสร็จสิ้น (เก็บ volumes ไว้)" -ForegroundColor Green
        }
    }
    
    'Full' {
        # ลบทุกอย่างรวม volumes (ถ้าไม่ใช้ -KeepData)
        Write-Step "⚠️  Full Cleanup" "Red"
        
        if (!$KeepData) {
            Write-Host "⚠️  WARNING: จะลบข้อมูลใน volumes ด้วย!" -ForegroundColor Red
        }
        
        if (Confirm-Cleanup "ลบทุกอย่าง $(if(!$KeepData){'รวมข้อมูล'})?") {
            # Stop และลบทุกอย่าง
            docker-compose -f docker-compose.yml -f docker-compose.override.yml down
            
            if ($KeepData) {
                # ลบทุกอย่างยกเว้น external volumes
                docker container prune -f
                docker image prune -a -f
                
                # ลบเฉพาะ volumes ที่ไม่ใช่ external
                docker volume ls --format "{{.Name}}" | 
                    Where-Object { $_ -match "$ProjectName" -and $_ -notmatch "rssdata|db-backups|rssdata-logs" } |
                    ForEach-Object { docker volume rm $_ 2>$null }
                
                docker network prune -f
                docker builder prune -f
                
                Write-Host "✅ Full cleanup เสร็จสิ้น (เก็บข้อมูลสำคัญ)" -ForegroundColor Green
            } else {
                # ลบทุกอย่างรวม volumes
                docker system prune -a --volumes -f
                
                Write-Host "✅ Full cleanup เสร็จสิ้น (ลบทุกอย่าง)" -ForegroundColor Red
            }
        }
    }
    
    'Reset' {
        # Reset โปรเจคเหมือนใหม่
        Write-Step "🔄 Reset Project (เหมือนติดตั้งใหม่)" "Magenta"
        
        Write-Host "⚠️  การดำเนินการนี้จะ:" -ForegroundColor Yellow
        Write-Host "   1. หยุดและลบทุก containers" -ForegroundColor Yellow
        Write-Host "   2. ลบทุก images ของโปรเจค" -ForegroundColor Yellow
        Write-Host "   3. ลบทุก volumes (รวมข้อมูล)" -ForegroundColor Red
        Write-Host "   4. ลบทุก networks" -ForegroundColor Yellow
        Write-Host "   5. ลบ build cache" -ForegroundColor Yellow
        
        if (Confirm-Cleanup "⚠️  Reset โปรเจคทั้งหมด? พิมพ์ 'yes' เพื่อยืนยัน") {
            # 1. Stop และลบ containers
            Write-Step "1/5 Stopping containers..." "Yellow"
            docker-compose down -v
            
            # 2. ลบ images
            Write-Step "2/5 Removing images..." "Yellow"
            docker images | Select-String "$ProjectName" | ForEach-Object {
                $imageId = ($_ -split '\s+')
                docker rmi -f $imageId 2>$null
            }
            
            # 3. ลบ volumes ทั้งหมด
            Write-Step "3/5 Removing volumes..." "Red"
            docker volume ls --format "{{.Name}}" | 
                Where-Object { $_ -match "$ProjectName" } |
                ForEach-Object { docker volume rm $_ 2>$null }
            
            # 4. ลบ networks
            Write-Step "4/5 Removing networks..." "Yellow"
            docker network ls --format "{{.Name}}" |
                Where-Object { $_ -match "$ProjectName" } |
                ForEach-Object { docker network rm $_ 2>$null }
            
            # 5. ลบ build cache
            Write-Step "5/5 Removing build cache..." "Yellow"
            docker builder prune -af
            
            Write-Host "`n✅ Reset เสร็จสิ้น! โปรเจคพร้อมสำหรับการติดตั้งใหม่" -ForegroundColor Green
            Write-Host "`n💡 ขั้นตอนต่อไป:" -ForegroundColor Cyan
            Write-Host "   1. สร้าง external volumes: docker volume create swu-rssnews_rssdata" -ForegroundColor Gray
            Write-Host "   2. Run setup: docker-compose --profile setup up" -ForegroundColor Gray
            Write-Host "   3. Start: docker-compose up -d" -ForegroundColor Gray
        }
    }
}

# แสดง disk usage หลัง
Write-Step "📊 Disk Usage (After):" "Yellow"
docker system df

Write-Host "`n" -NoNewline