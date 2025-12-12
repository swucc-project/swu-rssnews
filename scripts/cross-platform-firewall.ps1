# cross-platform-firewall.ps1
# Unified firewall management for Windows + Linux (via WSL2)

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Enable','Disable','Status','Sync')]
    [string]$Action = 'Enable',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Development','Production','All')]
    [string]$Environment = 'Development'
)

function Test-WSLAvailable {
    try {
        $wslStatus = wsl --status 2>&1
        return $?
    } catch {
        return $false
    }
}

function Sync-FirewallRules {
    Write-Host "`n🔄 Synchronizing firewall rules..." -ForegroundColor Cyan
    
    # Configure Windows Firewall
    Write-Host "`n📦 Windows Configuration:" -ForegroundColor Yellow
    & "$PSScriptRoot\firewall\windows\firewall-setup.ps1" -Action Enable -Environment $Environment
    
    # Configure Linux Firewall (if WSL2 available)
    if (Test-WSLAvailable) {
        Write-Host "`n🐧 Linux Configuration:" -ForegroundColor Yellow
        
        # Copy script to WSL
        $scriptPath = "$PSScriptRoot\firewall\linux\firewalld-setup.sh"
        wsl cp "$scriptPath" /tmp/firewalld-setup.sh
        wsl chmod +x /tmp/firewalld-setup.sh
        
        # Execute in WSL
        wsl sudo /tmp/firewalld-setup.sh enable $Environment.ToLower()
        
        Write-Host "✅ Linux firewall configured" -ForegroundColor Green
    } else {
        Write-Host "⚠️  WSL2 not available, skipping Linux configuration" -ForegroundColor Yellow
    }
}

function Show-CrossPlatformStatus {
    Write-Host "`n📊 Cross-Platform Firewall Status" -ForegroundColor Magenta
    Write-Host "=" * 80
    
    # Windows Status
    Write-Host "`n🪟 Windows Firewall:" -ForegroundColor Cyan
    & "$PSScriptRoot\firewall\windows\firewall-setup.ps1" -Action Status
    
    # Linux Status (if available)
    if (Test-WSLAvailable) {
        Write-Host "`n🐧 Linux Firewall:" -ForegroundColor Cyan
        wsl sudo firewall-cmd --list-all 2>/dev/null || Write-Host "Not configured" -ForegroundColor Gray
    }
}

# Main execution
switch ($Action) {
    'Enable' {
        Sync-FirewallRules
    }
    
    'Disable' {
        Write-Host "`n⏸️  Disabling all firewalls..." -ForegroundColor Yellow
        
        # Disable Windows
        & "$PSScriptRoot\firewall\windows\firewall-setup.ps1" -Action Disable
        
        # Disable Linux
        if (Test-WSLAvailable) {
            wsl sudo systemctl stop firewalld 2>/dev/null || true
        }
    }
    
    'Status' {
        Show-CrossPlatformStatus
    }
    
    'Sync' {
        Sync-FirewallRules
    }
}