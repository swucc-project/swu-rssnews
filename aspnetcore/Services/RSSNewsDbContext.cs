using Microsoft.EntityFrameworkCore;
using rssnews.Models;

namespace rssnews.Services
{
    public class RSSNewsDbContext(DbContextOptions<RSSNewsDbContext> options) : DbContext(options)
    {
        public DbSet<Item> Items { get; set; }

        public DbSet<Category> Categories { get; set; }

        public DbSet<Author> Authors { get; set; }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Item>()
                .HasKey(i => i.ItemID)
                .HasName("PK_Item");

            modelBuilder.Entity<Item>()
                .HasOne(i => i.Category)
                .WithMany()
                .HasForeignKey(i => i.CategoryID)
                .HasConstraintName("FK_Category");

            modelBuilder.Entity<Item>()
                .HasOne(i => i.Author)
                .WithMany()
                .HasForeignKey(i => i.AuthorID)
                .HasConstraintName("FK_Author");

            modelBuilder.Entity<Category>()
                .HasKey(c => c.CategoryID)
                .HasName("PK_Category");

            modelBuilder.Entity<Author>()
                .HasKey(a => a.AuthorID)
                .HasName("PK_Author");
        }
    }
}