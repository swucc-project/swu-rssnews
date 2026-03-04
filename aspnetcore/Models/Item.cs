using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace rssnews.Models
{
    [Table("Item")]
    public class Item
    {
        [Column("ItemID")]
        [Key]
        public string ItemID { get; set; } = Guid.NewGuid().ToString();

        [Column("Title")]
        public string Title { get; set; } = "";

        [Column("Link")]
        public string Link { get; set; } = "";

        [Column("Description")]
        public string Description { get; set; } = "";

        // ✅ FIX: ต้องตรงกับ DbContext configuration
        [Column("PublishedDate")]  // เปลี่ยนจาก "Published_Date"
        public DateTime PublishedDate { get; set; }

        [Column("CategoryID")]
        public int CategoryID { get; set; }

        [ForeignKey("CategoryID")]
        public Category? Category { get; set; }  // ✅ ใช้ nullable

        [Column("AuthorID")]
        public string AuthorID { get; set; } = "";

        [ForeignKey("AuthorID")]
        public Author? Author { get; set; }  // ✅ ใช้ nullable
    }
}