# performance-test.ps1
# Simple performance testing

param(
    [Parameter(Mandatory=$false)]
    [string]$Url = "http://localhost:8080",
    [Parameter(Mandatory=$false)]
    [int]$Requests = 100,
    [Parameter(Mandatory=$false)]
    [int]$Concurrency = 10
)

Write-Host "`n⚡ Performance Test - swu-rssnews" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host "URL: $Url" -ForegroundColor Yellow
Write-Host "Requests: $Requests" -ForegroundColor Yellow
Write-Host "Concurrency: $Concurrency" -ForegroundColor Yellow
Write-Host "=" * 60

$results = @()
$startTime = Get-Date

Write-Host "`n🚀 Running tests..." -ForegroundColor Cyan

# Run requests
for ($i = 0; $i -lt $Requests; $i++) {
    $requestStart = Get-Date
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 30 -UseBasicParsing
        $requestEnd = Get-Date
        $duration = ($requestEnd - $requestStart).TotalMilliseconds
        
        $results += [PSCustomObject]@{
            RequestNumber = $i + 1
            StatusCode = $response.StatusCode
            Duration = $duration
            Success = $true
        }
        
        Write-Progress -Activity "Testing" -Status "Request $($i + 1)/$Requests" -PercentComplete (($i + 1) / $Requests * 100)
    } catch {
        $requestEnd = Get-Date
        $duration = ($requestEnd - $requestStart).TotalMilliseconds
        
        $results += [PSCustomObject]@{
            RequestNumber = $i + 1
            StatusCode = 0
            Duration = $duration
            Success = $false
        }
    }
}

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

# Calculate statistics
$successfulRequests = ($results | Where-Object { $_.Success }).Count
$failedRequests = $Requests - $successfulRequests
$avgDuration = ($results | Measure-Object -Property Duration -Average).Average
$minDuration = ($results | Measure-Object -Property Duration -Minimum).Minimum
$maxDuration = ($results | Measure-Object -Property Duration -Maximum).Maximum

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "📊 Test Results" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "`nOverall:" -ForegroundColor Cyan
Write-Host "  Total Requests:      $Requests" -ForegroundColor White
Write-Host "  Successful:          $successfulRequests" -ForegroundColor Green
Write-Host "  Failed:              $failedRequests" -ForegroundColor $(if ($failedRequests -gt 0) { "Red" } else { "Green" })
Write-Host "  Total Duration:      $([math]::Round($totalDuration, 2))s" -ForegroundColor White
Write-Host "  Requests/Second:     $([math]::Round($Requests / $totalDuration, 2))" -ForegroundColor White

Write-Host "`nResponse Times:" -ForegroundColor Cyan
Write-Host "  Average:             $([math]::Round($avgDuration, 2))ms" -ForegroundColor White
Write-Host "  Minimum:             $([math]::Round($minDuration, 2))ms" -ForegroundColor Green
Write-Host "  Maximum:             $([math]::Round($maxDuration, 2))ms" -ForegroundColor Yellow

Write-Host "`n"