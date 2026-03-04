using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using rssnews.Models;

namespace rssnews.Services
{
    public class RSSNewsDbContext(DbContextOptions<RSSNewsDbContext> options) : DbContext(options)
    {
        public DbSet<Item> Items { get; set; } = null!;
        public DbSet<Category> Categories { get; set; } = null!;
        public DbSet<Author> Authors { get; set; } = null!;

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            optionsBuilder.ConfigureWarnings(warnings =>
            {
                warnings.Ignore(RelationalEventId.PendingModelChangesWarning);
                // ✅ เพิ่ม: ปิด warning สำหรับ sensitive data ใน production
                warnings.Log(RelationalEventId.QueryPossibleUnintendedUseOfEqualsWarning);
            });

            base.OnConfiguring(optionsBuilder);
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // ═══════════════════════════════════════════════════════════
            // 📂 Category Entity Configuration
            // ═══════════════════════════════════════════════════════════
            modelBuilder.Entity<Category>(entity =>
            {
                entity.ToTable("Category");
                entity.HasKey(c => c.CategoryID).HasName("PK_Category");

                entity.Property(c => c.CategoryID)
                    .HasColumnName("CategoryID")
                    .ValueGeneratedOnAdd();

                entity.Property(c => c.CategoryName)
                    .HasColumnName("CategoryName")
                    .IsRequired()
                    .HasMaxLength(200);

                entity.HasIndex(c => c.CategoryName)
                    .IsUnique()
                    .HasDatabaseName("UQ_Category_CategoryName");
            });

            // ═══════════════════════════════════════════════════════════
            // ✍️ Author Entity Configuration
            // ═══════════════════════════════════════════════════════════
            modelBuilder.Entity<Author>(entity =>
            {
                entity.ToTable("Author");
                entity.HasKey(a => a.AuthorID).HasName("PK_Author");

                entity.Property(a => a.AuthorID)
                    .HasColumnName("AuthorID")
                    .HasMaxLength(50);

                entity.Property(a => a.FirstName)
                    .HasColumnName("FirstName")
                    .HasMaxLength(100);

                entity.Property(a => a.LastName)
                    .HasColumnName("LastName")
                    .HasMaxLength(100);

                entity.HasIndex(a => new { a.FirstName, a.LastName })
                    .HasDatabaseName("IX_Author_Name");
            });

            // ═══════════════════════════════════════════════════════════
            // 📰 Item Entity Configuration
            // ═══════════════════════════════════════════════════════════
            modelBuilder.Entity<Item>(entity =>
            {
                entity.ToTable("Item");
                entity.HasKey(i => i.ItemID).HasName("PK_Item");

                entity.Property(i => i.ItemID)
                    .HasColumnName("ItemID")
                    .HasMaxLength(36);  // GUID string length

                entity.Property(i => i.Title)
                    .HasColumnName("Title")
                    .IsRequired()
                    .HasMaxLength(500);

                entity.Property(i => i.Link)
                    .HasColumnName("Link")
                    .HasMaxLength(2000);

                entity.Property(i => i.Description)
                    .HasColumnName("Description")
                    .HasColumnType("nvarchar(max)");

                entity.Property(i => i.PublishedDate)
                    .HasColumnName("PublishedDate")
                    .HasColumnType("datetime2");

                entity.Property(i => i.CategoryID)
                    .HasColumnName("CategoryID");

                entity.Property(i => i.AuthorID)
                    .HasColumnName("AuthorID")
                    .HasMaxLength(50);

                // ✅ Foreign Key Relationships
                entity.HasOne(i => i.Category)
                    .WithMany(c => c.Items)
                    .HasForeignKey(i => i.CategoryID)
                    .HasConstraintName("FK_Item_Category")
                    .OnDelete(DeleteBehavior.Restrict)
                    .IsRequired();

                entity.HasOne(i => i.Author)
                    .WithMany(a => a.Items)
                    .HasForeignKey(i => i.AuthorID)
                    .HasConstraintName("FK_Item_Author")
                    .OnDelete(DeleteBehavior.Restrict)
                    .IsRequired();

                // Indexes
                entity.HasIndex(i => i.PublishedDate)
                    .HasDatabaseName("IX_Item_PublishedDate");

                entity.HasIndex(i => i.CategoryID)
                    .HasDatabaseName("IX_Item_CategoryID");

                entity.HasIndex(i => i.AuthorID)
                    .HasDatabaseName("IX_Item_AuthorID");
            });

            modelBuilder.UseCollation("Thai_CI_AS");

            base.OnModelCreating(modelBuilder);
        }
    }
}