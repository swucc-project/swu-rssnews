namespace rssnews.Models
{
    public class Message
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string Content { get; set; } = string.Empty;
        public string Type { get; set; } = "info"; // info, success, warning, error
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        public string? UserId { get; set; }
        public Dictionary<string, object>? Metadata { get; set; }
    }
}