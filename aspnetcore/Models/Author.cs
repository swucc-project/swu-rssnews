using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace rssnews.Models
{
    [Table("Author")]
    public class Author
    {
        [Column("AuthorID")]
        [Key]
        [MaxLength(50)]
        public string AuthorID { get; set; } = "";

        [Column("FirstName")]
        [MaxLength(100)]
        public string FirstName { get; set; } = "";

        [Column("LastName")]
        [MaxLength(100)]
        public string LastName { get; set; } = "";

        public virtual ICollection<Item> Items { get; set; } = [];
    }
}