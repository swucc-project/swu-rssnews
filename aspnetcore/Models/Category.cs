using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace rssnews.Models
{
    [Table("Category")]
    public class Category
    {
        [Column("CategoryID")]
        [Key]
        public int CategoryID { get; set; }
        [Column("CategoryName")]
        public string CategoryName { get; set; } = "";

        public List<Item> Items { get; set; } = new List<Item>();
    }
}