using ServiceStack;
using rssnews.Models;
using rssnews.ServiceModel;
using rssnews.GraphQL.Handlers;
using rssnews.GraphQL.Repository;
using HotChocolate.Subscriptions;

namespace rssnews.ServiceInterface
{
    public class DeleteRSSItemService : Service
    {
        private readonly IItemService _itemService;
        private readonly ITopicEventSender _topicEventSender;
        public DeleteRSSItemService(IItemService itemService, ITopicEventSender topicEventSender)
        {
            _itemService = itemService;
            _topicEventSender = topicEventSender;
        }
        public async Task<DeleteRSSItemResponse> Delete(DeleteRSSItemRequest request)
        {
            try
            {
                await _itemService.DeleteRSSItem(request.Id);
                await _topicEventSender.SendAsync(nameof(RSSNewsSubscription.OnItemDeleted), request.Id);
                return new DeleteRSSItemResponse { Deleted = true, ResponseStatus = new ResponseStatus { Message = "RSS Item deleted successfully." } };
            }
            catch (Exception ex)
            {
                return new DeleteRSSItemResponse
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