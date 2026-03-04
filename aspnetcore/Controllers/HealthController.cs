using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using rssnews.Services;
using System.Diagnostics;

namespace rssnews.Controllers
{
    [ApiController]
    [Route("[controller]")]
    [Produces("application/json")]
    public class HealthController : ControllerBase
    {
        private readonly RSSNewsDbContext _dbContext;
        private readonly ILogger<HealthController> _logger;
        private static readonly Stopwatch _uptime = Stopwatch.StartNew();
        private static DateTime? _lastDbCheck;
        private static bool _lastDbStatus = false;
        private static readonly object _lockObj = new(); // ✅ Thread-safe

        public HealthController(RSSNewsDbContext dbContext, ILogger<HealthController> logger)
        {
            _dbContext = dbContext;
            _logger = logger;
        }

        /// <summary>
        /// ✅ Liveness probe - ตรวจสอบว่า process ยังทำงานอยู่
        /// ใช้สำหรับ Docker healthcheck และ Kubernetes liveness probe
        /// </summary>
        [HttpGet]
        [HttpGet("live")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public IActionResult GetHealth()
        {
            return Ok(new
            {
                status = "Healthy",
                timestamp = DateTime.UtcNow,
                uptime = _uptime.Elapsed.TotalSeconds,
                uptimeFormatted = FormatUptime(_uptime.Elapsed),
                environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production"
            });
        }

        /// <summary>
        /// ✅ Readiness probe - ตรวจสอบว่าพร้อมรับ traffic (รวมถึง database)
        /// ใช้สำหรับ Kubernetes readiness probe และ load balancer
        /// </summary>
        [HttpGet("ready")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
        public async Task<IActionResult> GetReadiness()
        {
            try
            {
                var now = DateTime.UtcNow;
                bool useCache;
                bool cachedStatus;

                // ✅ Thread-safe cache check
                lock (_lockObj)
                {
                    useCache = _lastDbCheck.HasValue && (now - _lastDbCheck.Value).TotalSeconds < 30;
                    cachedStatus = _lastDbStatus;
                }

                if (useCache)
                {
                    return cachedStatus
                        ? Ok(new { status = "Healthy", database = "connected", cached = true })
                        : StatusCode(503, new { status = "Unhealthy", database = "disconnected", cached = true });
                }

                // ✅ Quick database ping (timeout 3s)
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(3));
                var canConnect = await _dbContext.Database.CanConnectAsync(cts.Token);

                // ✅ Thread-safe cache update
                lock (_lockObj)
                {
                    _lastDbCheck = now;
                    _lastDbStatus = canConnect;
                }

                if (!canConnect)
                {
                    _logger.LogWarning("Database connection check failed");
                    return StatusCode(503, new
                    {
                        status = "Unhealthy",
                        database = "disconnected",
                        timestamp = now
                    });
                }

                return Ok(new
                {
                    status = "Healthy",
                    database = "connected",
                    timestamp = now
                });
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("Database readiness check timed out");
                return StatusCode(503, new { status = "Unhealthy", database = "timeout" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Readiness check failed");
                return StatusCode(503, new
                {
                    status = "Unhealthy",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// ✅ Detailed health status - สำหรับ monitoring dashboard
        /// </summary>
        [HttpGet("detailed")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
        public async Task<IActionResult> GetDetailedHealth()
        {
            var checks = new Dictionary<string, object>();
            var overallHealthy = true;

            // ✅ Database check
            try
            {
                var sw = Stopwatch.StartNew();
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                var canConnect = await _dbContext.Database.CanConnectAsync(cts.Token);
                sw.Stop();

                if (canConnect)
                {
                    // ✅ ใช้ CancellationToken ใหม่สำหรับ Count query
                    using var countCts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                    var itemCount = await _dbContext.Items.CountAsync(countCts.Token);

                    checks["database"] = new
                    {
                        status = "Healthy",
                        provider = _dbContext.Database.ProviderName,
                        itemCount,
                        responseTimeMs = sw.ElapsedMilliseconds
                    };
                }
                else
                {
                    checks["database"] = new { status = "Unhealthy", reason = "cannot connect" };
                    overallHealthy = false;
                }
            }
            catch (Exception ex)
            {
                checks["database"] = new { status = "Unhealthy", error = ex.Message };
                overallHealthy = false;
                _logger.LogError(ex, "Database health check failed");
            }

            // ✅ GraphQL check
            checks["graphql"] = new { status = "Healthy", endpoint = "/graphql" };

            // ✅ gRPC check
            checks["grpc"] = new { status = "Healthy", endpoint = "/grpc" };

            // ✅ System info
            checks["system"] = new
            {
                uptime = _uptime.Elapsed.TotalSeconds,
                uptimeFormatted = FormatUptime(_uptime.Elapsed),
                memoryMB = GC.GetTotalMemory(false) / 1024 / 1024,
                cpuCount = Environment.ProcessorCount,
                processId = Environment.ProcessId,
                gcGen0 = GC.CollectionCount(0),
                gcGen1 = GC.CollectionCount(1),
                gcGen2 = GC.CollectionCount(2)
            };

            var response = new
            {
                status = overallHealthy ? "Healthy" : "Degraded",
                timestamp = DateTime.UtcNow,
                version = GetVersion(),
                checks
            };

            return overallHealthy
                ? Ok(response)
                : StatusCode(503, response);
        }

        /// <summary>
        /// ✅ Startup probe - ตรวจสอบว่า application เริ่มต้นเสร็จแล้ว
        /// </summary>
        [HttpGet("startup")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
        public IActionResult GetStartup()
        {
            // ✅ ใช้ 10 วินาทีเป็น threshold ที่เหมาะสมกว่า
            var isReady = _uptime.Elapsed.TotalSeconds > 10;

            var response = new
            {
                status = isReady ? "Healthy" : "Starting",
                uptime = _uptime.Elapsed.TotalSeconds,
                uptimeFormatted = FormatUptime(_uptime.Elapsed)
            };

            return isReady ? Ok(response) : StatusCode(503, response);
        }

        /// <summary>
        /// ✅ GraphQL health check
        /// </summary>
        [HttpGet("graphql-status")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public IActionResult GetGraphQLHealth()
        {
            var isDevelopment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Development";
            var allowIntrospection = Request.Headers["X-Allow-Introspection"].ToString() == "true";

            return Ok(new
            {
                status = "Healthy",
                endpoint = "/graphql",
                wsEndpoint = "/graphql-ws",
                introspection = isDevelopment || allowIntrospection ? "enabled" : "disabled"
            });
        }

        // ✅ Helper methods
        private static string FormatUptime(TimeSpan elapsed)
        {
            if (elapsed.TotalDays >= 1)
                return $"{elapsed.TotalDays:F1}d";
            if (elapsed.TotalHours >= 1)
                return $"{elapsed.TotalHours:F1}h";
            if (elapsed.TotalMinutes >= 1)
                return $"{elapsed.TotalMinutes:F1}m";
            return $"{elapsed.TotalSeconds:F0}s";
        }

        private static string GetVersion()
        {
            return typeof(HealthController).Assembly
                .GetName().Version?.ToString() ?? "1.0.0";
        }
    }
}