using InertiaCore;
using Microsoft.AspNetCore.Mvc;

namespace rssnews.Controllers
{
    public class UserManualController : Controller
    {
        [Route("/usermanual")]
        public IActionResult Index()
        {
            return Inertia.Render("ManualApi");
        }
    }
}