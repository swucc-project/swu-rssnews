using InertiaCore;
using Microsoft.AspNetCore.Mvc;
using Vite.AspNetCore;
using ServiceStack;
using ServiceStack.Web;
using HotChocolate.Authorization;
using rssnews.Services;
using rssnews.ServiceModel;

namespace rssnews.Controllers
{
    [Microsoft.AspNetCore.Mvc.Route("rss")]
    public class RSSController(IConfiguration configuration, IViteManifest manifest, ISwitchLocalizationService currentLanguage) : Controller
    {
        private readonly IConfiguration _configuration = configuration;
        private readonly IViteManifest _manifest = manifest;
        private readonly ISwitchLocalizationService _currentLanguage = currentLanguage;

        [HttpGet("")]
        public IActionResult Index()
        {
            var language = _currentLanguage.GetRequestLanguage(HttpContext);
            return Inertia.Render("Index", new { message = "จัดการข่าวสารและกิจกรรมของมหาวิทยาลัยศรีนครินทรวิโรฒ" });
        }

        [HttpGet("add")]
        [Authenticate]
        public IActionResult Add()
        {
            return Inertia.Render("AddRSSItem");
        }

        // --- Action สำหรับหน้าแก้ไขข่าว ---
        // Route: /rss/update/{ItemId}
        [HttpGet("update/{itemId}")]
        [Authenticate]
        [Authorize(Policy = "EditRSSPolicy")]
        public IActionResult Update(string itemId)
        {
            if (string.IsNullOrEmpty(itemId))
            {
                return BadRequest("Item ID is required");
            }
            return Inertia.Render("UpdateRSSItem", new
            {
                itemID = itemId
            });
        }

        [HttpGet("delete/{itemId}")]
        [Authenticate]
        public IActionResult Delete(string itemId)
        {
            return Inertia.Render("DeleteRSSItem", new
            {
                id = itemId
            });
        }
        [HttpGet("signin")]
        public IActionResult SignIn([FromQuery(Name = "ReturnUrl")] string? returnUrl = null)
        {
            return Inertia.Render("Signin", new { ReturnUrl = returnUrl });
        }
        [HttpGet("failed")]
        public IActionResult Failed()
        {
            return Inertia.Render("Failure");
        }
        [HttpGet("view")]
        public IActionResult ViewXML()
        {
            return Inertia.Render("Feed");
        }
        [HttpGet("view/{CategoryId}")]
        public IActionResult ViewXMLByCategory(string CategoryId)
        {
            return Inertia.Render("Feed", new { categoryId = CategoryId });
        }
        [HttpGet("news-feed")]
        public IActionResult NewsFeed([FromQuery] string? categoryId = null)
        {
            return Inertia.Render("NewsFeed", new { categoryId });
        }
        [HttpGet("feed-xml")]
        [Produces("application/rss+xml")]
        public IActionResult RetrieveRssFeed([FromQuery] string? categoryName = null)
        {
            try
            {
                // สร้าง Request DTO เพื่อส่งให้ ServiceStack Service
                var request = new GetRSSFeed { CategoryName = categoryName };

                // เรียกใช้ ServiceStack Service โดยตรงผ่าน HostContext
                // ServiceStack จะจัดการ Dependency Injection ของ Service ให้เอง
                using var service = HostContext.ResolveService<RSSFeedService>((IRequest)HttpContext);

                // เรียก method ใน service และ return ผลลัพธ์ (ซึ่งเป็น HttpResult ที่มี XML)
                var response = service.Get(request);

                return response as IActionResult ?? new EmptyResult();
            }
            catch (Exception ex)
            {
                // จัดการ Error case
                return StatusCode(500, $"An error occurred while generating the RSS feed: {ex.Message}");
            }
        }
    }
}