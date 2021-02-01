using System;

namespace WeatherShare.Models
{
    public class WeatherReport
    {
        public Guid WeatherReportId { get; set; }
        public string Reporter { get; set; }
        public string Location { get; set; }
        public string Summary { get; set; }
        public DateTime Date { get; set; }
    }
}