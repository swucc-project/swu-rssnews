using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace rssnews.Models
{
    [Table("Author")]
    public class Author
    {
        [Column("AuthorID")]
        [Key]
        public string AuthorID { get; set; } = "";
        [Column("FirstName")]
        public string FirstName { get; set; } = "";
        [Column("LastName")]
        public string LastName { get; set; } = "";

        public List<Item> Items { get; set; } = new List<Item>();
    }
}