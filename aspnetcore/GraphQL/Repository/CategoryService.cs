using Microsoft.EntityFrameworkCore;
using rssnews.Models;
using rssnews.Services;

namespace rssnews.GraphQL.Repository
{
    public interface ICategoryService
    {
        public Task<List<Category>> GetCategories();
        public Task<Category?> GetCategoryById(int categoryID);
    }
    public class CategoryService(RSSNewsDbContext dbContext) : ICategoryService
    {
        private readonly RSSNewsDbContext _dbContext = dbContext;

        public async Task<List<Category>> GetCategories()
        {
            return await _dbContext.Categories
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Category?> GetCategoryById(int categoryID)
        {
            return await _dbContext.Categories
                .Where(t => t.CategoryID == categoryID)
                .AsNoTracking()
                .FirstOrDefaultAsync();
        }
    }
}