using Microsoft.EntityFrameworkCore;
using WeatherShare.Models;

namespace WeatherShare.Data
{
    public class WeatherReportContext : DbContext
    {
        public WeatherReportContext(DbContextOptions<WeatherReportContext> options) : base(options)
        { }

        public DbSet<WeatherReport> Reports { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<WeatherReport>().ToTable("WeatherReports");
        }
    }
}
