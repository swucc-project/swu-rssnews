using ServiceStack;
using HotChocolate.Subscriptions;
using rssnews.GraphQL.Handlers;
using rssnews.GraphQL.Repository;
using rssnews.Models;
using rssnews.ServiceModel;

namespace rssnews.ServiceInterface
{
    public class AddRSSItemService : Service
    {
        private readonly IItemService _itemService;
        private readonly ITopicEventSender _topicEventSender;
        public AddRSSItemService(IItemService itemService, ITopicEventSender topicEventSender)
        {
            _itemService = itemService;
            _topicEventSender = topicEventSender;
        }
        public async Task<object> Post(AddRSSItemRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Title) || string.IsNullOrEmpty(request.Link))
                {
                    throw new ArgumentException("Title and Link are required.");
                }

                var newItem = new Item
                {
                    Title = request.Title,
                    Link = request.Link,
                    Description = request.Description,
                    CategoryID = request.CategoryID,
                    AuthorID = request.AuthorID,
                    PublishedDate = request.PublishedDate
                };

                var addedItem = await _itemService.AddRSSItem(newItem);
                await _topicEventSender.SendAsync(nameof(RSSNewsSubscription.OnItemAdded), addedItem);
                return new AddRSSItemResponse
                {
                    ItemID = newItem.ItemID,
                    Message = "RSS Item added successfully!"
                };
            }
            catch (Exception ex)
            {
                return new AddRSSItemResponse
                {
                    ResponseStatus = new ResponseStatus
                    {
                        ErrorCode = ex.GetType().Name,
                        Message = ex.Message,
                        StackTrace = ex.StackTrace
                    }
                };
            }
        }
    }
}