using Microsoft.AspNetCore.Mvc;
using InertiaCore;
using ServiceStack;

namespace rssnews.Controllers
{
    /// <summary>
    /// Base controller สำหรับ Inertia.js pages
    /// </summary>
    public abstract class InertiaController : Controller
    {
        protected IActionResult Inertia(string component, object? props = null)
        {
            var mergedProps = new Dictionary<string, object>();

            // Add shared data
            var sharedData = GetSharedData();
            if (sharedData != null)
            {
                foreach (var prop in sharedData.GetType().GetProperties())
                {
                    mergedProps[ToCamelCase(prop.Name)] = prop.GetValue(sharedData) ?? new { };
                }
            }

            // Add component-specific props
            if (props != null)
            {
                foreach (var prop in props.GetType().GetProperties())
                {
                    mergedProps[ToCamelCase(prop.Name)] = prop.GetValue(props) ?? new { };
                }
            }

            // ✅ แก้ไขจุดที่ 1: ใช้ Object Initializer
            var response = new Response(
                component: component,
                props: mergedProps,
                rootView: Request.Path.ToString(),
                version: "1.0"
            );

            return new InertiaResult(response, this);
        }

        protected IActionResult InertiaRedirect(string url)
        {
            if (IsInertiaRequest)
            {
                Response.Headers["X-Inertia-Location"] = url;
                return StatusCode(409);
            }
            return Redirect(url);
        }

        protected IActionResult InertiaError(string message, int statusCode = 500)
        {
            if (IsInertiaRequest)
            {
                return Inertia("Error", new { Message = message, StatusCode = statusCode });
            }
            return StatusCode(statusCode, new { error = message });
        }

        protected bool IsInertiaRequest => Request.Headers["X-Inertia"].ToString() == "true";

        protected virtual object GetSharedData()
        {
            var session = HttpContext.Items.TryGetValue("ss-session", out var s) ? s as AuthUserSession : null;
            return new
            {
                Auth = new
                {
                    User = session?.IsAuthenticated == true
                        ? new { session.UserName, session.DisplayName, session.Roles }
                        : null
                },
                Flash = TempData["Message"] != null
                    ? new { Message = TempData["Message"], Type = TempData["MessageType"] }
                    : null
            };
        }

        protected void SetFlashMessage(string message, string type = "info")
        {
            TempData["Message"] = message;
            TempData["MessageType"] = type;
        }

        private static string ToCamelCase(string str)
        {
            if (string.IsNullOrEmpty(str) || char.IsLower(str[0])) return str;
            return char.ToLowerInvariant(str[0]) + str.Substring(1);
        }
    }

    public class InertiaResult : IActionResult
    {
        private readonly Response _response;
        private readonly Controller _controller;

        public InertiaResult(Response response, Controller controller)
        {
            _response = response;
            _controller = controller;
        }

        public async Task ExecuteResultAsync(ActionContext context)
        {

            if (context.HttpContext.Request.Headers["X-Inertia"] == "true")
            {
                context.HttpContext.Response.Headers["X-Inertia"] = "true";
                context.HttpContext.Response.Headers["Vary"] = "Accept";
                var jsonResult = new JsonResult(_response);
                await jsonResult.ExecuteResultAsync(context);
                return;
            }

            _controller.ViewData.Model = _response;
            var viewResult = new ViewResult
            {
                ViewName = "~/Views/Index.cshtml",
                ViewData = _controller.ViewData,
                TempData = _controller.TempData
            };

            await viewResult.ExecuteResultAsync(context);
        }
    }
}