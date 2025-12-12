using ServiceStack;
using Funq;
using ServiceStack.ProtoBuf;
using rssnews.ServiceInterface;
using rssnews.Services;

namespace rssnews;

public class AppHost() : AppHostBase("SWU News & Events application", typeof(RSSFeedService).Assembly)
{
    public override void Configure(Container container)
    {
        base.SetConfig(new HostConfig
        {
            EnableFeatures = Feature.All.Remove(Feature.Html),
            DebugMode = AppSettings.Get("DebugMode", false),
            DefaultRedirectPath = "/rss",
            WebHostUrl = Environment.GetEnvironmentVariable("PUBLIC_BASE_URL") ?? "https://news.swu.ac.th",
            UseSameSiteCookies = !HostingEnvironment.IsDevelopment()
        });

        // Register Services
        container.RegisterAutoWiredAs<AddRSSItemService, AddRSSItemService>();
        container.RegisterAutoWiredAs<UpdateRSSItemService, UpdateRSSItemService>();
        container.RegisterAutoWiredAs<DeleteRSSItemService, DeleteRSSItemService>();
        container.RegisterAutoWiredAs<BulkDeleteRSSService, BulkDeleteRSSService>();
        container.RegisterAutoWiredAs<AuthService, AuthService>();
        container.RegisterAutoWiredAs<RSSFeedService, RSSFeedService>();

        // Add Plugins
        Plugins.Add(new AutoQueryFeature
        {
            MaxLimit = 100
        });
        Plugins.Add(new SessionFeature());
        Plugins.Add(new RequestLogsFeature());
        Plugins.Add(new AdminDatabaseFeature());  // เพิ่มที่นี่แทน
        Plugins.Add(new GrpcFeature(App));
        Plugins.Add(new ProtoBufFormat());
    }
}