using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using DataHub.SvcKafkaPublisher.Services;

namespace DataHub.SvcKafkaPublisher.Controllers
{
    [Route("KafkaPub")]
    public class KafkaPubController : Controller
    {

        IKafkaPubService _kafkaPubService;

        public KafkaPubController(IKafkaPubService kafkaPubService) {
            _kafkaPubService = kafkaPubService;
        }

        [HttpGet]
        public IEnumerable<string> Get()
        {
            return new string[] { "value1", "value2" };
        }

        [Produces("text/html")]
        [HttpGet("/Version")]
        public string Version() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>Kafka Publisher Service</strong></p><p>&nbsp;</p>" +
                "<p>Here are the relevant API Calls:</p>" +
                "<ul><li><p>/KafkaPub/{RecordId}</p></li><li><p>/KafkaPub/Version</p></li></ul></font></ html > ";
            return msg;
        }

    }
}
