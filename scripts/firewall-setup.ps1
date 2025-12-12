# firewall-setup.ps1
# PowerShell Script สำหรับจัดการ Firewall Rules

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Enable','Disable','Remove','Status')]
    [string]$Action = 'Enable',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Development','Production','All')]
    [string]$Environment = 'Development'
)

# ตรวจสอบสิทธิ์ Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "❌ ต้องรันสคริปต์นี้ในโหมด Administrator"
    exit 1
}

# กำหนด Port Mappings
$DevPorts = @{
    "ASP.NET Core API" = 5000
    "Vite Dev Server" = 5173
    "Nginx Dev HTTP" = 8080
    "SSR Server" = 13714
    "Vite HMR WebSocket" = 24678
    "SQL Server (Localhost)" = 1433
    "OpenSSH Server" = 22
}

$ProdPorts = @{
    "Nginx HTTP" = 80
    "Nginx HTTPS" = 443
}

function Enable-FirewallRules {
    param($Ports, $Profile = "Domain,Private")
    
    foreach ($name in $Ports.Keys) {
        $port = $Ports[$name]
        $ruleName = "Docker - $name"
        
        Write-Host "🔧 สร้าง rule: $ruleName (Port $port)" -ForegroundColor Cyan
        
        # ลบ rule เก่า (ถ้ามี)
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        # สร้าง rule ใหม่
        $params = @{
            DisplayName = $ruleName
            Direction = "Inbound"
            LocalPort = $port
            Protocol = "TCP"
            Action = "Allow"
            Profile = $Profile
            Enabled = $true
        }
        
        # เพิ่มเงื่อนไขพิเศษสำหรับ SQL Server
        if ($name -like "*SQL Server*") {
            $params['RemoteAddress'] = "127.0.0.1,::1,LocalSubnet"
        }
        
        New-NetFirewallRule @params | Out-Null
        Write-Host "✅ สร้างสำเร็จ" -ForegroundColor Green
    }
}

function Disable-FirewallRules {
    param($Ports)
    
    foreach ($name in $Ports.Keys) {
        $ruleName = "Docker - $name"
        Write-Host "⏸️  ปิดการใช้งาน: $ruleName" -ForegroundColor Yellow
        Disable-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    }
}

function Remove-FirewallRules {
    param($Ports)
    
    foreach ($name in $Ports.Keys) {
        $ruleName = "Docker - $name"
        Write-Host "🗑️  ลบ rule: $ruleName" -ForegroundColor Red
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    }
}

function Show-FirewallStatus {
    Write-Host "`n📊 Firewall Rules Status" -ForegroundColor Magenta
    Write-Host "=" * 80 -ForegroundColor Gray
    
    Get-NetFirewallRule | Where-Object {$_.DisplayName -like "Docker -*"} | 
        Select-Object DisplayName, Enabled, Direction, Action, 
            @{Name='Port';Expression={(Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_).LocalPort}} |
        Format-Table -AutoSize
}

# Main Logic
switch ($Action) {
    'Enable' {
        Write-Host "`n🚀 กำลังเปิด Firewall Rules..." -ForegroundColor Green
        
        if ($Environment -eq 'Development' -or $Environment -eq 'All') {
            Write-Host "`n📦 Development Environment" -ForegroundColor Cyan
            Enable-FirewallRules -Ports $DevPorts -Profile "Domain,Private"
        }
        
        if ($Environment -eq 'Production' -or $Environment -eq 'All') {
            Write-Host "`n🏭 Production Environment" -ForegroundColor Cyan
            Enable-FirewallRules -Ports $ProdPorts -Profile "Domain,Private,Public"
        }
        
        Write-Host "`n✅ เสร็จสิ้น!`n" -ForegroundColor Green
    }
    
    'Disable' {
        Write-Host "`n⏸️  กำลังปิดการใช้งาน Firewall Rules..." -ForegroundColor Yellow
        
        if ($Environment -eq 'Development' -or $Environment -eq 'All') {
            Disable-FirewallRules -Ports $DevPorts
        }
        if ($Environment -eq 'Production' -or $Environment -eq 'All') {
            Disable-FirewallRules -Ports $ProdPorts
        }
        
        Write-Host "`n✅ เสร็จสิ้น!`n" -ForegroundColor Yellow
    }
    
    'Remove' {
        Write-Host "`n🗑️  กำลังลบ Firewall Rules..." -ForegroundColor Red
        
        if ($Environment -eq 'Development' -or $Environment -eq 'All') {
            Remove-FirewallRules -Ports $DevPorts
        }
        if ($Environment -eq 'Production' -or $Environment -eq 'All') {
            Remove-FirewallRules -Ports $ProdPorts
        }
        
        Write-Host "`n✅ เสร็จสิ้น!`n" -ForegroundColor Red
    }
    
    'Status' {
        Show-FirewallStatus
    }
}