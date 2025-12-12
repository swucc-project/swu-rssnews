using Microsoft.AspNetCore.Authorization;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace rssnews.Swagger
{
    /// <summary>
    /// Operation Filter สำหรับเพิ่มข้อมูล Authorization ใน Swagger UI
    /// </summary>
    public class AuthorizationOperationFilter : IOperationFilter
    {
        public void Apply(OpenApiOperation operation, OperationFilterContext context)
        {
            // ตรวจสอบว่า endpoint ต้องการ authentication หรือไม่
            var hasAuthorize = context.MethodInfo.DeclaringType != null &&
                (context.MethodInfo.DeclaringType.GetCustomAttributes(true).OfType<AuthorizeAttribute>().Any() ||
                 context.MethodInfo.GetCustomAttributes(true).OfType<AuthorizeAttribute>().Any());

            var hasAllowAnonymous = context.MethodInfo.DeclaringType != null &&
                (context.MethodInfo.DeclaringType.GetCustomAttributes(true).OfType<AllowAnonymousAttribute>().Any() ||
                 context.MethodInfo.GetCustomAttributes(true).OfType<AllowAnonymousAttribute>().Any());

            if (!hasAuthorize || hasAllowAnonymous)
            {
                return;
            }

            operation.Responses.TryAdd("401", new OpenApiResponse { Description = "Unauthorized - ต้องเข้าสู่ระบบ" });
            operation.Responses.TryAdd("403", new OpenApiResponse { Description = "Forbidden - ไม่มีสิทธิ์เข้าถึง" });

            var cookieScheme = new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Cookie"
                }
            };

            operation.Security = new List<OpenApiSecurityRequirement>
            {
                new OpenApiSecurityRequirement
                {
                    [cookieScheme] = new List<string>()
                }
            };
        }
    }
}