using ServiceStack;
using Google.Protobuf.WellKnownTypes;
using rssnews.Models;

namespace rssnews.ServiceInterface
{
    public interface IRSSItemRepository
    {
        Item Add(Item item);
        IEnumerable<Item> GetAll();
        Item? GetById(string itemId);
        (string firstname, string lastname)? GetAuthorById(string authorId);
        string? GetCategoryById(int categoryId);
        Item? Update(Item item);
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

        public Item Add(Item item)
        {
            item.ItemID = _nextId++.ToString();
            _inMemoryDb.Add(item);
            return item;
        }

        public IEnumerable<Item> GetAll() => _inMemoryDb;

        public Item? GetById(string itemId) => _inMemoryDb.FirstOrDefault(x => x.ItemID == itemId);
        public (string firstname, string lastname)? GetAuthorById(string authorId) => _authorsData.TryGetValue(authorId, out var author) ? author : null;
        public string? GetCategoryById(int categoryId) => _categoriesData.TryGetValue(categoryId, out var name) ? name : null;

        public Item? Update(Item item)
        {
            var existingItem = _inMemoryDb.FirstOrDefault(i => i.ItemID == item.ItemID); // แก้ไข

            if (existingItem == null)
            {
                return null;
            }

            existingItem.Title = item.Title;
            existingItem.Link = item.Link;
            existingItem.Description = item.Description;
            existingItem.PublishedDate = item.PublishedDate;
            existingItem.AuthorID = item.AuthorID;
            existingItem.CategoryID = item.CategoryID;

            return existingItem;
        }

        public bool DeleteById(string itemId)
        {
            return _inMemoryDb.RemoveAll(item => item.ItemID == itemId) > 0; // แก้ไข
        }
    }
}