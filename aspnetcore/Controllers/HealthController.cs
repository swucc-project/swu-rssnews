using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using rssnews.Services;

namespace rssnews.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class HealthController : ControllerBase
    {
        private readonly RSSNewsDbContext _dbContext;
        private readonly ILogger<HealthController> _logger;

        public HealthController(RSSNewsDbContext dbContext, ILogger<HealthController> logger)
        {
            _dbContext = dbContext;
            _logger = logger;
        }

        /// <summary>
        /// ตรวจสอบสถานะของระบบ
        /// </summary>
        /// <returns>สถานะความพร้อมของระบบ</returns>
        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
        public async Task<IActionResult> GetHealth()
        {
            try
            {
                var canConnect = await _dbContext.Database.CanConnectAsync();
                if (!canConnect)
                {
                    return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                    {
                        status = "Unhealthy",
                        timestamp = DateTime.UtcNow,
                        services = new
                        {
                            database = "Disconnected",
                            graphql = "Running",
                            grpc = "Running"
                        }
                    });
                }

                return Ok(new
                {
                    status = "Healthy",
                    timestamp = DateTime.UtcNow,
                    version = "1.0.0",
                    services = new
                    {
                        database = "Connected",
                        graphql = "Running",
                        grpc = "Running"
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Health check failed");
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    status = "Unhealthy",
                    timestamp = DateTime.UtcNow,
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// ตรวจสอบสถานะการเชื่อมต่อฐานข้อมูล
        /// </summary>
        /// <returns>สถานะการเชื่อมต่อฐานข้อมูล</returns>
        [HttpGet("database")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
        public async Task<IActionResult> GetDatabaseHealth()
        {
            try
            {
                var canConnect = await _dbContext.Database.CanConnectAsync();
                var itemCount = await _dbContext.Items.CountAsync();

                return Ok(new
                {
                    status = "Connected",
                    timestamp = DateTime.UtcNow,
                    itemCount,
                    databaseProvider = _dbContext.Database.ProviderName
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Database health check failed");

                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    status = "Disconnected",
                    timestamp = DateTime.UtcNow,
                    error = ex.Message
                });
            }
        }
    }
}