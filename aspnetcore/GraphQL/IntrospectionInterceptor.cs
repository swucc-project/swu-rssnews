using HotChocolate.AspNetCore;
using HotChocolate.Execution;

namespace rssnews.GraphQL
{
    public class IntrospectionInterceptor(IWebHostEnvironment env) : DefaultHttpRequestInterceptor
    {
        private readonly IWebHostEnvironment _env = env;

        public override ValueTask OnCreateAsync(HttpContext context, IRequestExecutor requestExecutor, OperationRequestBuilder requestBuilder, CancellationToken cancellationToken)
        {
            if (_env.IsDevelopment())
            {
                requestBuilder.AllowIntrospection();
            }
            else
            {
                if (context.Request.Headers.ContainsKey("X-Allow-Introspection") && (context.Request.Headers["X-Allow-Introspection"] == "true"))
                {
                    requestBuilder.AllowIntrospection();
                }
            }

            return base.OnCreateAsync(context, requestExecutor, requestBuilder,
                cancellationToken);
        }
    }
}