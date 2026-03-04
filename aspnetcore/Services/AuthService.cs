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

    // ✅ ลบ CustonUserSession ออก เพราะ CustomUserSession ถูกประกาศใน Configure.Auth.cs แล้ว
    // ถ้าต้องการเพิ่ม field ให้ไปเพิ่มที่ Configure.Auth.cs แทน

    public class AuthService : Service
    {
        public object Get(CheckAuth request)
        {
            var session = SessionAs<CustomUserSession>();

            // ✅ ใช้ null-conditional operators เพื่อความปลอดภัย
            return new CheckAuthResponse
            {
                IsAuthenticated = session?.IsAuthenticated ?? false,
                UserId = session?.UserAuthId,
                UserName = session?.UserName,
                DisplayName = session?.DisplayName,
                Roles = session?.Roles ?? new List<string>()
            };
        }
    }
}