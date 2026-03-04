# firewall-setup.ps1
# PowerShell Script สำหรับจัดการ Firewall Rules

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Enable', 'Disable', 'Remove', 'Status')]
    [string]$Action = 'Enable',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Development', 'Production', 'All')]
    [string]$Environment = 'Development'
)

# ตรวจสอบสิทธิ์ Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "❌ ต้องรันสคริปต์นี้ในโหมด Administrator"
    exit 1
}

# กำหนด Port Mappings
$DevPorts = @{
    "ASP.NET Core API"       = 5000
    "Vite Dev Server"        = 5173
    "Nginx Dev HTTP"         = 8080
    "Vite HMR WebSocket"     = 24678
    "SQL Server (Localhost)" = 1433
    "OpenSSH Server"         = 22
    "Samba Server"           = 445
}

$ProdPorts = @{
    "Nginx HTTP"  = 80
    "Nginx HTTPS" = 443
}

$SambaOptionalPorts = @{
    "Samba NetBIOS Name Service" = 137
    "Samba Datagram Service"     = 138
    "Samba Session Service"      = 139
}

function Enable-FirewallRules {
    param(
        $Ports,
        [string[]]$Rule = @("Domain", "Private")
    )
    
    foreach ($name in $Ports.Keys) {
        $port = $Ports[$name]
        $ruleName = "Docker - $name"
        
        # ลบ rule เก่า (ถ้ามี)
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

        $protocol = "TCP"
        if ($port -in 137, 138) {
            $protocol = "UDP"
        }
        
        # สร้าง rule ใหม่
        $params = @{
            DisplayName         = $ruleName
            Direction           = "Inbound"
            LocalPort           = $port
            Protocol            = $protocol
            Action              = "Allow"
            Profile             = $Rule
            Enabled             = $true
            EdgeTraversalPolicy = 'Block'
        }
        
        # เพิ่มเงื่อนไขพิเศษสำหรับ SQL Server
        if ($name -like "*SQL Server*") {
            $params['RemoteAddress'] = @("127.0.0.1", "::1", "LocalSubnet")
        }

        # เพิ่มเงื่อนไขพิเศษสำหรับ OpenSSH Server
        if ($name -like "*OpenSSH Server*") {
            $params['RemoteAddress'] = @("127.0.0.1", "::1", "LocalSubnet")
        }
        
        New-NetFirewallRule @params | Out-Null
        Write-Host "✅ $ruleName created" -ForegroundColor Green
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
    
    Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Docker -*" } | 
    Select-Object DisplayName, Enabled, Direction, Action, 
    @{Name         = 'Port';
        Expression = {
            (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_ |
            Select-Object -ExpandProperty LocalPort) -join ","
        } |
        Format-Table -AutoSize
    }
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
        Enable-FirewallRules -Ports $SambaOptionalPorts -Profile "Domain,Private,Public"
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