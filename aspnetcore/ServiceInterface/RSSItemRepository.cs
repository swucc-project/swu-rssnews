using ServiceStack;
using Google.Protobuf.WellKnownTypes;
using rssnews.Models;

namespace rssnews.ServiceInterface
{
    public interface IRSSItemRepository
    {
        SwuNews.gRPC.Item Add(SwuNews.gRPC.AddRSSItemRequest request);
        IEnumerable<SwuNews.gRPC.Item> GetAll();
        SwuNews.gRPC.Item? GetById(string itemId);
        SwuNews.gRPC.Item? Update(SwuNews.gRPC.UpdateRSSItemRequest request);
        bool DeleteById(string itemId);
    }
    public class RSSItemRepository : IRSSItemRepository
    {
        private readonly List<Item> _inMemoryDb = [];
        private int _nextId = 1;

        private readonly Dictionary<string, (string firstname, string lastname)> _authorsData = new()
        {
            { "A001", ("สมชาย", "ใจดี") },
            { "A002", ("สมหญิง", "รักชาติ") }
        };

        private readonly Dictionary<int, string> _categoriesData = new()
        {
            { 101, "ข่าวการศึกษา" },
            { 102, "ข่าวกิจกรรม" }
        };

        public RSSItemRepository()
        {
            // แก้ไข: ใช้ ItemID แทน Id
            _inMemoryDb.Add(new Item
            {
                ItemID = _nextId++.ToString(),
                Title = "ตัวอย่างข่าว 1",
                Link = "http://example.com/news/1",
                Description = "คำอธิบายข่าวตัวอย่าง 1",
                PublishedDate = new DateTime(2025, 6, 10, 10, 0, 0, DateTimeKind.Utc),
                AuthorID = "A001",
                CategoryID = 101
            });

            _inMemoryDb.Add(new Item
            {
                ItemID = _nextId++.ToString(),
                Title = "ตัวอย่างข่าว 2",
                Link = "http://example.com/news/2",
                Description = "คำอธิบายข่าวตัวอย่าง 2",
                PublishedDate = new DateTime(2025, 6, 9, 15, 30, 0, DateTimeKind.Utc),
                AuthorID = "A002",
                CategoryID = 102
            });
        }

        private SwuNews.gRPC.Item? ToGrpcItem(Item? domainItem)
        {
            if (domainItem == null) return null;

            var authorInfo = _authorsData.GetValueOrDefault(domainItem.AuthorID, ("Unknown", "Author"));
            var categoryName = _categoriesData.GetValueOrDefault(domainItem.CategoryID, "Unknown Category");

            return new SwuNews.gRPC.Item
            {
                ItemId = domainItem.ItemID, // แก้ไข
                Title = domainItem.Title,
                Link = domainItem.Link,
                Description = domainItem.Description,
                PublishedDate = Timestamp.FromDateTime(domainItem.PublishedDate),
                Author = new SwuNews.gRPC.Author
                {
                    AuthorId = domainItem.AuthorID,
                    Firstname = authorInfo.Item1,
                    Lastname = authorInfo.Item2
                },
                Category = new SwuNews.gRPC.Category
                {
                    Id = domainItem.CategoryID,
                    Name = categoryName
                }
            };
        }

        public SwuNews.gRPC.Item Add(SwuNews.gRPC.AddRSSItemRequest request)
        {
            var newItem = new Item
            {
                ItemID = _nextId++.ToString(), // แก้ไข
                Title = request.Title,
                Link = request.Link,
                Description = request.Description,
                PublishedDate = request.PublishedDate.ToDateTime(),
                AuthorID = request.Author.AuthorId,
                CategoryID = request.Category.Id
            };

            _inMemoryDb.Add(newItem);
            return ToGrpcItem(newItem)!;
        }

        public IEnumerable<SwuNews.gRPC.Item> GetAll()
        {
            return _inMemoryDb.Select(ToGrpcItem).ToList()!;
        }

        public SwuNews.gRPC.Item? GetById(string itemId)
        {
            var domainItem = _inMemoryDb.FirstOrDefault(item => item.ItemID == itemId);
            if (domainItem == null)
            {
                return null;
            }
            return ToGrpcItem(domainItem);
        }

        public SwuNews.gRPC.Item? Update(SwuNews.gRPC.UpdateRSSItemRequest request)
        {
            var existingItem = _inMemoryDb.FirstOrDefault(item => item.ItemID == request.ItemId); // แก้ไข

            if (existingItem == null)
            {
                return null;
            }

            existingItem.Title = request.Title;
            existingItem.Link = request.Link;
            existingItem.Description = request.Description;
            existingItem.PublishedDate = request.PublishedDate.ToDateTime();
            existingItem.AuthorID = request.Author.AuthorId;
            existingItem.CategoryID = request.Category.Id;

            return ToGrpcItem(existingItem);
        }

        public bool DeleteById(string itemId)
        {
            return _inMemoryDb.RemoveAll(item => item.ItemID == itemId) > 0; // แก้ไข
        }
    }
}