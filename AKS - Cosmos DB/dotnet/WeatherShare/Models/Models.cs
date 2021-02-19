using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace WeatherShare.Models
{
    public class User
    {
        [Key]
        public Guid UserId { get; set; }
        [Required, MaxLength(30)]
        public string Name { get; set; }
        [Required, MaxLength(50)]
        public string Email { get; set; }
        [StringLength(500)]
        public string About { get; set; }
    }

    public class WeatherReport
    {
        public Guid WeatherReportId { get; set; }
        public string Reporter { get; set; }
        public string Location { get; set; }
        public string Summary { get; set; }
        public DateTime Date { get; set; }
    }
}