using ServiceStack;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using rssnews;
using rssnews.Services;
using rssnews.GraphQL;
using rssnews.GraphQL.Repository;
using rssnews.GraphQL.Handlers;
using rssnews.GraphQL.Types;
using rssnews.Swagger;
using InertiaCore.Extensions;
using rssnews.ServiceInterface;
using Vite.AspNetCore;
using Microsoft.AspNetCore.Authentication.Cookies;
using System.Text.Json;
using System.Reflection;
using System.Threading.RateLimiting;
using HotChocolate.Execution;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using HotChocolate.AspNetCore;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

var grpcTypes = Assembly.GetExecutingAssembly()
        .GetTypes()
        .Where(t => t.Namespace != null && t.Namespace.StartsWith("SwuNews"))
        .ToList();

bool hasGrpcTypes = grpcTypes.Count > 0;

if (hasGrpcTypes)
{
    Console.WriteLine($"✅ Found {grpcTypes.Count} gRPC types:");
    foreach (var type in grpcTypes.Take(10))
    {
        Console.WriteLine($"  - {type.FullName}");
    }
}
else
{
    Console.WriteLine("⚠️  No gRPC types found - gRPC services will be disabled");
    Console.WriteLine("💡 This is expected during first build. Run migration to generate gRPC code.");
}

builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.ListenAnyIP(5000, listenOptions =>
    {
        listenOptions.Protocols = Microsoft.AspNetCore.Server.Kestrel.Core.HttpProtocols.Http1AndHttp2;
    });
});

var configuration = builder.Configuration;

bool enableIntrospection = configuration.GetValue<bool>("GraphQL:EnableIntrospection");
bool enablePlayground = configuration.GetValue<bool>("GraphQL:EnablePlayground");

builder.Logging.ClearProviders();
builder.Logging.AddDebug();

if (builder.Environment.IsDevelopment())
{
    builder.Logging.SetMinimumLevel(LogLevel.Debug);
}

builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/www/rssnews/.aspnet/DataProtection-Keys"))
    .SetApplicationName("rssnews");

var allowedOrigins = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowSpecificOrigins", policy =>
    {
        policy.WithOrigins(allowedOrigins!)
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials()
            .WithExposedHeaders("Grpc-Status", "Grpc-Message", "Grpc-Encoding", "Grpc-Accept-Encoding", "X-Inertia");
    });

    options.AddPolicy("GraphQLPolicy", policy =>
    {
        policy.WithOrigins(allowedOrigins!)
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
    });
});

builder.Services.AddGraphQLServer()
    .RegisterDbContextFactory<RSSNewsDbContext>()
    .ModifyRequestOptions(options =>
    {
        options.IncludeExceptionDetails = builder.Environment.IsDevelopment();
        options.ExecutionTimeout = TimeSpan.FromSeconds(30);
    })
    .AddQueryType<RSSNewsQuery>()
    .AddMutationType<RSSNewsMutation>()
    .AddSubscriptionType<RSSNewsSubscription>()
    .AddProjections()
    .AddFiltering()
    .AddSorting()
    .AddApolloFederation()
    .ModifyOptions(options =>
    {
        options.EnableDirectiveIntrospection = true;
    })
    .DisableIntrospection(!enableIntrospection)
    .AddHttpRequestInterceptor<IntrospectionInterceptor>()
    .AddInMemorySubscriptions()
    .AddType<ItemObject>()
    .AddType<CategoryObject>()
    .AddType<AuthorObject>()
    .AddType<MessageObject>()
    .AddInstrumentation(obj =>
    {
        obj.IncludeDocument = builder.Environment.IsDevelopment();
    })
    .AddAuthorizationCore();

builder.Services.AddScoped<RSSNewsDbContext>();
builder.Services.AddScoped<IItemService, ItemService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IAuthorService, AuthorService>();
builder.Services.AddScoped<ISwitchLocalizationService, SwitchLocalizationService>();
builder.Services.AddSingleton<IRSSItemRepository, RSSItemRepository>();
builder.Services.AddSingleton<GraphQLSchemaService>();
builder.Services.AddHostedService<SchemaExportService>();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddHttpClient();
if (!builder.Environment.IsDevelopment())
{
    builder.Services.AddHttpsRedirection(prop =>
    {
        prop.RedirectStatusCode = StatusCodes.Status307TemporaryRedirect;
    });
}
builder.Services.AddHsts(options =>
{
    options.Preload = true;
    options.IncludeSubDomains = true;
    options.MaxAge = TimeSpan.FromDays(60);
});

builder.Services.AddHealthChecks()
    .AddCheck<GraphQLHealthCheck>("graphql", tags: ["ready", "graphql"])
    .AddDbContextCheck<RSSNewsDbContext>("database", tags: ["ready", "database"]);

