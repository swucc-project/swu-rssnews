# firewall-advanced.ps1
# Advanced Windows Firewall configuration with logging and monitoring

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Enable', 'Disable', 'Monitor', 'Export', 'Import')]
    [string]$Action = 'Enable',
    
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = ".\firewall-backup.json"
)

# ตรวจสอบสิทธิ์
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "❌ Requires Administrator privileges"
    exit 1
}

# Port configurations
$DevPorts = @{
    "ASP.NET Core API"   = @{
        Port     = 5000 
        Protocol = "TCP"
        Profile  = @("Domain", "Private")
    }
    "Vite Dev Server"    = @{
        Port     = 5173
        Protocol = "TCP"
        Profile  = @("Domain", "Private")
    }
    "Nginx Dev HTTP"     = @{
        Port     = 8080
        Protocol = "TCP"
        Profile  = @("Domain", "Private")
    }
    "Vite HMR WebSocket" = @{
        Port     = 24678
        Protocol = "TCP"
        Profile  = @("Domain", "Private")
    }
    "SQL Server"         = @{
        Port          = 1433
        Protocol      = "TCP"
        Profile       = @("Domain", "Private")
        RemoteAddress = @("127.0.0.1,::1,LocalSubnet")
    }
    "OpenSSH Server"     = @{
        Port          = 22
        Protocol      = "TCP"
        Profile       = @("Domain", "Private")
        RemoteAddress = "LocalSubnet"
    }
}

function Enable-AdvancedRules {
    Write-Host "`n🔧 Creating advanced firewall rules..." -ForegroundColor Cyan
    
    foreach ($name in $DevPorts.Keys) {
        $config = $DevPorts[$name]
        $ruleName = "Docker - $name"
        
        # Remove old rule
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        # Create new rule with logging
        $params = @{
            DisplayName = $ruleName
            Direction   = "Inbound"
            LocalPort   = $config.Port
            Protocol    = $config.Protocol
            Action      = "Allow"
            Profile     = $config.Profile
            Enabled     = $true
        }
        
        # Add remote address restriction if specified
        if ($config.RemoteAddress) {
            $params['RemoteAddress'] = $config.RemoteAddress
        }
        
        # Create rule
        New-NetFirewallRule @params
        
        # Enable logging for this rule (requires Group Policy or manual configuration)
        Write-Host "✅ Created: $ruleName (Port $($config.Port))" -ForegroundColor Green
    }
    
    # Enable firewall logging
    Set-NetFirewallProfile -All `
        -LogAllowed $true `
        -LogBlocked $true `
        -LogMaxSizeKilobytes 4096
    
    Write-Host "`n✅ Advanced rules configured with logging enabled" -ForegroundColor Green
}

function Export-FirewallRules {
    param([string]$Path)
    
    Write-Host "`n💾 Exporting firewall rules..." -ForegroundColor Cyan
    
    $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Docker -*" } | 
    Select-Object DisplayName, Enabled, Direction, Action, Profile, @{
        Name       = 'Port'
        Expression = {
            (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_ |
            Select-Object -ExpandProperty LocalPort) -join ","
        }
    }, @{
        Name       = 'Protocol'
        Expression = {
            (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_ |
            Select-Object -ExpandProperty Protocol) -join ","
        }
    }
    
    $rules | ConvertTo-Json | Out-File -FilePath $Path -Encoding UTF8
    
    Write-Host "✅ Exported to: $Path" -ForegroundColor Green
}

function Import-FirewallRules {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error "❌ File not found: $Path"
        return
    }
    
    Write-Host "`n📥 Importing firewall rules..." -ForegroundColor Cyan
    
    $rules = Get-Content -Path $Path | ConvertFrom-Json
    
    foreach ($rule in $rules) {
        $params = @{
            DisplayName = $rule.DisplayName
            Direction   = $rule.Direction
            LocalPort   = $rule.Port -split ","
            Protocol    = $rule.Protocol
            Action      = $rule.Action
            Profile     = $rule.Profile
            Enabled     = $rule.Enabled
        }
        
        Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
        New-NetFirewallRule @params | Out-Null
        
        Write-Host "✅ Imported: $($rule.DisplayName)" -ForegroundColor Green
    }
}

function Show-FirewallMonitoring {
    Write-Host "`n📊 Firewall Monitoring" -ForegroundColor Magenta
    Write-Host "=" * 80
    
    # Show firewall profile status
    Write-Host "`n🔒 Firewall Profiles:" -ForegroundColor Yellow
    Get-NetFirewallProfile | Select-Object Name, Enabled, LogAllowed, LogBlocked, LogFileName | Format-Table -AutoSize
    
    # Show Docker rules
    Write-Host "`n📋 Docker Rules:" -ForegroundColor Yellow
    Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Docker -*" } | 
    Select-Object DisplayName, Enabled, Direction, Action | Format-Table -AutoSize
    
    # Show recent blocked connections (from log file)
    $logPath = "C:\Windows\System32\LogFiles\Firewall\pfirewall.log"
    if (Test-Path $logPath) {
        Write-Host "`n🚫 Recent Blocked Connections (last 10):" -ForegroundColor Yellow
        Get-Content $logPath -Tail 10 | Where-Object { $_ -match "DROP" } | Format-Table -AutoSize
    }
}

# Main execution
switch ($Action) {
    'Enable' {
        Enable-AdvancedRules
    }
    
    'Disable' {
        Write-Host "`n⏸️  Disabling firewall..." -ForegroundColor Yellow
        Set-NetFirewallProfile -All -Enabled False
    }
    
    'Monitor' {
        Show-FirewallMonitoring
    }
    
    'Export' {
        Export-FirewallRules -Path $ExportPath
    }
    
    'Import' {
        Import-FirewallRules -Path $ExportPath
    }
}