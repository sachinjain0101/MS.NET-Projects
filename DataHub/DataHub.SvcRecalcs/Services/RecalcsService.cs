using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DataHub.Models;
using DataHub.SvcRecalcs.DataAccess;

namespace DataHub.SvcRecalcs.Services
{
    public class RecalcsService : IRecalcsService {

        private RecalcsContext _context;

        public RecalcsService(RecalcsContext context) {
            _context = context;
        }

        public Recalc GetByRecordId(int recordId) {
            var recalc = _context.recalcs.Single(x => x.RecordID == recordId);
            return recalc;
        }

        public List<Recalc> GetNRecalcs(int numRecs) {
            var recalcs = _context.recalcs.OrderByDescending(m => m.RecordID).Take(numRecs);
            return recalcs.ToList<Recalc>();
        }

    }
}
