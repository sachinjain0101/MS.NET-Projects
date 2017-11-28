using DataHub.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.SvcRecalcs.DataAccess
{
    public class RecalcsContext : DbContext
    {
        public DbSet<Recalc> recalcs { get; set; }

        public RecalcsContext(DbContextOptions<RecalcsContext> options) : base(options) {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder) {
            modelBuilder.ApplyConfiguration(new RecalcsConfiguration());
        }
    }
}
