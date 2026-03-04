using HotChocolate.Execution;
using System.Security.Cryptography;
using System.Text;

namespace rssnews.Services;

public class GraphQLSchemaService
{
    private readonly IRequestExecutorResolver _resolver;
    private readonly IWebHostEnvironment _env;

    public GraphQLSchemaService(
        IRequestExecutorResolver resolver,
        IWebHostEnvironment env)
    {
        _resolver = resolver;
        _env = env;
    }

    public async Task<string> GetSchemaTextAsync()
    {
        var executor = await _resolver.GetRequestExecutorAsync();
        return executor.Schema.Print();
    }

    public async Task<string> GetSchemaHashAsync()
    {
        var text = await GetSchemaTextAsync();
        using var sha = SHA256.Create();
        return Convert.ToHexString(
            sha.ComputeHash(Encoding.UTF8.GetBytes(text))
        ).ToLowerInvariant();
    }

    public string GetSchemaVersion()
        => typeof(Program).Assembly.GetName().Version?.ToString() ?? "1.0.0";

    public DateTime? GetLastModified()
    {
        try
        {
            var path = typeof(Program).Assembly.Location;
            return File.Exists(path)
                ? File.GetLastWriteTimeUtc(path)
                : null;
        }
        catch { return null; }
    }

    public bool IsInternalRequest(HttpContext context)
    {
        var ip = context.Connection.RemoteIpAddress?.ToString();
        return _env.IsDevelopment()
            || ip == "127.0.0.1"
            || ip == "::1"
            || ip?.StartsWith("10.") == true
            || ip?.StartsWith("172.") == true
            || ip?.StartsWith("192.168.") == true;
    }

    public async Task ExportAsync(string path)
    {
        var text = await GetSchemaTextAsync();
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path)!);
        await File.WriteAllTextAsync(path, text);
    }
}