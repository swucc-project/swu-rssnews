using ServiceStack;
using SwuNews.gRPC;
using Grpc.Core;
using Google.Protobuf.WellKnownTypes;

namespace rssnews.ServiceInterface
{
    public class RSSItemService : SwuNews.gRPC.RSSItemService.RSSItemServiceBase
    {
        private readonly ILogger<RSSItemService> _logger;
        private readonly IRSSItemRepository _rssItemRepository;

        public RSSItemService(ILogger<RSSItemService> logger, IRSSItemRepository rssItemRepository)
        {
            _logger = logger;
            _rssItemRepository = rssItemRepository;
        }

        public override Task<Item> AddRSSItem(AddRSSItemRequest request, ServerCallContext context)
        {
            _logger.LogInformation($"Adding RSS Item: {request.Title}");

            var savedItem = _rssItemRepository.Add(request);

            if (savedItem == null)
            {
                throw new RpcException(new Status(StatusCode.Internal, "Failed to add RSS item."));
            }

            return Task.FromResult(savedItem);
        }

        public override Task<GetRSSItemResponse> GetRSSItems(Empty request, ServerCallContext context)
        {
            _logger.LogInformation("Getting all RSS Items.");

            var rssItems = _rssItemRepository.GetAll();
            var response = new GetRSSItemResponse();
            response.Items.AddRange(rssItems);

            return Task.FromResult(response);
        }

        public override Task<Item> GetRSSItemByID(GetRSSItemsRequest request, ServerCallContext context)
        {
            _logger.LogInformation($"Getting RSS Item by ID: {request.ItemId}");

            var item = _rssItemRepository.GetById(request.ItemId);

            if (item == null)
            {
                throw new RpcException(new Status(StatusCode.NotFound, $"Item with ID '{request.ItemId}' not found."));
            }

            return Task.FromResult(item);
        }

        public override Task<Item> UpdateRSSItem(UpdateRSSItemRequest request, ServerCallContext context)
        {
            _logger.LogInformation($"Updating RSS Item ID: {request.ItemId}");

            var updatedItem = _rssItemRepository.Update(request);

            if (updatedItem == null)
            {
                throw new RpcException(new Status(StatusCode.NotFound, $"RSS Item with ID {request.ItemId} not found for update."));
            }

            return Task.FromResult(updatedItem);
        }

        public override Task<DeleteRSSItemResponse> DeleteRSSItem(DeleteRSSItemRequest request, ServerCallContext context)
        {
            _logger.LogInformation($"Attempting to delete RSS Item. ID: {request.ItemId}");

            bool deleteSuccess = false;

            if (!string.IsNullOrEmpty(request.ItemId))
            {
                deleteSuccess = _rssItemRepository.DeleteById(request.ItemId);
            }
            else
            {
                throw new RpcException(new Status(StatusCode.InvalidArgument, "ItemId must be provided for deletion."));
            }

            if (!deleteSuccess)
            {
                throw new RpcException(new Status(StatusCode.NotFound, "RSS Item not found or could not be deleted."));
            }

            var response = new DeleteRSSItemResponse { Success = deleteSuccess };
            return Task.FromResult(response);
        }
    }
}