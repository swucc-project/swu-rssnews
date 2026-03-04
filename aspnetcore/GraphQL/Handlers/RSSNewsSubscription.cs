using HotChocolate.Authorization;
using rssnews.Models;

namespace rssnews.GraphQL.Handlers
{
    public class RSSNewsSubscription
    {
        [Authorize]
        [Subscribe]
        [Topic] // ให้ HotChocolate ตั้งชื่อ Topic ให้อัตโนมัติ (OnItemAdded)
        public Item OnItemAdded([EventMessage] Item item) => item;

        // ADDED: Subscription for item updates
        [Authorize]
        [Subscribe]
        [Topic] // Topic: OnItemUpdated
        public Item OnItemUpdated([EventMessage] Item item) => item;

        // ADDED: Subscription for item deletions
        [Authorize]
        [Subscribe]
        [Topic] // Topic: OnItemDeleted
        public string OnItemDeleted([EventMessage] string itemId) => itemId;

        [Authorize]
        [Subscribe]
        [Topic("BulkMessageTopic")]
        public Message BulkMessage([EventMessage] Message message) => message;
    }
}