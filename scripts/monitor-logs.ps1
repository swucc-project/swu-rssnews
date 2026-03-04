# monitor-logs.ps1
# Cross-version Docker log monitor with filter & color

param(
    [string]$Service,
    [string]$Filter,
    [ValidateSet('Error', 'Warning', 'Info', 'All')]
    [string]$Level = 'All',
    [int]$Lines = 100,
    [switch]$Follow,
    [switch]$Timestamps
)

function Get-Compose {
    $null = docker compose version 2>$null
    if ($?) { 
        return @("docker", "compose") 
    }
    return @("docker-compose")
}

$compose = Get-Compose

Write-Host "`n📋 Log Monitor - swu-rssnews" -ForegroundColor Cyan
Write-Host "=" * 60

# Build args
$arguments = @("logs")

if ($Lines -gt 0) { $arguments += "--tail=$Lines" }
if ($Follow) { $arguments += "-f" }
if ($Timestamps) { $arguments += "-t" }
if ($Service) { $ += $Service }

Write-Host "Service: " ($Service ?? "All") -ForegroundColor Yellow
if ($Filter) { Write-Host "Filter: $Filter" -ForegroundColor Yellow }
if ($Level -ne 'All') { Write-Host "Level: $Level" -ForegroundColor Yellow }
Write-Host "=" * 60

# Start docker logs process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $compose[0]
$psi.ArgumentList = $compose[1..($compose.Length - 1)] + $args
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$proc.Start() | Out-Null

try {
    while (-not $proc.HasExited) {
        $line = $proc.StandardOutput.ReadLine()
        if (-not $line) { continue }

        $show = $true

        if ($Filter -and $line -notmatch $Filter) { $show = $false }

        if ($Level -ne 'All') {
            switch ($Level) {
                'Error' { if ($line -notmatch '(?i)error|exception|fail') { $show = $false } }
                'Warning' { if ($line -notmatch '(?i)warn') { $show = $false } }
                'Info' { if ($line -notmatch '(?i)info|started|listening') { $show = $false } }
            }
        }

        if ($show) {
            if ($line -match '(?i)error|exception|fail') {
                Write-Host $line -ForegroundColor Red
            }
            elseif ($line -match '(?i)warn') {
                Write-Host $line -ForegroundColor Yellow
            }
            elseif ($line -match '(?i)success|ready|listening') {
                Write-Host $line -ForegroundColor Green
            }
            else {
                Write-Host $line
            }
        }
    }
}
finally {
    if (-not $proc.HasExited) {
        $proc.Kill()
    }
}