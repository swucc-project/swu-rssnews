using rssnews.Models;
using rssnews.GraphQL.InputType;
using rssnews.GraphQL.Repository;
using HotChocolate.Authorization;
using HotChocolate.Subscriptions;

namespace rssnews.GraphQL.Handlers
{
    [Authorize]
    public class RSSNewsMutation
    {
        [GraphQLDescription("Adds a new RSS item.")]
        public async Task<Item> AddItem(
            [Service] IItemService itemService,
            [Service] ILogger<RSSNewsMutation> logger,
            [Service] ITopicEventSender eventSender,
            [GraphQLName("input")]
            [GraphQLType<NonNullType<ItemInputType>>] ItemInput input)
        {
            try
            {
                var newItemModel = new Item
                {
                    Title = input.Title,
                    Link = input.Link,
                    Description = input.Description,
                    PublishedDate = input.PublishedDate,
                    CategoryID = input.CategoryId,
                    AuthorID = input.AuthorId,
                };
                var newItem = await itemService.AddRSSItem(newItemModel);
                await eventSender.SendAsync("OnItemAdded", newItem);
                return newItem;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error adding item");
                throw new GraphQLException($"Error adding item: {ex.Message}");
            }
        }

        [Authorize(Policy = "AdminPolicy")]
        [GraphQLDescription("Updates an existing RSS item.")]
        public async Task<Item> UpdateItem(
            [Service] IItemService itemService,
            [Service] ILogger<RSSNewsMutation> logger,
            [Service] ITopicEventSender eventSender,
            string id,
            [GraphQLName("input")]
            [GraphQLType<NonNullType<ItemInputType>>] ItemInput input)
        {
            try
            {
                // ไม่จำเป็นต้องสร้าง Item ใหม่ทั้งหมด
                // เพียงแค่ส่ง ItemInput ไป หรือสร้าง Item จาก ItemInput
                // แต่เนื่องจาก service รับ Item เราก็สร้างตรงนี้
                var updatedItemModel = new Item
                {
                    // ItemID จะถูกละเว้นในการอัปเดตใน service เพราะเราหาจาก ID ที่ให้มา
                    Title = input.Title,
                    Link = input.Link,
                    Description = input.Description,
                    PublishedDate = input.PublishedDate,
                    CategoryID = input.CategoryId,
                    AuthorID = input.AuthorId,
                };

                logger.LogInformation("Updating item with ID: {ID}", id);
                var result = await itemService.UpdateRSSItem(id, updatedItemModel);
                await eventSender.SendAsync(nameof(RSSNewsSubscription.OnItemUpdated), result);
                return result;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error updating item");
                throw new GraphQLException($"Error updating item: {ex.Message}");
            }
        }

        [Authorize(Policy = "AdminPolicy")]
        [GraphQLDescription("Deletes an RSS item by ID.")]
        // เปลี่ยน return type เป็น string หรือ bool เพื่อบอกว่าลบสำเร็จหรือไม่ หรือ ID ของสิ่งที่ถูกลบ
        public async Task<string> DeleteRssItem(
            [Service] IItemService itemService,
            [Service] ILogger<RSSNewsMutation> logger,
            [Service] ITopicEventSender eventSender,
            [GraphQLType<NonNullType<StringType>>] string id)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                throw new GraphQLException("ID must be provided for deletion.");
            }

            try
            {
                logger.LogInformation("Deleting item with ID: {ID}", id);
                await itemService.DeleteRSSItem(id);
                await eventSender.SendAsync(nameof(RSSNewsSubscription.OnItemDeleted), id);
                return id;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error deleting item");
                throw new GraphQLException($"Error deleting item: {ex.Message}");
            }
        }

        public async Task<Message> SendBulkMessage(string content, string type, [Service] ITopicEventSender sender, CancellationToken cancellationToken)
        {
            var message = new Message
            {
                Content = content,
                Type = type,
                Timestamp = DateTime.UtcNow
            };

            await sender.SendAsync("BulkMessageTopic", message, cancellationToken);

            return message;
        }
    }
}