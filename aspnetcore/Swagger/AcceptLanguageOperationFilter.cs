using Microsoft.OpenApi.Any;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace rssnews.Swagger
{
    /// <summary>
    /// Operation Filter สำหรับเพิ่ม Accept-Language header ให้กับทุก API endpoint
    /// </summary>
    public class AcceptLanguageOperationFilter : IOperationFilter
    {
        public void Apply(OpenApiOperation operation, OperationFilterContext context)
        {
            operation.Parameters ??= new List<OpenApiParameter>();

            // ตรวจสอบว่ามี Accept-Language อยู่แล้วหรือไม่
            if (operation.Parameters.Any(p => p.Name == "Accept-Language" && p.In == ParameterLocation.Header))
            {
                return;
            }

            operation.Parameters.Add(new OpenApiParameter
            {
                Name = "Accept-Language",
                In = ParameterLocation.Header,
                Description = "ระบุภาษาที่ต้องการในการตอบกลับจาก Server\n\n" +
                             "รองรับภาษา:\n" +
                             "- `th-TH` - ภาษาไทย (ค่าเริ่มต้น)\n" +
                             "- `en-US` - ภาษาอังกฤษ",
                Required = false,
                Schema = new OpenApiSchema
                {
                    Type = "string",
                    Default = new OpenApiString("th-TH"),
                    Enum = new List<IOpenApiAny>
                    {
                        new OpenApiString("th-TH"),
                        new OpenApiString("en-US")
                    }
                }
            });
        }
    }
}