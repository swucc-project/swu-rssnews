using ServiceStack;
using ServiceStack.Data;
using ServiceStack.OrmLite;
using rssnews.Models;
using rssnews.ServiceModel;
using rssnews.GraphQL.Handlers;
using rssnews.GraphQL.Repository;
using HotChocolate.Subscriptions;

namespace rssnews.ServiceInterface
{
    public class UpdateRSSItemService : Service
    {
        private readonly IItemService _itemService;
        private readonly ITopicEventSender _topicEventSender;
        private readonly IDbConnectionFactory _dbFactory;

        public UpdateRSSItemService(IItemService itemService, ITopicEventSender topicEventSender, IDbConnectionFactory dbFactory)
        {
            _itemService = itemService;
            _topicEventSender = topicEventSender;
            _dbFactory = dbFactory;
        }

        public async Task<GetRSSItemForUpdateResponse> Get(GetRSSItemForUpdateRequest request)
        {
            using (var db = await _dbFactory.OpenAsync())
            {
                var rssItem = await db.SingleByIdAsync<Item>(request.ItemID);
                if (rssItem == null)
                {
                    return new GetRSSItemForUpdateResponse
                    {
                        ResponseStatus = new ResponseStatus { ErrorCode = "NotFound", Message = $"RSS Item with ID '{request.ItemID}' not found." }
                    };
                }

                await db.LoadReferencesAsync(rssItem);

                var categories = await db.SelectAsync<Category>();
                var authors = await db.SelectAsync<Author>();

                return new GetRSSItemForUpdateResponse
                {
                    InitialRssItem = rssItem,
                    InitialCategories = categories,
                    InitialAuthors = authors
                };
            }
        }
        public async Task<UpdateRSSItemResponse> Put(UpdateRSSItemRequest request)
        {
            try
            {
                // REFACTORED: สร้าง Model และเรียกใช้ service กลาง
                var itemToUpdate = new Item
                {
                    Title = request.Title,
                    Link = request.Link,
                    Description = request.Description,
                    CategoryID = request.CategoryID,
                    AuthorID = request.AuthorID,
                    PublishedDate = request.PublishedDate
                };

                var updatedItem = await _itemService.UpdateRSSItem(request.Id, itemToUpdate);

                await _topicEventSender.SendAsync(nameof(RSSNewsSubscription.OnItemUpdated), updatedItem);

                return new UpdateRSSItemResponse { Updated = true, Message = "RSS Item updated successfully." };
            }
            catch (Exception)
            {
                return new UpdateRSSItemResponse
                {
                    ResponseStatus = new ResponseStatus("Error", "An unexpected error occurred while updating the item.")
                };
            }
        }
    }
}