builder.Services.AddControllersWithViews()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    });
builder.Services.AddRazorPages();
builder.Services.AddGrpc();
builder.Services.AddGrpcReflection();
if (hasGrpcTypes)
{
    builder.Services.AddServiceStackGrpc();
    Console.WriteLine("✅ ServiceStack gRPC registered");
}

builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 100,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            });
    });
});

builder.Services.AddViteServices(options =>
{
    options.Server.Host = "frontend";
    options.Server.Port = 5173;
    options.Server.UseReactRefresh = false;
});
builder.Services.AddInertia(properties =>
{
    properties.RootView = "~/Views/Index.cshtml";
    properties.SsrEnabled = false;
});

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "swu-news";
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.ExpireTimeSpan = TimeSpan.FromMinutes(20);
        options.SlidingExpiration = true;
        options.AccessDeniedPath = "/rss/failed";
        options.LoginPath = "/rss/signin";
    });
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("AdminPolicy", policy => policy.RequireRole("Admin"))
    .AddPolicy("EditRSSPolicy", policy => policy.RequireRole("Admin", "Editor"))
    .AddPolicy("ViewAllRSSPolicy", policy => policy.RequireRole("Admin", "Editor", "Viewer"));

builder.Services.AddViteHelper();

builder.Services.AddSpaStaticFiles(configuration =>
{
    configuration.RootPath = "wwwroot/volume";
});


builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Version = "v1",
        Title = "API ระบบข่าวและกิจกรรม มหาวิทยาลัยศรีนครินทรวิโรฒ",
        Description = "ระบบจัดการข่าวสารและกิจกรรม มศว ในรูปแบบ RSS Feed",
        Contact = new OpenApiContact
        {
            Name = "ฝ่ายระบบสารสนเทศ มหาวิทยาลัยศรีนครินทรวิโรฒ",
            Email = "pavarudh@g.swu.ac.th",
            Url = new Uri("https://news.swu.ac.th")
        },
        License = new OpenApiLicense
        {
            Name = "มหาวิทยาลัยศรีนครินทรวิโรฒ",
            Url = new Uri("https://www.swu.ac.th")
        }
    });
    var xmlFilename = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = System.IO.Path.Combine(AppContext.BaseDirectory, xmlFilename);
    if (File.Exists(xmlPath))
    {
        options.IncludeXmlComments(xmlPath);
    }
    options.AddSecurityDefinition("Cookie", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.ApiKey,
        In = ParameterLocation.Cookie,
        Name = "swu-news",
        Description = "Cookie Authentication"
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Cookie"
                }
            },
            Array.Empty<string>()
        }
    });
    options.OperationFilter<AcceptLanguageOperationFilter>();
    options.OperationFilter<AuthorizationOperationFilter>();
    options.TagActionsBy(api => [api.GroupName ?? api.ActionDescriptor.RouteValues["controller"] ?? "Default"]);
    options.DocInclusionPredicate((name, api) => true);
    options.CustomSchemaIds(type => type.FullName?.Replace("+", "."));
});

builder.Services.AddAntiforgery(options =>
{
    options.HeaderName = "X-XSRF-TOKEN";
});

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // ✅ สำคัญ: ใน Docker network เรามักไม่ทราบ IP ของ Proxy แน่นอน
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();

app.Logger.LogInformation("🌐 Kestrel listening on http://0.0.0.0:5000");

using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<RSSNewsDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

    try
    {
        logger.LogInformation("🔄 Checking database connection and applying migrations...");

        if (await dbContext.Database.CanConnectAsync())
        {
            var pendingMigrations = await dbContext.Database.GetPendingMigrationsAsync();

            if (pendingMigrations.Any())
            {
                logger.LogInformation("📦 Found {Count} pending migration(s), applying...", pendingMigrations.Count());
                foreach (var migration in pendingMigrations)
                {
                    logger.LogInformation("  ➜ {Migration}", migration);
                }

                await dbContext.Database.MigrateAsync();
                logger.LogInformation("✅ Database migrations applied successfully");
            }
            else
            {
                logger.LogInformation("✅ Database is up to date");
            }
        }
        else
        {
            logger.LogWarning("⚠️ Cannot connect to database");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "❌ Database migration failed");
    }
}

app.Logger.LogInformation("⏳ Warming up GraphQL server...");

using (var scope = app.Services.CreateScope())
{
    try
    {
        var resolver = scope.ServiceProvider.GetRequiredService<IRequestExecutorResolver>();
        var executor = await resolver.GetRequestExecutorAsync();

        app.Logger.LogInformation("✅ GraphQL server initialized successfully");
        app.Logger.LogInformation("📊 Schema contains {TypeCount} types", executor.Schema.Types.Count);
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning(ex, "⚠️ GraphQL server initialization warning");
    }
}

