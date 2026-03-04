using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using rssnews.Services;
using ServiceStack;
using ServiceStack.Data;
using ServiceStack.OrmLite;

[assembly: HostingStartup(typeof(rssnews.ConfigureDb))]

namespace rssnews;

public class BlueprintDbContextFactory : IDesignTimeDbContextFactory<RSSNewsDbContext>
{
    public RSSNewsDbContext CreateDbContext(string[] args)
    {
        Console.WriteLine("🔧 Using Design-Time DbContext Factory for EF Core Tools");

        // 1. ลองอ่าน password จากหลายแหล่ง
        string? password = GetPassword();

        // 2. ถ้าไม่มี password ใช้ค่า default สำหรับ design-time
        if (string.IsNullOrEmpty(password))
        {
            Console.WriteLine("⚠️  No password found, using design-time placeholder");
            password = "DesignTime_Placeholder_P@ssw0rd!";
        }

        // 3. อ่านค่า config
        var host = Environment.GetEnvironmentVariable("DATABASE_HOST") ?? "localhost";
        var database = Environment.GetEnvironmentVariable("DATABASE_NAME") ?? "RSSActivityWeb";

        Console.WriteLine($"📍 Design-Time Connection: {host}/{database}");

        var connectionString = new SqlConnectionStringBuilder
        {
            DataSource = host,
            InitialCatalog = database,
            UserID = "sa",
            Password = password,
            TrustServerCertificate = true,
            Encrypt = false
        }.ToString();

        var optionsBuilder = new DbContextOptionsBuilder<RSSNewsDbContext>();
        optionsBuilder.UseSqlServer(connectionString, sql =>
        {
            sql.MigrationsHistoryTable("__EFMigrationsHistory");
            sql.CommandTimeout(120);
        });

        return new RSSNewsDbContext(optionsBuilder.Options);
    }

    private static string? GetPassword()
    {
        var password = Environment.GetEnvironmentVariable("MSSQL_SA_PASSWORD");
        if (!string.IsNullOrEmpty(password))
        {
            Console.WriteLine("✅ Password from MSSQL_SA_PASSWORD");
            return password;
        }

        var connStr = Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection");
        if (!string.IsNullOrEmpty(connStr))
        {
            try
            {
                var builder = new SqlConnectionStringBuilder(connStr);
                if (!string.IsNullOrEmpty(builder.Password))
                {
                    Console.WriteLine("✅ Password from ConnectionStrings__DefaultConnection");
                    return builder.Password;
                }
            }
            catch { }
        }

        var secretFile = Environment.GetEnvironmentVariable("MSSQL_SA_PASSWORD_FILE");
        if (!string.IsNullOrEmpty(secretFile) && File.Exists(secretFile))
        {
            try
            {
                password = File.ReadAllText(secretFile).Trim();
                Console.WriteLine($"✅ Password from secret file: {secretFile}");
                return password;
            }
            catch { }
        }

        var localPaths = new[]
        {
            System.IO.Path.Combine(Directory.GetCurrentDirectory(), "..", "secrets", "db_password.txt"),
            System.IO.Path.Combine(Directory.GetCurrentDirectory(), "secrets", "db_password.txt"),
            "/run/secrets/db_password"
        };

        foreach (var path in localPaths)
        {
            try
            {
                if (File.Exists(path))
                {
                    password = File.ReadAllText(path).Trim();
                    Console.WriteLine($"✅ Password from local file: {path}");
                    return password;
                }
            }
            catch { }
        }

        return null;
    }
}

public class ConfigureDb : IHostingStartup
{
    public void Configure(IWebHostBuilder builder) => builder
        .ConfigureServices(static (context, services) =>
        {
            var logger = services.BuildServiceProvider().GetService<ILogger<ConfigureDb>>();

            var isDesignTime = IsDesignTime();
            if (isDesignTime)
            {
                logger?.LogInformation("🔧 Design-time detected - skipping runtime configuration");
                return;
            }
            string? databasePassword = null;
            var secretFile = Environment.GetEnvironmentVariable("MSSQL_SA_PASSWORD_FILE");
            logger?.LogInformation("🔍 Checking for MSSQL_SA_PASSWORD_FILE: {SecretFile}", secretFile ?? "not set");

            if (!string.IsNullOrWhiteSpace(secretFile))
            {
                if (File.Exists(secretFile))
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
                else
                {
                    logger?.LogWarning("⚠️  Secret file specified but not found: {SecretFile}", secretFile);
                }
            }

            if (string.IsNullOrWhiteSpace(databasePassword))
            {
                databasePassword = Environment.GetEnvironmentVariable("MSSQL_SA_PASSWORD");
                if (!string.IsNullOrWhiteSpace(databasePassword))
                {
                    logger?.LogInformation("✅ Loaded database password from environment variable");
                    logger?.LogWarning("⚠️  Using MSSQL_SA_PASSWORD is not recommended for production.");
                }
            }

            if (string.IsNullOrWhiteSpace(databasePassword))
            {
                var errorMsg = "❌ Database password not found. Please set one of:\n" +
                  "   - MSSQL_SA_PASSWORD_FILE (recommended for production)\n" +
                  "   - MSSQL_SA_PASSWORD (for development only)";
                logger?.LogError(errorMsg);
                throw new InvalidOperationException(errorMsg);
            }

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

            var experimentalConnString = new SqlConnectionStringBuilder(connectionString)
            {
                InitialCatalog = "master"
            };

            try
            {
                using var testConnection = new SqlConnection(experimentalConnString.ToString());
                testConnection.Open();
                logger?.LogInformation("✅ Database server connection test successful");
                testConnection.Close();
            }
            catch (Exception ex)
            {
                logger?.LogWarning(ex, "⚠️  Database connection test failed (will retry on first use)");
            }

            services.AddSingleton<IDbConnectionFactory>(new OrmLiteConnectionFactory(
                connectionString,
                SqlServer2022Dialect.Provider));

            services.AddDbContext<RSSNewsDbContext>(options =>
            {
                options.UseSqlServer(connectionString, sqlOptions =>
                {
                    sqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 10,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                    sqlOptions.CommandTimeout(120);
                    sqlOptions.MigrationsHistoryTable("__EFMigrationsHistory");
                });

                if (context.HostingEnvironment.IsDevelopment())
                {
                    options.EnableSensitiveDataLogging();
                    options.EnableDetailedErrors();
                }
            });

            logger?.LogInformation("✅ Database configuration completed");
        });

    private static bool IsDesignTime()
    {
        var entryAssembly = System.Reflection.Assembly.GetEntryAssembly();
        if (entryAssembly != null)
        {
            var name = entryAssembly.GetName().Name;
            if (name?.Contains("ef", StringComparison.OrdinalIgnoreCase) == true ||
                name?.Contains("dotnet", StringComparison.OrdinalIgnoreCase) == true)
            {
                return true;
            }
        }

        // ตรวจสอบ command line arguments
        var args = Environment.GetCommandLineArgs();
        return args.Any(a =>
            a.Contains("ef", StringComparison.OrdinalIgnoreCase) ||
            a.Contains("migrations", StringComparison.OrdinalIgnoreCase));
    }
}