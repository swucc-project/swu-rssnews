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

        // CHANGED: เปลี่ยนชื่อ Property เป็น PascalCase ตามมาตรฐาน C#
        [Column("Published_Date")]
        public DateTime PublishedDate { get; set; }

        [Column("CategoryID")]
        public int CategoryID { get; set; }
        public Category Category { get; set; } = null!; // Navigation Property

        [Column("AuthorID")]
        public string AuthorID { get; set; } = "";
        public Author Author { get; set; } = null!;
    }
}