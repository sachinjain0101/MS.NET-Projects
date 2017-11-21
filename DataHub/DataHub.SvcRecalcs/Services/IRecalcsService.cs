using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DataHub.Models;

namespace DataHub.SvcRecalcs.Services
{
    public interface IRecalcsService {
        Recalc GetByRecordId(int recordId);
        List<Recalc> GetNRecalcs(int numRecs);
    }
}
