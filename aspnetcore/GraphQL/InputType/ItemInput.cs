namespace rssnews.GraphQL.InputType
{
    public class ItemInput
    {
        public string Title { get; set; } = "";
        public string Link { get; set; } = "";
        public string Description { get; set; } = "";
        public DateTime PublishedDate { get; set; }
        public int CategoryId { get; set; }
        public string AuthorId { get; set; } = "";
    }
}