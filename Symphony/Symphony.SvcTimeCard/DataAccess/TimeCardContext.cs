using DataHub.Models;
using DataHub.SvcRecalcs.DataAccess;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.SvcTimeCard.DataAccess
{
    public class TimeCardContext : DbContext
    {
        public DbSet<TimeHistDetailEF> timecard { get; set; }

        public TimeCardContext(DbContextOptions<TimeCardContext> options) : base(options) {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder) {
            modelBuilder.ApplyConfiguration(new TimeCardConfiguration());
        }
    }
}
