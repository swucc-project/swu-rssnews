namespace rssnews.Services
{
    public interface ISwitchLocalizationService
    {
        string GetRequestLanguage(HttpContext context);
    }

    public class SwitchLocalizationService : ISwitchLocalizationService
    {
        private static readonly string DefaultLanguage = "th-TH";
        private static readonly HashSet<string> SupportedLanguages = new() { "th-TH", "en-US" };

        public string GetRequestLanguage(HttpContext context)
        {
            var language = context.Request.Headers["Accept-Language"].ToString() ?? DefaultLanguage;
            if (!string.IsNullOrWhiteSpace(language) && SupportedLanguages.Contains(language))
            {
                return language;
            }
            return DefaultLanguage;
        }
    }
}