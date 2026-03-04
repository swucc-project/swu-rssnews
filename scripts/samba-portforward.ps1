# samba-portforward.ps1
# Samba/SMB Port Forwarding for WSL2
# WARNING: Port 445 conflicts with Windows SMB service

param(
    [Parameter(Mandatory = $false)]
    [string]$DistroName = "rockylinux",
    
    [Parameter(Mandatory = $false)]
    [int]$Port = 445,
    
    [switch]$DisableWindowsSMB,
    
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
    param([string]$Distro)
    
    try {
        # Test if distro is running
        $testOutput = wsl -d $Distro -e echo "test" 2>$null
        
        if ($testOutput -ne "test") {
            throw "Distro not responding"
        }
        
        # Get IP address
        $ipOutput = wsl -d $Distro -e sh -c "ip addr show eth0 | grep 'inet ' | awk '{print `$2}' | cut -d/ -f1" 2>$null
        $validIP = $ipOutput.Trim()
        
        if ($validIP -match '^\d{1,3}(\.\d{1,3}){3}$') {
            return $validIP
        }
        
        return $null
    }
    catch {
        return $null
    }
}

function Test-WindowsSMBService {
    try {
        $service = Get-Service -Name "LanmanServer" -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Stop-WindowsSMBService {
    try {
        Write-Host "🛑 Stopping Windows SMB service..." -ForegroundColor Yellow
        Stop-Service -Name "LanmanServer" -Force
        Set-Service -Name "LanmanServer" -StartupType Disabled
        Write-Host "✅ Windows SMB service stopped and disabled" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Failed to stop SMB service: $_" -ForegroundColor Red
        return $false
    }
}

# ==================== Main Script ====================
Write-Host "`n📁 Samba/SMB Port Forwarding Setup" -ForegroundColor Cyan
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
    netsh interface portproxy show v4tov4 | Select-String "445"
    exit 0
}

# Reset rules
if ($Reset) {
    Write-Host "`n🔄 Removing Samba port forwarding..." -ForegroundColor Yellow
    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 2>$null
    Write-Host "✅ Samba port forwarding removed" -ForegroundColor Green
    exit 0
}

# ==================== Port 445 Warning ====================
if ($Port -eq 445) {
    Write-Host "`n⚠️  WARNING: Port 445 Conflict" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Yellow
    Write-Host "Port 445 is used by Windows SMB/CIFS service." -ForegroundColor White
    Write-Host "This can cause conflicts with:" -ForegroundColor White
    Write-Host "  • Windows File Sharing" -ForegroundColor Gray
    Write-Host "  • Network Discovery" -ForegroundColor Gray
    Write-Host "  • Active Directory" -ForegroundColor Gray
    Write-Host ""
    
    # Check if Windows SMB is running
    if (Test-WindowsSMBService) {
        Write-Host "🔍 Windows SMB service is currently running" -ForegroundColor Red
        Write-Host ""
        
        if ($DisableWindowsSMB) {
            Write-Host "🛑 Attempting to disable Windows SMB..." -ForegroundColor Yellow
            if (-not (Stop-WindowsSMBService)) {
                Write-Host "❌ Cannot proceed with port forwarding" -ForegroundColor Red
                exit 1
            }
        }
        else {
            Write-Host "Options:" -ForegroundColor Cyan
            Write-Host "  1. Stop Windows SMB manually:" -ForegroundColor White
            Write-Host "     Stop-Service -Name LanmanServer -Force" -ForegroundColor Gray
            Write-Host "  2. Run this script with -DisableWindowsSMB" -ForegroundColor White
            Write-Host "  3. Use alternative port (e.g., 1445)" -ForegroundColor White
            Write-Host ""
            
            $response = Read-Host "Continue anyway? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "❌ Aborted by user" -ForegroundColor Red
                exit 1
            }
        }
    }
    else {
        Write-Host "✅ Windows SMB service is not running" -ForegroundColor Green
    }
    
    Write-Host "=" * 60 -ForegroundColor Yellow
}

# ==================== Check WSL Distro ====================
Write-Host "`n🔍 Checking WSL distro: $DistroName" -ForegroundColor Cyan

# Check if distro exists
$distroList = wsl --list --quiet 2>$null | Where-Object { $_.Trim() }
$distroExists = $distroList -contains $DistroName

if (-not $distroExists) {
    Write-Host "❌ Distro '$DistroName' not found" -ForegroundColor Red
    Write-Host "`nAvailable distros:" -ForegroundColor Yellow
    $distroList | ForEach-Object { Write-Host "  • $_" -ForegroundColor Gray }
    exit 1
}

# Check if distro is running
$runningDistros = wsl --list --running --quiet 2>$null | Where-Object { $_.Trim() }
$isRunning = $runningDistros -contains $DistroName

if (-not $isRunning) {
    Write-Host "⚠️  Distro '$DistroName' is not running" -ForegroundColor Yellow
    Write-Host "💡 Starting distro..." -ForegroundColor Gray
    
    try {
        wsl -d $DistroName -e echo "Starting..." | Out-Null
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "❌ Failed to start distro" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ Distro is running" -ForegroundColor Green

# ==================== Get WSL IP ====================
Write-Host "`n🔍 Getting WSL IP address..." -ForegroundColor Cyan

$wslIP = Get-WSLIPAddress -Distro $DistroName

if (-not $wslIP) {
    Write-Host "❌ Cannot detect WSL IP address" -ForegroundColor Red
    Write-Host "💡 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check if WSL network is working: wsl -d $DistroName -e ip addr" -ForegroundColor Gray
    Write-Host "  2. Restart WSL: wsl --shutdown && wsl" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ WSL IP detected: $wslIP" -ForegroundColor Green

# ==================== Setup Port Forwarding ====================
Write-Host "`n🔧 Setting up port forwarding..." -ForegroundColor Cyan

try {
    # Remove existing rule
    Write-Host "  🔄 Removing existing rules..." -ForegroundColor Gray
    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 2>$null | Out-Null
    
    # Add new rule
    Write-Host "  ➕ Adding port forwarding rule..." -ForegroundColor Gray
    netsh interface portproxy add v4tov4 `
        listenport=$Port `
        listenaddress=0.0.0.0 `
        connectport=$Port `
        connectaddress=$wslIP | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Port forwarding configured successfully" -ForegroundColor Green
    }
    else {
        throw "netsh command failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "❌ Failed to setup port forwarding: $_" -ForegroundColor Red
    exit 1
}

# ==================== Verify Configuration ====================
Write-Host "`n📋 Current Configuration:" -ForegroundColor Magenta
Write-Host "  Distro:     $DistroName" -ForegroundColor White
Write-Host "  WSL IP:     $wslIP" -ForegroundColor White
Write-Host "  Port:       $Port" -ForegroundColor White
Write-Host "  Listen:     0.0.0.0:$Port" -ForegroundColor White

Write-Host "`n📋 Active Port Proxy Rules:" -ForegroundColor Magenta
netsh interface portproxy show v4tov4

# ==================== Additional Setup ====================
Write-Host "`n💡 Additional Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure Windows Firewall:" -ForegroundColor White
Write-Host "     New-NetFirewallRule -DisplayName 'Samba' -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Test Samba access:" -ForegroundColor White
Write-Host "     \\localhost\sharename" -ForegroundColor Gray
Write-Host "     \\$(hostname)\sharename" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. View logs in WSL:" -ForegroundColor White
Write-Host "     wsl -d $DistroName -e tail -f /var/log/samba/log.smbd" -ForegroundColor Gray

Write-Host ""