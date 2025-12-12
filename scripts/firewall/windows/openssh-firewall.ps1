# openssh-firewall.ps1
# Configure Windows Firewall for OpenSSH

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Enable','Disable','Remove','Status')]
    [string]$Action = 'Enable',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Strict','Medium','Permissive')]
    [string]$SecurityLevel = 'Medium',
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 22
)

# ตรวจสอบสิทธิ์ Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "❌ Requires Administrator privileges"
    exit 1
}

$RuleName = "Docker - OpenSSH"

function Enable-SSHFirewallRule {
    param(
        [string]$Level,
        [int]$PortNumber
    )
    
    Write-Host "`n🔧 Configuring OpenSSH Firewall Rule..." -ForegroundColor Cyan
    Write-Host "Security Level: $Level" -ForegroundColor Yellow
    Write-Host "Port: $PortNumber" -ForegroundColor Yellow
    
    # ลบ rule เก่า (ถ้ามี)
    Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    
    # กำหนดพารามิเตอร์ตามระดับความปลอดภัย
    $params = @{
        DisplayName = $RuleName
        Direction = "Inbound"
        LocalPort = $PortNumber
        Protocol = "TCP"
        Action = "Allow"
        Enabled = $true
    }
    
    switch ($Level) {
        'Strict' {
            # เฉพาะ localhost เท่านั้น
            $params['Profile'] = "Domain,Private"
            $params['RemoteAddress'] = "127.0.0.1", "::1"
            $params['Description'] = "Allow SSH from localhost only (Strict)"
            Write-Host "🔒 Mode: Localhost only" -ForegroundColor Green
        }
        
        'Medium' {
            # เฉพาะ Local Subnet
            $params['Profile'] = "Domain,Private"
            $params['RemoteAddress'] = "LocalSubnet"
            $params['Description'] = "Allow SSH from local network only (Medium)"
            Write-Host "🔒 Mode: Local network only" -ForegroundColor Yellow
        }
        
        'Permissive' {
            # ทุก network (⚠️ ไม่แนะนำสำหรับ production)
            $params['Profile'] = "Domain,Private,Public"
            $params['Description'] = "Allow SSH from any network (Permissive - Use with caution)"
            Write-Host "⚠️  Mode: All networks (NOT RECOMMENDED)" -ForegroundColor Red
        }
    }
    
    # สร้าง rule
    try {
        New-NetFirewallRule @params | Out-Null
        Write-Host "✅ OpenSSH firewall rule created successfully" -ForegroundColor Green
        
        # แสดงรายละเอียด
        Show-SSHFirewallStatus
        
    } catch {
        Write-Host "❌ Failed to create rule: $_" -ForegroundColor Red
        exit 1
    }
}

function Disable-SSHFirewallRule {
    Write-Host "`n⏸️  Disabling OpenSSH firewall rule..." -ForegroundColor Yellow
    
    try {
        Disable-NetFirewallRule -DisplayName $RuleName -ErrorAction Stop
        Write-Host "✅ Rule disabled" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Rule not found or already disabled" -ForegroundColor Yellow
    }
}

function Remove-SSHFirewallRule {
    Write-Host "`n🗑️  Removing OpenSSH firewall rule..." -ForegroundColor Red
    
    try {
        Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction Stop
        Write-Host "✅ Rule removed" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Rule not found" -ForegroundColor Yellow
    }
}

function Show-SSHFirewallStatus {
    Write-Host "`n📊 OpenSSH Firewall Status" -ForegroundColor Magenta
    Write-Host "=" * 80
    
    $rule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    
    if ($rule) {
        Write-Host "`n✅ Rule exists" -ForegroundColor Green
        
        # แสดงรายละเอียด
        $rule | Select-Object DisplayName, Enabled, Direction, Action, Profile | Format-List
        
        # แสดง Port และ Remote Address
        $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
        $addressFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule
        
        Write-Host "`n📋 Rule Details:" -ForegroundColor Cyan
        Write-Host "  Local Port: $($portFilter.LocalPort)" -ForegroundColor White
        Write-Host "  Protocol: $($portFilter.Protocol)" -ForegroundColor White
        Write-Host "  Remote Address: $($addressFilter.RemoteAddress)" -ForegroundColor White
        
        # แสดงคำเตือนถ้าเปิด Public profile
        if ($rule.Profile -match "Public") {
            Write-Host "`n⚠️  WARNING: Rule is enabled for Public networks!" -ForegroundColor Red
            Write-Host "   This may pose a security risk." -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "`n❌ No OpenSSH firewall rule found" -ForegroundColor Red
    }
    
    # แสดง SSH service status (ถ้ามี)
    Write-Host "`n🔍 OpenSSH Service Status:" -ForegroundColor Cyan
    try {
        $sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
        if ($sshService) {
            Write-Host "  Service: $($sshService.DisplayName)" -ForegroundColor White
            Write-Host "  Status: $($sshService.Status)" -ForegroundColor $(if($sshService.Status -eq 'Running'){'Green'}else{'Yellow'})
            Write-Host "  Start Type: $($sshService.StartType)" -ForegroundColor White
        } else {
            Write-Host "  ⚠️  OpenSSH service not installed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️  Cannot check SSH service status" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Test-SSHConnection {
    Write-Host "`n🧪 Testing SSH connectivity..." -ForegroundColor Cyan
    
    # ทดสอบว่า port 22 เปิดอยู่หรือไม่
    try {
        $connection = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction SilentlyContinue
        
        if ($connection.TcpTestSucceeded) {
            Write-Host "✅ Port $Port is open and accepting connections" -ForegroundColor Green
        } else {
            Write-Host "❌ Port $Port is not responding" -ForegroundColor Red
            Write-Host "💡 Make sure OpenSSH server is running" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Cannot test connection: $_" -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "`n🔐 OpenSSH Firewall Configuration" -ForegroundColor Cyan
Write-Host "=" * 80

switch ($Action) {
    'Enable' {
        Enable-SSHFirewallRule -Level $SecurityLevel -PortNumber $Port
        Test-SSHConnection
    }
    
    'Disable' {
        Disable-SSHFirewallRule
    }
    
    'Remove' {
        Remove-SSHFirewallRule
    }
    
    'Status' {
        Show-SSHFirewallStatus
        Test-SSHConnection
    }
}

Write-Host "`n💡 Tips:" -ForegroundColor Cyan
Write-Host "  To change security level, run:" -ForegroundColor Gray
Write-Host "    .\openssh-firewall.ps1 -Action Enable -SecurityLevel Strict" -ForegroundColor White
Write-Host "  To use custom port:" -ForegroundColor Gray
Write-Host "    .\openssh-firewall.ps1 -Action Enable -Port 2222" -ForegroundColor White
Write-Host ""