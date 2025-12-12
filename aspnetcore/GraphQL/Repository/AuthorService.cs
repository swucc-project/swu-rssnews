using Microsoft.EntityFrameworkCore;
using rssnews.Models;
using rssnews.Services;

namespace rssnews.GraphQL.Repository
{
    public interface IAuthorService
    {
        Task<List<Author>> GetAuthors();
        Task<Author?> GetAuthorById(string authorID);
    }
    public class AuthorService(RSSNewsDbContext dbContext) : IAuthorService
    {
        private readonly RSSNewsDbContext _dbContext = dbContext;
        public async Task<List<Author>> GetAuthors()
        {
            return await _dbContext.Authors
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Author?> GetAuthorById(string authorID)
        {
            return await _dbContext.Authors
                .Where(k => k.AuthorID == authorID)
                .AsNoTracking()
                .FirstOrDefaultAsync();
        }
    }
}