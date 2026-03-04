using InertiaCore;
using Microsoft.AspNetCore.Mvc;

namespace rssnews.Controllers
{
    [ApiExplorerSettings(IgnoreApi = true)]
    public class UserManualController : Controller
    {
        [HttpGet]
        [Route("/usermanual")]
        public IActionResult Index()
        {
            return Inertia.Render("ManualApi");
        }
    }
}