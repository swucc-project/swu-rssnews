using ServiceStack;
using ServiceStack.OrmLite;
using ServiceStack.Data;
using System.ServiceModel.Syndication;
using System.Text;
using System.Xml;
using ServiceStack.Web;
using rssnews.Models;
using rssnews.ServiceModel;

namespace rssnews.Services;

public class RSSFeedService(IDbConnectionFactory dbFactory, IRequest httpRequest) : Service
{
    private readonly IDbConnectionFactory _dbFactory = dbFactory;
    private readonly IRequest _httpRequest = httpRequest;

    public object Get(GetRSSFeed request)
    {
        using var db = _dbFactory.Open();
        var feedItemsQuery = db.From<Item>();

        if (!string.IsNullOrEmpty(request.CategoryName))
        {
            feedItemsQuery = feedItemsQuery
                                .Join<Item, Category>((item, category) => item.CategoryID == category.CategoryID)
                                .Where(item => item.Category.CategoryName.EqualsIgnoreCase(request.CategoryName));
        }

        var feedItems = db.LoadSelect(feedItemsQuery);

        var feed = new SyndicationFeed(
            "ระบบข่าวและกิจกรรม มศว",
            "ข่าวและกิจกรรม มศว",
            new Uri(_httpRequest.AbsoluteUri), // ใช้ Request.AbsoluteBaseUri เพื่อความถูกต้อง
            _httpRequest.AbsoluteUri, // Id for the feed itself
            DateTimeOffset.Now
        );
        feed.Links.Add(new SyndicationLink(new Uri(_httpRequest.AbsoluteUri)) { RelationshipType = "alternate" });
        feed.Language = "th";
        feed.Copyright = new TextSyndicationContent("&copy; ฝ่ายระบบสารสนเทศ สำนักคอมพิวเตอร์ มหาวิทยาลัยศรีนครินทรวิโรฒ");

        var items = new List<SyndicationItem>();
        foreach (var rssItem in feedItems)
        {
            var item = new SyndicationItem(
                rssItem.Title,
                new TextSyndicationContent(rssItem.Description, TextSyndicationContentKind.Html),
                new Uri(rssItem.Link),
                rssItem.Link,
                (DateTimeOffset)rssItem.PublishedDate
            );
            item.Categories.Add(new SyndicationCategory(rssItem.Category?.CategoryName));
            item.Authors.Add(new SyndicationPerson("", rssItem.Author?.FirstName + " " + rssItem.Author?.LastName, ""));
            items.Add(item);
        }
        feed.Items = items;

        var settings = new XmlWriterSettings
        {
            Encoding = Encoding.UTF8,
            NewLineOnAttributes = true,
            Indent = true,
        };

        using var stream = new MemoryStream();
        using (var xmlWriter = XmlWriter.Create(stream, settings))
        {
            var formatter = new Rss20FeedFormatter(feed, false);
            formatter.WriteTo(xmlWriter);
            xmlWriter.Flush();
        }

        return new HttpResult(stream.ToArray(), "application/rss+xml");
    }
}