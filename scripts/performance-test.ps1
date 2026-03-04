# performance-test.ps1
# Concurrent HTTP performance testing

param(
    [string]$Url = "http://localhost:8080",
    [int]$Requests = 100,
    [int]$Concurrency = 10,
    [string]$Method = "GET",
    [string]$Body,
    [hashtable]$Headers
)

$ProjectName = "swu-rssnews"

Write-Host "`n⚡ Performance Test - $ProjectName" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host "URL: $Url"
Write-Host "Method: $Method"
Write-Host "Requests: $Requests"
Write-Host "Concurrency: $Concurrency"
Write-Host "=" * 60

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(30)

if ($Headers) {
    foreach ($key in $Headers.Keys) {
        $client.DefaultRequestHeaders.Add($key, $Headers[$key])
    }
}

$results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
$startTime = Get-Date

Write-Host "`n🚀 Running concurrent test..." -ForegroundColor Cyan

$jobs = @()
$requestsPerWorker = [math]::Ceiling($Requests / $Concurrency)

for ($w = 1; $w -le $Concurrency; $w++) {
    $jobs += Start-ThreadJob -ScriptBlock {
        param($client, $Url, $Method, $Body, $Count, $results)

        for ($i = 1; $i -le $Count; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                if ($Method -eq "POST") {
                    $content = $Body ? [System.Net.Http.StringContent]::new($Body, [Text.Encoding]::UTF8, "application/json") : $null
                    $resp = $client.PostAsync($Url, $content).Result
                } else {
                    $resp = $client.GetAsync($Url).Result
                }

                $sw.Stop()
                $results.Add([pscustomobject]@{
                    Success  = $resp.IsSuccessStatusCode
                    Status   = [int]$resp.StatusCode
                    Duration = $sw.Elapsed.TotalMilliseconds
                })
            } catch {
                $sw.Stop()
                $results.Add([pscustomobject]@{
                    Success  = $false
                    Status   = 0
                    Duration = $sw.Elapsed.TotalMilliseconds
                })
            }
        }
    } -ArgumentList $client, $Url, $Method, $Body, $requestsPerWorker, $results
}

$jobs | Wait-Job | Remove-Job

$endTime = Get-Date
$totalSeconds = ($endTime - $startTime).TotalSeconds

$success = $results | Where-Object Success
$fail = $results.Count - $success.Count
$durations = $results.Duration | Sort-Object

function Percentile($p) {
    $index = [math]::Ceiling($p / 100 * $durations.Count) - 1
    return $durations[$index]
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "📊 Test Results" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "Total Requests:      $($results.Count)"
Write-Host "Successful:          $($success.Count)" -ForegroundColor Green
Write-Host "Failed:              $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "Total Time:          $([math]::Round($totalSeconds,2))s"
Write-Host "Requests/sec:        $([math]::Round($results.Count / $totalSeconds,2))"

Write-Host "`nResponse Time (ms):" -ForegroundColor Cyan
Write-Host "  Avg:               $([math]::Round(($durations | Measure-Object -Average).Average,2))"
Write-Host "  Min:               $([math]::Round($durations[0],2))"
Write-Host "  Max:               $([math]::Round($durations[-1],2))"
Write-Host "  P95:               $([math]::Round((Percentile 95),2))"
Write-Host "  P99:               $([math]::Round((Percentile 99),2))"

Write-Host "`n✅ Test completed.`n" -ForegroundColor Green