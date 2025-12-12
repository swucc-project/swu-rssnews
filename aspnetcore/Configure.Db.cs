using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using rssnews.Services;
using ServiceStack;
using ServiceStack.Data;
using ServiceStack.OrmLite;

[assembly: HostingStartup(typeof(rssnews.ConfigureDb))]

namespace rssnews;

public class ConfigureDb : IHostingStartup
{
    public void Configure(IWebHostBuilder builder) => builder
        .ConfigureServices(static (context, services) =>
        {
            var logger = services.BuildServiceProvider().GetService<ILogger<ConfigureDb>>();

            // อ่าน password จาก secret file หรือ environment variable
            string? databasePassword = null;

            // 1. ลองอ่านจาก MSSQL_SA_PASSWORD_FILE ก่อน (Docker secrets)
            var secretFile = Environment.GetEnvironmentVariable("MSSQL_SA_PASSWORD_FILE");
            if (!string.IsNullOrWhiteSpace(secretFile) && File.Exists(secretFile))
            {
                try
                {
                    databasePassword = File.ReadAllText(secretFile).Trim();
                    logger?.LogInformation("✅ Loaded database password from secret file: {SecretFile}", secretFile);
                }
                catch (Exception ex)
                {
                    logger?.LogError(ex, "❌ Failed to read password from secret file: {SecretFile}", secretFile);
                }
            }

            // 2. ถ้าไม่มี ลองอ่านจาก MSSQL_SA_PASSWORD
            if (string.IsNullOrWhiteSpace(databasePassword))
            {
                databasePassword = Environment.GetEnvironmentVariable("MSSQL_SA_PASSWORD");
                if (!string.IsNullOrWhiteSpace(databasePassword))
                {
                    logger?.LogInformation("✅ Loaded database password from environment variable");
                }
            }

            // 3. ตรวจสอบว่ามี password หรือไม่
            if (string.IsNullOrWhiteSpace(databasePassword))
            {
                var errorMsg = "❌ Database password not found. Please set MSSQL_SA_PASSWORD_FILE or MSSQL_SA_PASSWORD environment variable.";
                logger?.LogError(errorMsg);
                throw new InvalidOperationException(errorMsg);
            }

            // อ่านค่า config โดยตรงจาก environment variables
            var databaseHost = Environment.GetEnvironmentVariable("DATABASE_HOST") ?? "localhost";
            var databaseName = Environment.GetEnvironmentVariable("DATABASE_NAME") ?? "RSSActivityWeb";

            logger?.LogInformation("🗄️  Configuring database connection:");
            logger?.LogInformation("   Host: {Host}", databaseHost);
            logger?.LogInformation("   Database: {Database}", databaseName);

            var connectionStringBuilder = new SqlConnectionStringBuilder
            {
                DataSource = databaseHost,
                InitialCatalog = databaseName,
                UserID = "sa",
                Password = databasePassword,
                ConnectTimeout = 30,
                Encrypt = false,
                ApplicationName = "RSS News Application",
                Pooling = true,
                MinPoolSize = 5,
                MaxPoolSize = 50
            };

            var connectionString = connectionStringBuilder.ToString();

            // ทดสอบการเชื่อมต่อ (แต่ไม่ให้ fail ถ้าเชื่อมต่อไม่ได้)
            try
            {
                using var testConnection = new SqlConnection(connectionString);
                testConnection.Open();
                logger?.LogInformation("✅ Database connection test successful");
                testConnection.Close();
            }
            catch (Exception ex)
            {
                logger?.LogWarning(ex, "⚠️  Database connection test failed (will retry on first use)");
                // แสดง connection string (ไม่รวม password) เพื่อ debug
                var safeConnectionString = new SqlConnectionStringBuilder(connectionString)
                {
                    Password = "***HIDDEN***"
                }.ToString();
                logger?.LogWarning("Connection string (password hidden): {ConnectionString}", safeConnectionString);
            }

            // Configure OrmLite (สำหรับ ServiceStack)
            services.AddSingleton<IDbConnectionFactory>(new OrmLiteConnectionFactory(
                connectionString,
                SqlServer2022Dialect.Provider));

            // Configure EF Core DbContext
            services.AddDbContext<RSSNewsDbContext>(options =>
            {
                options.UseSqlServer(connectionString, sqlOptions =>
                {
                    sqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 10,  // เพิ่มจำนวนครั้งที่ retry
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                    sqlOptions.CommandTimeout(120);  // เพิ่มเป็น 120 วินาที
                    sqlOptions.MigrationsHistoryTable("__EFMigrationsHistory");
                });

                if (context.HostingEnvironment.IsDevelopment())
                {
                    options.EnableSensitiveDataLogging();
                    options.EnableDetailedErrors();
                }
            });

            // ไม่ต้อง Add AdminDatabaseFeature ที่นี่ (จะ add ใน AppHost แทน)

            logger?.LogInformation("✅ Database configuration completed");
        });
}