if (app.Environment.IsDevelopment())
{
    try
    {
        app.UseViteDevelopmentServer();
        app.Logger.LogInformation("✅ Vite development server connected");
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning(ex, "⚠️ Vite dev server not reachable - using production assets");
    }
    app.UseSwagger(c =>
    {
        c.RouteTemplate = "swagger/{documentName}/swagger.json";
        c.PreSerializeFilters.Add((swaggerDoc, httpReq) =>
        {
            swaggerDoc.Servers =
            [
                new OpenApiServer { Url = $"{httpReq.Scheme}://{httpReq.Host.Value}" }
            ];
        });
    });
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "SWU RSS News API v1");
        c.RoutePrefix = "swagger";
        c.DocumentTitle = "API Documentation - SWU News System";
        c.DefaultModelsExpandDepth(-1);
        c.DisplayRequestDuration();
        c.EnableDeepLinking();
        c.EnableFilter();
        c.ShowExtensions();
        c.EnableTryItOutByDefault();
        c.InjectStylesheet("swagger-guide.css");
    });
    app.MapGet("/manual-api.json", async context =>
    {
        var filePath = System.IO.Path.Combine(AppContext.BaseDirectory, "manual-api.json");
        if (File.Exists(filePath))
        {
            context.Response.ContentType = "application/json";
            await context.Response.SendFileAsync(filePath);
        }
        else
        {
            context.Response.StatusCode = 404;
        }
    });
    app.MapGrpcReflectionService();
}
else
{
    app.UseHsts();
}

app.UseForwardedHeaders();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Error");
}
app.UseStaticFiles();

if (!app.Environment.IsDevelopment())
{
    app.UseSpaStaticFiles();
}

app.UseRouting();
app.UseCors("AllowSpecificOrigins");
app.UseAuthentication();
app.UseAuthorization();
app.UseInertia();
app.UseGrpcWeb();
app.UseWebSockets();
app.UseRateLimiter();

app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = _ => true,
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        var result = JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new
            {
                name = e.Key,
                status = e.Value.Status.ToString(),
                description = e.Value.Description
            })
        });
        await context.Response.WriteAsync(result);
    }
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false
});

app.MapGet("/health/graphql", async (IRequestExecutorResolver resolver) =>
{
    try
    {
        await resolver.GetRequestExecutorAsync();
        return Results.Ok(new { status = "healthy", message = "GraphQL Ready" });
    }
    catch (Exception ex)
    {
        return Results.Json(
            new { status = "unhealthy", message = ex.Message },
            statusCode: 503
        );
    }
});

app.MapGraphQLWebSocket("/graphql-ws");
app.MapGraphQL("/graphql")
    .RequireCors("GraphQLPolicy")
    .WithOptions(new GraphQLServerOptions
    {
        EnableSchemaRequests = enableIntrospection
    });

app.MapNitroApp("/graphql-ui");

app.MapGet("/graphql/schema", async (
    GraphQLSchemaService schemaService,
    IRequestExecutorResolver resolver,
    HttpContext context) =>
{
    var isDev = app.Environment.IsDevelopment();
    var isInternal = schemaService.IsInternalRequest(context);
    var allowIntrospection = context.Request.Headers["X-Allow-Introspection"].ToString() == "true";

    if (!isDev && !isInternal && !allowIntrospection)
    {
        return Results.Json(
            new { error = "Schema introspection is disabled in production" },
            statusCode: 403
        );
    }

    try
    {
        var executor = await resolver.GetRequestExecutorAsync();
        var schemaText = executor.Schema.Print();
        var hash = await schemaService.GetSchemaHashAsync();

        context.Response.Headers.ETag = $"\"{hash}\"";
        context.Response.Headers["X-GraphQL-Schema-Version"] = schemaService.GetSchemaVersion();
        context.Response.ContentType = "text/plain; charset=utf-8";

        return Results.Text(schemaText);
    }
    catch (Exception ex)
    {
        return Results.Json(
            new { error = "Failed to generate schema", message = ex.Message },
            statusCode: 500
        );
    }
});

app.MapGrpcService<RSSItemService>()
    .EnableGrpcWeb()
    .RequireCors("AllowSpecificOrigins");

app.MapGet("/manual-api", context =>
{
    context.Response.Redirect("/usermanual");
    return Task.CompletedTask;
});

app.UseServiceStack(new AppHost());
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=RSS}/{action=Index}/{id?}"
);

app.Logger.LogInformation("✅ Application configured successfully");
app.Logger.LogInformation("📍 Health check available at: /health");
app.Logger.LogInformation("📍 GraphQL endpoint available at: /graphql");
if (hasGrpcTypes)
{
    app.Logger.LogInformation("📍 gRPC endpoint available at: /grpc");
}
if (app.Environment.IsDevelopment())
{
    app.Logger.LogInformation("📍 Swagger UI available at: /swagger");
}
app.MapFallbackToController("Index", "RSS");
app.Run();