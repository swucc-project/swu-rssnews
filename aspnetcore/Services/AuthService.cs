using ServiceStack;

namespace rssnews.Services
{
    [Route("/auth/check", "GET")]
    public class CheckAuth : IReturn<CheckAuthResponse> { }

    public class CheckAuthResponse
    {
        public bool IsAuthenticated { get; set; }
        public string? UserId { get; set; }
        public string? UserName { get; set; }
        public string? DisplayName { get; set; }
        public List<string> Roles { get; set; } = new();
    }

    public class CustonUserSession : AuthUserSession
    {
        public string? BuasriID { get; set; } = "";
    }
    public class AuthService : Service
    {
        public object Get(CheckAuth request)
        {
            var session = SessionAs<CustomUserSession>();

#pragma warning disable CS8602 // Dereference of a possibly null reference.
            return new CheckAuthResponse
            {
                IsAuthenticated = session.IsAuthenticated,
                UserId = session.UserAuthId,
                UserName = session.UserName,
                DisplayName = session.DisplayName,
                Roles = session.Roles ?? new List<string>()
            };
#pragma warning restore CS8602 // Dereference of a possibly null reference.
        }
    }
}