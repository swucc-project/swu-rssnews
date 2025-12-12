using ServiceStack;
using ServiceStack.Web;
using ServiceStack.Data;
using ServiceStack.Auth;
using ServiceStack.Configuration;

[assembly: HostingStartup(typeof(rssnews.ConfigureAuthRepository))]

namespace rssnews;

// Custom User Table with extended Metadata properties
public class SWUAccount : UserAuth
{
    public string BuasriID { get; set; } = "";
    public string PersonalName { get; set; } = "";
    public string Surname { get; set; } = "";

    public string? Position { get; set; }
    public string? Faculty { get; set; }

    public string? Department { get; set; }
    public string? InternalPhone { get; set; }
}

public class AppUserAuthEvents : AuthEvents
{
    public override async Task OnAuthenticatedAsync(IRequest httpReq, IAuthSession session, IServiceBase authService,
        IAuthTokens tokens, Dictionary<string, string> authInfo, CancellationToken token = default)
    {
        var authRepo = HostContext.AppHost.GetAuthRepositoryAsync(httpReq);
        using (authRepo as IDisposable)
        {
            var userAuth = await authRepo.GetUserAuthAsync(session.UserAuthId, token) as SWUAccount;
            if (userAuth != null)
            {
                // ตรวจสอบว่าข้อมูลยังไม่เคยถูกกรอก เพื่อไม่ให้เขียนทับทุกครั้งที่ login
                if (string.IsNullOrEmpty(userAuth.BuasriID))
                {
                    userAuth.BuasriID = session.UserName;
                }
                if (string.IsNullOrEmpty(userAuth.PersonalName))
                {
                    userAuth.PersonalName = session.FirstName;
                }
                if (string.IsNullOrEmpty(userAuth.Surname))
                {
                    userAuth.Surname = session.LastName;
                }

                await authRepo.SaveUserAuthAsync(userAuth, token);
            }
        }
    }
}

public class ConfigureAuthRepository : IHostingStartup
{
    public void Configure(IWebHostBuilder builder) => builder
        .ConfigureServices(services =>
        {
            services.AddSingleton<IAuthRepository>(c =>
                new OrmLiteAuthRepository<SWUAccount, UserAuthDetails>(c.GetRequiredService<IDbConnectionFactory>())
                {
                    UseDistinctRoleTables = true
                });
        })
        .ConfigureAppHost(appHost =>
        {
            try
            {
                var authRepo = appHost.Resolve<IAuthRepository>();

                // ตรวจสอบว่า schema ถูกสร้างแล้วหรือยัง
                authRepo.InitSchema();

                appHost.Resolve<ILogger<ConfigureAuthRepository>>()?.LogInformation("✅ Auth schema initialized");

                // สร้าง default users (ถ้ายังไม่มี)
                CreateUser(authRepo, "setsiri", "setsiri", "p@55wOrd", roles: [RoleNames.Admin]);
                CreateUser(authRepo, "pichaias", "pichaias", "p@55wOrd", roles: ["Employee", "Manager"]);
                CreateUser(authRepo, "nattapor", "nattapor", "p@55wOrd", roles: ["Employee"]);

                appHost.Resolve<ILogger<ConfigureAuthRepository>>()?.LogInformation("✅ Default users created");
            }
            catch (Exception ex)
            {
                // Log error แต่ไม่ throw เพื่อให้ app ยังทำงานได้
                appHost.Resolve<ILogger<ConfigureAuthRepository>>()?.LogError(ex, "❌ Failed to initialize auth repository");
            }
        },
        afterConfigure: appHost =>
        {
            try
            {
                var authFeature = appHost.AssertPlugin<AuthFeature>();
                authFeature.AuthEvents.Add(new AppUserAuthEvents());
                appHost.Resolve<ILogger<ConfigureAuthRepository>>().LogInformation("✅ Auth events registered");
            }
            catch (Exception ex)
            {
                appHost.Resolve<ILogger<ConfigureAuthRepository>>()?.LogError(ex, "❌ Failed to register auth events");
            }
        });

    // Add initial Users to the configured Auth Repository
    public void CreateUser(IAuthRepository authRepo, string buasri_id, string name, string password, string[] roles)
    {
        try
        {
            if (authRepo.GetUserAuthByUserName(buasri_id) == null)
            {
                var newAdmin = new SWUAccount { UserName = buasri_id, DisplayName = name };
                var user = authRepo.CreateUserAuth(newAdmin, password);
                authRepo.AssignRoles(user, roles);
            }
        }
        catch (Exception)
        {
            // Ignore errors when creating users (might already exist)
        }
    }
}