# cross-platform-firewall.ps1
# Unified firewall management for Windows + WSL2
# Compatible with firewalld / ufw

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Enable', 'Disable', 'Status', 'Sync')]
    [string]$Action = 'Enable',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Development', 'Production', 'All')]
    [string]$Environment = 'Development'
)

# ------------------------------
# Require Administrator
# ------------------------------
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "❌ This script must be run as Administrator"
    exit 1
}

# ------------------------------
# Check WSL availability
# ------------------------------
function Test-WSLAvailable {
    try {
        $distros = wsl -l -q 2>$null
        return ($distros -and $distros.Count -gt 0)
    }
    catch {
        return $false
    }
}

# ------------------------------
# Detect Linux firewall
# ------------------------------
function Get-LinuxFirewallType {
    if (-not (Test-WSLAvailable)) {
        return $null
    }

    $firewalld = wsl bash -c "command -v firewall-cmd" 2>$null
    if ($firewalld) { return "firewalld" }

    $ufw = wsl bash -c "command -v ufw" 2>$null
    if ($ufw) { return "ufw" }

    return "none"
}

# ------------------------------
# Sync firewall rules
# ------------------------------
function Sync-FirewallRules {

    Write-Host "`n🔄 Synchronizing firewall rules..." -ForegroundColor Cyan

    # --------------------------
    # Windows Firewall
    # --------------------------
    Write-Host "`n🪟 Windows Firewall:" -ForegroundColor Yellow
    & "$PSScriptRoot\firewall\windows\firewall-setup.ps1" `
        -Action Enable `
        -Environment $Environment

    # --------------------------
    # Linux Firewall (WSL2)
    # --------------------------
    if (-not (Test-WSLAvailable)) {
        Write-Host "⚠️  WSL2 not available, skipping Linux firewall" -ForegroundColor Yellow
        return
    }

    $fwType = Get-LinuxFirewallType
    Write-Host "`n🐧 Linux Firewall Detected: $fwType" -ForegroundColor Yellow

    switch ($fwType) {

        "firewalld" {
            $scriptPath = "$PSScriptRoot\firewall\linux\firewalld-setup.sh"
            if (-not (Test-Path $scriptPath)) {
                Write-Host "❌ firewalld-setup.sh not found" -ForegroundColor Red
                return
            }

            $linuxPath = wsl wslpath "$scriptPath"
            wsl chmod +x $linuxPath
            wsl sudo $linuxPath enable $Environment.ToLower()

            Write-Host "✅ firewalld configured" -ForegroundColor Green
        }

        "ufw" {
            Write-Host "⚙ Configuring ufw..." -ForegroundColor Cyan
            wsl sudo ufw allow ssh
            wsl sudo ufw --force enable
            Write-Host "✅ ufw enabled" -ForegroundColor Green
        }

        default {
            Write-Host "⚠️  No supported Linux firewall detected" -ForegroundColor Yellow
        }
    }
}

# ------------------------------
# Show status
# ------------------------------
function Show-CrossPlatformStatus {

    Write-Host "`n📊 Cross-Platform Firewall Status" -ForegroundColor Magenta
    Write-Host ("=" * 80)

    # Windows
    Write-Host "`n🪟 Windows Firewall:" -ForegroundColor Cyan
    & "$PSScriptRoot\firewall\windows\firewall-setup.ps1" -Action Status

    # Linux
    if (-not (Test-WSLAvailable)) {
        Write-Host "`n🐧 Linux Firewall: WSL2 not available" -ForegroundColor Yellow
        return
    }

    $fwType = Get-LinuxFirewallType
    Write-Host "`n🐧 Linux Firewall ($fwType):" -ForegroundColor Cyan

    switch ($fwType) {
        "firewalld" {
            wsl sudo firewall-cmd --list-all
        }
        "ufw" {
            wsl sudo ufw status
        }
        default {
            Write-Host "Not configured" -ForegroundColor Gray
        }
    }
}

# ------------------------------
# Main
# ------------------------------
switch ($Action) {

    'Enable' {
        Sync-FirewallRules
    }

    'Sync' {
        Sync-FirewallRules
    }

    'Disable' {
        Write-Host "`n⏸️  Disabling firewalls..." -ForegroundColor Yellow

        # Windows
        & "$PSScriptRoot\firewall\windows\firewall-setup.ps1" -Action Disable

        # Linux
        if (Test-WSLAvailable) {
            try {
                wsl bash -c "sudo systemctl stop firewalld || true"
                wsl bash -c "sudo ufw disable || true"
            }
            catch {}
        }
    }

    'Status' {
        Show-CrossPlatformStatus
    }
}