using ServiceStack;
using ServiceStack.Data;
using ServiceStack.OrmLite;
using rssnews.Models;
using rssnews.ServiceModel;
using rssnews.GraphQL.Repository;

namespace rssnews.ServiceInterface
{
    public class BulkDeleteRSSService : Service
    {
        private readonly IItemService _itemService;
        private readonly IDbConnectionFactory _dbFactory;

        public BulkDeleteRSSService(IItemService itemService, IDbConnectionFactory dbFactory)
        {
            _itemService = itemService;
            _dbFactory = dbFactory;
        }
        public async Task<DeleteRSSResponse> Post(DeleteRSSRequest request)
        {
            try
            {
                if (request.StartDate > request.EndDate)
                {
                    return new DeleteRSSResponse
                    {
                        DeletedCount = 0,
                        Message = "Start Date cannot be after End Date.",
                        ResponseStatus = new ResponseStatus { ErrorCode = "InvalidDateRange" }
                    };
                }

                int deletedRows = 0;
                using (var db = await _dbFactory.OpenAsync())
                {
                    deletedRows = await db.DeleteAsync<Item>(x =>
                        x.PublishedDate >= request.StartDate && x.PublishedDate <= request.EndDate);
                }

                return new DeleteRSSResponse { DeletedCount = deletedRows, Message = $"{deletedRows} items deleted successfully." };
            }
            catch (Exception ex)
            {
                return new DeleteRSSResponse
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