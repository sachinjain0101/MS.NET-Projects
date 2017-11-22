using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using DataHub.SvcTimeCard.Services;
using DataHub.Models;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net;
using Newtonsoft.Json;
using System.IO;
using DataHub.SvcTimeCard.DataAccess;
using System.Data.SqlClient;
using System.Text;

namespace DataHub.SvcRecalcs.Controllers
{
    [Route("TimeCard")]
    public class TimeCardController : Controller
    {
        private readonly ITimeCardService _timeCardService;

        public TimeCardController(ITimeCardService timeCardService) {
            _timeCardService = timeCardService;
        }

        [HttpGet("GetRecalcs")]
        public List<Recalc> GetRecalcs(int recordId) {
            List<Recalc> recalcs = new List<Recalc>();


            var webRequest = System.Net.WebRequest.Create("http://localhost:51002/Recalcs/TopN/100");
            if (webRequest != null) {
                webRequest.Method = WebRequestMethods.Http.Get;
                webRequest.ContentType = "application/json";
                using (var reponse = webRequest.GetResponse().GetResponseStream())
                    using (var reader = new StreamReader(reponse))
                        recalcs = JsonConvert. DeserializeObject<List<Recalc>>(reader.ReadToEnd());
            }
            _timeCardService.GetTimeCardData(recalcs);

            return recalcs;
        }

        [HttpGet("GetTimeCardsEF")]
        public List<TimeHistDetailEF> GetTimeCardsEF() {
            List<Recalc> recalcs = new List<Recalc>();

            var webRequest = System.Net.WebRequest.Create("http://localhost:51002/Recalcs/TopN/100");
            if (webRequest != null) {
                webRequest.Method = WebRequestMethods.Http.Get;
                webRequest.ContentType = "application/json";
                using (var reponse = webRequest.GetResponse().GetResponseStream())
                using (var reader = new StreamReader(reponse))
                    recalcs = JsonConvert.DeserializeObject<List<Recalc>>(reader.ReadToEnd());
            }

            return _timeCardService.GetTimeCards(recalcs);



        }

        [HttpGet("TopN/{numRecs}")]
        public List<TimeHistDetailEF> GetTopN(int numRecs) {
            var timecards = _timeCardService.GetNTimeCards(numRecs);
            return (List<TimeHistDetailEF>)timecards;
        }

        [HttpGet("TestPost")]
        public List<Recalc> TestPost() {
            List<Recalc> recalcs = GetRecalcs(10);
            WebRequest webRequest = WebRequest.Create("http://localhost:51002/Recalcs/UpdateRecalcs");
            StringContent content = new StringContent(JsonConvert.SerializeObject(recalcs), Encoding.UTF8, "application/json");
            Task<byte[]> t = content.ReadAsByteArrayAsync();
            var byteContent = t.Result;

            if (webRequest != null) {
                webRequest.Method = WebRequestMethods.Http.Post;
                webRequest.ContentType = "application/json";
                webRequest.Timeout = 20000;

                using (Stream dataStream = webRequest.GetRequestStream())
                    dataStream.Write(byteContent, 0, byteContent.Length);


                using (var reponse = webRequest.GetResponse().GetResponseStream())
                using (var reader = new StreamReader(reponse))
                    recalcs = JsonConvert.DeserializeObject<List<Recalc>>(reader.ReadToEnd());
            }
            return recalcs;

        }

        [HttpGet("GetTimeCards/{numRecs}")]
        public List<TimeHistDetail> GetTimeCards(int numRecs) {
            List<Recalc> recalcs = new List<Recalc>();
            string url = "http://localhost:51002/Recalcs/TopN/{0}";
            url = String.Format(url, numRecs);
            var webRequest = System.Net.WebRequest.Create(url);
            if (webRequest != null) {
                webRequest.Method = WebRequestMethods.Http.Get;
                webRequest.ContentType = "application/json";
                using (var reponse = webRequest.GetResponse().GetResponseStream())
                using (var reader = new StreamReader(reponse))
                    recalcs = JsonConvert.DeserializeObject<List<Recalc>>(reader.ReadToEnd());
            }

            return _timeCardService.GetTimeCardData(recalcs);

            
        }

        [Produces("text/html")]
        [HttpGet("/Version")]
        public string Version() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>TimeCard Service</strong></p><p>&nbsp;</p>" +
                "<p>Here are the relevant API Calls:</p>" +
                "<ul><li><p>/TimeCard/GetTimeCards/100</p></li><li><p>/TimeCard/GetRecalcs</p></li></ul></font></ html > ";
            return msg;
        }



    }
}
