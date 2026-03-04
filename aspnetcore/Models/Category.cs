using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace rssnews.Models
{
    [Table("Category")]
    public class Category
    {
        [Column("CategoryID")]
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int CategoryID { get; set; }

        [Column("CategoryName")]
        [Required]
        [MaxLength(200)]
        public string CategoryName { get; set; } = "";

        // ✅ Navigation property - ใช้ virtual สำหรับ lazy loading
        public virtual ICollection<Item> Items { get; set; } = [];
    }
}