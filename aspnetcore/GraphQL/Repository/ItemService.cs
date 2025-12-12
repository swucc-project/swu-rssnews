using Microsoft.EntityFrameworkCore;
using rssnews.Models;
using rssnews.Services;

namespace rssnews.GraphQL.Repository
{
    public interface IItemService
    {
        IQueryable<Item> GetRSSItems(); // ไม่ต้อง async เพราะยังไม่ได้ดึงข้อมูลจริง
        Task<Item?> GetRSSItemById(string id);
        IQueryable<Item> GetRSSItemByCategory(int categoryId);
        Task<Item> AddRSSItem(Item item);
        Task<Item> UpdateRSSItem(string id, Item item);
        Task DeleteRSSItem(string id);
    }
    public class ItemService(RSSNewsDbContext dbContext) : IItemService
    {
        private readonly RSSNewsDbContext _dbContext = dbContext;

        // ไม่ต้องเป็น async Task<List<Item>> อีกต่อไป
        public IQueryable<Item> GetRSSItems()
        {
            return _dbContext.Items
                    .Include(i => i.Category)
                    .Include(i => i.Author)
                    .AsNoTracking(); // ยังคงใช้ AsNoTracking() เพื่อประสิทธิภาพ
        }

        public async Task<Item?> GetRSSItemById(string id)
        {
            return await _dbContext.Items
                    .Include(i => i.Category)
                    .Include(i => i.Author)
                    .Where(index => index.ItemID == id)
                    .AsNoTracking()
                    .FirstOrDefaultAsync();
        }

        // ไม่ต้องเป็น async Task<List<Item>> อีกต่อไป
        public IQueryable<Item> GetRSSItemByCategory(int categoryId)
        {
            return _dbContext.Items
            .Include(i => i.Category)
            .Where(index => index.CategoryID == categoryId)
            .AsNoTracking();
        }

        public async Task<Item> AddRSSItem(Item item)
        {
            item.ItemID = Guid.NewGuid().ToString();
            _dbContext.Add(item);
            await _dbContext.SaveChangesAsync();
            return item;
        }

        public async Task<Item> UpdateRSSItem(string id, Item item)
        {
            // สำหรับ ToUpdateItem อาจไม่จำเป็นต้อง AsNoTracking เพราะเราจะติดตามและอัปเดตมัน
            var existingItem = await _dbContext.Items
                .Where(index => index.ItemID == id)
                .FirstOrDefaultAsync();

            if (existingItem == null)
            {
                throw new Exception($"Item with ID '{id}' not found.");
            }

            // อัปเดตคุณสมบัติของ existingItem
            existingItem.Title = item.Title;
            existingItem.Link = item.Link;
            existingItem.Description = item.Description;
            existingItem.PublishedDate = item.PublishedDate;
            existingItem.CategoryID = item.CategoryID;
            existingItem.AuthorID = item.AuthorID;

            // _dbContext.Items.Update(existingItem); // ไม่จำเป็นต้องเรียก Update() เนื่องจาก existingItem ถูกติดตามอยู่แล้ว (attached entity)
            await _dbContext.SaveChangesAsync();
            return existingItem;
        }

        public async Task DeleteRSSItem(string id)
        {
            var itemToDelete = await _dbContext.Items
                .Where(index => index.ItemID == id)
                .FirstOrDefaultAsync();

            if (itemToDelete == null)
            {
                throw new Exception($"Item with ID '{id}' not found.");
            }

            _dbContext.Items.Remove(itemToDelete);
            await _dbContext.SaveChangesAsync();
        }
    }
}