using ServiceStack;
using rssnews.Models;

namespace rssnews.ServiceModel
{
    [Route("/rss/{CategoryId}", "GET")]
    [Route("/rss", "GET")]
    public class GetRSSItemsRequest : IReturn<GetRSSItemsResponse>
    {
        public int? CategoryID { get; set; }
    }
    public class GetRSSItemsResponse
    {
        public List<Item> Items { get; set; } = [];
        public string Message { get; set; } = "";
        public string RssFeedUrl { get; set; } = "";
        public List<Category> Categories { get; set; } = [];
        public Category? SelectedCategory { get; set; }
        public ResponseStatus? ResponseStatus { get; set; }
    }

    [Route("/rss/add", "POST")]
    public class AddRSSItemRequest : IReturn<AddRSSItemResponse>
    {
        public string Title { get; set; } = "";
        public string Link { get; set; } = "";
        public string Description { get; set; } = "";
        public DateTime PublishedDate { get; set; }
        public int CategoryID { get; set; }
        public string AuthorID { get; set; } = "";
    }
    [Route("/api/rssfeed", "GET")]
    public class GetRSSFeed : IReturn<object>
    {
        public string? CategoryID { get; set; }
        public string? CategoryName { get; set; }
    }

    // Response DTO for AddRSSItem
    public class AddRSSItemResponse
    {
        public string ItemID { get; set; } = "";
        public string Message { get; set; } = "";
        public ResponseStatus? ResponseStatus { get; set; } // Make nullable for consistency
    }
    [Route("/rss/item-for-update/{ItemId}", "GET")]
    public class GetRSSItemForUpdateRequest : IReturn<GetRSSItemForUpdateResponse>
    {
        public string ItemID { get; set; } = ""; // ใช้ string สำหรับ ID, ถ้าเป็น Guid หรือ Int ก็เปลี่ยน Type
    }
    public class RSSItemDTO
    {
        public string ItemID { get; set; } = "";
        public string Title { get; set; } = "";
        public string Link { get; set; } = "";
        public string Description { get; set; } = "";
        public DateTime? PubDate { get; set; }
        public int? CategoryID { get; set; }
        public string AuthorID { get; set; } = "";
    }
    public class CategoryDTO
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
    }

    public class AuthorDTO
    {
        public string AuthorID { get; set; } = "";
        public string Firstname { get; set; } = "";
        public string Lastname { get; set; } = "";
    }
    public class GetRSSItemForUpdateResponse
    {
        public Item? InitialRssItem { get; set; }
        public List<Category> InitialCategories { get; set; } = [];
        public List<Author> InitialAuthors { get; set; } = [];
        public ResponseStatus? ResponseStatus { get; set; }
    }
    [Route("/rss/update", "PUT")]
    public class UpdateRSSItemRequest : IReturn<UpdateRSSItemResponse>
    {
        public string Id { get; set; } = "";
        public string Title { get; set; } = "";
        public string Link { get; set; } = "";
        public string Description { get; set; } = "";
        public DateTime PublishedDate { get; set; }
        public int CategoryID { get; set; }
        public string AuthorID { get; set; } = "";
    }
    public class UpdateRSSItemResponse
    {
        public bool Updated { get; set; }
        public string Message { get; set; } = "";
        public ResponseStatus? ResponseStatus { get; set; }
    }
    [Route("/rss/delete/{Id}", "DELETE")]
    public class DeleteRSSItemRequest : IReturn<DeleteRSSItemResponse>
    {
        public string Id { get; set; } = ""; // ใช้ ItemId แทน Slug
    }

    public class DeleteRSSItemResponse
    {
        public bool Deleted { get; set; }
        public ResponseStatus? ResponseStatus { get; set; } // Make nullable
    }
    [Route("/rss/bulk-delete", "POST")] // เปลี่ยน Route เพื่อไม่ให้ชนกับ DeleteRSSItem
    public class DeleteRSSRequest : IReturn<DeleteRSSResponse>
    {
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
    }
    public class DeleteRSSResponse
    {
        public int DeletedCount { get; set; }
        public string Message { get; set; } = "";
        public ResponseStatus? ResponseStatus { get; set; } // Make nullable
    }
}