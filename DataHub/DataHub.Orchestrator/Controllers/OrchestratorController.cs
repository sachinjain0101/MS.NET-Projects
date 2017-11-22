using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using DataHub.Commons;
using Microsoft.Extensions.Options;

namespace DataHub.Orchestrator.Controllers
{
    [Route("Orchestrator")]
    public class OrchestratorController : Controller
    {
        DataHubServicesUrls _urls;

        public OrchestratorController(IOptions<DataHubServicesUrls> urls) {
            _urls = urls.Value;
        }

        [Produces("text/html")]
        [HttpGet("GetUrls")]
        public string GetUrls() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>Orchestrator Service URL Info</strong></p><p>&nbsp;</p>" +
                "<p>The Urls for the API Calls:</p>" +
                "<ul><li><p>"+ _urls.UrlSvcRecalcs + "</p></li></ul>" +
                "<ul><li><p>" + _urls.UrlSvcTimeCard + "</p></li></ul>" +
                "<ul><li><p>" + _urls.UrlSvcKafkaPub + "</p></li></ul>" +
                "</font></ html > ";
            return msg;
        }

        [Produces("text/html")]
        [HttpGet("/Version")]
        public string Version() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>Orchestrator Service</strong></p><p>&nbsp;</p>" +
                "<p>Here are the relevant API Calls:</p>" +
                "<ul><li><p>/Orchestrator/StartProcess/10</p></li></ul></font></ html > ";
            return msg;
        }
    }
}
