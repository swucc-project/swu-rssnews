using ServiceStack;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.OpenApi.Models;
using rssnews;
using rssnews.Services;
using rssnews.GraphQL;
using rssnews.GraphQL.Repository;
using rssnews.GraphQL.Handlers;
using rssnews.GraphQL.Types;
using rssnews.GraphQL.InputType;
using rssnews.Swagger;
using InertiaCore.Extensions;
using rssnews.ServiceInterface;
using Vite.AspNetCore;
using Microsoft.AspNetCore.Authentication.Cookies;
using HotChocolate.AspNetCore;
using System.Reflection;
using System.Threading.RateLimiting;
using HotChocolate.Execution;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpsRedirection(options =>
{
    options.HttpsPort = builder.Environment.IsDevelopment() ? 5001 : 443;
});
builder.Services.AddHsts(options =>
{
    options.Preload = true;
    options.IncludeSubDomains = true;
    options.MaxAge = TimeSpan.FromDays(60);
});

builder.Services.AddHealthChecks();
builder.Services.AddGrpc();
builder.Services.AddServiceStackGrpc();
builder.Services.AddLogging(logging =>
{
    logging.AddDebug();
});
builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy<string>("api", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.User.Identity?.Name ?? context.Request.Headers.Host.ToString(),
            factory: partition => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = 100,
                QueueLimit = 10,
                Window = TimeSpan.FromMinutes(1),
            }
        )
    );
});
builder.Services.AddControllersWithViews();
builder.Services.AddViteServices(options =>
{
    options.Server.AutoRun = true;
    options.Server.Https = true;
    options.Base = "/";
});
builder.Services.AddInertia(properties =>
{
    properties.RootView = "~/Views/Index.cshtml";
    properties.SsrEnabled = true;
    properties.SsrUrl = "http://frontend:13714/render";
});

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "swu-news";
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
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

builder.Services.AddViteHelper(vite =>
{
    vite.PublicDirectory = "wwwroot";
    vite.BuildDirectory = "wwwroot/volume";
    vite.HotFile = "hot";
    vite.ManifestFilename = "manifest.json";
});

builder.Services.AddScoped<RSSNewsDbContext>();
builder.Services.AddScoped<IItemService, ItemService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IAuthorService, AuthorService>();
builder.Services.AddScoped<IRSSItemRepository, RSSItemRepository>();
builder.Services.AddScoped<ISwitchLocalizationService, SwitchLocalizationService>();
builder.Services.AddRazorPages();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowSpecificOrigins", builder =>
    {
        builder.WithOrigins("http://localhost:5000", "https://localhost:5001",
            "http://localhost:5173", "https://localhost:5173",
            "http://frontend:5173", "http://frontend:13714",
            "https://news.swu.ac.th")
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
    });
});

builder.Services.AddGraphQLServer()
    .ModifyRequestOptions(options =>
    {
        options.IncludeExceptionDetails = builder.Environment.IsDevelopment();
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
        options.EnableDirectiveIntrospection = builder.Environment.IsDevelopment();
    })
    .DisableIntrospection(!builder.Environment.IsDevelopment())
    .AddHttpRequestInterceptor<IntrospectionInterceptor>()
    .AddInMemorySubscriptions()
    .AddType<ItemObject>()
    .AddType<CategoryObject>()
    .AddType<AuthorObject>()
    .AddType<ItemInputType>()
    .AddType<CategoryInputType>()
    .AddType<AuthorInputType>()
    .AddInstrumentation(obj =>
    {
        obj.IncludeDocument = builder.Environment.IsDevelopment();
    })
    .AddAuthorizationCore();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Version = "v1",
        Title = "API ระบบข่าวและกิจกรรม มหาวิทยาลัยศรีนครินทรวิโรฒ",
        Description = @"
            <h3>ระบบจัดการข่าวสารและกิจกรรม มศว ในรูปแบบ RSS Feed</h3>
            <p>API นี้รองรับ:</p>
            <ul>
                <li><strong>REST API</strong> - สำหรับ CRUD operations</li>
                <li><strong>GraphQL</strong> - สำหรับ query ข้อมูลแบบ flexible ที่ /graphql</li>
                <li><strong>gRPC</strong> - สำหรับ high-performance communication ที่ /grpc</li>
            </ul>
            <p><strong>Authentication:</strong> ใช้ Cookie-based authentication ผ่าน ServiceStack</p>
            <p><strong>GraphQL Playground:</strong> เข้าถึงได้ที่ /graphql ในโหมด Development</p>
        ",
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
        Description = "Cookie Authentication ผ่าน ServiceStack\n\n" +
                     "ใช้ endpoint `/auth/credentials` เพื่อเข้าสู่ระบบ"
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
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();

