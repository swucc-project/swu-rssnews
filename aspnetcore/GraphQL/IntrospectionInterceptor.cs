using HotChocolate.AspNetCore;
using HotChocolate.Execution;
using Microsoft.Extensions.Primitives;
using System.Net;

namespace rssnews.GraphQL;

public class IntrospectionInterceptor : DefaultHttpRequestInterceptor
{
    private readonly IWebHostEnvironment _environment;
    private readonly ILogger<IntrospectionInterceptor> _logger;

    public IntrospectionInterceptor(
        IWebHostEnvironment environment,
        ILogger<IntrospectionInterceptor> logger)
    {
        _environment = environment;
        _logger = logger;
    }

    public override ValueTask OnCreateAsync(
        HttpContext context,
        IRequestExecutor requestExecutor,
        OperationRequestBuilder requestBuilder,
        CancellationToken cancellationToken)
    {
        try
        {
            var allowHeader = context.Request.Headers.TryGetValue("X-Allow-Introspection", out var v)
                ? v.ToString().Trim()
                : string.Empty;

            var allowByHeader = string.Equals(allowHeader, "true", StringComparison.OrdinalIgnoreCase)
                              || string.Equals(allowHeader, "1", StringComparison.OrdinalIgnoreCase);

            // หากมี X-Forwarded-For ให้ใช้ตัวแรก (client IP)
            string? remoteIp = null;
            if (context.Request.Headers.TryGetValue("X-Forwarded-For", out var xff) && !StringValues.IsNullOrEmpty(xff))
            {
                remoteIp = xff.ToString().Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)[0];
            }
            remoteIp ??= context.Connection.RemoteIpAddress?.ToString();

            var isInternal = false;
            if (!string.IsNullOrWhiteSpace(remoteIp) && IPAddress.TryParse(remoteIp, out var parsed))
            {
                isInternal = IsLocalOrPrivate(parsed);
            }

            var allow = _environment.IsDevelopment() || allowByHeader || isInternal;
            if (allow)
            {
                requestBuilder.AllowIntrospection();
                _logger.LogDebug("Introspection allowed for {IP} (Header={Header}, Dev={Dev})", remoteIp, allowHeader, _environment.IsDevelopment());
            }
            else
            {
                _logger.LogDebug("Introspection blocked for {IP} (Header={Header}, Dev={Dev})", remoteIp, allowHeader, _environment.IsDevelopment());
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error evaluating introspection permission; defaulting to blocked.");
        }

        return base.OnCreateAsync(context, requestExecutor, requestBuilder, cancellationToken);
    }

    private static bool IsLocalOrPrivate(IPAddress ip)
    {
        if (IPAddress.IsLoopback(ip)) return true;

        if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
        {
            var b = ip.GetAddressBytes();
            if (b[0] == 10) return true;
            if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
            if (b[0] == 192 && b[1] == 168) return true;
            if (b[0] == 127) return true;
            return false;
        }

        if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetworkV6)
        {
            if (IPAddress.IsLoopback(ip)) return true;
            var bytes = ip.GetAddressBytes();
            if ((bytes[0] & 0xfe) == 0xfc) return true; // fc00::/7 unique local
            if ((bytes[0] == 0xfe) && ((bytes[1] & 0xc0) == 0x80)) return true; // fe80::/10 link-local
        }

        return false;
    }
}