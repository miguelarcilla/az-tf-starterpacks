using Microsoft.EntityFrameworkCore;
using WeatherShare.Models;

namespace WeatherShare.Data
{
    public class WeatherShareContext : DbContext
    {
        public WeatherShareContext(DbContextOptions<WeatherShareContext> options) : base(options)
        { }

        public DbSet<WeatherReport> Reports { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<WeatherReport>().ToTable("WeatherReports");
        }
    }

    public static class DbInitializer
    {
        public static void Initialize(WeatherShareContext context)
        {
            context.Database.EnsureCreated();
        }
    }
}
