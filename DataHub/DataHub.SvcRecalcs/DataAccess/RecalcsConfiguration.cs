using DataHub.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DataHub.SvcRecalcs.DataAccess
{
    public class RecalcsConfiguration : IEntityTypeConfiguration<Recalc> {
        public void Configure(EntityTypeBuilder<Recalc> builder) {
            builder.ToTable("tblRecalcs");

            builder.HasKey(x => x.RecordID);
            builder.Property(c => c.RecordID).HasColumnName("RecordId");

            builder.Property(m => m.Client).HasColumnName("Client");
            builder.Property(m => m.GroupCode).HasColumnName("GroupCode");
            builder.Property(m => m.SSN).HasColumnName("SSN");
            builder.Property(m => m.PPED).HasColumnName("PPED");
            builder.Property(m => m.Status).HasColumnName("Status");
        }
    }
}
