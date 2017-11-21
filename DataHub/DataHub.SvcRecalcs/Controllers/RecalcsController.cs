using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using DataHub.SvcRecalcs.Services;
using DataHub.Models;
using System.Net.Http;
using System.Net.Http.Headers;

namespace DataHub.SvcRecalcs.Controllers
{
    [Route("Recalcs")]
    public class RecalcsController : Controller
    {
        private readonly IRecalcsService _recalcsService;

        public RecalcsController(IRecalcsService recalcsService) {
            _recalcsService = recalcsService;
        }

        [HttpGet("{recordId}")]
        public Recalc Get(int recordId) {
            var recalc = _recalcsService.GetByRecordId(recordId);
            return recalc;
        }

        [HttpGet("TopN/{numRecs}")]
        public List<Recalc> GetTopN(int numRecs) {
            var recalcs = _recalcsService.GetNRecalcs(numRecs);
            return (List<Recalc>) recalcs;
        }

        [Produces("text/html")]
        [HttpGet("/Version")]
        public string Version() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>Recalcs Service</strong></p><p>&nbsp;</p>" +
                "<p>Here are the relevant API Calls:</p>" +
                "<ul><li><p>/Recalcs/{RecordId}</p></li><li><p>/Recalcs/TopN/{NumberOfRecords}</p></li></ul></font></ html > ";
            return msg;
        }



    }
}
