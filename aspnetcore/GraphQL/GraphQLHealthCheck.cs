using Microsoft.Extensions.Diagnostics.HealthChecks;
using HotChocolate.Execution;

namespace rssnews.GraphQL
{
    public class GraphQLHealthCheck(IRequestExecutorResolver executorResolver) : IHealthCheck
    {
        private readonly IRequestExecutorResolver _executorResolver = executorResolver;

        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            try
            {
                // Logic เดิมที่คุณเขียนไว้
                await _executorResolver.GetRequestExecutorAsync(cancellationToken: cancellationToken);
                return HealthCheckResult.Healthy("GraphQL ready");
            }
            catch (Exception ex)
            {
                return HealthCheckResult.Unhealthy("GraphQL not ready", exception: ex);
            }
        }
    }
}