app.UseForwardedHeaders();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
    app.UseSwagger(c =>
    {
        c.RouteTemplate = "swagger/{documentName}/swagger.json";
        c.PreSerializeFilters.Add((swaggerDoc, httpReq) =>
        {
            swaggerDoc.Servers = new List<OpenApiServer>
            {
                new OpenApiServer { Url = $"{httpReq.Scheme}://{httpReq.Host.Value}" }
            };
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
        if (File.Exists(System.IO.Path.Combine(AppContext.BaseDirectory, "css", "swagger-guide.css")))
        {
            c.InjectStylesheet("/css/swagger-guide.css");
        }
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
}
else
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}
app.UseHttpsRedirection();
app.UseStaticFiles();

if (app.Environment.IsDevelopment())
{
    app.UseViteDevelopmentServer(true);
}
app.UseWebSockets();
app.UseRouting();
app.UseCors("AllowSpecificOrigins");
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapHealthChecks("/health");
app.MapGraphQLWebSocket("/graphql-ws");
app.MapGraphQL("/graphql")
    .WithOptions(new GraphQLServerOptions
    {
        EnableSchemaRequests = app.Environment.IsDevelopment(),
        Tool = {
            Enable = app.Environment.IsDevelopment()
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
app.MapGet("/graphql/schema.graphql", async (IRequestExecutorResolver resolver, HttpContext context) =>
{
    var allowIntrospection = context.Request.Headers["X-Allow-Introspection"].ToString();

    if (context.RequestServices.GetRequiredService<IWebHostEnvironment>().IsDevelopment()
        || allowIntrospection == "true")
    {
        var executor = await resolver.GetRequestExecutorAsync();
        var schema = executor.Schema;

        context.Response.ContentType = "text/plain; charset=utf-8";
        await context.Response.WriteAsync(schema.Print());

    }
    else
    {
        context.Response.StatusCode = 403;
        await context.Response.WriteAsync("Introspection disabled in production");
    }
});
app.MapGet("/health/graphql", async (IHttpClientFactory factory) =>
{
    try
    {
        var client = factory.CreateClient();
        var response = await client.GetAsync("http://localhost:5000/graphql?sdl");
        return response.IsSuccessStatusCode
            ? Results.Ok(new { status = "healthy", graphql = "available" })
            : Results.Problem("GraphQL not available");
    }
    catch (Exception ex)
    {
        return Results.Problem($"GraphQL check failed: {ex.Message}");
    }
});
app.MapGet("/graphql-schema", async context =>
{
    var allowIntrospection = context.Request.Headers["X-Allow-Introspection"].ToString();

    if (builder.Environment.IsDevelopment() || allowIntrospection == "true")
    {
        var schema = context.RequestServices
            .GetRequiredService<ISchema>()
            .ToString();

        context.Response.ContentType = "text/plain";
        await context.Response.WriteAsync(schema);
    }
    else
    {
        context.Response.StatusCode = 403;
        await context.Response.WriteAsync("Introspection is disabled in production");
    }
});
app.UseServiceStack(new AppHost());
app.UseInertia();
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=RSS}/{action=Index}/{id?}"
);

app.MapFallbackToController("Index", "RSS");
app.Run();