using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WeatherShare.Data;
using WeatherShare.Models;

namespace WeatherShare.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class WeatherReportsController : ControllerBase
    {
        private readonly WeatherReportContext _context;

        public WeatherReportsController(WeatherReportContext context)
        {
            _context = context;
        }

        // GET: api/WeatherReports
        [HttpGet]
        public async Task<ActionResult<IEnumerable<WeatherReport>>> GetReports()
        {
            return await _context.Reports.ToListAsync();
        }

        // GET: api/WeatherReports/5
        [HttpGet("{id}")]
        public async Task<ActionResult<WeatherReport>> GetWeatherReport(Guid id)
        {
            var weatherReport = await _context.Reports.FindAsync(id);

            if (weatherReport == null)
            {
                return NotFound();
            }

            return weatherReport;
        }

        // PUT: api/WeatherReports/5
        // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
        [HttpPut("{id}")]
        public async Task<IActionResult> PutWeatherReport(Guid id, WeatherReport weatherReport)
        {
            if (id != weatherReport.WeatherReportId)
            {
                return BadRequest();
            }

            _context.Entry(weatherReport).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!WeatherReportExists(id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        // POST: api/WeatherReports
        // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
        [HttpPost]
        public async Task<ActionResult<WeatherReport>> PostWeatherReport(WeatherReport weatherReport)
        {
            _context.Reports.Add(weatherReport);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetWeatherReport", new { id = weatherReport.WeatherReportId }, weatherReport);
        }

        // DELETE: api/WeatherReports/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteWeatherReport(Guid id)
        {
            var weatherReport = await _context.Reports.FindAsync(id);
            if (weatherReport == null)
            {
                return NotFound();
            }

            _context.Reports.Remove(weatherReport);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool WeatherReportExists(Guid id)
        {
            return _context.Reports.Any(e => e.WeatherReportId == id);
        }
    }
}
