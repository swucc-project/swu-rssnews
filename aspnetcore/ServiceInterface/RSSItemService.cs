using SwuNews;
using Grpc.Core;
using Google.Protobuf.WellKnownTypes;

namespace rssnews.ServiceInterface
{
    public class RSSItemService : SwuNews.RSSItemService.RSSItemServiceBase
    {
        private readonly ILogger<RSSItemService> _logger;
        private readonly IRSSItemRepository _rssItemRepository;

        public RSSItemService(ILogger<RSSItemService> logger, IRSSItemRepository rssItemRepository)
        {
            _logger = logger;
            _rssItemRepository = rssItemRepository;
        }

        public override async Task<Item> AddRSSItem(AddRSSItemRequest request, ServerCallContext context)
        {
            _logger.LogInformation($"Adding RSS Item: {request.Title}");

            var domainItem = ToDomain(request);
            var saved = _rssItemRepository.Add(domainItem);

            return await Task.FromResult(ToGrpc(saved));
        }

        public override Task<GetRSSItemsResponse> GetRSSItems(Empty request, ServerCallContext context)
        {
            var items = _rssItemRepository.GetAll()
                    .Select(ToGrpc);

            var response = new GetRSSItemsResponse();
            response.Items.AddRange(items);

            return Task.FromResult(response);
        }

        public override Task<Item> GetRSSItemByID(GetRSSItemRequest request, ServerCallContext context)
        {
            var item = _rssItemRepository.GetById(request.ItemId);

            if (item == null)
                throw new RpcException(new Status(StatusCode.NotFound, "Item not found"));

            return Task.FromResult(ToGrpc(item));
        }

        public override async Task<Item> UpdateRSSItem(UpdateRSSItemRequest request, ServerCallContext context)
        {
            var domain = new rssnews.Models.Item
            {
                ItemID = request.ItemId,
                Title = request.Title,
                Link = request.Link,
                Description = request.Description,
                PublishedDate = request.PublishedDate != null
                    ? request.PublishedDate.ToDateTime()
                    : DateTime.UtcNow,
                AuthorID = request.Author?.AuthorId ?? string.Empty,
                CategoryID = request.Category?.Id ?? 0
            };

            var updatedItem = _rssItemRepository.Update(domain);

            if (updatedItem == null)
                throw new RpcException(new Status(StatusCode.NotFound, "Item not found"));

            return await Task.FromResult(ToGrpc(updatedItem));
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

        private rssnews.Models.Item ToDomain(AddRSSItemRequest request)
        {
            return new rssnews.Models.Item
            {
                Title = request.Title,
                Link = request.Link,
                Description = request.Description,
                PublishedDate = request.PublishedDate != null
                    ? request.PublishedDate.ToDateTime()
                    : DateTime.UtcNow,
                AuthorID = request.Author?.AuthorId ?? string.Empty,
                CategoryID = request.Category?.Id ?? 0
            };
        }

        private SwuNews.Item ToGrpc(rssnews.Models.Item domain)
        {
            var authorData = _rssItemRepository.GetAuthorById(domain.AuthorID);
            var categoryName = _rssItemRepository.GetCategoryById(domain.CategoryID);
            return new SwuNews.Item
            {
                ItemId = domain.ItemID,
                Title = domain.Title,
                Link = domain.Link,
                Description = domain.Description,
                PublishedDate = Timestamp.FromDateTime(DateTime.SpecifyKind(domain.PublishedDate, DateTimeKind.Utc)),
                Author = new SwuNews.Author
                {
                    AuthorId = domain.AuthorID,
                    Firstname = authorData?.firstname ?? "",
                    Lastname = authorData?.lastname ?? ""
                },
                Category = new SwuNews.Category
                {
                    Id = domain.CategoryID,
                    Name = categoryName ?? ""
                }
            };
        }
    }
}