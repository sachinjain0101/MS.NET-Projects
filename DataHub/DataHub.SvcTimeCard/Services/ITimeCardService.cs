using DataHub.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.SvcTimeCard.Services
{
    public interface ITimeCardService
    {
        List<TimeHistDetail> GetTimeCardData(List<Recalc> recalcs);
        TimeHistDetailEF GetByRecordId(int recordId);
        List<TimeHistDetailEF> GetNTimeCards(int numRecs);
        List<TimeHistDetailEF> GetTimeCards(List<Recalc> list);
    }
}
