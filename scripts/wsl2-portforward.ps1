# wsl2-portforward.ps1
# Enhanced WSL2 Port Forwarding with Multi-Distro Support

param(
    [int[]]$Ports = @(5000, 5173, 8080, 1433, 24678),
    
    [switch]$IncludeSSH,
    
    [Parameter(Mandatory = $false)]
    [string]$DistroName = $null,
    
    [switch]$ShowCurrent,
    
    [switch]$Reset
)

$ErrorActionPreference = "Stop"

# ==================== Helper Functions ====================
function Test-AdminPrivileges {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WSLIPAddress {
    param(
        [string]$Distro = $null
    )
    
    try {
        if ($Distro) {
            Write-Host "🔍 Getting IP from distro: $Distro" -ForegroundColor Gray
            $ipOutput = wsl -d $Distro -e sh -c "ip addr show eth0 | grep 'inet ' | awk '{print `$2}' | cut -d/ -f1" 2>$null
        }
        else {
            Write-Host "🔍 Getting IP from default WSL distro" -ForegroundColor Gray
            $ipOutput = (wsl hostname -I).Trim()
        }
        
        # Extract first valid IPv4
        $validIP = $ipOutput.Trim().Split(' ') |
        Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } |
        Select-Object -First 1
        
        if ($validIP) {
            return $validIP.Trim()
        }
        
        return $null
    }
    catch {
        Write-Host "⚠️  Failed to get WSL IP: $_" -ForegroundColor Yellow
        return $null
    }
}

function Test-PortAvailable {
    param([int]$Port)
    
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    }
    catch {
        return $false
    }
}

function Remove-PortProxy {
    param([int]$Port)
    
    netsh interface portproxy delete v4tov4 `
        listenport=$Port `
        listenaddress=0.0.0.0 2>$null | Out-Null
}

function Add-PortProxy {
    param(
        [int]$Port,
        [string]$TargetIP
    )
    
    netsh interface portproxy add v4tov4 `
        listenport=$Port `
        listenaddress=0.0.0.0 `
        connectport=$Port `
        connectaddress=$TargetIP | Out-Null
}

# ==================== Main Script ====================
Write-Host "`n🔗 WSL2 Port Forwarding Setup" -ForegroundColor Cyan
Write-Host "=" * 60

# Check admin privileges
if (-not (Test-AdminPrivileges)) {
    Write-Host "❌ This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "💡 Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Show current rules
if ($ShowCurrent) {
    Write-Host "`n📋 Current Port Proxy Rules:" -ForegroundColor Magenta
    netsh interface portproxy show all
    exit 0
}

# Reset all rules
if ($Reset) {
    Write-Host "`n🔄 Resetting all port proxy rules..." -ForegroundColor Yellow
    netsh interface portproxy reset
    Write-Host "✅ All port proxy rules cleared" -ForegroundColor Green
    exit 0
}

# Check WSL status
Write-Host "`n🔍 Checking WSL status..." -ForegroundColor Cyan
try {
    $null = wsl --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "WSL not available"
    }
}
catch {
    Write-Host "❌ WSL2 is not available or not running" -ForegroundColor Red
    Write-Host "💡 Please ensure WSL2 is installed and running" -ForegroundColor Yellow
    exit 1
}

# Get WSL IP address
$wslIP = Get-WSLIPAddress -Distro $DistroName

if (-not $wslIP) {
    Write-Host "❌ Cannot determine WSL2 IPv4 address" -ForegroundColor Red
    Write-Host "💡 Make sure WSL is running: wsl --list --running" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ WSL2 IPv4: $wslIP" -ForegroundColor Green

# Add SSH port if requested
if ($IncludeSSH) {
    $Ports += 22
    Write-Host "📝 Including SSH port 22" -ForegroundColor Gray
}

# Setup port forwarding
Write-Host "`n🔧 Setting up port forwarding..." -ForegroundColor Cyan
$successCount = 0
$failCount = 0

foreach ($port in $Ports) {
    Write-Host "`n  Port $port" -NoNewline
    
    # Check if port is available on Windows
    if (-not (Test-PortAvailable -Port $port)) {
        Write-Host " ⚠️  Port already in use on Windows" -ForegroundColor Yellow
        $response = Read-Host "    Continue anyway? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "    ⏭️  Skipped" -ForegroundColor Gray
            continue
        }
    }
    
    try {
        # Remove existing rule
        Remove-PortProxy -Port $port
        
        # Add new rule
        Add-PortProxy -Port $port -TargetIP $wslIP
        
        Write-Host " ✅" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host " ❌ Failed: $_" -ForegroundColor Red
        $failCount++
    }
}

# Summary
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "  ✅ Success: $successCount" -ForegroundColor Green
Write-Host "  ❌ Failed:  $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host "  🎯 Target:  $wslIP" -ForegroundColor Cyan

# Show active rules
Write-Host "`n📋 Active Port Proxy Rules:" -ForegroundColor Magenta
netsh interface portproxy show all

Write-Host "`n💡 Tip: Use -ShowCurrent to view rules, -Reset to clear all" -ForegroundColor Gray
Write-Host ""