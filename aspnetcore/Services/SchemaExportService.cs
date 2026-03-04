using HotChocolate.Execution;

namespace rssnews.Services
{
    public class SchemaExportService(
        IServiceProvider serviceProvider,
        ILogger<SchemaExportService> logger,
        IConfiguration configuration) : IHostedService
    {
        private readonly IServiceProvider _serviceProvider = serviceProvider;
        private readonly ILogger<SchemaExportService> _logger = logger;
        private readonly IConfiguration _configuration = configuration;

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            var exportOnStartup = _configuration.GetValue<bool>("EXPORT_SCHEMA_ON_STARTUP", true);
            if (!exportOnStartup)
            {
                _logger.LogInformation("ℹ️ Schema export on startup is disabled");
                return;
            }

            // รอให้ GraphQL พร้อมก่อน
            await WaitForGraphQLReadyAsync(cancellationToken);

            try
            {
                using var scope = _serviceProvider.CreateScope();
                var schemaService = scope.ServiceProvider.GetRequiredService<GraphQLSchemaService>();

                // 🔧 FIX: ใช้ paths ที่ถูกต้องและ shared volume
                var exportPaths = new[]
                {
                    "/app/apollo/schema.graphql",           // Shared volume (primary)
                    "/var/www/rssnews/apollo/schema.graphql",
                    Environment.GetEnvironmentVariable("SCHEMA_EXPORT_PATH") ?? ""
                }.Where(p => !string.IsNullOrEmpty(p)).Distinct().ToArray();

                foreach (var path in exportPaths)
                {
                    await ExportWithRetryAsync(schemaService, path, cancellationToken);
                }

                _logger.LogInformation("✅ All schema exports completed");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Failed to export GraphQL schema");
            }
        }

        private async Task WaitForGraphQLReadyAsync(CancellationToken cancellationToken)
        {
            var maxAttempts = 30;
            var delayMs = 1000;

            _logger.LogInformation("⏳ Waiting for GraphQL to be ready...");

            for (int i = 0; i < maxAttempts; i++)
            {
                try
                {
                    using var scope = _serviceProvider.CreateScope();
                    var resolver = scope.ServiceProvider.GetRequiredService<IRequestExecutorResolver>();
                    var executor = await resolver.GetRequestExecutorAsync(cancellationToken: cancellationToken);

                    if (executor?.Schema != null)
                    {
                        _logger.LogInformation("✅ GraphQL is ready after {Attempts} attempts", i + 1);
                        return;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogDebug("Attempt {Attempt}: GraphQL not ready yet - {Message}", i + 1, ex.Message);
                }

                await Task.Delay(delayMs, cancellationToken);
            }

            _logger.LogWarning("⚠️ GraphQL readiness check timed out, attempting export anyway");
        }

        private async Task ExportWithRetryAsync(GraphQLSchemaService schemaService, string path, CancellationToken cancellationToken)
        {
            var maxRetries = 3;

            for (int retry = 0; retry < maxRetries; retry++)
            {
                try
                {
                    // Ensure directory exists
                    var directory = System.IO.Path.GetDirectoryName(path);
                    if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                    {
                        Directory.CreateDirectory(directory);
                        _logger.LogInformation("📁 Created directory: {Directory}", directory);
                    }

                    await schemaService.ExportAsync(path);

                    // Verify file was written
                    if (File.Exists(path))
                    {
                        var fileInfo = new FileInfo(path);
                        _logger.LogInformation("✅ Schema exported to: {Path} ({Size} bytes)", path, fileInfo.Length);
                        return;
                    }
                    else
                    {
                        throw new IOException($"File was not created: {path}");
                    }
                }
                catch (Exception ex) when (retry < maxRetries - 1)
                {
                    _logger.LogWarning("⚠️ Export attempt {Retry} failed for {Path}: {Error}. Retrying...",
                        retry + 1, path, ex.Message);
                    await Task.Delay(1000 * (retry + 1), cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError("❌ Failed to export schema to {Path} after {MaxRetries} attempts: {Error}",
                        path, maxRetries, ex.Message);
                }
            }
        }

        public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    }
}