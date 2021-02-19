namespace WeatherShare.Data
{
    public static class DbInitializer
    {
        public static void Initialize(UserContext userContext, WeatherReportContext WeatherReportContext)
        {
            userContext.Database.EnsureCreated();
            WeatherReportContext.Database.EnsureCreated();
        }
    }
}
