using DataHub.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DataHub.SvcRecalcs.DataAccess
{
    public class TimeCardConfiguration : IEntityTypeConfiguration<TimeHistDetailEF> {
        public void Configure(EntityTypeBuilder<TimeHistDetailEF> builder) {
            builder.ToTable("tblTimeHistDetail");

            builder.HasKey(x => x.RecordID);
            builder.Property(c => c.RecordID).HasColumnName("RecordId");

            builder.Property(m => m.Client).HasColumnName("Client");
            builder.Property(m => m.GroupCode).HasColumnName("GroupCode");
            builder.Property(m => m.SSN).HasColumnName("SSN");
            builder.Property(m => m.PayrollPeriodEndDate).HasColumnName("PayrollPeriodEndDate");
        }
    }
}
