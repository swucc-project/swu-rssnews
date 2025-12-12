using ServiceStack;
using ServiceStack.Auth;
using ServiceStack.FluentValidation;
using ServiceStack.Html;

[assembly: HostingStartup(typeof(rssnews.ConfigureAuth))]

namespace rssnews;

// Add any additional metadata properties you want to store in the Users Typed Session
public class CustomUserSession : AuthUserSession
{
    public string? ReturnUrl { get; set; }
}

// Custom Validator to add custom validators to built-in /register Service requiring DisplayName and ConfirmPassword
public class CustomRegistrationValidator : RegistrationValidator
{
    public CustomRegistrationValidator()
    {
        RuleSet(ApplyTo.Post, () =>
        {
            RuleFor(x => x.DisplayName).NotEmpty();
            RuleFor(x => x.ConfirmPassword).NotEmpty();
        });
    }
}

public class ConfigureAuth : IHostingStartup
{
    public void Configure(IWebHostBuilder builder) => builder
        .ConfigureServices(services =>
        {
            // Enable /register Service
            services.AddPlugin(new RegistrationFeature());

            // Override the default registration validation with your own custom implementation
            services.AddSingleton<IValidator<Register>, CustomRegistrationValidator>();
        })
        .ConfigureAppHost(appHost =>
        {
            var appSettings = appHost.AppSettings;

            // Configure AuthFeature (ทำครั้งเดียวที่นี่)
            appHost.Plugins.Add(new AuthFeature(() => new CustomUserSession(),
            [
                new CredentialsAuthProvider(appSettings)
            ])
            {
                HtmlRedirect = "~/rss/signin",
                HtmlRedirectAccessDenied = "~/rss/failed",
                IncludeAssignRoleServices = false,
                ValidateRedirectLinks = AuthFeature.AllowAllRedirects,
                MaxLoginAttempts = 5,
                // เพิ่ม session timeout settings
                SessionExpiry = TimeSpan.FromMinutes(30),
                PermanentSessionExpiry = TimeSpan.FromDays(7),
            });

            // Configure Admin Users UI
            appHost.Plugins.Add(new AdminUsersFeature
            {
                // Show custom fields in Search Results
                QueryUserAuthProperties =
                [
                    nameof(SWUAccount.BuasriID),
                    nameof(SWUAccount.PersonalName),
                    nameof(SWUAccount.Surname),
                    nameof(SWUAccount.Position),
                    nameof(SWUAccount.Faculty),
                    nameof(SWUAccount.Department),
                    nameof(SWUAccount.InternalPhone)
                ],
                QueryMediaRules =
                [
                    MediaRules.ExtraSmall.Show<SWUAccount>(x => new { x.Id, x.UserName, x.DisplayName }),
                    MediaRules.Small.Show<SWUAccount>(x => x.Department)
                ],
                // Add Custom Fields to Create/Edit User Forms
                FormLayout =
                [
                    Input.For<SWUAccount>(x => x.UserName, c => c.Label = "รหัสบัวศรี"),
                    Input.For<SWUAccount>(x => x.DisplayName, c => c.Label = "ชื่อแสดง"),
                    Input.For<SWUAccount>(x => x.BuasriID, c => c.Label = "Buasri ID"),
                    Input.For<SWUAccount>(x => x.PersonalName, c => c.Label = "ชื่อจริง"),
                    Input.For<SWUAccount>(x => x.Surname, c => c.Label = "นามสกุล"),
                    Input.For<SWUAccount>(x => x.Position, c => c.Label = "ตำแหน่ง"),
                    Input.For<SWUAccount>(x => x.Faculty, c => c.Label = "คณะ"),
                    Input.For<SWUAccount>(x => x.Department, c => c.Label = "ภาควิชา"),
                    Input.For<SWUAccount>(x => x.InternalPhone, c => c.Label = "เบอร์ภายใน"),
                ]
            });
        });
}