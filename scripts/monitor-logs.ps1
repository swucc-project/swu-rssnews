# monitor-logs.ps1
# Advanced log monitoring with filtering

param(
    [Parameter(Mandatory=$false)]
    [string]$Service,
    [Parameter(Mandatory=$false)]
    [string]$Filter,
    [Parameter(Mandatory=$false)]
    [ValidateSet('Error','Warning','Info','All')]
    [string]$Level = 'All',
    [Parameter(Mandatory=$false)]
    [int]$Lines = 100,
    [Parameter(Mandatory=$false)]
    [switch]$Follow,
    [Parameter(Mandatory=$false)]
    [switch]$Timestamps
)

Write-Host "`n📋 Log Monitor - swu-rssnews" -ForegroundColor Cyan
Write-Host "=" * 60

# Build docker-compose logs command
$logCmd = "docker-compose logs"

if ($Lines -gt 0) {
    $logCmd += " --tail=$Lines"
}

if ($Follow) {
    $logCmd += " -f"
}

if ($Timestamps) {
    $logCmd += " -t"
}

if ($Service) {
    $logCmd += " $Service"
    Write-Host "Service: $Service" -ForegroundColor Yellow
} else {
    Write-Host "Service: All" -ForegroundColor Yellow
}

if ($Filter) {
    Write-Host "Filter: $Filter" -ForegroundColor Yellow
}

if ($Level -ne 'All') {
    Write-Host "Level: $Level" -ForegroundColor Yellow
}

Write-Host "=" * 60

# Execute and filter
if ($Filter -or $Level -ne 'All') {
    $process = Start-Process -FilePath "powershell" -ArgumentList "-Command", $logCmd -PassThru -NoNewWindow -RedirectStandardOutput "temp_logs.txt"
    
    Get-Content "temp_logs.txt" -Wait | ForEach-Object {
        $line = $_
        $show = $true
        
        # Filter by search term
        if ($Filter -and $line -notmatch $Filter) {
            $show = $false
        }
        
        # Filter by level
        if ($Level -ne 'All') {
            switch ($Level) {
                'Error' { if ($line -notmatch '\[error\]|\[ERR\]|ERROR|Exception') { $show = $false } }
                'Warning' { if ($line -notmatch '\[warn\]|\[WRN\]|WARNING') { $show = $false } }
                'Info' { if ($line -notmatch '\[info\]|\[INF\]|INFO') { $show = $false } }
            }
        }
        
        if ($show) {
            # Colorize output
            if ($line -match 'error|exception|fail') {
                Write-Host $line -ForegroundColor Red
            } elseif ($line -match 'warn') {
                Write-Host $line -ForegroundColor Yellow
            } elseif ($line -match 'success|complete') {
                Write-Host $line -ForegroundColor Green
            } else {
                Write-Host $line
            }
        }
    }
    
    Remove-Item "temp_logs.txt" -Force -ErrorAction SilentlyContinue
} else {
    # Execute directly
    Invoke-Expression $logCmd
}